---
description: Piano editoriale (default 3 mesi) + sintesi per il cliente, esportato in md/csv/docx
argument-hint: "[slug-cliente] [mesi=3]"
---
# /geo-piano

Chiedi il cliente (elenca `${GEO_CLIENTS_DIR:-~/agency-clients}`; argomenti: $ARGUMENTS). Usa l'**ultima** cartella in `<slug>/analisi/` (mostra data, chiedi conferma). Durata: 3 mesi salvo diversa indicazione.

## Piano
Dal `cluster.csv`, ordinando per priorità e distribuendo pillar prima dei satelliti. Per ogni articolo: titolo provvisorio, keyword principale + secondarie (con volume/fonte/data), cluster, intento, formato, lunghezza indicativa, link interni suggeriti (verso pagine esistenti o altri articoli del piano), CTA verso un servizio reale del cliente (da `client.yaml`), priorità, mese. Rispetta `tono_di_voce` e `claim_vietati`. Usa la skill `geo-content-plan`.

## Sintesi esecutiva (1 pagina)
Linguaggio non tecnico: cosa abbiamo trovato, opportunità, proposta, risultati attesi **senza promettere posizioni o traffico specifici**.

## Output (in `<slug>/`)
- `piano-editoriale.md` (template `${CLAUDE_PLUGIN_ROOT}/templates/piano-editoriale.md`)
- `piano-editoriale.csv` — colonne: `id,mese,titolo,keyword_principale,keyword_secondarie,cluster,intento,formato,lunghezza,link_interni,cta,priorita,stato,url`, con `stato: proposto`
- `.docx`: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/export_docx.py <slug>/piano-editoriale.md --cliente "<nome>" --out <slug>/piano-editoriale.docx`

## Approvazione
Chiudi chiedendo **quali articoli approvare**. Solo quelli confermati ricevono `stato: approvato` nel CSV e passano a `/geo-articoli`.
