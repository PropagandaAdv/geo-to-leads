-- Test RLS: un utente del cliente A non deve leggere né modificare nulla del cliente B.
-- Esegui dopo stub (solo locale) e schema.sql. Fallisce con eccezione al primo controllo non rispettato.
\set ON_ERROR_STOP on
grant select, insert, update, delete on all tables in schema public to service_role;

-- Dati fittizi (DEMO)
insert into clients (id, slug, nome) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'demo-a', 'Demo A (fittizio)'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'demo-b', 'Demo B (fittizio)');
insert into agency_admins values ('99999999-0000-0000-0000-000000000009');
insert into client_users values
  ('a1a1a1a1-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'client_owner'),
  ('a2a2a2a2-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'client_member'),
  ('b1b1b1b1-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000002', 'client_owner');
insert into companies (id, client_id, nome) values
  ('c0000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'Azienda A'),
  ('c0000000-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000002', 'Azienda B');
insert into visits (client_id, company_id, visited_at, dedupe_key) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-00000000000a', now(), 'k1'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-00000000000b', now(), 'k2');
insert into email_messages (id, client_id, company_id, destinatario, oggetto, corpo) values
  ('e0000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-00000000000a', 'x@a.example', 'o', 'c'),
  ('e0000000-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-00000000000b', 'x@b.example', 'o', 'c');
insert into email_messages (id, client_id, destinatario, oggetto, corpo) values
  ('e0000000-0000-0000-0000-00000000000c', 'aaaaaaaa-0000-0000-0000-000000000001', 'y@a.example', 'o', 'c');
insert into integrations (id, client_id, provider) values
  ('f0000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'gmail');
insert into integration_secrets values ('f0000000-0000-0000-0000-00000000000a', 'segreto-fittizio', now());

create or replace function t_as(uid text) returns void language plpgsql as
$$ begin perform set_config('request.jwt.claim.sub', uid, false); end $$;
create or replace function t_assert(cond boolean, msg text) returns void language plpgsql as
$$ begin if not cond then raise exception 'FALLITO: %', msg; end if; raise notice 'ok: %', msg; end $$;

-- 1) Owner A
set role authenticated; select t_as('a1a1a1a1-0000-0000-0000-00000000000a');
select t_assert((select count(*) from companies) = 1, 'owner A vede solo le sue aziende');
select t_assert((select count(*) from visits where client_id='bbbbbbbb-0000-0000-0000-000000000002') = 0, 'owner A non vede visite di B');
select t_assert((select count(*) from email_messages) = 2, 'owner A vede solo le sue email (2 di A, 0 di B)');
select t_assert((select count(*) from clients) = 1, 'owner A vede solo il proprio cliente');
select t_assert((select count(*) from v_client_kpis) = 1, 'vista KPI rispetta la RLS');
select t_assert((select count(*) from integrations) = 1, 'owner A vede le proprie integrazioni');
do $$ begin perform 1 from integration_secrets; raise exception 'FALLITO: token leggibili'; exception when insufficient_privilege then raise notice 'ok: token OAuth non leggibili da authenticated'; end $$;
-- approva bozza propria
update email_messages set stato='approvata' where id='e0000000-0000-0000-0000-00000000000a';
select t_assert((select stato from email_messages where id='e0000000-0000-0000-0000-00000000000a') = 'approvata', 'owner A approva la propria bozza');
-- non può segnare 'inviata' (bozza nuova) né modificare righe già approvate
do $$ declare n int; begin
  begin
    update email_messages set stato='inviata' where id='e0000000-0000-0000-0000-00000000000c';
    get diagnostics n = row_count;
    if n > 0 then raise exception 'FALLITO: owner ha impostato inviata'; end if;
  exception when insufficient_privilege or others then
    if sqlerrm like 'FALLITO%' then raise; end if; raise notice 'ok: owner non può impostare stato inviata (%)', sqlerrm; end;
  update email_messages set corpo='x' where id='e0000000-0000-0000-0000-00000000000a';  -- già approvata
  get diagnostics n = row_count;
  if n > 0 then raise exception 'FALLITO: modificata email già approvata'; end if;
  raise notice 'ok: email già approvata non più modificabile dal cliente';
end $$;
-- non può modificare email di B
update email_messages set stato='scartata' where id='e0000000-0000-0000-0000-00000000000b';
reset role;
select t_assert((select stato from email_messages where id='e0000000-0000-0000-0000-00000000000b') = 'bozza', 'owner A non modifica le email di B');
-- non può cambiare client_id (privilegio di colonna)
set role authenticated; select t_as('a1a1a1a1-0000-0000-0000-00000000000a');
do $$ begin
  update email_messages set client_id='bbbbbbbb-0000-0000-0000-000000000002' where id='e0000000-0000-0000-0000-00000000000a';
  raise exception 'FALLITO: client_id modificabile';
exception when insufficient_privilege then raise notice 'ok: client_id non modificabile'; end $$;
-- nessuna scrittura su visite/aziende
do $$ begin
  insert into visits (client_id, company_id, visited_at, dedupe_key) values ('aaaaaaaa-0000-0000-0000-000000000001','c0000000-0000-0000-0000-00000000000a',now(),'zz');
  raise exception 'FALLITO: authenticated ha inserito visite';
exception when insufficient_privilege then raise notice 'ok: authenticated non scrive visite'; end $$;
-- non può auto-assegnarsi a un cliente
do $$ begin
  insert into client_users values ('a1a1a1a1-0000-0000-0000-00000000000a','bbbbbbbb-0000-0000-0000-000000000002','client_owner');
  raise exception 'FALLITO: auto-assegnazione riuscita';
exception when others then if sqlerrm like 'FALLITO%' then raise; end if; raise notice 'ok: auto-assegnazione bloccata'; end $$;

-- 2) Member A: sola lettura
select t_as('a2a2a2a2-0000-0000-0000-00000000000a');
select t_assert((select count(*) from companies) = 1, 'member A legge');
select t_assert((select count(*) from integrations) = 0, 'member A non vede integrazioni');
-- bozza ormai approvata: member comunque non può modificare
update email_messages set corpo='hack' where id='e0000000-0000-0000-0000-00000000000a';
reset role;
select t_assert((select corpo from email_messages where id='e0000000-0000-0000-0000-00000000000a') = 'c', 'member A non modifica email');

-- 3) Owner B
set role authenticated; select t_as('b1b1b1b1-0000-0000-0000-00000000000b');
select t_assert((select count(*) from companies where client_id='aaaaaaaa-0000-0000-0000-000000000001') = 0, 'owner B non vede aziende di A');
select t_assert((select count(*) from integrations) = 0, 'owner B non vede integrazioni di A');

-- 4) Utente sconosciuto e anon
select t_as('12121212-0000-0000-0000-000000000012');
select t_assert((select count(*) from companies) = 0, 'utente senza cliente non vede nulla');
reset role; set role anon;
do $$ begin perform 1 from companies; raise exception 'FALLITO: anon legge'; exception when insufficient_privilege then raise notice 'ok: anon senza accesso'; end $$;

-- 5) Agency admin
reset role; set role authenticated; select t_as('99999999-0000-0000-0000-000000000009');
select t_assert((select count(*) from companies) = 2, 'agency_admin vede tutti i clienti');
reset role;
-- 6) Audit
select t_assert((select count(*) from audit_log where azione='email_approvata') = 1, 'audit log della approvazione');
\echo === RLS: TUTTI I TEST SUPERATI ===
