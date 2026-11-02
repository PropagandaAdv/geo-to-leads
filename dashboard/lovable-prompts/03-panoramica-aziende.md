Costruisci le pagine Panoramica e Aziende usando solo le tabelle esistenti.
- Panoramica: carte KPI da `v_client_kpis`; feed delle visite in tempo reale con Supabase Realtime su `visits` (join con `companies`); banner con la dicitura di latenza da `clients.latenza_visite` ("Dati in tempo reale" SOLO se vale `tempo_reale`; altrimenti "Aggiornati ogni giorno/ogni N minuti/manualmente"). Notifica in-app per nuove visite di aziende con `icp_score >= 70`.
- Aziende: tabella filtrabile (periodo, settore, paese, ICP, stato contatto), ordinabile; scheda azienda con cronologia visite e pagine viste, contatti, email e appuntamenti collegati e una "prossima azione suggerita" (testo semplice basato su pagine ad alto intento e stato contatto, etichettata come suggerimento).
Sola lettura: nessun inserimento da questa UI.

Valori di `clients.latenza_visite`: `tempo_reale` (unico caso "live": "Dati in tempo reale"), `minuti` ("Aggiornati ogni pochi minuti"), `giornaliera` ("Aggiornati ogni giorno"), `manuale` ("Aggiornati manualmente"), `non_dichiarata` ("Frequenza di aggiornamento non indicata").
Verifica che `tsgo --noEmit` e i test passino prima di chiudere.
