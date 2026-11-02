---
description: Bozze di email di presentazione alle aziende selezionate (mai invio automatico)
argument-hint: "[slug-cliente]"
---
# /leadradar-outreach

Chiedi il cliente (argomento: $ARGUMENTS), mostra l'ultimo digest e chiedi **quali aziende** contattare e a quale referente (solo contatti presenti nei dati o forniti dall'utente: non inventare indirizzi).

## Bozze
Per ogni azienda scelta, compila `${CLAUDE_PLUGIN_ROOT}/templates/email-presentazione.md` con settore e tema d'interesse, tono caldo e consulenziale, in italiano, firmata dal referente del cliente. **Non far capire in modo inquietante di aver tracciato la visita**: mai data, ora, pagine specifiche ("ieri alle 15:32…"). Niente promesse di risultati.

## Consegna
**Mai invio automatico.** Opzioni: (a) crea **bozze** nella casella del cliente/agenzia con l'MCP Gmail (solo creazione draft, mai `send`); (b) esporta CSV per lo strumento di email marketing → `<slug>/leadradar/outreach-AAAA-MM-GG.csv`; (c) solo testo. Mostra le bozze e invia solo se l'utente approva esplicitamente e separatamente.

## Avvertenza obbligatoria (da riportare nel report)
> In Italia l'invio di email promozionali non sollecitate, anche B2B verso indirizzi nominativi, è regolato da GDPR e Codice Privacy (art. 130). La base giuridica va verificata con il consulente privacy del cliente prima di attivare qualsiasi sequenza automatica.

Salva un registro in `<slug>/leadradar/outreach-log.md` (azienda, data bozza, stato).
