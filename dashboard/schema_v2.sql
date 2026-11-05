-- Schema v2 — migrazione ADDITIVA da applicare dopo schema.sql e schema_storage.sql.
-- Aggiunge: profilo Outreach (ICP + tono di voce, versionato), valutazioni ICP, area Visibilità
-- (posizionamento, visibilità nelle IA, citazioni, crescita) e promemoria periodico al cliente.
-- Stessi principi di schema.sql: RLS per client_id; scritture "di sistema" solo con service_role.

create type icp_stato as enum ('in_target', 'fuori_target', 'da_verificare');
create type reminder_frequenza as enum ('mensile', 'quindicinale');
create type ai_provider as enum ('openai', 'gemini', 'google_aio', 'perplexity', 'altro');

-- ---------- OUTREACH: profilo ICP + tono di voce (versioni immutabili) ----------
-- Il titolare crea una NUOVA versione a ogni modifica; la versione attiva è la più recente.
create table outreach_profiles (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  versione int not null,
  icp_prompt text not null check (length(trim(icp_prompt)) >= 20),       -- testo libero: chi è il target e chi escludere
  tono_prompt text not null check (length(trim(tono_prompt)) >= 20),     -- testo libero: tono di voce, parole da usare/evitare, firma
  offerta text not null default '',                                      -- cosa vende il cliente, per chi, con quali prove
  esempi jsonb not null default '[]'::jsonb,                             -- 2-3 email di esempio approvate: [{"oggetto":"..","corpo":".."}]
  max_contatti_settimana int not null default 10 check (max_contatti_settimana between 1 and 200),
  giorni_invio smallint[] not null default '{1,2,3,4,5}' check (giorni_invio <@ array[1,2,3,4,5,6,7]::smallint[]),
  creato_da uuid,
  created_at timestamptz not null default now(),
  unique (client_id, versione)
);
create index on outreach_profiles (client_id, versione desc);

create or replace function set_profile_version() returns trigger language plpgsql as $$
begin
  select coalesce(max(versione), 0) + 1 into new.versione from outreach_profiles where client_id = new.client_id;
  new.creato_da := coalesce(new.creato_da, auth.uid());
  return new;
end $$;
create trigger trg_profile_version before insert on outreach_profiles
  for each row execute function set_profile_version();

create view v_outreach_attivo with (security_invoker = true) as
select distinct on (client_id) * from outreach_profiles order by client_id, versione desc;

-- Valutazioni ICP: una per (azienda, versione del profilo). Si rivaluta solo se il profilo cambia.
create table icp_evaluations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  profile_id uuid not null references outreach_profiles(id) on delete cascade,
  stato icp_stato not null,
  motivazione text not null,                                  -- 1-3 frasi
  evidenze jsonb not null default '[]'::jsonb,                -- [{"dato":"fatturato","valore":"n.d.","fonte":"Apollo","data":"2026-11-05"}]
  override_stato icp_stato,                                   -- decisione manuale del titolare
  override_da uuid, override_il timestamptz, override_nota text,
  created_at timestamptz not null default now(),
  unique (company_id, profile_id)
);
create index on icp_evaluations (client_id, stato);

-- Stato effettivo per azienda: override del titolare > valutazione sulla versione attiva del profilo.
create view v_company_icp with (security_invoker = true) as
select c.id as company_id, c.client_id,
  coalesce(e.override_stato, e.stato) as stato_effettivo,
  e.stato as stato_valutato, e.motivazione, e.evidenze, e.profile_id, e.id as evaluation_id
from companies c
left join v_outreach_attivo p on p.client_id = c.client_id
left join icp_evaluations e on e.company_id = c.id and e.profile_id = p.id;

-- Le bozze nascono solo per aziende "in target" sulla versione attiva del profilo.
alter table email_messages add column profile_id uuid references outreach_profiles(id) on delete set null;
create or replace function guard_draft_in_target() returns trigger language plpgsql security definer set search_path = public as $$
declare s icp_stato;
begin
  if new.company_id is null then raise exception 'bozza senza azienda: non consentita'; end if;
  select stato_effettivo into s from v_company_icp_internal where company_id = new.company_id;
  if s is distinct from 'in_target' then
    raise exception 'azienda non in target (stato: %): bozza non consentita', coalesce(s::text, 'non valutata');
  end if;
  return new;
end $$;
-- vista interna (senza security_invoker) usata solo dal trigger
create view v_company_icp_internal as
select c.id as company_id, coalesce(e.override_stato, e.stato) as stato_effettivo
from companies c
left join lateral (select id from outreach_profiles p where p.client_id = c.client_id order by versione desc limit 1) pa on true
left join icp_evaluations e on e.company_id = c.id and e.profile_id = pa.id;
revoke all on v_company_icp_internal from anon, authenticated;
create trigger trg_guard_draft before insert on email_messages
  for each row when (new.stato = 'bozza') execute function guard_draft_in_target();

-- ---------- VISIBILITÀ ----------
create table keyword_rankings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  keyword text not null, url text, posizione int, volume int, difficolta int,
  lingua text not null default 'it', paese text not null default 'IT',
  rilevato_il date not null, fonte text not null,
  unique (client_id, keyword, lingua, paese, rilevato_il)
);
create index on keyword_rankings (client_id, rilevato_il desc);

create table ai_visibility_snapshots (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  provider ai_provider not null,
  visibilita_pct numeric check (visibilita_pct between 0 and 100),
  rank_medio numeric, share_of_voice numeric, menzioni int, sentiment numeric,
  rilevato_il date not null, fonte text not null,
  unique (client_id, provider, rilevato_il)
);
create index on ai_visibility_snapshots (client_id, rilevato_il desc);

create table ai_citations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  provider ai_provider not null,
  prompt text not null,
  url_citato text, dominio text,
  cita_cliente boolean not null default false,
  competitor text,                                           -- nome/dominio del competitor citato, se presente
  rilevato_il date not null, fonte text not null
);
create index on ai_citations (client_id, rilevato_il desc);

create table traffic_history (
  client_id uuid not null references clients(id) on delete cascade,
  mese date not null check (mese = date_trunc('month', mese)::date),
  traffico_organico int, keyword_organiche int, domain_authority int,
  backlink int, domini_referenti int,
  fonte text not null,
  primary key (client_id, mese)
);

-- ---------- PROMEMORIA AL CLIENTE ----------
create table reminder_settings (
  client_id uuid primary key references clients(id) on delete cascade,
  attivo boolean not null default false,                     -- disattivo finché l'agenzia non approva il testo
  frequenza reminder_frequenza not null default 'mensile',
  mittente text not null default 'commerciale@propagandaadv.com',
  oggetto text not null default 'La tua dashboard è aggiornata',
  corpo text not null default 'Buongiorno, nella tua dashboard trovi i dati aggiornati su visite, outreach e visibilità. Accedi qui: {{link}}',
  testo_approvato_il timestamptz,                            -- l'invio parte solo se valorizzato
  ultimo_invio timestamptz,
  prossimo_invio timestamptz
);

create table reminder_log (
  id bigint generated always as identity primary key,
  client_id uuid not null references clients(id) on delete cascade,
  inviato_il timestamptz not null default now(),
  destinatari int not null default 0,
  esito text not null check (esito in ('inviato', 'errore', 'saltato')),
  errore text
);

-- Preferenze dell'utente (tabella separata: NON si aggiunge una policy di auto-update su client_users,
-- perché permetterebbe di cambiare il proprio ruolo). Nessuna riga = promemoria attivo.
create table user_prefs (
  user_id uuid not null,
  client_id uuid not null references clients(id) on delete cascade,
  notifiche_promemoria boolean not null default true,
  primary key (user_id, client_id)
);

-- Casella dell'agenzia (mittente dei promemoria): solo service_role (come integration_secrets).
create table agency_mailbox (
  email text primary key,
  stato text not null default 'da_collegare' check (stato in ('da_collegare', 'collegata', 'scaduta', 'revocata')),
  token_cifrato text, aggiornato_il timestamptz not null default now()
);

-- ---------- RLS ----------
alter table outreach_profiles enable row level security;
alter table icp_evaluations enable row level security;
alter table keyword_rankings enable row level security;
alter table ai_visibility_snapshots enable row level security;
alter table ai_citations enable row level security;
alter table traffic_history enable row level security;
alter table reminder_settings enable row level security;
alter table reminder_log enable row level security;
alter table user_prefs enable row level security;
alter table agency_mailbox enable row level security;   -- nessuna policy: solo service_role

create policy profiles_read on outreach_profiles for select to authenticated using (has_client_access(client_id));
create policy profiles_owner_insert on outreach_profiles for insert to authenticated with check (is_client_owner(client_id));
create policy icp_read on icp_evaluations for select to authenticated using (has_client_access(client_id));
create policy icp_owner_override on icp_evaluations for update to authenticated
  using (is_client_owner(client_id)) with check (is_client_owner(client_id));
create policy rankings_read on keyword_rankings for select to authenticated using (has_client_access(client_id));
create policy aivis_read on ai_visibility_snapshots for select to authenticated using (has_client_access(client_id));
create policy citations_read on ai_citations for select to authenticated using (has_client_access(client_id));
create policy traffic_read on traffic_history for select to authenticated using (has_client_access(client_id));
create policy reminder_read on reminder_settings for select to authenticated using (is_client_owner(client_id));
create policy reminder_admin_write on reminder_settings for all to authenticated using (is_agency_admin()) with check (is_agency_admin());
create policy reminder_log_read on reminder_log for select to authenticated using (is_client_owner(client_id));
create policy prefs_read on user_prefs for select to authenticated using (user_id = auth.uid());
create policy prefs_insert on user_prefs for insert to authenticated with check (user_id = auth.uid() and has_client_access(client_id));
create policy prefs_update on user_prefs for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Privilegi di colonna: il titolare cambia solo l'override ICP e (per sé) il flag notifiche in user_prefs.
grant select on outreach_profiles, icp_evaluations, keyword_rankings, ai_visibility_snapshots,
  ai_citations, traffic_history, reminder_settings, reminder_log to authenticated;
grant select on v_outreach_attivo, v_company_icp to authenticated;
grant insert (client_id, icp_prompt, tono_prompt, offerta, esempi, max_contatti_settimana, giorni_invio) on outreach_profiles to authenticated;
grant update (override_stato, override_da, override_il, override_nota) on icp_evaluations to authenticated;
grant insert, update, delete on reminder_settings to authenticated;           -- limitato dalle policy agli agency_admin
grant select on user_prefs to authenticated;
grant insert (user_id, client_id, notifiche_promemoria) on user_prefs to authenticated;
grant update (notifiche_promemoria) on user_prefs to authenticated;
-- agency_mailbox: nessun grant.

-- Audit: ogni nuova versione di profilo e ogni override ICP
create or replace function log_profile_and_override() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'outreach_profiles' then
    insert into audit_log (client_id, user_id, azione, entita, entita_id, dettagli)
    values (new.client_id, auth.uid(), 'profilo_outreach_v' || new.versione, 'outreach_profiles', new.id, '{}'::jsonb);
  elsif new.override_stato is distinct from old.override_stato then
    insert into audit_log (client_id, user_id, azione, entita, entita_id, dettagli)
    values (new.client_id, auth.uid(), 'icp_override', 'icp_evaluations', new.id,
            jsonb_build_object('da', old.override_stato, 'a', new.override_stato, 'nota', new.override_nota));
  end if;
  return new;
end $$;
create trigger trg_profile_audit after insert on outreach_profiles for each row execute function log_profile_and_override();
create trigger trg_icp_audit after update on icp_evaluations for each row execute function log_profile_and_override();
