# Edge function (specifiche)
Implementate in Lovable Cloud (Deno/TypeScript). Regole comuni: verificare il JWT e l'appartenenza al cliente prima di ogni azione per conto dell'utente; usare `service_role` solo lato funzione; i token OAuth si leggono/scrivono solo qui (`integration_secrets`, cifrati); registrare in `audit_log`; nessun segreto nel frontend. Segreti da impostare nei *Secrets* di Lovable Cloud: `GOOGLE_CLIENT_ID/SECRET`, `MS_CLIENT_ID/SECRET/TENANT`, `TOKEN_ENC_KEY`, `INBOUND_DOMAIN`.

| Funzione | Trigger | Scopo |
|---|---|---|
| `oauth-start` | utente (client_owner) | Genera URL di consenso (state firmato con client_id+user_id+provider, PKCE). Scope Fase 1: Gmail `gmail.send`; Calendar sola lettura; Microsoft `Mail.Send`, `Calendars.Read`, `offline_access`. |
| `oauth-callback` | redirect provider | Verifica `state`, scambia il codice, cifra e salva il refresh token, crea/aggiorna `integrations`, mostra esito. |
| `oauth-revoke` | utente | Revoca presso il provider, cancella il segreto, `integrations.stato='revocata'`. |
| `send-approved-email` | DB webhook su `email_messages.stato→'approvata'` + retry schedulato | Invia dalla casella del cliente; imposta `Reply-To`/`Bcc` `in+<message_id>@INBOUND_DOMAIN`; aggiorna `inviata`/`errore`, `provider_message_id`, `thread_id`. Se manca l'integrazione: lascia `approvata` e segnala in UI. **Nessun invio per stati diversi da `approvata`.** |
| `ingest-reply` | webhook posta in ingresso | Associa la risposta al messaggio via indirizzo `in+<id>@`, salva `email_events`, chiama `classify-reply`. Rileva bounce. |
| `classify-reply` | chiamata interna | Classifica (`interessato`, `non_interessato`, `da_ricontattare`, `fuori_ufficio`, `bounce`, `altro`) con un LLM; salva solo un estratto breve; la classificazione è un suggerimento, mostrata come tale in UI. |
| `sync-calendar` | cron (es. ogni 15 min) | Legge eventi dei calendari collegati; associa un evento a un'azienda se il dominio di un partecipante coincide con `contacts.email`/`companies.dominio`; upsert su `meetings(client_id, external_id)`. |
| `ingest-visits` | webhook (solo se il fornitore LeadRadar conferma un'API) | Stesso schema di `scripts/sync_dashboard.py visits`. Finché non esiste, le visite arrivano dal plugin. |
| `retention-cleanup` | cron giornaliero | Cancella dati oltre `clients.retention_giorni`. |

Aperture email: nessun pixel (disattivato di default).

## Funzioni aggiunte con lo schema v2 (specifiche)
| Funzione | Trigger | Scopo |
|---|---|---|
| `evaluate-icp` | nuova azienda/visita, cambio versione profilo, richiesta manuale | Legge il profilo attivo (`v_outreach_attivo`), confronta i dati dell'azienda (Apollo, sito) con l'ICP e scrive `icp_evaluations` (`in_target` / `fuori_target` / `da_verificare`, motivazione breve, evidenze con fonte e data). Dato mancante ⇒ `da_verificare`, mai una supposizione. Una sola valutazione per (azienda, profilo). |
| `send-reminder` | cron giornaliero | Per ogni `reminder_settings` con `attivo`, `testo_approvato_il` valorizzato e `prossimo_invio <= now()`: invia da `commerciale@propagandaadv.com` (token in `agency_mailbox`, solo service role) agli utenti del cliente che non hanno disattivato in `user_prefs`; scrive `reminder_log`; aggiorna `ultimo_invio`/`prossimo_invio`. È l'unico invio automatico: nessun dato commerciale nel testo. |
| `sync-visibility` | cron settimanale / plugin | Scrive `keyword_rankings`, `ai_visibility_snapshots`, `ai_citations`, `traffic_history` con `fonte` e data. |
Secret aggiuntivi: `AGENCY_MAILBOX_ENC_KEY` (cifratura del token della casella commerciale). Nessun segreto nel frontend.
