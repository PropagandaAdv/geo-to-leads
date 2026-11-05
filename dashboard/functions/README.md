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

## Funzioni dello schema v2 (codice scritto, NON ancora distribuito)
Codice in `evaluate-icp/`, `send-reminder/`, `sync-visibility/` (+ `_shared/` con la logica pura e `tools/encrypt-token.ts`). Test della logica: `node --experimental-strip-types --test functions/tests/shared.test.ts` (14 test). **Non provate** contro Supabase, Anthropic e Google: servono Secrets reali e una prova guidata (vedi sotto).

| Funzione | Chi la chiama | Cosa fa |
|---|---|---|
| `evaluate-icp` | plugin / dashboard (service role oppure `client_owner`/`agency_admin` con JWT) | Per le aziende senza giudizio sulla **versione attiva** del profilo (max 20 per chiamata) chiede a Claude, con output forzato su uno strumento strutturato, `in_target` / `fuori_target` / `da_verificare` con motivazione ed evidenze. Il risultato viene **validato**: se manca la fonte, la fonte non è tra quelle fornite, il giudizio non ha alcun dato o si basa solo su inferenza, viene **declassato a `da_verificare`**. I testi di azienda e sito sono trattati come dati non fidati. `use_website: true` legge la home pubblica (solo https, un redirect verso lo stesso dominio, niente IP/host interni). Gli override del titolare non vengono toccati. |
| `send-reminder` | cron giornaliero (`x-cron-secret`) | Invia il promemoria da `commerciale@propagandaadv.com` **solo** se `attivo`, `testo_approvato_il` valorizzato, `prossimo_invio` scaduto e casella collegata. Un messaggio per destinatario (nessuno vede gli altri), esclusi gli utenti con `user_prefs.notifiche_promemoria = false`. "Prenota" il cliente prima di inviare per evitare doppioni; in caso di errore riprova il giorno dopo. Scrive `reminder_log`. `{"dry_run":true}` mostra cosa invierebbe senza inviare né modificare nulla. |
| `sync-visibility` | plugin / task programmato (`x-ingest-secret` o service role) | Valida e scrive posizionamento, visibilità IA, citazioni e storico mensile (stesse regole di `scripts/sync_dashboard.py visibility`: ogni dato con fonte e data). **Non interroga Ubersuggest**: non esiste una chiave API utilizzabile da una edge function (solo MCP con OAuth); le rilevazioni le esegue `/geo-visibilita`. |

### Secrets da impostare (Lovable Cloud → Secrets; mai in chat né nel repo)
`ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` (opz., default `claude-sonnet-5-5`), `CRON_SECRET`, `INGEST_SECRET`, `AGENCY_MAILBOX_ENC_KEY` (≥16 caratteri casuali), `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `APP_URL` (`https://portale-clienti-pro.lovable.app`).

### Casella commerciale@propagandaadv.com (una tantum)
1. Autorizza l'app Google (modalità Testing, scope `gmail.send`) **con quell'account** e ottieni il refresh token (flusso OAuth in locale, mai in chat).
2. Cifralo: `AGENCY_MAILBOX_ENC_KEY=... deno run functions/tools/encrypt-token.ts` (token su stdin) e inserisci l'output in `agency_mailbox` con lo `INSERT` indicato nel file. Se il rinnovo fallisce, la casella passa a `scaduta` e i promemoria vanno in errore (non si perdono silenziosamente).

### Distribuzione e pianificazione [DA VERIFICARE su Lovable Cloud]
- Le funzioni invocate con `x-cron-secret`/`x-ingest-secret` non portano un JWT utente: servono `verify_jwt = false` per `send-reminder` e `sync-visibility` (l'autenticazione è nel codice). `evaluate-icp` usa il JWT dell'utente o la service role.
- Il cron giornaliero di `send-reminder` si imposta con `pg_cron` + `pg_net` (`net.http_post` con l'header `x-cron-secret`) oppure con lo scheduler di Lovable, se disponibile. Non ho verificato quale sia disponibile nel progetto.
- Il link "gestisci notifiche" punta a `APP_URL/impostazioni/notifiche`: la pagina va creata con coerenza (prompt 11).

### Prima prova consigliata (nessun invio reale)
1. `evaluate-icp` sul cliente demo `noyfar` senza aziende → deve rispondere 0 valutate; poi con 1 azienda fittizia.
2. `send-reminder` con `{"dry_run":true}` → deve elencare i destinatari senza inviare.
3. `sync-visibility` con un payload minimo di Noyfar → righe in `keyword_rankings`.
Solo dopo, un invio reale a un indirizzo interno con `attivo = true` e testo approvato.
