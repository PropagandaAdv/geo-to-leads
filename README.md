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

Requisiti: Python ≥ 3.10 con `pip install pyyaml python-docx`. Le variabili (vedi `.env.example`) si impostano nell'ambiente cloud, mai nel repo.

### Collegamenti (solo cloud, nessun server locale)
- **Ubersuggest** (OAuth): è un MCP remoto nel `.mcp.json` del plugin. Va autorizzato una volta dall'utente (connettori/`/mcp`); nessuna chiave da gestire.
- **Arvow**: imposta `ARVOW_API_KEY` come **variabile d'ambiente/segreto dell'ambiente cloud** (impostazioni ambiente → Edit), poi avvia una nuova sessione. **Non incollare chiavi in chat.** L'endpoint `https://api.arvow.com/mcp` non è verificato; se rifiuta la chiave (401) o non risponde, `/geo-articoli` usa l'API REST (https://api.arvow.com/api/docs).
- **Dati cliente**: repo GitHub **privato** (es. `propagandaadv/geo-clients`) collegato alla sessione; il filesystem cloud è effimero, quindi ogni fase fa commit+push lì.
- **LeadRadar**: nessun MCP; script di import in `connectors/leadradar/`.

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
Fuori da questo repo: `GEO_CLIENTS_DIR` (checkout del repo privato clienti) con `client.yaml`, `analisi/AAAA-MM-GG/`, `piano-editoriale.*`, `articoli/`, `leadradar/`, `.tool-map.json`. Usa un repo **privato** per cliente (o unico). Nessun dato cliente è hard-coded nel plugin.

## Personalizzazione per cliente
Ogni cliente parte da `profilo-cliente.md` (sito reale + `client.yaml`). Piano e brief citano l'evidenza dell'analisi (cluster, gap, competitor) e l'angolo proprio del cliente; il controllo qualità respinge testi intercambiabili con quelli di un altro cliente.

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
Vedi `CHANGELOG.md`. Funzionanti e testati: `validate_client.py`, `export_docx.py`, import CSV, parser alert (.eml), import CSV/alert. **Non testati** (richiedono credenziali/account): tutti i flussi Ubersuggest, Arvow, IMAP, Gmail. **Stub**: LeadRadar modalità A, client REST Arvow (`scripts/arvow_client.py` da scrivere dopo lettura della doc).
