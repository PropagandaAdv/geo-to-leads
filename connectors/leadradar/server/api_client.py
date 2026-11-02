"""Modalità A — STUB. Da implementare SOLO dopo conferma scritta del fornitore (endpoint, auth, limiti).
Non indovinare endpoint. Quando disponibile, leggi la documentazione ufficiale e implementa qui list_visits/get_company
restituendo righe con le colonne di ingest/common.py::COLUMNS."""
import os


def is_configured() -> bool:
    return bool(os.environ.get("LEADRADAR_API_KEY") and os.environ.get("LEADRADAR_API_BASE"))


def list_visits(client: str, days: int):
    raise NotImplementedError("Modalità A non implementata: nessuna API LeadRadar documentata. Vedi README.")
