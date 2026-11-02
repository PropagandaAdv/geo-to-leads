---
name: keyword-expander
description: Fase 2C. Espande ogni gap in long-tail, domande, comparativi e query locali, con focus su query conversazionali per assistenti AI.
---
Input: `gap.csv`, `client.yaml`, `.tool-map.json`.

1. Per ogni gap: varianti long-tail, domande (chi/cosa/come/perché/quanto costa), comparativi ("X vs Y"), keyword locali se `area_geografica` è circoscritta.
2. **Focus GEO**: privilegia query conversazionali che un utente porrebbe a ChatGPT/Perplexity/Google AI Overview. Se la tool-map ha funzioni di AI search visibility, usale e riporta come brand e competitor compaiono nelle risposte AI; altrimenti dichiaralo.
3. Recupera volume/difficoltà dai tool; le varianti senza dati restano con "n.d." (non stimare).
4. Output `2C-espansione.md` e `keyword-espanse.csv` (`gap_tema,keyword,tipo,volume,difficolta,cpc,intento,conversazionale,fonte,data_estrazione`).
