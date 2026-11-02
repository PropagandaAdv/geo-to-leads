---
description: Crea o aggiorna la scheda cliente (client.yaml) per l'agenzia
argument-hint: "[slug-cliente opzionale]"
---
# /geo-cliente-nuovo

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Prima di tutto verifica che `${GEO_CLIENTS_DIR}` sia il checkout di un repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non è collegato, usa `add_repo` (accesso push) per collegarlo e clonalo lì. A fine di ogni fase: `git add`, commit e push su quel repo (mai nel repo del plugin). Non uscire dalla sessione con dati non pushati.

**Prima cosa: chiedi all'utente per quale cliente stiamo lavorando** (nome o slug: $ARGUMENTS).

## Cartella dati
`CLIENTS=${GEO_CLIENTS_DIR:-/home/user/geo-clients}`. Se non esiste, chiedi conferma prima di crearla. I dati cliente non vanno mai nel repo del plugin.

## Cliente già esistente?
Se `$CLIENTS/<slug>/client.yaml` esiste, caricalo, mostra un riepilogo e chiedi **solo cosa è cambiato**.

## Nuovo cliente — domande (una alla volta, proponi un default)
1. Nome cliente e slug (kebab-case, derivato dal nome)
2. URL del sito
3. Settore, prodotti/servizi principali, area geografica servita
4. Lingua e mercato (default: it / IT)
5. Target (B2B/B2C), buyer persona, ICP (settori, dimensione, paesi)
6. Competitor già noti (opzionale)
7. Tono di voce; parole/claim da evitare
8. CMS; Arvow pubblica direttamente o solo in bozza? (default: bozza)
9. Email del referente cliente per gli alert Lead Radar
10. Esiste già un progetto Ubersuggest per il dominio? (sì/no)

## Salvataggio
1. Copia `${CLAUDE_PLUGIN_ROOT}/templates/client.yaml` in `$CLIENTS/<slug>/client.yaml` e compilalo; crea le sottocartelle `analisi/ articoli/ leadradar/`.
2. Valida: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/validate_client.py $CLIENTS/<slug>/client.yaml`. Correggi gli errori con l'utente.
3. Suggerisci di versionare la cartella in un repo **privato** (uno per cliente o un unico "clients").
