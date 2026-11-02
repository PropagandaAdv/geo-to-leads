# Dashboard cliente — specifica funzionale

App Lovable **unica e multi-tenant** (Lovable Cloud / Supabase). Ogni cliente accede con le proprie credenziali e vede solo i propri dati (RLS per `client_id`). Fonte unica di verità per visite, aziende, email, risposte e appuntamenti: il database. Analisi e piani restano come file nel repo privato clienti; il plugin li sincronizza con `scripts/sync_dashboard.py`.

## Ruoli
| Ruolo | Può |
|---|---|
| `agency_admin` | vedere e gestire tutti i clienti, creare clienti, invitare utenti |
| `client_owner` | vedere i dati del cliente, collegare email/calendario, modificare/approvare/scartare bozze |
| `client_member` | sola lettura |

## Pagine
1. **Panoramica** — KPI (aziende identificate, calde, email inviate, tasso di risposta, appuntamenti), feed visite in Realtime. Mostra la **latenza reale** della sorgente visite (campo `clients.latenza_visite`): la dicitura "tempo reale" compare solo se la fonte lo è.
2. **Aziende** — filtri (periodo, settore, paese, ICP, stato contatto); scheda con visite, pagine, contatti, email, appuntamenti, prossima azione.
3. **Email** — inviate dalla casella del cliente + thread risposte; coda **bozze da approvare** (modifica, "Approva e invia", scarta).
4. **Appuntamenti** — lista/calendario collegato alle aziende.
5. **Integrazioni** — Collega Gmail/Outlook, Google/Outlook Calendar, stato, revoca.
6. **Report** — digest e piani (PDF/DOCX) scaricabili.
7. **Admin agenzia** — clienti, utenti, stato integrazioni/sync.
Italiano, mobile-friendly, notifiche in-app per aziende calde e nuove risposte. Branding per cliente da `clients`.

## Invio email: regole
- Nessun invio automatico. Il plugin scrive solo `email_messages.stato = 'bozza'`.
- Solo un `client_owner` può portare lo stato a `approvata`; l'invio lo esegue la edge function `send-approved-email` dalla casella collegata, poi `inviata`/`errore`. Ogni transizione finisce in `audit_log`.
- Senza casella collegata le bozze restano in attesa e la dashboard invita a collegarla.
- Tracciamento aperture **disattivato** di default (tema privacy).

## OAuth — piano a fasi [INFERENZA sui tempi]
Verificato (Google, doc ufficiale consultata il 2026-11-02): `gmail.send` è *sensitive*; `gmail.readonly`, `gmail.metadata`, `gmail.compose`, `gmail.modify` sono *restricted*. Un'app per utenti esterni che archivia dati restricted su server richiede verifica + valutazione di sicurezza CASA ("possono volerci settimane", ricertificazione annuale; costi non indicati dalla pagina).
- **Fase 1 (test, ≤100 utenti in modalità "Testing")**: Gmail `gmail.send` + `calendar.readonly` (o `calendar.events.readonly`); Microsoft `Mail.Send`, `Calendars.Read`, `offline_access`. Rilevamento risposte **senza leggere la casella**: l'email esce con `Reply-To`/`Bcc` verso un indirizzo di ingresso della piattaforma (`in+<message_id>@<dominio-agenzia>`), la edge function `ingest-reply` analizza i messaggi ricevuti. Da validare con un test reale.
- **Fase 2 (produzione)**: verifica OAuth Google per gli scope sensitive; valutare se `gmail.readonly` (restricted + CASA) serva davvero rispetto alla Fase 1.
- **Microsoft**: registrazione app su Entra ID; consenso admin per i permessi Mail **non verificato** nella documentazione consultata: controllare per i tenant dei clienti.
- **Alternativa se Google è troppo oneroso**: invio con servizio transazionale e dominio del cliente verificato (SPF/DKIM), risposte che arrivano nella casella del cliente e intercettate via Bcc.

## Sincronizzazioni (edge function schedulate)
- Visite: da `scripts/sync_dashboard.py` (CSV/alert importati dal connettore LeadRadar) → `companies`/`visits`. Se il fornitore conferma un'API/webhook: `ingest-visits`.
- Risposte: `ingest-reply` (Fase 1) o polling dei thread (Fase 2) → `email_events` + classificazione (interessato / non interessato / da ricontattare / fuori ufficio).
- Appuntamenti: `sync-calendar` legge gli eventi; collega all'azienda se il dominio di un partecipante coincide con un contatto/azienda → `meetings`. Calendly come seconda fonte, opzionale.

## Privacy e sicurezza
Cliente = titolare; agenzia = responsabile (DPA); Lovable/Supabase, LeadRadar, Google/Microsoft = sub-responsabili. Token OAuth cifrati in tabella senza policy (solo service role), mai al frontend; revoca in ogni momento. Retention configurabile (`clients.retention_giorni`). Test RLS automatico: `dashboard/tests/rls_test.sql`.
