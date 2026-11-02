-- Schema dashboard GEO Growth Engine (Supabase / Lovable Cloud, PostgreSQL 15+).
-- Principio: tutto filtrato per client_id con RLS. Le scritture "di sistema" (visite, aziende, contatti,
-- eventi, riunioni, invii) avvengono con service_role (plugin ed edge function), che bypassa RLS.
-- Gli utenti 'authenticated' possono solo leggere, più modificare/approvare le proprie bozze.

create type app_role as enum ('client_owner', 'client_member');
create type email_stato as enum ('bozza', 'approvata', 'scartata', 'inviata', 'errore');
create type reply_class as enum ('interessato', 'non_interessato', 'da_ricontattare', 'fuori_ufficio', 'bounce', 'altro');
create type provider as enum ('gmail', 'outlook', 'google_calendar', 'outlook_calendar');

create table clients (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  nome text not null,
  dominio text,
  branding jsonb not null default '{}'::jsonb,       -- logo_url, colore, nome_visualizzato
  servizi jsonb not null default '{}'::jsonb,        -- {"leadradar": true, "articoli": true, ...}
  latenza_visite text not null default 'non_dichiarata', -- tempo_reale | minuti | giornaliera | manuale | non_dichiarata
  retention_giorni int not null default 365 check (retention_giorni >= 30),
  attivo boolean not null default true,
  created_at timestamptz not null default now()
);

create table agency_admins (user_id uuid primary key);   -- auth.users.id

create table client_users (
  user_id uuid not null,
  client_id uuid not null references clients(id) on delete cascade,
  ruolo app_role not null,
  primary key (user_id, client_id)
);

create table companies (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  nome text not null,
  dominio text,
  settore text, dimensione text, paese text,
  icp_score numeric,
  prima_visita timestamptz, ultima_visita timestamptz,
  fonte text not null default 'sconosciuta',
  stato_contatto text not null default 'nuova',
  created_at timestamptz not null default now(),
  unique (client_id, nome)
);
create index on companies (client_id, ultima_visita desc);

create table visits (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  visited_at timestamptz not null,
  pagine jsonb not null default '[]'::jsonb,
  durata_sec int, sorgente text, device text,
  fonte text not null default 'sconosciuta',
  dedupe_key text not null,
  created_at timestamptz not null default now(),
  unique (client_id, dedupe_key)
);
create index on visits (client_id, visited_at desc);

create table contacts (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  company_id uuid not null references companies(id) on delete cascade,
  nome text, ruolo text, email text, linkedin text,
  fonte text not null default 'sconosciuta',
  created_at timestamptz not null default now()
);
create index on contacts (client_id, company_id);

create table email_messages (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  company_id uuid references companies(id) on delete set null,
  contact_id uuid references contacts(id) on delete set null,
  destinatario text not null,
  oggetto text not null,
  corpo text not null,
  stato email_stato not null default 'bozza',
  provider_message_id text, thread_id text,
  inviata_da text, inviata_il timestamptz,
  errore text,
  created_at timestamptz not null default now()
);
create index on email_messages (client_id, stato, created_at desc);

create table email_events (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  message_id uuid not null references email_messages(id) on delete cascade,
  tipo text not null check (tipo in ('risposta', 'bounce')),
  classificazione reply_class,
  estratto text,
  ricevuta_il timestamptz not null default now()
);
create index on email_events (client_id, ricevuta_il desc);

create table meetings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  company_id uuid references companies(id) on delete set null,
  message_id uuid references email_messages(id) on delete set null,
  titolo text, inizio timestamptz not null, fine timestamptz,
  partecipanti jsonb not null default '[]'::jsonb,
  origine text not null check (origine in ('calendario', 'link_prenotazione')),
  stato text not null default 'confermato',
  external_id text,
  unique (client_id, external_id)
);

create table integrations (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  provider provider not null,
  account_email text,
  stato text not null default 'collegata' check (stato in ('collegata', 'scaduta', 'revocata')),
  scopes text[] not null default '{}',
  ultimo_sync timestamptz,
  unique (client_id, provider)
);

-- Token OAuth: RLS attiva e NESSUNA policy => leggibili solo da service_role. Cifrare il valore (Vault/pgsodium).
create table integration_secrets (
  integration_id uuid primary key references integrations(id) on delete cascade,
  token_cifrato text not null,
  aggiornato_il timestamptz not null default now()
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references clients(id) on delete cascade,
  tipo text not null check (tipo in ('digest', 'piano_editoriale', 'analisi', 'guida')),
  titolo text not null, periodo text,
  storage_path text not null,
  created_at timestamptz not null default now()
);

create table audit_log (
  id bigint generated always as identity primary key,
  client_id uuid not null references clients(id) on delete cascade,
  user_id uuid, azione text not null, entita text, entita_id uuid,
  dettagli jsonb, created_at timestamptz not null default now()
);

-- ---------- Funzioni di accesso (SECURITY DEFINER: evitano ricorsione RLS) ----------
create or replace function is_agency_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from agency_admins where user_id = auth.uid()) $$;

create or replace function has_client_access(cid uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select is_agency_admin() or exists (select 1 from client_users where user_id = auth.uid() and client_id = cid) $$;

create or replace function is_client_owner(cid uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select is_agency_admin() or exists (select 1 from client_users where user_id = auth.uid() and client_id = cid and ruolo = 'client_owner') $$;

-- ---------- RLS ----------
alter table clients enable row level security;
alter table agency_admins enable row level security;
alter table client_users enable row level security;
alter table companies enable row level security;
alter table visits enable row level security;
alter table contacts enable row level security;
alter table email_messages enable row level security;
alter table email_events enable row level security;
alter table meetings enable row level security;
alter table integrations enable row level security;
alter table integration_secrets enable row level security;
alter table reports enable row level security;
alter table audit_log enable row level security;

create policy clients_read on clients for select to authenticated using (has_client_access(id));
create policy clients_admin_write on clients for all to authenticated using (is_agency_admin()) with check (is_agency_admin());
create policy agency_admins_read on agency_admins for select to authenticated using (user_id = auth.uid());
create policy client_users_read on client_users for select to authenticated using (user_id = auth.uid() or is_agency_admin());
create policy client_users_admin_write on client_users for all to authenticated using (is_agency_admin()) with check (is_agency_admin());

create policy companies_read on companies for select to authenticated using (has_client_access(client_id));
create policy visits_read on visits for select to authenticated using (has_client_access(client_id));
create policy contacts_read on contacts for select to authenticated using (has_client_access(client_id));
create policy email_events_read on email_events for select to authenticated using (has_client_access(client_id));
create policy meetings_read on meetings for select to authenticated using (has_client_access(client_id));
create policy reports_read on reports for select to authenticated using (has_client_access(client_id));
create policy integrations_read on integrations for select to authenticated using (is_client_owner(client_id));
create policy audit_read on audit_log for select to authenticated using (is_client_owner(client_id));

create policy email_read on email_messages for select to authenticated using (has_client_access(client_id));
-- Il titolare modifica/approva/scarta SOLO bozze del proprio cliente. L'invio (inviata/errore) è solo service_role.
create policy email_owner_update on email_messages for update to authenticated
  using (is_client_owner(client_id) and stato = 'bozza')
  with check (is_client_owner(client_id) and stato in ('bozza', 'approvata', 'scartata'));

-- Privilegi di colonna: l'utente non può spostare una bozza su altro cliente né toccare campi di sistema.
revoke all on all tables in schema public from anon, authenticated;
grant select on clients, client_users, agency_admins, companies, visits, contacts, email_messages,
  email_events, meetings, integrations, reports, audit_log to authenticated;
grant insert, update, delete on clients, client_users to authenticated;   -- limitato dalle policy agli agency_admin
grant update (oggetto, corpo, stato) on email_messages to authenticated;
-- integration_secrets: nessun grant a authenticated/anon.

-- Audit automatico delle transizioni di stato email
create or replace function log_email_state() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.stato is distinct from old.stato then
    insert into audit_log (client_id, user_id, azione, entita, entita_id, dettagli)
    values (new.client_id, auth.uid(), 'email_' || new.stato::text, 'email_messages', new.id,
            jsonb_build_object('da', old.stato, 'a', new.stato, 'destinatario', new.destinatario));
  end if;
  return new;
end $$;
create trigger trg_email_state after update on email_messages
  for each row execute function log_email_state();

-- ---------- Viste (security_invoker: rispettano la RLS dell'utente) ----------
create view v_client_kpis with (security_invoker = true) as
select c.id as client_id,
  (select count(*) from companies x where x.client_id = c.id and x.prima_visita >= now() - interval '30 days') as aziende_30g,
  (select count(*) from companies x where x.client_id = c.id and coalesce(x.icp_score, 0) >= 70) as aziende_calde,
  (select count(*) from email_messages m where m.client_id = c.id and m.stato = 'inviata') as email_inviate,
  (select count(distinct e.message_id) from email_events e where e.client_id = c.id and e.tipo = 'risposta') as email_con_risposta,
  (select count(*) from meetings t where t.client_id = c.id and t.inizio >= now()) as appuntamenti_futuri
from clients c;
grant select on v_client_kpis to authenticated;

-- ---------- Realtime (solo su Supabase) ----------
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table visits, email_events, email_messages;
  end if;
end $$;
