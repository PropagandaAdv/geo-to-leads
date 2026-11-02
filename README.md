# GEO Growth Engine

Plugin Claude Code per agenzie, riutilizzabile su tutti i clienti. Tre servizi:
1. **Analisi GEO/SEO** — dati da Ubersuggest (MCP ufficiale)
2. **Produzione articoli** — Arvow (MCP o API REST)
3. **Visitatori B2B** — Lead Radar (alert, digest, bozze email)

## Installazione
```bash
claude plugin marketplace add propagandaadv/geo-to-leads
claude plugin install geo-growth-engine@propaganda-geo
```
(da dentro Claude Code: `/plugin marketplace add propagandaadv/geo-to-leads`, poi `/plugin install geo-growth-engine@propaganda-geo`). Sviluppo locale: `claude --plugin-dir .` e `/reload-plugins`.

Requisiti: Python ≥ 3.10 con `pip install pyyaml python-docx`. Copia `.env.example` in `.env` e imposta le variabili (mai committare `.env`).

### MCP
`.mcp.json` registra **ubersuggest** (HTTP, OAuth: autenticati con `/mcp`) e **arvow**. Equivalenti manuali:
```bash
claude mcp add --transport http ubersuggest https://ubersuggest-mcp.neilpatelapi.com/mcp
claude mcp add --transport http arvow https://api.arvow.com/mcp --header "Authorization: Bearer $ARVOW_API_KEY"
```
> **Arvow non verificato:** l'URL `https://api.arvow.com/mcp` proviene da una fonte secondaria. Se non si connette, `/geo-articoli` usa l'API REST (https://api.arvow.com/api/docs) dopo aver letto la documentazione reale.
> **LeadRadar** non è in `.mcp.json` finché il connettore non è pronto: vedi `connectors/leadradar/`.

## Comandi
I comandi sono namespaced col plugin (`/geo-growth-engine:geo-analisi`); l'autocompletamento accorcia.

| Comando | Cosa fa |
|---|---|
| `/geo-cliente-nuovo` | Crea/aggiorna `client.yaml` (validato) |
| `/geo-analisi` | Baseline → competitor → gap → keyword → cluster → audit GEO |
| `/geo-piano` | Piano editoriale 3 mesi + sintesi cliente (md, csv, docx), approvazione articoli |
| `/geo-articoli` | Brief + bozze Arvow + controllo qualità |
| `/leadradar-setup` | Checklist snippet, ICP, alert, privacy |
| `/leadradar-report [--tutti]` | Digest visitatori (md + docx) |
| `/leadradar-outreach` | Bozze email (mai invio automatico) |

Flusso: `cliente-nuovo → analisi → piano → (approvazione) → articoli`; in parallelo `leadradar-setup → report → outreach`.

## Dati cliente
Fuori dal repo: `GEO_CLIENTS_DIR` (default `~/agency-clients/<slug>/`) con `client.yaml`, `analisi/AAAA-MM-GG/`, `piano-editoriale.*`, `articoli/`, `leadradar/`, `.tool-map.json`. Usa un repo **privato** per cliente (o unico). Nessun dato cliente è hard-coded nel plugin.

## Regole built-in
- Discovery dei tool MCP prima di usarli → `.tool-map.json`; nessun nome di tool inventato.
- Ogni numero con fonte e data; ipotesi marcate **[INFERENZA]**.
- Conferma esplicita per: pubblicare articoli, inviare email, installare snippet su siti live, creare progetti Ubersuggest/task.
- Nessun segreto nel repo.

## Differenze rispetto alla documentazione verificata (2026-11-02)
- `commands/` è ancora supportato ma la doc raccomanda `skills/` per i nuovi plugin; qui le `commands/` seguono il design richiesto.
- Il nome del plugin non può iniziare con `claude-`/`anthropic-`.
- Comandi e agenti hanno il prefisso del plugin.
- `claude plugin validate .` è il controllo autorevole del manifest.

## Troubleshooting
- *Ubersuggest non risponde*: `/mcp` → autenticare. Senza MCP l'analisi non parte (nessun dato inventato).
- *Arvow MCP non si connette*: verifica endpoint/chiave; usa il fallback REST.
- *`validate_client.py` fallisce*: leggi gli ERRORE, correggi `client.yaml`.
- *Parser alert vuoto*: usa `--dry-run` e adatta `LABELS` al formato reale.

## Stato implementazione
Vedi `CHANGELOG.md`. Funzionanti e testati: `validate_client.py`, `export_docx.py`, import CSV, parser alert (.eml), server MCP locale. **Non testati** (richiedono credenziali/account): tutti i flussi Ubersuggest, Arvow, IMAP, Gmail. **Stub**: LeadRadar modalità A, client REST Arvow (`scripts/arvow_client.py` da scrivere dopo lettura della doc).
