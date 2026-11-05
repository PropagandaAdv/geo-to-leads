-- Collaudo del database (schema v1 + v2 + v2.1) con dati di prova AUTOSUFFICIENTI e annullamento garantito.
-- Crea due clienti fittizi (zz-collaudo-a/b) e utenti fittizi, esegue i controlli impersonando ogni ruolo, poi termina con
-- un'ECCEZIONE che riporta i risultati: l'eccezione annulla l'intera transazione (nessun dato residuo, nessuna tabella residua).
-- Funziona su PostgreSQL locale (con tests/supabase_stub.sql) e sul database reale (Lovable Cloud / Supabase).
begin;
create table public.zz_res (nome text, ok boolean, dettaglio text, t timestamptz default clock_timestamp());
grant all on public.zz_res to authenticated, anon;
create function public.zz_chk(n text, c boolean, d text default null) returns void language sql as
$$ insert into public.zz_res(nome, ok, dettaglio) values (n, coalesce(c, false), d) $$;
grant execute on function public.zz_chk(text, boolean, text) to authenticated, anon;
create function public.zz_as(uid text) returns void language sql as $$ select set_config('request.jwt.claim.sub', uid, true) $$;
grant execute on function public.zz_as(text) to authenticated, anon;

-- ---- dati di prova ----
insert into clients (id, slug, nome) values
  ('a0a0a0a0-0000-4000-8000-00000000000a', 'zz-collaudo-a', 'Collaudo A (fittizio)'),
  ('b0b0b0b0-0000-4000-8000-00000000000b', 'zz-collaudo-b', 'Collaudo B (fittizio)');
insert into client_users values
  ('a1a1a1a1-0000-4000-8000-0000000000a1', 'a0a0a0a0-0000-4000-8000-00000000000a', 'client_owner'),
  ('a2a2a2a2-0000-4000-8000-0000000000a2', 'a0a0a0a0-0000-4000-8000-00000000000a', 'client_member'),
  ('b1b1b1b1-0000-4000-8000-0000000000b1', 'b0b0b0b0-0000-4000-8000-00000000000b', 'client_owner');
insert into agency_admins values ('99999999-0000-4000-8000-000000000099');
insert into companies (id, client_id, nome) values
  ('c1c1c1c1-0000-4000-8000-0000000000c1', 'a0a0a0a0-0000-4000-8000-00000000000a', 'Azienda Test A'),
  ('c2c2c2c2-0000-4000-8000-0000000000c2', 'b0b0b0b0-0000-4000-8000-00000000000b', 'Azienda Test B');
insert into outreach_profiles (client_id, icp_prompt, tono_prompt) values
  ('a0a0a0a0-0000-4000-8000-00000000000a', 'ICP del cliente A (fittizio) abbastanza lungo', 'Tono del cliente A (fittizio) abbastanza lungo'),
  ('b0b0b0b0-0000-4000-8000-00000000000b', 'ICP del cliente B (fittizio) abbastanza lungo', 'Tono del cliente B (fittizio) abbastanza lungo');
insert into icp_evaluations (client_id, company_id, profile_id, stato, motivazione)
select p.client_id, case when p.client_id = 'a0a0a0a0-0000-4000-8000-00000000000a' then 'c1c1c1c1-0000-4000-8000-0000000000c1'::uuid else 'c2c2c2c2-0000-4000-8000-0000000000c2'::uuid end,
       p.id, case when p.client_id = 'a0a0a0a0-0000-4000-8000-00000000000a' then 'fuori_target'::icp_stato else 'in_target'::icp_stato end, 'test'
from outreach_profiles p where p.client_id in ('a0a0a0a0-0000-4000-8000-00000000000a', 'b0b0b0b0-0000-4000-8000-00000000000b');
insert into traffic_history (client_id, mese, traffico_organico, fonte) values
  ('a0a0a0a0-0000-4000-8000-00000000000a', '2026-10-01', 100, 'test'), ('b0b0b0b0-0000-4000-8000-00000000000b', '2026-10-01', 200, 'test');
insert into keyword_rankings (client_id, keyword, posizione, rilevato_il, fonte) values
  ('a0a0a0a0-0000-4000-8000-00000000000a', 'kw a', null, '2026-11-05', 'test'), ('b0b0b0b0-0000-4000-8000-00000000000b', 'kw b', 3, '2026-11-05', 'test');
insert into ai_visibility_snapshots (client_id, provider, visibilita_pct, rilevato_il, fonte) values
  ('a0a0a0a0-0000-4000-8000-00000000000a', 'openai', 0, '2026-11-05', 'test'), ('b0b0b0b0-0000-4000-8000-00000000000b', 'openai', 5, '2026-11-05', 'test');
insert into ai_citations (client_id, url_citato, piattaforme, rilevato_il, fonte) values
  ('a0a0a0a0-0000-4000-8000-00000000000a', 'https://a.example/', '{openai}', '2026-11-05', 'test'), ('b0b0b0b0-0000-4000-8000-00000000000b', 'https://b.example/', '{gemini}', '2026-11-05', 'test');
insert into reminder_settings (client_id) values ('a0a0a0a0-0000-4000-8000-00000000000a'), ('b0b0b0b0-0000-4000-8000-00000000000b');
insert into agency_mailbox (email, token_cifrato) values ('zz-collaudo@test.invalid', 'segreto-fittizio');

-- ======== OWNER A ========
set local role authenticated; select zz_as('a1a1a1a1-0000-4000-8000-0000000000a1');
select zz_chk('A1 owner A vede solo il proprio cliente', (select count(*) from clients where slug like 'zz-collaudo%') = 1);
select zz_chk('A2 owner A vede i propri dati di tutte le tabelle v2 (1+1+1+1+1+1)',
  (select count(*) from outreach_profiles) = 1 and (select count(*) from icp_evaluations) = 1 and (select count(*) from traffic_history) = 1
  and (select count(*) from keyword_rankings) = 1 and (select count(*) from ai_visibility_snapshots) = 1 and (select count(*) from ai_citations) = 1);
select zz_chk('A3 owner A non vede nulla di B', (select count(*) from keyword_rankings where client_id = 'b0b0b0b0-0000-4000-8000-00000000000b') = 0
  and (select count(*) from ai_citations where client_id = 'b0b0b0b0-0000-4000-8000-00000000000b') = 0);
select zz_chk('A4 owner A legge le impostazioni promemoria', (select count(*) from reminder_settings) = 1);
do $$ begin begin insert into outreach_profiles (client_id, icp_prompt, tono_prompt) values ('b0b0b0b0-0000-4000-8000-00000000000b', 'ICP altrui testo lungo a sufficienza ok', 'Tono altrui testo lungo a sufficienza ok');
  perform zz_chk('A6 owner A NON scrive profili di B', false, 'inserimento riuscito');
  exception when insufficient_privilege then perform zz_chk('A6 owner A NON scrive profili di B', true); end; end $$;
do $$ begin begin update outreach_profiles set icp_prompt = 'modifica retroattiva testo lungo a sufficienza';
  perform zz_chk('A7 versioni di profilo immutabili', false, 'update riuscito');
  exception when insufficient_privilege then perform zz_chk('A7 versioni di profilo immutabili', true); end; end $$;
update icp_evaluations set override_stato = 'in_target', override_nota = 'ok titolare';
select zz_chk('A8 owner A imposta l''override ICP', (select override_stato::text from icp_evaluations) = 'in_target');
do $$ begin begin update icp_evaluations set stato = 'in_target';
  perform zz_chk('A9 owner A NON modifica la valutazione di sistema', false, 'update riuscito');
  exception when insufficient_privilege then perform zz_chk('A9 owner A NON modifica la valutazione di sistema', true); end; end $$;
do $$ begin begin perform 1 from agency_mailbox; perform zz_chk('A10 agency_mailbox inaccessibile', false, 'letta');
  exception when insufficient_privilege then perform zz_chk('A10 agency_mailbox inaccessibile', true); end; end $$;
do $$ begin begin insert into ai_citations (client_id, url_citato, rilevato_il, fonte) values ('a0a0a0a0-0000-4000-8000-00000000000a', 'https://x.example/', current_date, 't');
  perform zz_chk('A11 il cliente NON scrive citazioni', false, 'scritta');
  exception when insufficient_privilege then perform zz_chk('A11 il cliente NON scrive citazioni', true); end; end $$;
do $$ begin begin insert into keyword_rankings (client_id, keyword, rilevato_il, fonte) values ('a0a0a0a0-0000-4000-8000-00000000000a', 'x', current_date, 't');
  perform zz_chk('A12 il cliente NON scrive posizionamento', false, 'scritto');
  exception when insufficient_privilege then perform zz_chk('A12 il cliente NON scrive posizionamento', true); end; end $$;
insert into user_prefs (user_id, client_id, notifiche_promemoria) values ('a1a1a1a1-0000-4000-8000-0000000000a1', 'a0a0a0a0-0000-4000-8000-00000000000a', false);
select zz_chk('A13 l''utente gestisce le proprie notifiche', (select count(*) from user_prefs) = 1);
do $$ begin begin insert into user_prefs (user_id, client_id) values ('a2a2a2a2-0000-4000-8000-0000000000a2', 'a0a0a0a0-0000-4000-8000-00000000000a');
  perform zz_chk('A14 non si scrivono preferenze di altri utenti', false, 'scritta');
  exception when insufficient_privilege then perform zz_chk('A14 non si scrivono preferenze di altri utenti', true); end; end $$;
update reminder_settings set attivo = true, testo_approvato_il = now();
reset role;
select zz_chk('A15 il titolare NON attiva né approva il promemoria', (select attivo from reminder_settings where client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') = false);

-- ======== MEMBER A ========
set local role authenticated; select zz_as('a2a2a2a2-0000-4000-8000-0000000000a2');
select zz_chk('M1 member A legge il profilo', (select count(*) from outreach_profiles) >= 1);
select zz_chk('M2 member A non vede le impostazioni promemoria', (select count(*) from reminder_settings) = 0);
do $$ begin begin insert into outreach_profiles (client_id, icp_prompt, tono_prompt) values ('a0a0a0a0-0000-4000-8000-00000000000a', 'member non puo scrivere profilo, testo lungo', 'member non puo scrivere tono, testo lungo');
  perform zz_chk('M3 member A NON scrive profili', false, 'scritto');
  exception when insufficient_privilege then perform zz_chk('M3 member A NON scrive profili', true); end; end $$;
update icp_evaluations set override_stato = 'fuori_target';
update client_users set ruolo = 'client_owner' where user_id = 'a2a2a2a2-0000-4000-8000-0000000000a2';
reset role;
select zz_chk('M4 member A NON imposta override ICP', (select override_stato::text from icp_evaluations where client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') = 'in_target');
select zz_chk('M5 member A NON si promuove a owner', (select ruolo::text from client_users where user_id = 'a2a2a2a2-0000-4000-8000-0000000000a2') = 'client_member');

-- ======== OWNER B ========
set local role authenticated; select zz_as('b1b1b1b1-0000-4000-8000-0000000000b1');
select zz_chk('B1 owner B vede solo i propri dati', (select count(*) from keyword_rankings) = 1 and (select count(*) from ai_citations) = 1
  and (select count(*) from outreach_profiles) = 1 and (select count(*) from traffic_history) = 1);
select zz_chk('B2 owner B non vede dati di A', (select count(*) from outreach_profiles where client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') = 0
  and (select count(*) from ai_visibility_snapshots where client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') = 0);
reset role;

-- ======== AGENCY ADMIN ========
set local role authenticated; select zz_as('99999999-0000-4000-8000-000000000099');
select zz_chk('G1 agency_admin vede entrambi i clienti di prova', (select count(*) from keyword_rankings where client_id in ('a0a0a0a0-0000-4000-8000-00000000000a', 'b0b0b0b0-0000-4000-8000-00000000000b')) = 2 and (select count(*) from reminder_settings where client_id in ('a0a0a0a0-0000-4000-8000-00000000000a', 'b0b0b0b0-0000-4000-8000-00000000000b')) = 2);
update reminder_settings set attivo = true where client_id = 'a0a0a0a0-0000-4000-8000-00000000000a';
reset role;
select zz_chk('G2 agency_admin può attivare il promemoria', (select attivo from reminder_settings where client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') = true);

-- ======== ANONIMO ========
set local role anon;
do $$ begin begin perform 1 from outreach_profiles; perform zz_chk('N1 anon NON legge i profili', false, 'letti');
  exception when insufficient_privilege then perform zz_chk('N1 anon NON legge i profili', true); end; end $$;
do $$ begin begin perform 1 from ai_citations; perform zz_chk('N2 anon NON legge le citazioni', false, 'lette');
  exception when insufficient_privilege then perform zz_chk('N2 anon NON legge le citazioni', true); end; end $$;
do $$ begin begin perform 1 from v_client_kpis; perform zz_chk('N3 anon NON legge la vista KPI', false, 'letta');
  exception when insufficient_privilege then perform zz_chk('N3 anon NON legge la vista KPI', true); end; end $$;
do $$ begin begin perform 1 from agency_mailbox; perform zz_chk('N4 anon NON legge agency_mailbox', false, 'letta');
  exception when insufficient_privilege then perform zz_chk('N4 anon NON legge agency_mailbox', true); end; end $$;
reset role;

-- ======== REGOLE DI SISTEMA (service role) ========
do $$ begin begin insert into email_messages (client_id, company_id, destinatario, oggetto, corpo) values ('b0b0b0b0-0000-4000-8000-00000000000b', null, 'x@test.invalid', 'o', 'c');
  perform zz_chk('S1 bozza senza azienda rifiutata', false, 'creata');
  exception when raise_exception then perform zz_chk('S1 bozza senza azienda rifiutata', true); end; end $$;
-- azienda A: valutazione fuori_target + override in_target => stato effettivo in_target => bozza ammessa
insert into email_messages (client_id, company_id, destinatario, oggetto, corpo) values ('a0a0a0a0-0000-4000-8000-00000000000a', 'c1c1c1c1-0000-4000-8000-0000000000c1', 'x@test.invalid', 'o', 'c');
select zz_chk('S2 bozza ammessa per azienda in target (override)', (select count(*) from email_messages where destinatario = 'x@test.invalid' and client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') = 1);
-- ora il titolare A modifica il profilo (nuova versione v2): l'override e la valutazione appartengono alla v1
set local role authenticated; select zz_as('a1a1a1a1-0000-4000-8000-0000000000a1');
insert into outreach_profiles (client_id, icp_prompt, tono_prompt) values ('a0a0a0a0-0000-4000-8000-00000000000a', 'ICP aggiornato dal titolare, testo lungo a sufficienza', 'Tono aggiornato dal titolare, testo lungo a sufficienza');
select zz_chk('A5 owner A crea una nuova versione del profilo (v2)', (select max(versione) from outreach_profiles) = 2);
reset role;
-- la v2 del profilo A (creata da owner A) è la versione attiva e non ha ancora valutazioni: l'azienda risulta "non valutata"
do $$ begin begin insert into email_messages (client_id, company_id, destinatario, oggetto, corpo) values ('a0a0a0a0-0000-4000-8000-00000000000a', 'c1c1c1c1-0000-4000-8000-0000000000c1', 'y@test.invalid', 'o', 'c');
  perform zz_chk('S3 nuova versione del profilo => azienda da rivalutare (anche override decade), bozza rifiutata', false, 'creata');
  exception when raise_exception then perform zz_chk('S3 nuova versione del profilo => azienda da rivalutare (anche override decade), bozza rifiutata', true); end; end $$;
insert into email_messages (client_id, company_id, destinatario, oggetto, corpo) values ('b0b0b0b0-0000-4000-8000-00000000000b', 'c2c2c2c2-0000-4000-8000-0000000000c2', 'z@test.invalid', 'o', 'c');
select zz_chk('S4 bozza ammessa per azienda in target (valutazione)', (select count(*) from email_messages where destinatario = 'z@test.invalid') = 1);
select zz_chk('S5 audit: nuova versione profilo e override registrati',
  (select count(*) from audit_log where azione = 'profilo_outreach_v2' and client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') = 1 and (select count(*) from audit_log where azione = 'icp_override' and client_id = 'a0a0a0a0-0000-4000-8000-00000000000a') >= 1);

-- ======== RISULTATO (l'eccezione annulla tutto) ========
do $$ declare r text; tot int; ko int;
begin
  select count(*), count(*) filter (where not ok), string_agg(case when ok then 'OK   ' else 'FALLITO ' end || nome || coalesce(' [' || dettaglio || ']', ''), E'\n' order by t)
    into tot, ko, r from public.zz_res;
  raise exception E'RISULTATI COLLAUDO (transazione annullata): % controlli, % falliti\n%', tot, ko, r;
end $$;
