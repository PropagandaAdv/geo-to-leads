---
description: Digest dei visitatori B2B identificati da Lead Radar (un cliente o --tutti)
argument-hint: "[slug-cliente | --tutti] [giorni=7]"
---
# /leadradar-report

Argomenti: $ARGUMENTS. Se manca il cliente chiedilo; con `--tutti` esegui per ogni cliente con `stato: attivo` e `leadradar.abilitato: true` (utile per esecuzione settimanale programmata) e produci un digest per cliente. Periodo di default: ultimi 7 giorni.

## Sorgente dati (in quest'ordine)
1. MCP `leadradar` se registrato (modalità A/B), dopo discovery dei tool reali → `.tool-map.json`.
2. Altrimenti `<slug>/leadradar/visite.csv` (modalità B: `python3 ${CLAUDE_PLUGIN_ROOT}/connectors/leadradar/ingest/import_csv.py`).
3. Altrimenti storico alert (modalità C: `ingest/parse_alert_emails.py`).
Se nessuna è disponibile, spiega cosa fare (export CSV dal dashboard). Dichiara sempre la modalità usata e la data dei dati.

## Contenuto del digest (skill `leadradar-digest`, template `digest-visitatori.md`)
Aziende ordinate per priorità: ICP score, numero visite, pagine ad alto intento (prezzi, servizi, contatti), recency. Per ciascuna: cosa ha guardato, ipotesi di interesse **[INFERENZA]**, decision maker suggerito (solo se presente nei dati), prossima azione (chiamata, email, LinkedIn, nurturing). Sezione "come procedere con i ricontatti" in linguaggio semplice. Tono caldo, non da vendita aggressiva.

## Output
`<slug>/leadradar/digest-AAAA-MM-GG.md` e `.docx` (`python3 ${CLAUDE_PLUGIN_ROOT}/scripts/export_docx.py ... --cliente "<nome>"`).

Opzionale, **solo con conferma**: crea task di ricontatto nello strumento di task management dell'agenzia se c'è un MCP collegato (elenca prima i task che creeresti).
