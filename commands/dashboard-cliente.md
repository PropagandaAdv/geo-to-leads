---
description: Attiva un cliente nella dashboard (record, branding, invito, sorgente visite, prima sincronizzazione, guida)
argument-hint: "[slug-cliente]"
---
# /dashboard-cliente

Chiedi il cliente (argomento: $ARGUMENTS), carica `client.yaml` (valida con `validate_client.py`). Richiede la dashboard già creata con `/dashboard-setup` (`_agenzia/dashboard.yaml`) e `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` nei segreti dell'ambiente (mai in chat).

1. `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/sync_dashboard.py client <slug>` (mostra prima `--dry-run`).
2. Branding (logo, colore, nome visualizzato) e `latenza_visite` reale della sorgente: chiedi all'utente e aggiorna `clients`. **Non dichiarare "tempo reale"** se la fonte è CSV o alert email.
3. **Invito del referente** (`referente.email`): mostra destinatario e ruolo (`client_owner`) e invia l'invito solo dopo conferma esplicita.
4. Sorgente visite: aggiorna lo storico (`connectors/leadradar/ingest/...`) e lancia `sync_dashboard.py visits <slug>`.
5. Guida cliente in italiano, tono caldo (accesso, collegare email e calendario con spiegazione dei permessi, approvare le bozze, revocare): scrivi `<slug>/guida-dashboard.md`, esporta `.docx` con `export_docx.py`, carica con `sync_dashboard.py report <slug> --file ... --tipo guida --titolo "Guida alla dashboard"`.
6. Aggiorna `client.yaml` (`dashboard.attiva: true`) e fai commit+push del repo clienti.
