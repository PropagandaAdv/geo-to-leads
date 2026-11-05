-- Schema v2.1 — migrazione ADDITIVA dopo schema_v2.sql.
-- Motivo: Ubersuggest (brand_citations) restituisce le citazioni AGGREGATE PER PAGINA (con piattaforme, argomenti,
-- numero di risposte e quota di citazione), non per prompt. ai_citations richiedeva un prompt per ogni riga.
-- Regola: una riga con prompt NULL è una citazione aggregata per pagina; una con prompt è una citazione per prompt.
alter table ai_citations alter column prompt drop not null;
alter table ai_citations alter column provider drop not null;
alter table ai_citations
  add column piattaforme ai_provider[] not null default '{}',
  add column argomenti text[] not null default '{}',
  add column titolo text,
  add column tipo_fonte text check (tipo_fonte in ('owned', 'competitor', 'social', 'third_party')),
  add column risposte_citanti int check (risposte_citanti >= 0),
  add column quota_citazione numeric check (quota_citazione between 0 and 100);
alter table ai_citations add constraint ai_citations_ha_riferimento check (prompt is not null or url_citato is not null);
create unique index ai_citations_aggregata_uq on ai_citations (client_id, rilevato_il, url_citato) where prompt is null;
