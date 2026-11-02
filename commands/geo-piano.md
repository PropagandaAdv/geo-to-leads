---
description: Piano editoriale (default 3 mesi) + sintesi per il cliente, esportato in md/csv/docx
argument-hint: "[slug-cliente] [mesi=3]"
---
# /geo-piano

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Prima di tutto verifica che `${GEO_CLIENTS_DIR}` sia il checkout di un repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non è collegato, usa `add_repo` (accesso push) per collegarlo e clonalo lì. A fine di ogni fase: `git add`, commit e push su quel repo (mai nel repo del plugin). Non uscire dalla sessione con dati non pushati.

Chiedi il cliente (elenca `${GEO_CLIENTS_DIR:-/home/user/geo-clients}`; argomenti: $ARGUMENTS). Usa l'**ultima** cartella in `<slug>/analisi/` (mostra data, chiedi conferma). Durata: 3 mesi salvo diversa indicazione.

## Piano
Ogni voce deve poter rimandare a una riga di `cluster.csv`/`gap.csv` e a `profilo-cliente.md`; indica nel CSV la colonna `evidenza` (cluster + gap + competitor di riferimento) e `angolo_cliente` (cosa il cliente può dire che i competitor non dicono: dati propri, casi, competenze, territorio).
Dal `cluster.csv`, ordinando per priorità e distribuendo pillar prima dei satelliti. Per ogni articolo: titolo provvisorio, keyword principale + secondarie (con volume/fonte/data), cluster, intento, formato, lunghezza indicativa, link interni suggeriti (verso pagine esistenti o altri articoli del piano), CTA verso un servizio reale del cliente (da `client.yaml`), priorità, mese. Rispetta `tono_di_voce` e `claim_vietati`. Usa la skill `geo-content-plan`.

## Sintesi esecutiva (1 pagina)
Linguaggio non tecnico: cosa abbiamo trovato, opportunità, proposta, risultati attesi **senza promettere posizioni o traffico specifici**.

## Output (in `<slug>/`)
- `piano-editoriale.md` (template `${CLAUDE_PLUGIN_ROOT}/templates/piano-editoriale.md`)
- `piano-editoriale.csv` — colonne: `id,mese,titolo,keyword_principale,keyword_secondarie,cluster,intento,formato,lunghezza,link_interni,cta,priorita,evidenza,angolo_cliente,stato,url`, con `stato: proposto`
- `.docx`: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/export_docx.py <slug>/piano-editoriale.md --cliente "<nome>" --out <slug>/piano-editoriale.docx`

## Approvazione
Chiudi chiedendo **quali articoli approvare**. Solo quelli confermati ricevono `stato: approvato` nel CSV e passano a `/geo-articoli`.
