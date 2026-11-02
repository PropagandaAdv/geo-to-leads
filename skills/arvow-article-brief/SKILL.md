---
name: arvow-article-brief
description: Scrive il brief di un articolo per Arvow con struttura GEO (risposta diretta, FAQ, entità, link interni, CTA). Usare in /geo-articoli.
---
# Brief articolo per Arvow

Compila `${CLAUDE_PLUGIN_ROOT}/templates/brief-articolo.md` da una riga del piano e da `client.yaml`.

- **Risposta diretta**: 2–3 frasi in apertura che rispondono alla query principale in modo autonomo e citabile.
- **Struttura**: H2/H3 che coprono le domande reali (da `keyword-espanse.csv`), ordine dal più generale al più specifico.
- **FAQ**: 4–6 domande conversazionali con risposte brevi (40–60 parole), adatte a FAQPage.
- **Entità**: brand, prodotti, normative, standard, luoghi da citare per nome.
- **Fonti**: indica dove servono dati; imponi "nessuna statistica senza fonte citata".
- **Tono**: da `tono_di_voce`; elenca esplicitamente `claim_vietati`.
- **Lingua/mercato** da `client.yaml`. Link interni e CTA dal piano.
Il brief è la specifica che Arvow riceve: deve bastare da solo, senza contesto della conversazione.
