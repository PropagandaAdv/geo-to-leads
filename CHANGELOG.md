# Changelog
Versioning semantico.

## 0.4.0 — 2026-11-05
- Nuovi comandi `/leadradar-icp` e `/geo-visibilita`, nuovo agente `icp-evaluator`.
- `/leadradar-outreach`: richiede profilo Outreach attivo (ICP + tono di voce) e aziende in target; una bozza dedicata per contatto; conferma e costo prima di ogni arricchimento Apollo.
- `sync_dashboard.py`: comandi `profile`, `icp-pending`, `icp`, `visibility`; `drafts` rifiuta aziende non in target e richiede `azienda`.
- Specifica dashboard v2 (`dashboard/SPEC-v2.md`, `schema_v2.sql`).

## 0.3.0 — 2026-11-02
- Dashboard cliente (Lovable, multi-tenant): SPEC, `schema.sql` con RLS (testato: 23 controlli su PostgreSQL 16), prompt Lovable, specifiche edge function, comandi `/dashboard-setup` e `/dashboard-cliente`, `scripts/sync_dashboard.py`.
- `/leadradar-outreach` scrive bozze nel database (mai invio dal plugin); `/leadradar-report` legge/pubblica via dashboard.
- MCP Lovable aggiunto a `.mcp.json`.

## 0.2.0 — 2026-11-02
- Solo cloud: rimosso il server MCP locale LeadRadar; dati cliente in repo GitHub privato con commit/push per fase.
- Personalizzazione: skill `client-profile` (profilo-cliente.md), colonne `evidenza`/`angolo_cliente` nel piano, sezioni evidenza/angolo nel brief, test di personalizzazione nel QA.

## 0.1.0 — 2026-11-02
- Prima versione: comandi cliente/analisi/piano/articoli/leadradar, 5 agenti, 3 skill, template, script, connettore LeadRadar (modalità B e C funzionanti, A stub).
