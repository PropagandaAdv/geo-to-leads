---
description: Crea o aggiorna l'app Lovable "Portale Clienti" (una tantum per l'agenzia)
argument-hint: "[--aggiorna]"
---
# /dashboard-setup

Una sola app Lovable multi-tenant per tutta l'agenzia (non un progetto per cliente; remix per cliente solo se l'utente lo chiede esplicitamente). Specifica: `${CLAUDE_PLUGIN_ROOT}/dashboard/SPEC.md`.

## Prima di tutto
1. **Discovery** dei tool del server MCP `lovable` (https://mcp.lovable.dev, OAuth). Non inventare nomi; mappa le operazioni (creare progetto, inviare messaggio, abilitare database, query database, connettori, deploy, leggere diff) in `.tool-map.json`. Se non è connesso: indica di autorizzarlo (connettori claude.ai oppure `claude mcp add --transport http lovable https://mcp.lovable.dev`) e fermati.
2. Mostra il workspace Lovable e **chiedi conferma**: `create_project` e `send_message` consumano crediti. Verifica nella documentazione Lovable attuale cosa include il piano e annotalo nel README.
3. Se esiste già un progetto (`--aggiorna`), leggi stato e diff; non ricreare.

## Sequenza
Per ogni file `${CLAUDE_PLUGIN_ROOT}/dashboard/lovable-prompts/NN-*.md` in ordine: (a) mostra un riassunto, (b) invia il prompt (nel 02 e 07 incolla il contenuto di `schema.sql` / `functions/README.md`), (c) controlla il diff e lo stato della build, (d) **non passare al successivo se ci sono errori o avvisi di sicurezza critici**. Se un prompt va modificato, aggiorna prima il file in `lovable-prompts/` (l'app deve essere ricostruibile dal repo).

## Verifiche obbligatorie
- RLS: `bash ${CLAUDE_PLUGIN_ROOT}/dashboard/tests/run_rls_test.sh` sullo schema locale **e** una verifica sul database reale (query via MCP con due utenti di test: A non deve leggere nulla di B).
- Nessun token OAuth leggibile con la chiave anon/authenticated.

## Conferme esplicite richieste
Collegamento GitHub, **deploy**, **dominio** (`clienti.<dominio-agenzia>`), inserimento dei segreti OAuth (l'utente li inserisce nell'editor Lovable: mai in chat). Dopo il deploy salva URL e id progetto in `${GEO_CLIENTS_DIR}/_agenzia/dashboard.yaml` e committa nel repo privato clienti.

## Fasi OAuth
Ricorda all'utente il piano a fasi di SPEC.md (Google: `gmail.send` sensitive, `gmail.readonly` restricted + CASA; Microsoft: consenso admin Mail non verificato).
