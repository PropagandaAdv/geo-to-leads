#!/usr/bin/env python3
"""Modalità B — importa l'export CSV del dashboard LeadRadar nello storico del cliente.
Uso: import_csv.py <slug> <export.csv> [--map colonna_csv=colonna_normalizzata ...]"""
import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import ALIASES, COLUMNS, merge_rows  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("slug")
    ap.add_argument("csv_file")
    ap.add_argument("--map", nargs="*", default=[], help="mappature manuali: 'Nome in CSV=azienda'")
    ap.add_argument("--delimiter", default=None)
    a = ap.parse_args()
    manual = dict(m.split("=", 1) for m in a.map)
    text = Path(a.csv_file).read_text(encoding="utf-8-sig")
    delim = a.delimiter or (";" if text.splitlines()[0].count(";") > text.splitlines()[0].count(",") else ",")
    reader = csv.DictReader(text.splitlines(), delimiter=delim)
    lookup = {}
    for target, names in ALIASES.items():
        for n in names:
            lookup[n.lower()] = target
    for k, v in manual.items():
        lookup[k.lower()] = v
    mapping = {h: lookup.get(h.strip().lower()) for h in reader.fieldnames or []}
    unmapped = [h for h, t in mapping.items() if not t]
    if "azienda" not in mapping.values():
        print("ERRORE: nessuna colonna riconosciuta come 'azienda'. Usa --map 'NomeColonna=azienda'.", file=sys.stderr)
        print("Intestazioni trovate:", reader.fieldnames, file=sys.stderr)
        return 1
    rows = []
    for raw in reader:
        r = {c: "" for c in COLUMNS}
        for h, t in mapping.items():
            if t and t in COLUMNS:
                r[t] = (raw.get(h) or "").strip()
        r["fonte"] = "csv"
        rows.append(r)
    added, total = merge_rows(a.slug, rows)
    print(f"Importate {added} nuove righe (totale storico: {total}).")
    if unmapped:
        print("Colonne ignorate:", unmapped)
    return 0


if __name__ == "__main__":
    sys.exit(main())
