---
description: Checklist di setup Lead Radar per un cliente (snippet, ICP, alert email, privacy)
argument-hint: "[slug-cliente]"
---
# /leadradar-setup

Chiedi il cliente (argomento: $ARGUMENTS) e carica `client.yaml`.

## 0. Conferma il prodotto (non dare nulla per scontato)
Stato noto: *LeadRadar* (leadradar.idea4me.pl) identifica le aziende che visitano il sito via snippet, con pagine viste, decision maker, ICP score, alert email, export CSV; il piano Pro ha dashboard brandizzata. **Non risulta documentata pubblicamente alcuna API, webhook o server MCP.** **[INFERENZA]** potrebbe esistere un altro prodotto con lo stesso nome: chiedi all'utente di confermare URL e piano prima di procedere.

## 1. Checklist installazione snippet → `<slug>/leadradar/setup-checklist.md`
Via GTM (nuovo tag HTML personalizzato, trigger All Pages, consenso cookie) oppure via tema/snippet manager WordPress. Includi: dove prendere lo snippet nel dashboard, test in anteprima, verifica che la visita compaia, rollback. **Non installare nulla su siti live senza conferma esplicita.** Se il sito è WordPress e c'è un MCP WordPress collegato, proponi l'inserimento via snippet manager **in stato inattivo/bozza** e attiva solo dopo conferma.

## 2. ICP nel dashboard
Elenca i valori da inserire (settori, dimensioni, paesi) presi da `client.yaml → icp`. La configurazione si fa a mano nel dashboard.

## 3. Alert in tempo reale
Usa gli alert email nativi verso `client.yaml → leadradar.alert_email` (via più semplice e affidabile finché non c'è un'API). Opzionale: inoltra una copia a una casella agenzia per il connettore modalità C (`connectors/leadradar/`).

## 4. Privacy (GDPR) — da far validare al consulente privacy del cliente
- [ ] Privacy policy aggiornata (tracciamento visitatori, identificazione aziende, fornitore come responsabile/terza parte, base giuridica)
- [ ] Cookie banner: lo script parte solo dopo il consenso se richiesto
- [ ] Registro dei trattamenti / DPA col fornitore; sede dei dati
- [ ] Tempi di conservazione; procedura diritti degli interessati
Questa non è consulenza legale.

## 5. Chiusura
Imposta `leadradar.abilitato: true` in `client.yaml` solo a setup confermato. Suggerisci `/leadradar-report`.
