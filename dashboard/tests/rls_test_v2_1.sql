-- Test schema v2.1 (citazioni aggregate). Eseguire dopo schema_v2_1_citazioni.sql e rls_test_v2.sql.
\set ON_ERROR_STOP on
insert into ai_citations (client_id, url_citato, dominio, piattaforme, argomenti, titolo, tipo_fonte, risposte_citanti, quota_citazione, cita_cliente, rilevato_il, fonte) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'https://a.example/', 'a.example', '{openai,gemini}', '{"t1"}', 'A', 'third_party', 5, 9.26, false, current_date, 'test'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'https://b.example/', 'b.example', '{gemini}', '{}', 'B', 'third_party', 2, 3.7, false, current_date, 'test');
insert into ai_citations (client_id, provider, prompt, rilevato_il, fonte)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'openai', 'prompt di test', current_date, 'test');
select t_assert(true, 'citazione aggregata e per prompt entrambe ammesse');
do $$ begin
  begin insert into ai_citations (client_id, rilevato_il, fonte) values ('aaaaaaaa-0000-0000-0000-000000000001', current_date, 'test');
    raise exception 'FALLITO: citazione senza prompt né URL accettata';
  exception when check_violation then raise notice 'ok: citazione senza prompt né URL rifiutata'; end;
end $$;
do $$ begin
  begin insert into ai_citations (client_id, url_citato, rilevato_il, fonte) values ('aaaaaaaa-0000-0000-0000-000000000001', 'https://a.example/', current_date, 'test');
    raise exception 'FALLITO: duplicato aggregato accettato';
  exception when unique_violation then raise notice 'ok: duplicato di citazione aggregata rifiutato'; end;
end $$;
do $$ begin
  begin insert into ai_citations (client_id, url_citato, quota_citazione, rilevato_il, fonte) values ('aaaaaaaa-0000-0000-0000-000000000001', 'https://c.example/', 140, current_date, 'test');
    raise exception 'FALLITO: quota 140 accettata';
  exception when check_violation then raise notice 'ok: quota di citazione fuori range rifiutata'; end;
end $$;
set role authenticated; select t_as('a1a1a1a1-0000-0000-0000-00000000000a');
select t_assert((select count(*) from ai_citations) = 2, 'owner A vede solo le proprie citazioni');
select t_assert((select count(*) from ai_citations where client_id='bbbbbbbb-0000-0000-0000-000000000002') = 0, 'owner A non vede citazioni di B');
do $$ begin
  begin insert into ai_citations (client_id, url_citato, rilevato_il, fonte) values ('aaaaaaaa-0000-0000-0000-000000000001', 'https://x.example/', current_date, 'test');
    raise exception 'FALLITO: authenticated scrive citazioni';
  exception when insufficient_privilege then raise notice 'ok: authenticated non scrive citazioni'; end;
end $$;
reset role;
\echo === RLS v2.1: TUTTI I TEST SUPERATI ===
