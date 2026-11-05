Aggiungi (1) in Admin > Promemoria la gestione di `reminder_settings` per cliente (solo agency_admin: attivo, frequenza mensile/quindicinale, oggetto, corpo con segnaposto {{link}}, pulsante "Approva testo" che valorizza `testo_approvato_il`, ultimo e prossimo invio, ultimi esiti da `reminder_log`) e (2) in Impostazioni > Notifiche l'interruttore dell'utente su `user_prefs.notifiche_promemoria` (insert/update solo della propria riga).
L'invio NON è nella UI: lo fa la funzione `send-reminder` (vedi functions/README.md). Mostra l'avviso: "Il promemoria parte solo se attivo e con testo approvato".

Testo proposto (da approvare):
Oggetto: La tua dashboard è aggiornata
Corpo: Buongiorno, nella tua dashboard trovi i dati aggiornati su visite, outreach e visibilità. Accedi qui: {{link}}. Per non ricevere più questo promemoria: {{link_notifiche}}. — Propaganda Adv
Verifica `tsgo --noEmit` e i test.
