#!/usr/bin/env python3
"""Valida un client.yaml. Uso: validate_client.py <percorso/client.yaml>
Exit 0 = ok, 1 = errori. Richiede PyYAML."""
import re
import sys
from pathlib import Path

import yaml

REQUIRED_STR = ["slug", "nome", "sito_url", "settore", "area_geografica", "lingua", "mercato", "tono_di_voce"]
LISTS = ["prodotti_servizi", "competitor_noti", "claim_vietati"]
TARGETS = {"B2B", "B2C", "MISTO"}
STATI = {"attivo", "sospeso", "chiuso"}
PUBBL = {"bozza", "diretta"}


def validate(d):
    e, w = [], []
    if not isinstance(d, dict):
        return ["il file non è una mappa YAML"], w
    for k in REQUIRED_STR:
        if not isinstance(d.get(k), str) or not d[k].strip():
            e.append(f"{k}: obbligatorio, stringa non vuota")
    slug = d.get("slug")
    if isinstance(slug, str) and slug and not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", slug):
        e.append("slug: deve essere kebab-case (a-z, 0-9, trattini)")
    url = d.get("sito_url")
    if isinstance(url, str) and url and not re.fullmatch(r"https?://[^\s/]+\.[^\s/]+\S*", url):
        e.append("sito_url: URL http(s) non valido")
    if d.get("target") not in TARGETS:
        e.append(f"target: uno di {sorted(TARGETS)}")
    if d.get("stato") not in STATI:
        e.append(f"stato: uno di {sorted(STATI)}")
    for k in LISTS:
        if not isinstance(d.get(k), list):
            e.append(f"{k}: deve essere una lista")
    if isinstance(d.get("prodotti_servizi"), list) and not d["prodotti_servizi"]:
        e.append("prodotti_servizi: almeno un elemento")
    icp = d.get("icp")
    if not isinstance(icp, dict) or not isinstance(icp.get("settori"), list) or not isinstance(icp.get("paesi"), list):
        e.append("icp: mappa con 'settori' e 'paesi' (liste)")
    arv = d.get("arvow")
    if not isinstance(arv, dict) or arv.get("modalita_pubblicazione") not in PUBBL:
        e.append(f"arvow.modalita_pubblicazione: una di {sorted(PUBBL)}")
    elif arv["modalita_pubblicazione"] == "diretta":
        w.append("arvow: 'diretta' impostata; la pubblicazione richiede comunque conferma esplicita")
    lr = d.get("leadradar")
    if not isinstance(lr, dict):
        e.append("leadradar: mappa mancante")
    else:
        mail = lr.get("alert_email", "")
        if lr.get("abilitato") and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", str(mail)):
            e.append("leadradar.alert_email: obbligatoria e valida se abilitato=true")
        elif mail and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", str(mail)):
            e.append("leadradar.alert_email: formato non valido")
    if not isinstance(d.get("ubersuggest"), dict):
        e.append("ubersuggest: mappa mancante")
    for k in ("buyer_persona", "cms"):
        if not d.get(k):
            w.append(f"{k}: vuoto")
    return e, w


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    p = Path(sys.argv[1])
    if not p.is_file():
        print(f"File non trovato: {p}")
        return 2
    try:
        data = yaml.safe_load(p.read_text(encoding="utf-8"))
    except yaml.YAMLError as ex:
        print(f"YAML non valido: {ex}")
        return 1
    errors, warns = validate(data)
    for x in warns:
        print(f"AVVISO  {x}")
    for x in errors:
        print(f"ERRORE  {x}")
    if errors:
        print(f"\n{len(errors)} errori")
        return 1
    print("OK: client.yaml valido")
    return 0


if __name__ == "__main__":
    sys.exit(main())
