Riorganizza la navigazione in aree, senza cambiare dati né permessi. Prima applica `schema_v2.sql` (tabelle e viste già presenti: usale, non crearne altre).
Menu laterale a gruppi (su mobile schede in basso): Panoramica; Aziende (Aziende, Visite); Outreach (Da contattare, Bozze, Inviate e risposte, Appuntamenti, Impostazioni Outreach); Visibilità (Posizionamento, Visibilità IA, Citazioni, Crescita); Report; Impostazioni (Integrazioni, Notifiche); Admin (solo agency_admin: Clienti, Utenti, Promemoria, Stato sync).
- La pagina Email attuale diventa "Bozze" + "Inviate e risposte"; Appuntamenti si sposta sotto Outreach.
- Nell'area Aziende non ci sono azioni di invio: solo osservazione, con il badge dello stato ICP (da `v_company_icp`: in target / fuori target / da verificare) e la motivazione.
- "Da contattare": aziende con `stato_effettivo = 'in_target'` e senza bozza o invio; sola lettura per client_member.
- Panoramica: tre blocchi di KPI (Aziende, Outreach, Visibilità). I blocchi senza dati mostrano "Nessun dato ancora", non zeri.
Italiano, ruoli invariati. Verifica che `tsgo --noEmit` e i test passino.
