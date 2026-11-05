# Dashboard cliente — specifica v2 (aree, ICP/tono di voce, Visibilità, promemoria)

Estende `SPEC.md` (resta valido per ruoli, OAuth, privacy). Schema: `schema_v2.sql` (additivo, testato con `tests/run_rls_test_v2.sh`). Stato: **specifica**, nessun prompt Lovable ancora eseguito.

## 1. Navigazione per aree
Menu laterale a gruppi (mobile: schede in basso). Ruoli come in `SPEC.md`: `client_member` solo lettura.

| Area | Pagine | Contenuto |
|---|---|---|
| **Panoramica** | Panoramica | KPI sintetici delle tre aree + banner latenza visite |
| **Aziende** | Aziende · Visite | Chi visita il sito: elenco/filtri, scheda azienda (visite, pagine, stato ICP con motivazione). **Solo osservazione**: qui non si scrive a nessuno. |
| **Outreach** | Da contattare · Bozze · Inviate e risposte · Appuntamenti · **Impostazioni Outreach** | Dalle aziende "in target" ai messaggi. Le Impostazioni contengono ICP, tono di voce, offerta, esempi e limiti. |
| **Visibilità** | Posizionamento · Visibilità IA · Citazioni · Crescita | Dati di Ubersuggest (e rilevazioni proprie) con data e fonte. **Nessuna stima di guadagno in euro.** |
| **Report** | Report | Come in `SPEC.md` |
| **Impostazioni** | Integrazioni · Notifiche | Collegamento casella/calendario; preferenza promemoria dell'utente |
| **Admin agenzia** | Clienti · Utenti · Promemoria · Stato sync | Solo `agency_admin` |

## 2. Outreach: ICP e tono di voce come prompt
**Principio:** l'ICP è un testo libero, non un insieme di filtri. Esempio: «Aziende manifatturiere italiane che producono per OEM, con ufficio acquisti strutturato. Escludere distributori e rivenditori. Il fatturato ideale è 10–100 milioni di euro.»

**Impostazioni Outreach** (modificabili dal `client_owner`; ogni salvataggio crea una nuova versione immutabile in `outreach_profiles`):
- *ICP* (testo), *Tono di voce* (testo: registro, Lei/tu, lunghezza, parole da usare/evitare, firma, lingua), *Offerta* (cosa vende, a chi, con quali prove).
- *Esempi approvati*: 2–3 email modello. Le bozze si ispirano al tono, non copiano.
- *Limiti*: massimo contatti a settimana, giorni di invio.
- Cronologia versioni (sola lettura) e "Prova su un'azienda" (anteprima del giudizio, senza salvare).

**Flusso:**
1. Visita/azienda nuova → `evaluate-icp` confronta i dati disponibili con l'ICP della **versione attiva** → `icp_evaluations`: `in_target` / `fuori_target` / `da_verificare`, con motivazione breve ed `evidenze` (dato, valore, fonte, data).
2. Solo le aziende `in_target` (stato effettivo) entrano in **Da contattare**. Il titolare può forzare lo stato (`override_stato`, con nota, registrato in `audit_log`).
3. Ricerca decisori e arricchimento (consuma crediti Apollo) **solo** per le aziende in target e dopo conferma esplicita; tetto = `max_contatti_settimana`.
4. Una bozza dedicata per contatto, scritta con tono + offerta + evidenza dell'azienda. Il database **rifiuta** bozze per aziende non in target (trigger `guard_draft_in_target`).
5. Il titolare modifica/approva/scarta; l'invio avviene dalla sua casella (`send-approved-email`). Nessun invio automatico.

**Regole di valutazione (per `evaluate-icp`):**
- Dato mancante = `da_verificare`, mai una supposizione. Es.: Apollo non ha il fatturato di Noyfar (`has_revenue: false`) e l'ICP lo cita → `da_verificare`. Ogni inferenza è marcata **[INFERENZA]**.
- Ogni giudizio cita almeno un'evidenza con fonte e data. Niente motivazioni generiche.
- Si valuta una volta per (azienda, versione profilo): rivalutazione solo se il profilo cambia o l'utente la richiede.
- Le valutazioni sono un supporto: in UI sono etichettate come "valutazione automatica".

## 3. Area Visibilità
Dati in sola lettura per il cliente; scritti dal plugin o da funzioni (service role), sempre con `fonte` e data.
- **Posizionamento** (`keyword_rankings`): keyword, posizione, URL, volume, variazione rispetto alla rilevazione precedente.
- **Visibilità IA** (`ai_visibility_snapshots`): per provider, % di risposte che citano il brand, rank medio, share of voice, menzioni, sentiment.
- **Citazioni** (`ai_citations`, schema v2.1): due tipi di riga. *Aggregata per pagina* (`prompt` nullo; è ciò che restituisce Ubersuggest `brand_citations`): URL, titolo, tipo fonte, piattaforme, argomenti, risposte citanti, quota di citazione. *Per prompt* (`prompt` + `provider`): quando la fonte dà il dettaglio per prompt. In entrambi: se cita il cliente, competitor citato.
- **Crescita** (`traffic_history`): serie mensile (traffico organico stimato, keyword organiche, domain authority, backlink, domini referenti). Serve una rilevazione regolare per avere uno storico; la prima è la baseline.
- Fonte: Ubersuggest (piano da 99 $, 15 brand, 20 prompt per brand; verificato con `user_limits` il 2026-11-05). Dove manca il dato: "n.d.", non una stima.

## 4. Promemoria periodico al cliente
- Mittente: **commerciale@propagandaadv.com** (casella dell'agenzia in `agency_mailbox`, OAuth `gmail.send` autorizzato con quell'account; token cifrato, solo service role).
- Frequenza per cliente (`reminder_settings.frequenza`): **mensile** (predefinita) o quindicinale. Modifica solo da `agency_admin`.
- Testo: modello unico approvato una volta (`testo_approvato_il`); l'invio parte **solo se valorizzato** e se `attivo`. Contenuto: invito ad aprire la dashboard + link. Nessun dato personale o commerciale nel messaggio.
- Destinatari: gli utenti del cliente (`client_users`), tranne chi ha disattivato in `user_prefs`. Ogni email include il link per gestire le notifiche.
- Funzione `send-reminder` (cron giornaliero; codice in `functions/send-reminder/`): seleziona i clienti con `prossimo_invio <= now()`, invia, scrive `reminder_log`, aggiorna `ultimo_invio`/`prossimo_invio`. In caso di errore: `reminder_log.esito='errore'`, nessun nuovo tentativo oltre uno al giorno.
- Questo è l'**unico** invio automatico del sistema, ed è un messaggio di servizio verso utenti già registrati. I messaggi di outreach restano sempre approvati a mano.

## 5. Plugin: modifiche previste (non ancora implementate)
- `sync_dashboard.py`: nuovi comandi `profile` (legge il profilo attivo), `icp` (scrive le valutazioni), `visibility` (rankings, snapshot, citazioni, storico mensile).
- `/leadradar-outreach`: legge il profilo attivo, valuta l'ICP, mostra l'elenco "in target / da verificare", chiede conferma e tetto contatti **prima** di qualsiasi arricchimento Apollo; poi scrive bozze solo come `bozza`.
- Nuovo comando `/geo-visibilita [slug]`: rilevazioni Ubersuggest → file in `geo-clients` + sync in dashboard.
- Prova Apollo (2026-11-05): ricerca aziende per nome gratuita; ricerca persone senza consumo apparente; arricchimento standard = 1 credito/contatto; waterfall disattivato per scelta.

## 6. Costi e limiti noti
Ubersuggest: piano da 99 $/mese (limiti verificati). Lovable: piano free (poche azioni: i prompt 08–11 vanno incollati a mano o richiedono più crediti). Altri costi: vedi recap in conversazione; nessun listino ufficiale verificato per Lovable/Supabase/Arvow.

## 7. Domande aperte
1. Servizio di posta in ingresso per `ingest-reply` (non scelto).
2. Se la valutazione ICP debba usare anche il contenuto del sito dell'azienda (più accurata, più costosa in uso di Claude).
3. Testo definitivo del promemoria (bozza in `lovable-prompts/11-promemoria.md`), da approvare.
