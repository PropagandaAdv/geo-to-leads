# Connettore LeadRadar

**Stato verificato:** per LeadRadar (leadradar.idea4me.pl) non risulta pubblicamente alcuna API, webhook o server MCP, e non esiste un connettore nella directory Claude. **[INFERENZA]** potrebbe esistere un omonimo: confermare prodotto e piano col cliente/fornitore. Per questo il connettore ha tre adattatori modulari; si attivano solo quelli realmente possibili.

| Modalità | Stato | File |
|---|---|---|
| **A. API** | **STUB** (nessun endpoint noto, non implementare a caso) | `server/api_client.py` |
| **B. Export CSV** | **Funzionante** (testata con dati fittizi) | `ingest/import_csv.py` |
| **C. Alert email** | **Funzionante** su `.eml`/IMAP, ma il formato reale degli alert è **non verificato**: parser euristico, calibrare con `--dry-run` sulla prima email vera | `ingest/parse_alert_emails.py` |

I dati restano fuori dal repo: `<GEO_CLIENTS_DIR>/<slug>/leadradar/visite.csv`. Colonne: `azienda,sito,settore,paese,dimensione,icp_score,visite,pagine,ultima_visita,decision_maker,fonte,importato_il`.

## Uso rapido
```bash
export GEO_CLIENTS_DIR=~/agency-clients
# B: export dal dashboard
python3 ingest/import_csv.py <slug> export.csv              # --map "Nome colonna=azienda" se serve
# C: alert salvati come .eml, oppure IMAP (LEADRADAR_IMAP_* in .env)
python3 ingest/parse_alert_emails.py <slug> --eml-dir ./alert --dry-run
python3 ingest/parse_alert_emails.py <slug> --imap
```
Via MCP Gmail: l'agente legge gli alert, li salva come file `.txt/.eml` e lancia `--eml-dir` (nessuna password IMAP da gestire).

## Server MCP (locale)
Richiede Python ≥ 3.10 e l'SDK **v1** (`mcp<2`: nella 2.x FastMCP è stato rinominato).
```bash
python3 -m venv .venv && .venv/bin/pip install -r server/requirements.txt
GEO_CLIENTS_DIR=~/agency-clients .venv/bin/python server/server.py     # stdio
```
Tool esposti: `list_visits(client, days)`, `get_company(client, name)`, `list_hot_companies(client, days, limit)`.

Registrazione in Claude Code:
```bash
claude mcp add leadradar --env GEO_CLIENTS_DIR=$HOME/agency-clients -- $PWD/.venv/bin/python $PWD/server/server.py
```
(`mcp.example.json` è l'equivalente per il `.mcp.json` del plugin: non è attivo di default; usa il python del venv.)

## Pubblicazione come connettore remoto (custom connector in Claude)
Non fatto in questa versione. Percorso: avviare con `LEADRADAR_TRANSPORT=streamable-http`, esporre dietro HTTPS (Cloudflare Workers/Vercel/VM) **con autenticazione** (OAuth o token) e aggiungere l'URL in Claude → Impostazioni → Connettori → connettore personalizzato. Il server oggi legge file locali: per un deploy remoto serve prima uno storage condiviso (S3/DB) e **non va esposto senza autenticazione**: contiene dati personali.

## Email al fornitore
Testo pronto (inglese) in `vendor-email.md`.
