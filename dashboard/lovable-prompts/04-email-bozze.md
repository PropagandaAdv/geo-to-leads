Costruisci la pagina Email.
- Tab "Da approvare": elenco `email_messages` con stato `bozza`; il client_owner può modificare oggetto e corpo, "Approva e invia" (imposta stato `approvata`, previa conferma esplicita con riepilogo destinatario/oggetto) o "Scarta" (`scartata`). Il client_member vede ma non agisce. Se non c'è un'integrazione email `collegata`, mostra un invito a collegarla e disabilita l'approvazione.
- Tab "Inviate": messaggi `inviata`/`errore` con stato e thread delle risposte (`email_events`) con classificazione mostrata come suggerimento.
- Aggiorna in tempo reale su `email_messages` ed `email_events`.
Non scrivere mai lo stato `inviata`: lo imposta solo la funzione server `send-approved-email`.
