# Stato dashboard (aggiornato 2026-11-05, sera)

Progetto Lovable **"Portale Clienti Pro"** — workspace "Giovanni's Lovable" (piano free), id `d0718620-a4a4-429c-a783-3065cf88dfa9`
Editor: https://lovable.dev/projects/d0718620-a4a4-429c-a783-3065cf88dfa9 · Preview: https://id-preview--d0718620-a4a4-429c-a783-3065cf88dfa9.lovable.app
**Pubblicato il 2026-11-05 su https://portale-clienti-pro.lovable.app** (deployment `70ee066d-9c53-4a13-aa78-1068475f8e12`, su richiesta esplicita). Nessun dominio personalizzato. Nessun utente invitato, nessun segreto OAuth inserito.

| Prompt | Stato | Crediti |
|---|---|---|
| 01 fondazioni | **fatto**: login password+magic link, signup disattivato, layout sidebar, branding da `clients.branding` | 5,6 |
| 02 schema | **fatto via SQL diretto** (gratuito): 13 tabelle, 15 policy, RLS su tutte, vista KPI, Realtime, bucket `reports` (`schema_storage.sql`) | 0 |
| 03 panoramica/aziende | **fatto**: correzione inviata, `tsgo` pulito, 8/8 test, preview si carica (login). Pagine interne non provate con utente reale | 4,4 + 1,5 |
| 04 email/bozze | **fatto e verificato**: `email.tsx` senza errori di tipo | 3,5 |
| 05 appuntamenti/integrazioni | **fatto**: lista+calendario mensile; card provider con Collega/Revoca solo per owner/admin che invocano `oauth-start`/`oauth-revoke` (se mancano: "Il collegamento sarà disponibile a breve"); allowlist host OAuth lato frontend; `tsgo` OK, 25 test | 4,3 |
| 06 report/admin | **fatto**: Report con download da URL firmati 60 s; Admin (solo agency_admin) con clienti, utenti, integrazioni, email in errore, creazione cliente; invito utenti come server function (verifica `agency_admins`, service role solo server, rollback con eliminazione dell'account se l'inserimento in `client_users` fallisce). `tsgo` OK, 30 test. **Non provato da loggato**; un'email già registrata non si può invitare a un secondo cliente; gli utenti compaiono per ID interno (le tabelle non hanno le email) | 4,9 |
| 07 edge function | **da fare**: richiede prerequisiti esterni (vedi sotto) | — |

## Verifiche sul database reale (transazione annullata, nessun dato residuo)
Utente A vede solo i propri dati (aziende, email, clienti); non vede email/aziende/integrazioni di B; token OAuth non leggibili; approva solo la propria bozza; non può impostare `inviata`; non scrive visite; non può auto-assegnarsi a un cliente; anon bloccato. Test locale equivalente: `dashboard/tests/run_rls_test.sh` (23 controlli).

## Per riprendere (prompt 07: edge function)
Prerequisiti esterni, non risolvibili da qui:
1. **Primo utente** (More → Users → Add user nell'editor Lovable) da inserire in `agency_admins`; senza utenti nessuna pagina è provabile.
2. **Google**: progetto Google Cloud con client OAuth in modalità *Testing* (scope `gmail.send` + calendario sola lettura); Client ID/Secret da inserire nei Secrets Lovable, mai in chat. Produzione: verifica OAuth (e CASA se si usa `gmail.readonly`).
3. **Microsoft**: registrazione app su Entra ID (`Mail.Send`, `Calendars.Read`, `offline_access`); consenso admin per Mail da verificare sul tenant.
4. **Rilevamento risposte (Fase 1)**: serve un indirizzo di ingresso (`in+<id>@dominio-agenzia`) con un servizio di posta in ingresso/webhook: da scegliere. Alternativa: leggere i thread (Gmail `readonly`, restricted → CASA).
5. Poi: prompt 07 (testo in `lovable-prompts/07-edge-functions.md`), test end-to-end con "demo-srl", deploy e dominio (conferma esplicita).

## Note
- Il preview segnala avvisi di idratazione React recuperabili (non analizzati). Nessuna pagina interna è stata provata da loggato: non esistono utenti.

## Utenti e dati di prova (da cancellare a fine collaudo)
- Utente `info@propagandaadv.com` creato dall'editor; inserito in `agency_admins`. Verificato in SQL (transazione annullata) che vede 1 cliente, 3 aziende, 1 bozza e i KPI.
- Cliente fittizio `demo-srl` (id `d3d3d3d3-0000-4000-8000-000000000001`): 3 aziende, 4 visite, 1 contatto, 1 bozza `[DEMO]` — tutti marcati FITTIZI. Pulizia: `delete from clients where slug='demo-srl';` (cascade).
- Utente cliente di prova **FITTIZIO** `cliente.prova@demo-srl.example` (`client_owner` di demo-srl; indirizzo inventato, non riceve email; password casuale generata in sessione, non nel repo) e cliente fittizio `altro-cliente` con un'azienda "SEGRETA" per provare l'isolamento. Pulizia: `delete from clients where slug in ('demo-srl','altro-cliente'); delete from auth.users where email='cliente.prova@demo-srl.example';`

## Collaudo reale via API del backend (2026-11-05, utente cliente loggato)
Login OK. Vede solo `demo-srl` e le sue 3 aziende; 0 righe di `altro-cliente` anche con filtro esplicito; non vede `agency_admins`; `integration_secrets` → 403; KPI corretti (3 aziende, 2 calde). Scritture bloccate (403): visite, creazione clienti, auto-assegnazione a un altro cliente, bozza→`inviata`, spostamento bozza su altro cliente. Anonimo: 401 su tutte le 10 tabelle.
Non verificato: l'interfaccia da loggato (il preview è privato: da browser senza login Lovable rimanda alla loro pagina di accesso; servirebbe il deploy o il tuo browser). Nota: Cloudflare blocca lo user-agent Python di default (errore 1010).

## Collaudo UI sul sito pubblicato (browser reale, utente cliente di prova)
Login → Panoramica (KPI 3/2/0/0, banner "Aggiornati manualmente", feed visite), Aziende (3 righe, filtri nell'URL), Email (1 bozza, invito a collegare la casella, "Approva e invia" disattivato), Integrazioni (4 provider "Non collegata", testo permessi), Report (stato vuoto); `/admin` reindirizza alla Panoramica e la voce non compare nel menu; nessun dato di `altro-cliente`; nessun errore di pagina. Badge "Edit with Lovable" visibile (piano free).
Attenzione: il sito è pubblico e l'utente di prova ha una password stampata nel registro della sessione → cancellare l'utente a fine collaudo (comando sopra) o cambiarne la password.

---
## Aggiornamento 2026-11-05 — schema v2 applicato al database reale
- Applicato `schema_v2.sql` in un'unica transazione: **23 tabelle, tutte con RLS**, 29 policy, 4 trigger nuovi. Verificati i permessi: `authenticated` scrive solo override ICP, nuove versioni di profilo e proprie preferenze; `agency_mailbox` senza alcun permesso; `anon` senza accesso.
- Correzione trovata in test: su Supabase le tabelle nuove ereditano ALL per anon/authenticated, quindi i permessi per colonna da soli non limitavano nulla. `schema_v2.sql` ora fa `revoke all` prima dei grant; `tests/run_rls_test_v2.sh` simula i default privileges e **fallisce senza la revoca** (verificato).
- Revocato anche `anon` su `v_client_kpis` (permessi eccessivi ereditati dalla v1; i dati restavano protetti dalle tabelle sottostanti).
- **Cliente demo `noyfar`** ("Noyfar S.R.L. (DEMO)"): 17 mesi di storico (Ubersuggest `domain_overview`, estratto 2026-11-05, traffico *stimato*), 8 keyword posizionate (`domain_keywords`), profilo Outreach v1 con testi marcati *[DEMO]*, promemoria **disattivo**. Nessuna azienda visitatrice e **nessun dato personale** (il contatto arricchito con Apollo non è stato caricato). Pulizia: `delete from clients where slug='noyfar';`
- **Non fatto:** i prompt Lovable 08–11 (UI) non sono stati inviati: consumano crediti del piano free. Le pagine Aziende/Outreach/Visibilità, le funzioni `evaluate-icp`, `send-reminder`, `sync-visibility` e il collaudo da loggato restano da fare.

### Funzioni edge (2026-11-05, codice scritto, non distribuito)
`evaluate-icp`, `send-reminder`, `sync-visibility` e `tools/encrypt-token.ts` in `dashboard/functions/`; 14 test sulla logica pura passano (Node 22), controllo di tipi pulito con Deno simulato. **Non provate** contro Supabase/Anthropic/Google e **non distribuite**. `sync-visibility` riceve i dati dal plugin: non interroga Ubersuggest (nessuna chiave API per edge function). Prerequisiti: Secrets, token della casella commerciale@ cifrato, scheduler (da verificare). Vedi `functions/README.md`.

### Schema v2.1 — citazioni aggregate (2026-11-05)
`schema_v2_1_citazioni.sql` applicato al database reale: `ai_citations.prompt` e `provider` ora facoltativi; nuove colonne `piattaforme`, `argomenti`, `titolo`, `tipo_fonte`, `risposte_citanti`, `quota_citazione`; vincolo "prompt oppure url_citato"; indice unico per le righe aggregate. Test locali (`tests/run_rls_test_v2.sh`, incluso `rls_test_v2_1.sql`) superati. Cliente demo `noyfar`: baseline 2026-11-05 caricata (3 snapshot IA, 8 keyword non in top 100, 20 pagine più citate su 216). Aggiornati validatore, `sync-visibility`, `sync_dashboard.py visibility`, prompt 10, SPEC-v2.

### Collaudo (2026-11-05)
Piano completo in `COLLAUDO.md`. Eseguita la parte database: `tests/collaudo_db.sql` (33 controlli, 0 falliti) sia in locale sia sul database reale, con transazione annullata e stato ripristinato verificato. Emerso un comportamento di progetto da decidere: l'override ICP del titolare decade quando cambia la versione del profilo (le aziende tornano da rivalutare). Restano non provati: interfaccia v2 (non costruita), funzioni edge (non distribuite), invio reale.

### Area Visibilità pubblicata (2026-11-09)
Prompt 10 eseguito su Lovable (4 crediti): voce di menu "Visibilità" + 4 pagine in sola lettura (Posizionamento, Visibilità IA, Citazioni, Crescita), logica in `src/lib/visibility.ts` (36 test, tipi puliti secondo l'agente). Pubblicato su https://portale-clienti-pro.lovable.app (deployment `661f63f4-d862-4976-a4c2-82cfbcd30e0b`, su richiesta esplicita); il bundle servito contiene i 4 chunk delle pagine. Verificato sul DB con transazione annullata ciò che vedrebbe `commerciale@propagandaadv.com` (solo Propaganda Adv: 42 keyword, 3 piattaforme IA, 20 citazioni, 25 mesi). **Non provato da loggato nell'interfaccia.** Lacune rispetto al prompt: nessun grafico (Posizionamento, Visibilità IA), nessun filtro nelle Citazioni, Visibilità IA solo ultima rilevazione, KPI "pagine citate" conta solo le aggregate. Utente `commerciale@propagandaadv.com` = `client_owner` di `propagandaadv` (accesso solo via link email).
