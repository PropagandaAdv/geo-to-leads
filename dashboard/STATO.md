# Stato dashboard (aggiornato 2026-11-04)

Progetto Lovable **"Portale Clienti Pro"** — workspace "Giovanni's Lovable" (piano free), id `d0718620-a4a4-429c-a783-3065cf88dfa9`
Editor: https://lovable.dev/projects/d0718620-a4a4-429c-a783-3065cf88dfa9 · Preview: https://id-preview--d0718620-a4a4-429c-a783-3065cf88dfa9.lovable.app
Non pubblicato (nessun deploy, nessun dominio). Nessun utente invitato, nessun segreto OAuth inserito.

| Prompt | Stato | Crediti |
|---|---|---|
| 01 fondazioni | **fatto**: login password+magic link, signup disattivato, layout sidebar, branding da `clients.branding` | 5,6 |
| 02 schema | **fatto via SQL diretto** (gratuito): 13 tabelle, 15 policy, RLS su tutte, vista KPI, Realtime, bucket `reports` (`schema_storage.sql`) | 0 |
| 03 panoramica/aziende | **fatto**: correzione inviata, `tsgo` pulito, 8/8 test, preview si carica (login). Pagine interne non provate con utente reale | 4,4 + 1,5 |
| 04 email/bozze | **fatto e verificato**: `email.tsx` senza errori di tipo | 3,5 |
| 05 appuntamenti/integrazioni | **fatto**: lista+calendario mensile; card provider con Collega/Revoca solo per owner/admin che invocano `oauth-start`/`oauth-revoke` (se mancano: "Il collegamento sarà disponibile a breve"); allowlist host OAuth lato frontend; `tsgo` OK, 25 test | 4,3 |
| 06 report/admin | **NON implementato**: l'agente ha fatto solo controlli e ha chiesto di procedere; messaggio di conferma non inviato (crediti esauriti) | 0,7 |
| 07 edge function | **da fare** | — |

## Verifiche sul database reale (transazione annullata, nessun dato residuo)
Utente A vede solo i propri dati (aziende, email, clienti); non vede email/aziende/integrazioni di B; token OAuth non leggibili; approva solo la propria bozza; non può impostare `inviata`; non scrive visite; non può auto-assegnarsi a un cliente; anon bloccato. Test locale equivalente: `dashboard/tests/run_rls_test.sh` (23 controlli).

## Per riprendere
1. Aggiungere crediti: https://lovable.dev/settings/billing (o attendere il rinnovo). Consumo finora: ~20 crediti per 6 prompt (3–5 a prompt).
2. Inviare il prompt 06 (`lovable-prompts/06-report-admin.md`) dicendo di implementare subito, senza chiedere conferma; l'invito utenti deve essere una server function che verifica `agency_admins`, altrimenti pulsante disabilitato.
3. Prompt 07 (edge function): richiede i segreti OAuth, che si inseriscono **nell'editor Lovable**, mai in chat.
4. Creare il primo `agency_admin` e invitare utenti (More → Users → Add user), poi `/dashboard-cliente`.
5. Solo dopo: deploy e dominio (conferma esplicita).

## Note
- Il preview segnala avvisi di idratazione React recuperabili (non analizzati). Nessuna pagina interna è stata provata da loggato: non esistono utenti.
