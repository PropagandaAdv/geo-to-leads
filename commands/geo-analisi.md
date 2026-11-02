---
description: Analisi GEO/SEO completa di un cliente (baseline, competitor, gap, keyword, cluster, audit GEO) con dati Ubersuggest
argument-hint: "[slug-cliente]"
---
# /geo-analisi

## Dati in cloud (obbligatorio)
Il filesystem della sessione è effimero. Prima di tutto verifica che `${GEO_CLIENTS_DIR}` sia il checkout di un repo GitHub **privato** dei clienti (es. `propagandaadv/geo-clients`); se non è collegato, usa `add_repo` (accesso push) per collegarlo e clonalo lì. A fine di ogni fase: `git add`, commit e push su quel repo (mai nel repo del plugin). Non uscire dalla sessione con dati non pushati.

**Chiedi sempre: "Per quale cliente faccio l'analisi?"** Elenca le cartelle in `${GEO_CLIENTS_DIR:-/home/user/geo-clients}` (solo quelle con `client.yaml`, `stato: attivo`). Argomento ricevuto: $ARGUMENTS. Carica `client.yaml`. Nessun dato cliente hard-coded.

## Regole
- Ogni numero (volume, difficoltà, CPC, traffico) riporta **tool + data di estrazione**. Niente numeri a memoria: se un dato manca, scrivi "n.d.".
- Distingui sempre dato verificato da **[INFERENZA]**.
- Output in `<slug>/analisi/AAAA-MM-GG/` (data odierna), ogni fase = `.md` + CSV grezzo.

## Discovery MCP (obbligatoria, prima di tutto)
1. Elenca i tool realmente esposti dal server MCP `ubersuggest`. Non inventare nomi.
2. Mappa le operazioni richieste (panoramica dominio, keyword posizionate, pagine top, backlink, competitor, keyword ideas, gap, AI visibility, gestione progetto) sui tool trovati.
3. Salva `<slug>/.tool-map.json`: `{"server":"ubersuggest","data":"AAAA-MM-GG","operazioni":{"<operazione>":"<tool>|null"}}`.
4. Per ogni operazione senza tool: dillo esplicitamente e proponi l'alternativa (es. dedurre da altri tool, WebFetch su sitemap, dato fornito a mano).
5. Se il server non è connesso/autenticato, fermati e spiega come collegarlo (`claude mcp add --transport http ubersuggest https://ubersuggest-mcp.neilpatelapi.com/mcp`, poi `/mcp` per l'OAuth).

Se il dominio non ha un progetto Ubersuggest (`ubersuggest.progetto_esistente: false`), **proponi di crearlo e chiedi conferma** prima di farlo; poi aggiungi competitor e keyword. Aggiorna `client.yaml`.

## Fasi
**Fase 0 — Profilo cliente + baseline** → `profilo-cliente.md` (skill `client-profile`, **base di ogni testo successivo**), `00-baseline.md`, `pagine-esistenti.csv`: keyword posizionate, traffico organico stimato, pagine top, backlink overview; inventario contenuti (pagine top + sitemap se leggibile via WebFetch).

**Fase 2A — Competitor** (subagent `competitor-scout`) → `2A-competitor.md`, `competitor-keywords.csv`. Mostra **entrambe** le liste (competitor commerciali dichiarati vs organici reali) e **lascia scegliere all'utente** i 3–5 da usare prima di procedere.

**Fase 2B — Gap** (subagent `gap-analyst`) → `2B-gap.md`, `gap.csv` con colonne: `tema,keyword,volume,difficolta,cpc,competitor,url_competitor,intento,fase_funnel,fonte,data_estrazione`.

**Fase 2C — Espansione** (subagent `keyword-expander`) → `2C-espansione.md`, `keyword-espanse.csv`. Focus query conversazionali per assistenti AI; usa le funzioni di AI search visibility di Ubersuggest solo se presenti nella tool-map.

**Fase 2D — Cluster** (subagent `cluster-strategist`) → `2D-cluster.md`, `cluster.csv`. Formula priorità visibile nel report.

**Audit GEO** (subagent `geo-auditor`) → `audit-geo.md`.

Passa a ogni subagent: percorso della cartella analisi, `client.yaml`, `.tool-map.json` e i file delle fasi precedenti. Dopo ogni fase riassumi brevemente all'utente e chiedi se procedere solo dove serve una scelta (competitor).

## Personalizzazione (vincolo di tutto il workflow)
Nessun output generico. Ogni raccomandazione deve citare l'evidenza specifica del cliente (riga di `gap.csv`, competitor, pagina esistente, voce di `profilo-cliente.md`). Se un paragrafo potrebbe valere per un altro cliente senza modifiche, riscrivilo o eliminalo.

## Chiusura
Assembla un riepilogo con `${CLAUDE_PLUGIN_ROOT}/templates/report-analisi.md` → `report-analisi.md` e suggerisci `/geo-piano`.
