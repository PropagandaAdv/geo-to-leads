---
description: Valuta le aziende visitatrici rispetto all'ICP del cliente (prompt libero) e scrive i giudizi nella dashboard
argument-hint: "[slug-cliente]"
---
# /leadradar-icp

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Verifica che `${GEO_CLIENTS_DIR}` sia il checkout del repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non lo è, `add_repo` (accesso push) e clone. A fine fase: commit e push lì (mai nel repo del plugin).

Chiedi il cliente (argomento: $ARGUMENTS). Variabili: `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` nell'ambiente cloud (mai in chat).

## Passi
1. **Profilo attivo:** `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sync_dashboard.py profile <slug>`. Se non esiste, fermati: l'ICP e il tono di voce li definisce il titolare in *Impostazioni Outreach* nella dashboard (non inventarli).
2. **Aziende da valutare:** `... icp-pending <slug>` (aziende senza giudizio sulla versione attiva). Mostra il numero e chiedi se valutarle tutte o un sottoinsieme.
3. **Valutazione:** subagent `icp-evaluator` con profilo + aziende. Nessun credito Apollo senza conferma esplicita: se per un giudizio serve `apollo_organizations_enrich`, elenca prima aziende e **costo totale in crediti** (1 per azienda) e attendi l'ok.
4. **Revisione:** mostra la tabella `in_target / fuori_target / da_verificare` con motivazioni ed evidenze. Le valutazioni sono automatiche: chiedi se correggere qualcosa.
5. **Scrittura:** salva `<slug>/outreach/valutazioni-icp-AAAA-MM-GG.json`, poi `... icp <slug> --file ...`. Il titolare può forzare un giudizio dalla dashboard; il plugin non sovrascrive mai gli override.
6. Commit e push in `geo-clients`. Riassumi: n. in target / fuori target / da verificare, e suggerisci `/leadradar-outreach` per le sole aziende in target.

## Regole
- Dato mancante = `da_verificare`. Nessuna inferenza spacciata per fatto; le inferenze sono marcate **[INFERENZA]**.
- Si rivaluta solo se il profilo cambia (nuova versione) o su richiesta esplicita.
- Nessun invio e nessuna bozza in questo comando.
