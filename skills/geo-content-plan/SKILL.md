---
name: geo-content-plan
description: Costruisce un piano editoriale GEO/SEO da un file cluster.csv (calendario, link interni, CTA, sintesi non tecnica per il cliente). Usare in /geo-piano.
---
# Piano editoriale GEO

1. **Selezione**: parti da `cluster.csv` ordinato per `priorita`. Pillar prima dei satelliti dello stesso cluster; max 1 pillar nuovo ogni 2 settimane circa (adatta alla capacità di revisione del cliente).
2. **Titolo provvisorio**: contiene la keyword principale, promette un beneficio concreto, niente clickbait. Formato coerente con l'intento (guida, comparativo, FAQ, caso studio, glossario).
3. **Lunghezza indicativa**: dichiarala come stima editoriale **[INFERENZA]** (non derivata da dati) salvo che i competitor top siano stati misurati.
4. **Link interni**: verso pagine esistenti (`pagine-esistenti.csv`) e altri articoli del piano; mai verso URL non verificati.
5. **CTA**: verso un servizio realmente presente in `client.yaml → prodotti_servizi`; coerente con la fase del funnel (awareness → risorsa; decision → contatto).
6. **Sintesi cliente (1 pagina)**: frasi corte, zero gergo (o spiegato), caldo e orientato ai benefici. Vietato promettere posizioni, traffico o tempi di risultato.
7. **Stato**: tutti `proposto` finché l'utente non approva.
Ogni cifra riporta fonte+data dal CSV di origine.
