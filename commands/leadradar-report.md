---
description: Digest dei visitatori B2B identificati da Lead Radar (un cliente o --tutti)
argument-hint: "[slug-cliente | --tutti] [giorni=7]"
---
# /leadradar-report

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Prima di tutto verifica che `${GEO_CLIENTS_DIR}` sia il checkout di un repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non è collegato, usa `add_repo` (accesso push) per collegarlo e clonalo lì. A fine di ogni fase: `git add`, commit e push su quel repo (mai nel repo del plugin). Non uscire dalla sessione con dati non pushati.

Argomenti: $ARGUMENTS. Se manca il cliente chiedilo; con `--tutti` esegui per ogni cliente con `stato: attivo` e `leadradar.abilitato: true` (utile per esecuzione settimanale programmata) e produci un digest per cliente. Periodo di default: ultimi 7 giorni.

## Sorgente dati (in quest'ordine)
0. **Dashboard** (fonte unica di verità per le visite, se il cliente è attivato): `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sync_dashboard.py export-visits <slug> --days <N>`.
1. `<slug>/leadradar/visite.csv` (alimentato da `python3 ${CLAUDE_PLUGIN_ROOT}/connectors/leadradar/ingest/import_csv.py <slug> <export.csv>`; l'export CSV si scarica dal dashboard e si carica in sessione).
2. Alert email: leggili con l'MCP Gmail (se collegato), salvali come `.txt` in `<slug>/leadradar/alert/` e importali con `ingest/parse_alert_emails.py <slug> --eml-dir ...`.
3. Modalità A (API): solo se il fornitore la conferma.
Nessun server locale: tutto gira nella sessione cloud.
Se nessuna è disponibile, spiega cosa fare (export CSV dal dashboard). Dichiara sempre la modalità usata e la data dei dati.

## Contenuto del digest (skill `leadradar-digest`, template `digest-visitatori.md`)
Aziende ordinate per priorità: ICP score, numero visite, pagine ad alto intento (prezzi, servizi, contatti), recency. Per ciascuna: cosa ha guardato, ipotesi di interesse **[INFERENZA]**, decision maker suggerito (solo se presente nei dati), prossima azione (chiamata, email, LinkedIn, nurturing). Sezione "come procedere con i ricontatti" in linguaggio semplice. Tono caldo, non da vendita aggressiva.

## Output
`<slug>/leadradar/digest-AAAA-MM-GG.md` e `.docx` (`python3 ${CLAUDE_PLUGIN_ROOT}/scripts/export_docx.py ... --cliente "<nome>"`).

Dopo il digest: carica `.docx` nella sezione Report con `sync_dashboard.py report <slug> --file ... --tipo digest --titolo "..." --periodo "..."` e, se nuove visite sono state importate da CSV/alert, `sync_dashboard.py visits <slug>`.

Opzionale, **solo con conferma**: crea task di ricontatto nello strumento di task management dell'agenzia se c'è un MCP collegato (elenca prima i task che creeresti).
