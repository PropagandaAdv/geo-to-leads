---
description: Bozze di email personalizzate (una per contatto) per le sole aziende in target, nel tono del cliente (mai invio automatico)
argument-hint: "[slug-cliente]"
---
# /leadradar-outreach

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Prima di tutto verifica che `${GEO_CLIENTS_DIR}` sia il checkout di un repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non è collegato, usa `add_repo` (accesso push) per collegarlo e clonalo lì. A fine di ogni fase: `git add`, commit e push su quel repo (mai nel repo del plugin). Non uscire dalla sessione con dati non pushati.

Chiedi il cliente (argomento: $ARGUMENTS). Variabili `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` nell'ambiente cloud (mai in chat).

## Prerequisiti (verificali prima di tutto)
1. **Profilo Outreach attivo:** `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sync_dashboard.py profile <slug>`. Contiene ICP, **tono di voce**, offerta, email di esempio approvate e limiti (`max_contatti_settimana`, `giorni_invio`). Se manca, fermati: lo definisce il titolare nella dashboard. Non inventare tono né offerta.
2. **Valutazione ICP:** le aziende devono essere state valutate con `/leadradar-icp`. Si lavora **solo** su quelle `in_target` (stato effettivo: l'override del titolare prevale). `da_verificare` e `fuori_target` non entrano; il database rifiuta comunque le bozze per aziende non in target.

## Scelta aziende e contatti
Mostra le aziende `in_target` (con motivazione) e il digest recente. Chiedi **quali** contattare, entro il tetto settimanale del profilo. Per i decisori:
- usa solo contatti già presenti nei dati o forniti dall'utente: non inventare indirizzi;
- se serve cercarli con Apollo: `apollo_organizations_lookup` (gratis) e `apollo_mixed_people_api_search` (non rivela email); **prima di ogni arricchimento** (`apollo_people_match`, 1 credito a contatto circa) mostra l'elenco, il **costo totale** e il saldo crediti (`apollo_users_api_profile`), e attendi l'ok esplicito. Rivelazione standard: niente telefono, niente waterfall salvo richiesta. Dopo, riporta crediti usati e saldo.
- il piano mostra se il contatto era già presente in Apollo.

## Bozze: una per contatto, nel tono del cliente
Per ogni contatto scrivi una bozza **dedicata**, seguendo il `tono_prompt` e gli esempi approvati del profilo (si ispira al tono, non li copia), in italiano. Struttura di partenza: `${CLAUDE_PLUGIN_ROOT}/templates/email-presentazione.md`. Ogni bozza deve:
- citare **un'evidenza specifica dell'azienda** (dato verificato con fonte, es. esito dell'analisi GEO), mai generica: se il testo varrebbe per un'altra azienda, riscrivilo;
- non far capire in modo inquietante di aver tracciato la visita: mai data, ora o pagine specifiche;
- non promettere risultati; includere nell'ultima riga l'invito a rispondere "no grazie" per non ricevere altro;
- marcare come **[INFERENZA]** nel report (non nel testo) ciò che non è verificato.

## Consegna
**Mai invio automatico, nemmeno dal plugin.** Salva le bozze in `<slug>/outreach/bozze-AAAA-MM-GG.json` (`[{azienda,destinatario,oggetto,corpo}]`; `azienda` è obbligatoria), mostrale all'utente e, dopo il suo ok, scrivile con `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sync_dashboard.py drafts <slug> --file ...` (stato forzato `bozza`, legate alla versione del profilo; lo script elenca le aziende rifiutate perché non in target). Il titolare le rivede e le approva dalla dashboard con "Approva e invia"; l'invio parte **dalla sua casella collegata**. Senza casella collegata restano in attesa. Alternativa senza dashboard: esporta CSV per lo strumento di email marketing.

## Avvertenza obbligatoria (da riportare nel report)
> In Italia l'invio di email promozionali non sollecitate, anche B2B verso indirizzi nominativi, è regolato da GDPR e Codice Privacy (art. 130). La base giuridica va verificata con il consulente privacy del cliente prima di attivare qualsiasi sequenza automatica.

Salva un registro in `<slug>/outreach/outreach-log.md` (azienda, data bozza, stato, crediti Apollo usati) e fai commit e push in `geo-clients`.
