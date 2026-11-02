"""Schema e utilità condivise (modalità B e C). I dati vivono fuori dal repo: <GEO_CLIENTS_DIR>/<slug>/leadradar/visite.csv"""
import csv
import os
from datetime import datetime
from pathlib import Path

COLUMNS = ["azienda", "sito", "settore", "paese", "dimensione", "icp_score", "visite",
           "pagine", "ultima_visita", "decision_maker", "fonte", "importato_il"]

# Intestazioni plausibili di un export -> colonna normalizzata.
# NOTA [INFERENZA]: i nomi reali dell'export LeadRadar non sono documentati pubblicamente;
# usa --map per correggere alla prima importazione reale.
ALIASES = {
    "azienda": ["azienda", "company", "company name", "organization", "nome azienda", "ragione sociale"],
    "sito": ["sito", "website", "domain", "dominio", "url"],
    "settore": ["settore", "industry", "sector"],
    "paese": ["paese", "country", "nazione"],
    "dimensione": ["dimensione", "size", "employees", "company size", "dipendenti"],
    "icp_score": ["icp_score", "icp score", "icp", "score", "fit score"],
    "visite": ["visite", "visits", "sessions", "numero visite", "visit count"],
    "pagine": ["pagine", "pages", "pages viewed", "pagine viste", "top pages"],
    "ultima_visita": ["ultima_visita", "last visit", "last seen", "ultima visita", "date", "data"],
    "decision_maker": ["decision_maker", "decision maker", "contact", "contatto", "contacts"],
}


def clients_dir() -> Path:
    return Path(os.path.expanduser(os.environ.get("GEO_CLIENTS_DIR", "~/agency-clients")))


def visits_path(slug: str) -> Path:
    return clients_dir() / slug / "leadradar" / "visite.csv"


def read_visits(slug: str):
    p = visits_path(slug)
    if not p.is_file():
        return []
    with p.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def merge_rows(slug: str, new_rows):
    """Aggiunge righe allo storico evitando duplicati (azienda+ultima_visita+pagine). Ritorna (aggiunte, totali)."""
    p = visits_path(slug)
    p.parent.mkdir(parents=True, exist_ok=True)
    rows = read_visits(slug)
    seen = {(r["azienda"].lower(), r["ultima_visita"], r["pagine"]) for r in rows}
    added = 0
    now = datetime.now().isoformat(timespec="seconds")
    for r in new_rows:
        key = (r["azienda"].lower(), r["ultima_visita"], r["pagine"])
        if not r["azienda"] or key in seen:
            continue
        seen.add(key)
        rows.append({**{c: "" for c in COLUMNS}, **r, "importato_il": now})
        added += 1
    with p.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)
    return added, len(rows)
