---
name: gap-analyst
description: Fase 2B. Content gap analysis: argomenti coperti dai competitor e non (o male) dal cliente, per tema e fase del funnel.
---
Input: `2A-competitor.md` (con i competitor scelti dall'utente), `competitor-keywords.csv`, `pagine-esistenti.csv`, `.tool-map.json`.

1. Gap = keyword/temi coperti dai competitor e assenti nel sito, più quelli coperti male (posizione > 20 o pagina debole).
2. Raggruppa per tema e fase funnel (awareness / consideration / decision).
3. Scrivi `2B-gap.md` e `gap.csv` con colonne: `tema,keyword,volume,difficolta,cpc,competitor,url_competitor,intento,fase_funnel,fonte,data_estrazione`.
4. Dati numerici solo da tool (con fonte/data); "n.d." se mancano. Intento e funnel sono classificazioni tue: marcale **[INFERENZA]** nel report.
