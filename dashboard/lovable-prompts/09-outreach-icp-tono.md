Costruisci "Impostazioni Outreach" sotto l'area Outreach, usando `outreach_profiles` (solo INSERT: ogni salvataggio crea una nuova versione, le versioni non si modificano), `v_outreach_attivo` e `icp_evaluations`.
- Form (visibile in scrittura solo al client_owner; il member vede in sola lettura): ICP (textarea, testo libero, con esempio segnaposto), Tono di voce (textarea: registro, Lei/tu, lunghezza, parole da usare/evitare, firma, lingua), Offerta (textarea), Esempi approvati (fino a 3: oggetto + corpo), massimo contatti a settimana (1–200), giorni di invio.
- Validazione: ICP e Tono di almeno 20 caratteri (lo impone anche il database). Salva = nuovo INSERT con client_id; non inviare versione né creato_da (li imposta il trigger).
- Cronologia versioni in sola lettura (versione, data, autore) con "ripristina come nuova versione".
- Pagina Aziende e scheda azienda: mostra `v_company_icp` (stato effettivo, motivazione, evidenze con fonte e data). Il client_owner può forzare lo stato con `update icp_evaluations set override_stato, override_nota` (altre colonne non scrivibili); mostra "Modificato dal titolare" quando c'è un override.
- Etichetta "valutazione automatica" accanto al giudizio. Nessun invio da queste pagine.
La valutazione la scrive la funzione `evaluate-icp` (non la UI). Verifica `tsgo --noEmit` e i test.
