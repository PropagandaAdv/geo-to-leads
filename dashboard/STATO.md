# Stato dashboard (aggiornato 2026-11-03)

Progetto Lovable **"Portale Clienti Pro"** — workspace "Giovanni's Lovable" (piano free), id `d0718620-a4a4-429c-a783-3065cf88dfa9`
Editor: https://lovable.dev/projects/d0718620-a4a4-429c-a783-3065cf88dfa9 · Preview: https://id-preview--d0718620-a4a4-429c-a783-3065cf88dfa9.lovable.app
Non pubblicato (nessun deploy, nessun dominio). Nessun utente invitato, nessun segreto OAuth inserito.

| Prompt | Stato | Crediti |
|---|---|---|
| 01 fondazioni | **fatto**: login password+magic link, signup disattivato, layout sidebar, branding da `clients.branding` | 5,6 |
| 02 schema | **fatto via SQL diretto** (gratuito): 13 tabelle, 15 policy, RLS su tutte, vista KPI, Realtime, bucket `reports` (`schema_storage.sql`) | 0 |
| 03 panoramica/aziende | **fatto**: correzione inviata, `tsgo` pulito, 8/8 test, preview si carica (login). Pagine interne non provate con utente reale | 4,4 + 1,5 |
| 04 email/bozze | **scritto**: tab "Da approvare" (modifica, conferma, approva/scarta, disabilitato senza casella collegata) e "Inviate" con risposte come suggerimento; 16/16 test. **L'ultimo `tsgo` segnalava ancora un errore** in `src/routes/_authenticated/email.tsx` (forse obsoleto): serve una verifica | 3,5 |
| 05 appuntamenti/integrazioni · 06 report/admin · 07 edge function | **da fare** (la pagina Email rimanda a `/integrazioni`, non ancora creata) | — |

## Verifiche sul database reale (transazione annullata, nessun dato residuo)
Utente A vede solo i propri dati (aziende, email, clienti); non vede email/aziende/integrazioni di B; token OAuth non leggibili; approva solo la propria bozza; non può impostare `inviata`; non scrive visite; non può auto-assegnarsi a un cliente; anon bloccato. Test locale equivalente: `dashboard/tests/run_rls_test.sh` (23 controlli).

## Per riprendere
1. Aggiungere crediti: https://lovable.dev/settings/billing (o attendere il rinnovo). Consumo finora: ~15 crediti per 4 prompt.
2. Chiedere di rilanciare `tsgo --noEmit` e i test sulla pagina Email e correggere l'eventuale errore, poi prompt 05 e 06.
3. Prompt 07 (edge function): richiede i segreti OAuth, che si inseriscono **nell'editor Lovable**, mai in chat.
4. Creare il primo `agency_admin` e invitare utenti (More → Users → Add user), poi `/dashboard-cliente`.
5. Solo dopo: deploy e dominio (conferma esplicita).
