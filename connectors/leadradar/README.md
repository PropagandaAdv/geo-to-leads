# Connettore LeadRadar (cloud, senza server locale)

**Stato verificato:** per LeadRadar (leadradar.idea4me.pl) non risulta pubblicamente alcuna API, webhook o server MCP. **[INFERENZA]** potrebbe esistere un omonimo: confermare prodotto e piano. Non c'è nessun MCP locale: gli script girano nella sessione cloud e i dati finiscono nel repo privato dei clienti.

| Modalità | Stato | File |
|---|---|---|
| **A. API** | non disponibile (da chiedere al fornitore) | — |
| **B. Export CSV** | funzionante (testata con dati fittizi) | `ingest/import_csv.py` |
| **C. Alert email** | funzionante su `.eml/.txt`; formato reale degli alert **non verificato** (calibrare con `--dry-run`) | `ingest/parse_alert_emails.py` |

Dati: `<GEO_CLIENTS_DIR>/<slug>/leadradar/visite.csv` (repo privato clienti).

```bash
python3 ingest/import_csv.py <slug> export.csv        # --map "Nome colonna=azienda" se serve
python3 ingest/parse_alert_emails.py <slug> --eml-dir <cartella> --dry-run
```
Alert via Gmail: l'agente li legge con l'MCP Gmail (connettore claude.ai), li salva come `.txt` e usa `--eml-dir`. `--imap` esiste ma richiede credenziali: preferire Gmail.

Email al fornitore (API/webhook, white-label): `vendor-email.md`.
