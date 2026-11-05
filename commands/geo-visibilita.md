---
description: Rilevazione di posizionamento, visibilità nelle risposte IA, citazioni e crescita (Ubersuggest) con salvataggio in repo e dashboard
argument-hint: "[slug-cliente]"
---
# /geo-visibilita

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Verifica che `${GEO_CLIENTS_DIR}` sia il checkout del repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non lo è, `add_repo` (accesso push) e clone. A fine fase: commit e push lì (mai nel repo del plugin).

Chiedi il cliente (argomento: $ARGUMENTS). Carica `<slug>/ubersuggest.json` (id progetto, mercato, keyword e prompt tracciati). Se manca il progetto Ubersuggest: proponi `onboard_project` e **chiedi conferma prima di creare** (consuma operazioni brand mensili); non inventare competitor, lascia scegliere all'utente.

## Regole
- Ogni numero riporta **tool + data di estrazione**. Se un dato manca scrivi `n.d.` (e in JSON `null`). Nessun valore a memoria e **nessuna stima di guadagno in euro**.
- Primo rilevamento = **baseline**: dillo esplicitamente; la crescita si calcola solo da due rilevazioni.
- I campi restituiti dai tool brand non sono documentati a priori: mappa quelli realmente restituiti. Se un campo non c'è, `null`, mai un valore ipotizzato.
- Distingui dato verificato da **[INFERENZA]**. Se il sito blocca i crawler (robots.txt) segnalalo come causa probabile di bassa visibilità, senza dichiararla certa.

## Discovery (prima di tutto)
Elenca i tool `mcp__Ubersuggest__*` realmente esposti e aggiorna `<slug>/.tool-map.json` con le operazioni: panoramica dominio (`domain_overview`), keyword posizionate (`domain_keywords`), visibilità IA (`brand_visibility_overview`), prompt (`brand_prompts`), citazioni (`brand_citations`, `brand_citation_gaps`), configurazione (`brand_config`), limiti (`user_limits`). Se un'operazione non ha tool, dillo.

## Passi
1. `user_limits` e `brand_config`: verifica che brand, prompt e frequenza siano quelli attesi. Un `has_brand: false` in `get_project` con un brand configurato va segnalato, non ignorato.
2. Estrai: posizioni delle keyword tracciate; `brand_visibility_overview` (per provider); `brand_prompts`/`brand_citations`; `domain_overview` per il mese corrente (traffico stimato, keyword organiche, DA, backlink, domini referenti). Se un report è "in calcolo" (pending), riprova più tardi e dillo.
3. Salva in `<slug>/visibilita/AAAA-MM-GG/`: `report-visibilita.md` (tabelle con fonte e data; confronto con la rilevazione precedente se esiste, altrimenti "baseline") e `visibilita.json`:
   `{"rankings":[{keyword,url,posizione,volume,difficolta,lingua,paese,rilevato_il,fonte}], "ai_snapshots":[{provider,visibilita_pct,rank_medio,share_of_voice,menzioni,sentiment,rilevato_il,fonte}], "citations":[{provider,prompt,url_citato,dominio,cita_cliente,competitor,rilevato_il,fonte}], "traffic":[{mese(AAAA-MM-01),traffico_organico,keyword_organiche,domain_authority,backlink,domini_referenti,fonte}]}`
   `provider` ∈ `openai | gemini | google_aio | perplexity | altro`.
4. Mostra il riepilogo all'utente. Con il suo ok: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sync_dashboard.py visibility <slug> --file ...` (richiede `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY`; senza dashboard, solo i file).
5. Commit e push in `geo-clients`.

## Chiusura
Riassumi: cosa è cresciuto/calato rispetto all'ultima rilevazione (o "baseline"), citazioni nuove, prompt in cui compaiono i competitor ma non il cliente (solo se i competitor sono tracciati), e le 3 azioni prioritarie. Suggerisci la prossima rilevazione (gli aggiornamenti Ubersuggest sono settimanali).
