# Handoff — GEO Growth Engine (2026-11-05)

Documento per riprendere il lavoro in una nuova sessione. Leggilo prima di agire; per il dettaglio della dashboard vedi `dashboard/STATO.md`, per l'uso `README.md`.

## Cos'è
Plugin Claude Code per un'agenzia italiana (Propaganda Adv), multi-cliente: analisi GEO/SEO (Ubersuggest), articoli (Arvow), visitatori B2B (LeadRadar) e **dashboard cliente** (Lovable + Supabase). Lingua italiana, tono caldo, ogni dato con fonte+data, inferenze marcate **[INFERENZA]**.

## Dove sta il codice
- Repo plugin: `PropagandaAdv/geo-to-leads`, branch **`claude/confident-knuth-ogmyx5`** (v0.3.0). Nessuna PR creata, nulla su `main`. Installazione: `/plugin marketplace add propagandaadv/geo-to-leads` → `/plugin install geo-growth-engine@propaganda-geo`.
- Repo dati clienti (privato, **vuoto**, nulla pushato): `PropagandaAdv/geo-clients`, da clonare in `/home/user/geo-clients` (`GEO_CLIENTS_DIR`). Il disco della sessione è effimero: ogni fase fa commit+push lì.
- Contenuto: 9 comandi (`geo-cliente-nuovo`, `geo-analisi`, `geo-piano`, `geo-articoli`, `leadradar-setup|report|outreach`, `dashboard-setup|cliente`), 5 agenti, 4 skill (incl. `client-profile`), template, `scripts/` (`validate_client.py`, `export_docx.py`, `sync_dashboard.py`), `connectors/leadradar/` (solo script di import, **nessun MCP locale**), `dashboard/` (SPEC, schema.sql, prompt Lovable, specifiche funzioni, test RLS).

## Decisioni prese dall'utente
- Solo cloud, nessun MCP locale. Dati cliente in repo privato.
- Chiavi **mai in chat**: segreti nell'ambiente cloud (Impostazioni ambiente → Edit) o nell'editor Lovable. Ubersuggest/Apollo/Lovable usano OAuth (autorizzare dai connettori claude.ai; i connettori si leggono solo all'avvio sessione).
- Nessun invio email automatico: il plugin scrive solo bozze (`stato='bozza'`, forzato); invio solo da "Approva e invia" del titolare, dalla sua casella.
- Personalizzazione per cliente: `profilo-cliente.md` + evidenza dall'analisi in piano e brief.

## Stato per area
| Area | Stato |
|---|---|
| Plugin (comandi/agenti/skill/template/script) | scritto, `claude plugin validate` OK. `validate_client`, `export_docx`, import CSV/alert, `sync_dashboard` testati con dati fittizi. **Mai eseguiti su un cliente reale**: Ubersuggest/Arvow/Gmail/IMAP non provati. |
| Ubersuggest | Era da autorizzare; nell'ultima sessione i tool `mcp__Ubersuggest__*` compaiono (verificare con `auth_status`). |
| Arvow | `ARVOW_API_KEY` non impostata/401 sull'endpoint `https://api.arvow.com/mcp` (non verificato). Fallback REST: `scripts/arvow_client.py` **da scrivere dopo aver letto** https://api.arvow.com/api/docs. |
| LeadRadar | Prodotto/piano da confermare (leadradar.idea4me.pl?). Nessuna API nota; email al fornitore pronta in `connectors/leadradar/vendor-email.md`. |
| Apollo.io | MCP autorizzato dall'utente (`mcp__Apollo_io__*`, endpoint ufficiale `https://mcp.apollo.io/mcp`). **Prova richiesta, non fatta**: serve 2 aziende italiane reali, piano/crediti (`apollo_users_api_profile`, `apollo_usage_stats_credit_usage_stats`). Vedi sotto. |
| Dashboard Lovable | Progetto "Portale Clienti Pro" id `d0718620-a4a4-429c-a783-3065cf88dfa9`, workspace `a79285aaaf8a1a80992c` (piano **free**, ~25 crediti usati; si esauriscono dopo 1–2 prompt). Pubblicato su **https://portale-clienti-pro.lovable.app**. Prompt 01–06 fatti (login, schema+RLS, Panoramica, Aziende, Email, Appuntamenti, Integrazioni, Report, Admin con inviti sicuri). **Prompt 07 (edge function) non iniziato.** |
| DB dashboard | 13 tabelle, 15 policy, RLS su tutte, bucket privato `reports`. Test RLS locale 23 controlli + collaudo reale via API (utente cliente isolato, anon 401). |

## Utenti e dati di prova (FITTIZI, da cancellare a fine collaudo)
- Admin agenzia reale: `info@propagandaadv.com` (in `agency_admins`).
- Cliente di prova: `cliente.prova@demo-srl.example` (ruolo `client_owner` di demo-srl; email inventata). **La password è stata scritta in chiaro nella chat precedente: non è nel repo.** Se serve, reimpostarla via SQL (`update auth.users set encrypted_password = extensions.crypt('<nuova>', extensions.gen_salt('bf')) where email=...`).
- Clienti fittizi `demo-srl` e `altro-cliente` con aziende/visite/bozza `[DEMO]`.
- Pulizia: `delete from clients where slug in ('demo-srl','altro-cliente'); delete from auth.users where email='cliente.prova@demo-srl.example';`

## Prossimi passi, in ordine
1. **Apollo (prova con 2 aziende)**: discovery tool → `.tool-map.json`; ricerca decisori (`apollo_mixed_companies_search`, `apollo_mixed_people_api_search`); mostrare risultati e **costo stimato prima** di arricchire (`apollo_people_match` consuma crediti); max 2 contatti; poi 2 bozze personalizzate solo come testo. Riportare crediti usati/saldo. Se utile, aggiungere il passo a `/leadradar-outreach` (con elenco di conferma e tetto contatti).
2. **Prompt 07 edge function** (OAuth, `send-approved-email`, risposte, calendario): servono credenziali Google (client OAuth in modalità *Testing*, `gmail.send` + calendario sola lettura) da inserire nei Secrets Lovable; Microsoft (Entra ID) opzionale; scelta del rilevamento risposte (indirizzo di ingresso `in+<id>@dominio` con servizio di posta in ingresso, oppure Gmail `readonly` = scope *restricted* → CASA). Fatti verificati (doc Google 2026-11-02): `gmail.send` sensitive; `readonly/metadata/compose/modify` restricted. Microsoft: consenso admin per Mail **non verificato**.
3. Crediti Lovable: piano a pagamento oppure incollare a mano i prompt in `dashboard/lovable-prompts/`.
4. Primo cliente reale: `/geo-cliente-nuovo` → `/geo-analisi` → `/geo-piano` → `/geo-articoli`; collegare `geo-clients`.
5. Dominio personalizzato e deploy successivi: solo con conferma esplicita.

## Cautele
- Cloudflare blocca lo user-agent Python di default (errore 1010) verso `*.lovable.cloud`: usare uno UA generico.
- Il preview `id-preview--…lovable.app` è privato; il sito pubblicato no (iscrizione disattivata, utenti solo su invito).
- Privacy: ricontatti ed email regolati da GDPR e art. 130 Codice Privacy; estrazione di contatti nominativi (Apollo) richiede base giuridica e informativa, da validare col consulente privacy del cliente.
- Il plugin ufficiale `ubersuggest:*` può duplicare l'MCP `ubersuggest` del `.mcp.json`: verificare conflitti.
- Pulizia dei file temporanei: la scratchpad della sessione contiene la password di prova; non serve altro.

---
## Aggiornamento 2026-11-05 (sessione successiva) — branch `claude/peaceful-brahmagupta-ounxiy` (v0.4.0)
**Fatto**
- `geo-clients` collegato e con `main` creato: `noyfar/` (analisi GEO preliminare, `.tool-map.json`, `ubersuggest.json`).
- Prova Apollo su 2 aziende: Noyfar S.R.L. (noyfar.it) trovata, Swifty srl **non trovata** in Apollo (servirebbe il dominio). 1 contatto arricchito (CEO, email verificata): 1 credito (381 → 380). Nessuna email inviata.
- Analisi Noyfar: `robots.txt` = `Disallow: /` (verificato con curl) → il sito blocca tutti i crawler; 8 keyword organiche non pertinenti, ~114 visite/mese stimate, DA 12. Nessun dato competitor.
- Ubersuggest passato al piano da 99 $: 15 progetti/brand, 20 prompt per brand. **Progetto Noyfar creato** (id in `geo-clients/noyfar/ubersuggest.json`), 8 keyword, 20 prompt IA in 4 argomenti, nessun competitor. Baseline attesa dopo ~1 giorno; `get_project` mostrava `has_brand:false` pur con brand creato → verificare con `brand_config`.
- Dashboard v2: `dashboard/SPEC-v2.md`, `schema_v2.sql` (testato con `tests/run_rls_test_v2.sh`, 23 + nuovi controlli), prompt Lovable 08–11, funzioni in `functions/README.md`.
- Plugin v0.4.0: `/leadradar-icp`, `/geo-visibilita`, agente `icp-evaluator`, `/leadradar-outreach` riscritto, `sync_dashboard.py` con `profile`, `icp-pending`, `icp`, `visibility`. `claude plugin validate` OK; i nuovi comandi dello script provati solo in `--dry-run` (nessun test contro un database reale: in particolare il rifiuto delle bozze per aziende non in target è verificato nel database di test, non via REST).

**Decisioni dell'utente**
- Mittente del promemoria: `commerciale@propagandaadv.com`; frequenza predefinita mensile (da confermare). ICP e tono di voce come **prompt libero** per cliente. Lovable: nessun upgrade per ora. Arvow non ancora attivato. Parere positivo su LeadRadar. Demo = Noyfar.

**Da fare, in ordine**
1. Leggere la baseline Noyfar (`/geo-visibilita noyfar`), salvarla in `geo-clients`.
2. Applicare `schema_v2.sql` al database reale (non ancora fatto) e incollare/eseguire i prompt 08–11 in Lovable (crediti free quasi esauriti).
3. Prompt 07 e funzioni `evaluate-icp`/`send-reminder`/`sync-visibility`; Google OAuth (Testing) con l'account commerciale@; scelta posta in ingresso.
4. Competitor di Noyfar (da scegliere con l'utente), poi gap/cluster; correzione del `robots.txt` richiede il titolare del sito.
5. Approvare il testo del promemoria; verificare prezzi Lovable/Supabase.
6. Pulizia dati fittizi (`demo-srl`, `altro-cliente`, utente di prova).
