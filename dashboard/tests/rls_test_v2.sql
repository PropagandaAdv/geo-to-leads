-- Test RLS schema v2. Eseguire DOPO stub, schema.sql, rls_test.sql e schema_v2.sql (usa i dati fittizi di rls_test.sql).
\set ON_ERROR_STOP on
grant select, insert, update, delete on all tables in schema public to service_role;

-- Dati fittizi v2 (service_role/superuser)
insert into outreach_profiles (client_id, icp_prompt, tono_prompt) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Aziende manifatturiere italiane con ufficio acquisti, escludere rivenditori', 'Tono diretto e cordiale, dare del Lei, niente superlativi'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'ICP del cliente B (fittizio) con testo abbastanza lungo', 'Tono del cliente B (fittizio) con testo abbastanza lungo');
select t_assert((select versione from outreach_profiles where client_id='aaaaaaaa-0000-0000-0000-000000000001') = 1, 'prima versione profilo = 1');
insert into icp_evaluations (client_id, company_id, profile_id, stato, motivazione)
select client_id, 'c0000000-0000-0000-0000-00000000000a', id, 'fuori_target', 'Fatturato non in linea (test)'
from outreach_profiles where client_id='aaaaaaaa-0000-0000-0000-000000000001';
insert into icp_evaluations (client_id, company_id, profile_id, stato, motivazione)
select client_id, 'c0000000-0000-0000-0000-00000000000b', id, 'in_target', 'ok (test)'
from outreach_profiles where client_id='bbbbbbbb-0000-0000-0000-000000000002';
insert into keyword_rankings (client_id, keyword, posizione, rilevato_il, fonte) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'kw a', 5, current_date, 'test'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'kw b', 7, current_date, 'test');
insert into reminder_settings (client_id) values ('aaaaaaaa-0000-0000-0000-000000000001'), ('bbbbbbbb-0000-0000-0000-000000000002');
insert into agency_mailbox (email, token_cifrato) values ('commerciale@propagandaadv.com', 'segreto-fittizio');

-- Guardia: bozza consentita solo per aziende in target (service_role, trigger attivo)
do $$ begin
  begin
    insert into email_messages (client_id, company_id, destinatario, oggetto, corpo)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-00000000000a', 'z@a.example', 'o', 'c');
    raise exception 'FALLITO: bozza creata per azienda fuori target';
  exception when raise_exception then
    if sqlerrm like 'FALLITO%' then raise; end if;
    raise notice 'ok: bozza rifiutata per azienda fuori target (%)', sqlerrm;
  end;
end $$;
insert into email_messages (client_id, company_id, destinatario, oggetto, corpo)
values ('bbbbbbbb-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-00000000000b', 'z@b.example', 'o', 'c');
select t_assert(true, 'bozza creata per azienda in target');

-- Owner A
set role authenticated; select t_as('a1a1a1a1-0000-0000-0000-00000000000a');
select t_assert((select count(*) from outreach_profiles) = 1, 'owner A vede solo i propri profili');
select t_assert((select count(*) from keyword_rankings) = 1, 'owner A vede solo i propri ranking');
select t_assert((select count(*) from icp_evaluations) = 1, 'owner A vede solo le proprie valutazioni');
select t_assert((select count(*) from reminder_settings) = 1, 'owner A legge le proprie impostazioni promemoria');
insert into outreach_profiles (client_id, icp_prompt, tono_prompt)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'ICP aggiornato con testo sufficientemente lungo', 'Tono aggiornato con testo sufficientemente lungo');
select t_assert((select max(versione) from outreach_profiles) = 2, 'nuova versione profilo = 2');
do $$ begin
  begin
    insert into outreach_profiles (client_id, icp_prompt, tono_prompt)
    values ('bbbbbbbb-0000-0000-0000-000000000002', 'ICP altrui con testo abbastanza lungo', 'Tono altrui con testo abbastanza lungo');
    raise exception 'FALLITO: owner A scrive profilo di B';
  exception when insufficient_privilege or check_violation then raise notice 'ok: owner A non scrive profili di B'; end;
end $$;
do $$ begin
  begin
    update outreach_profiles set icp_prompt = 'modifica retroattiva non consentita lunga' where client_id='aaaaaaaa-0000-0000-0000-000000000001';
    raise exception 'FALLITO: profilo modificabile';
  exception when insufficient_privilege then raise notice 'ok: versioni di profilo immutabili'; end;
end $$;
set role authenticated; select t_as('a1a1a1a1-0000-0000-0000-00000000000a');
update icp_evaluations set override_stato='in_target', override_nota='titolare: ok' where company_id='c0000000-0000-0000-0000-00000000000a';
reset role;
select t_assert((select override_stato::text from icp_evaluations where company_id='c0000000-0000-0000-0000-00000000000a') = 'in_target', 'owner A imposta override ICP');
select t_assert((select count(*) from audit_log where azione='icp_override') = 1, 'audit dell''override ICP');
set role authenticated; select t_as('a1a1a1a1-0000-0000-0000-00000000000a');
do $$ begin
  begin
    update icp_evaluations set stato='in_target' where company_id='c0000000-0000-0000-0000-00000000000a';
    raise exception 'FALLITO: owner modifica la valutazione di sistema';
  exception when insufficient_privilege then raise notice 'ok: owner non modifica la valutazione di sistema (solo override)'; end;
end $$;
do $$ begin
  begin
    update reminder_settings set attivo = true where client_id='aaaaaaaa-0000-0000-0000-000000000001';
    -- policy: scrittura solo agency_admin; senza riga visibile/permessa l'update non cambia nulla
    if (select attivo from reminder_settings where client_id='aaaaaaaa-0000-0000-0000-000000000001') then
      raise exception 'FALLITO: owner attiva il promemoria';
    end if;
    raise notice 'ok: owner non attiva il promemoria';
  end;
end $$;
do $$ begin
  begin perform 1 from agency_mailbox; raise exception 'FALLITO: owner legge agency_mailbox';
  exception when insufficient_privilege then raise notice 'ok: owner non legge agency_mailbox'; end;
end $$;
insert into user_prefs (user_id, client_id, notifiche_promemoria) values ('a1a1a1a1-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', false);
reset role;
select t_assert((select notifiche_promemoria from user_prefs where user_id='a1a1a1a1-0000-0000-0000-00000000000a') = false, 'utente gestisce le proprie notifiche promemoria');
-- Escalation: un membro non deve poter cambiare il proprio ruolo
set role authenticated; select t_as('a2a2a2a2-0000-0000-0000-00000000000a');
update client_users set ruolo = 'client_owner' where user_id = 'a2a2a2a2-0000-0000-0000-00000000000a';
reset role;
select t_assert((select ruolo::text from client_users where user_id='a2a2a2a2-0000-0000-0000-00000000000a') = 'client_member', 'member non si promuove a owner');
do $$ begin
  begin
    set local role authenticated; perform set_config('request.jwt.claim.sub','a2a2a2a2-0000-0000-0000-00000000000a',true);
    insert into user_prefs (user_id, client_id) values ('b1b1b1b1-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000002');
    raise exception 'FALLITO: member scrive preferenze di altri';
  exception when insufficient_privilege or others then
    if sqlerrm like 'FALLITO%' then raise; end if; raise notice 'ok: member non scrive preferenze di altri';
  end;
end $$;

-- Member A: sola lettura sul profilo, nessun override, nessuna scrittura
set role authenticated; select t_as('a2a2a2a2-0000-0000-0000-00000000000a');
select t_assert((select count(*) from outreach_profiles) = 2, 'member A legge i profili del cliente');
select t_assert((select count(*) from reminder_settings) = 0, 'member A non vede le impostazioni promemoria');
do $$ begin
  begin
    insert into outreach_profiles (client_id, icp_prompt, tono_prompt)
    values ('aaaaaaaa-0000-0000-0000-000000000001', 'member non puo scrivere profilo lungo', 'member non puo scrivere tono lungo');
    raise exception 'FALLITO: member scrive profilo';
  exception when insufficient_privilege or check_violation then raise notice 'ok: member non scrive profili'; end;
end $$;

-- Owner B: nulla di A
reset role; set role authenticated; select t_as('b1b1b1b1-0000-0000-0000-00000000000b');
select t_assert((select count(*) from keyword_rankings where client_id='aaaaaaaa-0000-0000-0000-000000000001') = 0, 'owner B non vede ranking di A');
select t_assert((select count(*) from outreach_profiles where client_id='aaaaaaaa-0000-0000-0000-000000000001') = 0, 'owner B non vede profili di A');

-- Anon
reset role; set role anon;
do $$ begin perform 1 from outreach_profiles; raise exception 'FALLITO: anon legge profili';
exception when insufficient_privilege then raise notice 'ok: anon senza accesso ai profili'; end $$;
reset role;
\echo === RLS v2: TUTTI I TEST SUPERATI ===
