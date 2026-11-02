---
description: Produce gli articoli approvati con Arvow (brief, bozza, controllo qualità)
argument-hint: "[slug-cliente]"
---
# /geo-articoli

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Prima di tutto verifica che `${GEO_CLIENTS_DIR}` sia il checkout di un repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non è collegato, usa `add_repo` (accesso push) per collegarlo e clonalo lì. A fine di ogni fase: `git add`, commit e push su quel repo (mai nel repo del plugin). Non uscire dalla sessione con dati non pushati.

**Chiedi sempre: "Per quale cliente devo scrivere gli articoli?"** (argomento: $ARGUMENTS). Mostra gli articoli con `stato: approvato` in `<slug>/piano-editoriale.csv` e chiedi quali produrre ora.

## Connessione Arvow
1. **MCP**: fai discovery dei tool del server `arvow` (non inventare nomi), mappa le operazioni (creare/avviare articolo, leggere stato/contenuto, salvare bozza, pubblicare) in `<slug>/.tool-map.json` (chiave `arvow`). Operazione senza tool → dillo e proponi l'alternativa.
2. **Fallback REST** se l'MCP non risponde: documentazione https://api.arvow.com/api/docs, chiave `ARVOW_API_KEY`. **Leggi prima la documentazione reale (WebFetch)** e solo poi implementa `${CLAUDE_PLUGIN_ROOT}/scripts/arvow_client.py` sugli endpoint documentati. Non indovinare endpoint.

## Per ogni articolo
0. **Fonti del cliente**: carica `profilo-cliente.md`, la riga di piano (`evidenza`, `angolo_cliente`), `cluster.csv`/`gap.csv`/`keyword-espanse.csv` e le pagine competitor indicate (WebFetch) per l'angolo. Chiedi all'utente materiale proprietario mancante (casi, dati, citazioni) invece di inventarlo.
1. **Brief** con la skill `arvow-article-brief` e `${CLAUDE_PLUGIN_ROOT}/templates/brief-articolo.md` (risposta diretta in apertura, H2/H3, domande FAQ, entità, link interni, CTA, tono, claim vietati, lingua).
2. Mostra il brief all'utente se è il primo della sessione; poi invia ad Arvow. **Default: salva in bozza.** Pubblicare = azione irreversibile verso terzi: richiede conferma esplicita articolo per articolo, anche se `modalita_pubblicazione: diretta`.
3. **QA** sull'output: aderenza al brief; keyword in title/H1/primo paragrafo; **test di personalizzazione**: l'articolo contiene l'angolo del cliente, le sue entità/servizi reali, il suo lessico e almeno un elemento non intercambiabile con un altro cliente (se no: da rivedere); FAQ presenti; lunghezza; link interni; ogni affermazione numerica senza fonte va **segnalata**; claim vietati assenti. Esito: OK / da rivedere con elenco puntuale.
4. Scrivi `<slug>/articoli/<slug-articolo>.md` (brief, esito QA, link alla bozza) e aggiorna `piano-editoriale.csv`: `stato` = `bozza` | `in revisione` | `pubblicato` (+ `url`).

Chiudi con un riepilogo e ciò che attende conferma.
