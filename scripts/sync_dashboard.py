#!/usr/bin/env python3
"""Sincronizza dati del plugin verso il database della dashboard (Supabase / Lovable Cloud) via REST.
Variabili d'ambiente (segreti dell'ambiente cloud, mai nel repo): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
Comandi:
  client <slug>                         crea/aggiorna il record cliente da client.yaml
  visits <slug> [--csv file]            visite+aziende da <slug>/leadradar/visite.csv
  drafts <slug> --file bozze.json       bozze email (SEMPRE stato 'bozza': mai invio)
  report <slug> --file f --tipo T --titolo "..." [--periodo P]   carica il file nello Storage e lo registra
  export-visits <slug> [--days N]       legge le visite dal database (JSON su stdout)
Tutti accettano --dry-run (nessuna chiamata di rete, mostra i payload)."""
import argparse
import csv
import hashlib
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

import yaml

TIPI_REPORT = {"digest", "piano_editoriale", "analisi", "guida"}


def clients_dir():
    return Path(os.path.expanduser(os.environ.get("GEO_CLIENTS_DIR", "/home/user/geo-clients")))


def parse_date(s):
    s = (s or "").strip()
    if not s:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%d/%m/%Y %H:%M", "%d/%m/%Y"):
        try:
            d = datetime.strptime(s, fmt)
            return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
        except ValueError:
            pass
    try:
        d = parsedate_to_datetime(s)
        return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
    except Exception:
        return None


def num(s):
    try:
        return float(str(s).replace(",", ".")) if str(s).strip() else None
    except ValueError:
        return None


class Api:
    def __init__(self, dry):
        self.dry = dry
        self.base = os.environ.get("SUPABASE_URL", "").rstrip("/")
        self.key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
        if not dry and not (self.base and self.key):
            sys.exit("ERRORE: imposta SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY nell'ambiente cloud (oppure usa --dry-run).")

    def call(self, method, path, body=None, headers=None, raw=None):
        if self.dry:
            print(f"[dry-run] {method} {path}")
            if body is not None:
                print(json.dumps(body, ensure_ascii=False, indent=1, default=str)[:1500])
            return [] if method == "GET" else None
        h = {"apikey": self.key, "Authorization": f"Bearer {self.key}", **(headers or {})}
        data = raw
        if body is not None:
            data = json.dumps(body, default=str).encode()
            h["Content-Type"] = "application/json"
        req = urllib.request.Request(self.base + path, data=data, method=method, headers=h)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                txt = r.read().decode()
                return json.loads(txt) if txt else None
        except urllib.error.HTTPError as e:
            sys.exit(f"ERRORE HTTP {e.code} su {method} {path}: {e.read().decode()[:400]}")

    def client_id(self, slug):
        if self.dry:
            return "00000000-0000-0000-0000-000000000000"
        r = self.call("GET", f"/rest/v1/clients?slug=eq.{urllib.parse.quote(slug)}&select=id")
        if not r:
            sys.exit(f"ERRORE: cliente '{slug}' non presente nella dashboard. Esegui prima: sync_dashboard.py client {slug}")
        return r[0]["id"]

    def upsert(self, table, rows, conflict):
        if not rows:
            return []
        return self.call("POST", f"/rest/v1/{table}?on_conflict={conflict}", rows,
                         {"Prefer": "resolution=merge-duplicates,return=representation"})


def cmd_client(a, api):
    cfg = yaml.safe_load((clients_dir() / a.slug / "client.yaml").read_text(encoding="utf-8"))
    row = {"slug": cfg["slug"], "nome": cfg["nome"], "dominio": cfg.get("sito_url", ""),
           "servizi": {"leadradar": bool(cfg.get("leadradar", {}).get("abilitato"))},
           "attivo": cfg.get("stato") == "attivo"}
    api.upsert("clients", [row], "slug")
    print(f"Cliente '{a.slug}' sincronizzato.")


def cmd_visits(a, api):
    src = Path(a.csv) if a.csv else clients_dir() / a.slug / "leadradar" / "visite.csv"
    if not src.is_file():
        sys.exit(f"ERRORE: {src} non trovato (importa prima l'export con connectors/leadradar/ingest/import_csv.py).")
    cid = api.client_id(a.slug)
    companies, visits, skipped = {}, [], []
    for r in csv.DictReader(src.open(encoding="utf-8", newline="")):
        nome = (r.get("azienda") or "").strip()
        d = parse_date(r.get("ultima_visita"))
        if not nome or d is None:
            skipped.append(nome or "(senza nome)")  # niente date inventate
            continue
        c = companies.setdefault(nome, {"client_id": cid, "nome": nome, "dominio": r.get("sito") or None,
                                        "settore": r.get("settore") or None, "dimensione": r.get("dimensione") or None,
                                        "paese": r.get("paese") or None, "icp_score": num(r.get("icp_score")),
                                        "fonte": r.get("fonte") or "csv", "prima_visita": d.isoformat(), "ultima_visita": d.isoformat()})
        c["prima_visita"] = min(c["prima_visita"], d.isoformat())
        c["ultima_visita"] = max(c["ultima_visita"], d.isoformat())
        pagine = [p.strip() for p in (r.get("pagine") or "").replace(";", ",").split(",") if p.strip()]
        key = hashlib.sha1(f"{nome}|{d.isoformat()}|{','.join(pagine)}".encode()).hexdigest()
        visits.append({"nome": nome, "row": {"client_id": cid, "visited_at": d.isoformat(), "pagine": pagine,
                                             "fonte": r.get("fonte") or "csv", "dedupe_key": key}})
    saved = api.upsert("companies", list(companies.values()), "client_id,nome")
    ids = {c["nome"]: c["id"] for c in saved} if saved else {n: "00000000-0000-0000-0000-000000000000" for n in companies}
    api.upsert("visits", [{**v["row"], "company_id": ids[v["nome"]]} for v in visits], "client_id,dedupe_key")
    print(f"Aziende: {len(companies)} · visite: {len(visits)} · scartate (nome/data mancanti): {len(skipped)}")
    if skipped:
        print("Scartate:", ", ".join(skipped[:10]))


def cmd_drafts(a, api):
    items = json.loads(Path(a.file).read_text(encoding="utf-8"))
    cid = api.client_id(a.slug)
    rows = []
    for it in items:
        for k in ("destinatario", "oggetto", "corpo"):
            if not it.get(k):
                sys.exit(f"ERRORE: bozza senza '{k}': {it}")
        company_id = None
        if it.get("azienda") and not api.dry:
            r = api.call("GET", f"/rest/v1/companies?client_id=eq.{cid}&nome=eq.{urllib.parse.quote(it['azienda'])}&select=id")
            company_id = r[0]["id"] if r else None
        rows.append({"client_id": cid, "company_id": company_id, "destinatario": it["destinatario"],
                     "oggetto": it["oggetto"], "corpo": it["corpo"], "stato": "bozza"})  # forzato: mai invio dal plugin
    api.call("POST", "/rest/v1/email_messages", rows, {"Prefer": "return=minimal"})
    print(f"{len(rows)} bozze scritte in stato 'bozza' (da approvare dal cliente in dashboard).")


def cmd_report(a, api):
    if a.tipo not in TIPI_REPORT:
        sys.exit(f"ERRORE: --tipo uno di {sorted(TIPI_REPORT)}")
    f = Path(a.file)
    cid = api.client_id(a.slug)
    path = f"{cid}/{f.name}"
    ctype = mimetypes.guess_type(f.name)[0] or "application/octet-stream"
    api.call("POST", f"/storage/v1/object/reports/{urllib.parse.quote(path)}", None,
             {"Content-Type": ctype, "x-upsert": "true"}, raw=None if api.dry else f.read_bytes())
    api.call("POST", "/rest/v1/reports", [{"client_id": cid, "tipo": a.tipo, "titolo": a.titolo,
                                           "periodo": a.periodo, "storage_path": path}], {"Prefer": "return=minimal"})
    print(f"Report caricato: {path}")


def cmd_export(a, api):
    cid = api.client_id(a.slug)
    since = (datetime.now(timezone.utc) - timedelta(days=a.days)).isoformat()
    q = f"/rest/v1/visits?client_id=eq.{cid}&visited_at=gte.{urllib.parse.quote(since)}&select=visited_at,pagine,fonte,companies(nome,settore,paese,icp_score)&order=visited_at.desc"
    print(json.dumps(api.call("GET", q), ensure_ascii=False, indent=1))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    for name in ("client", "visits", "drafts", "report", "export-visits"):
        s = sp.add_parser(name)
        s.add_argument("slug")
        s.add_argument("--dry-run", action="store_true")
        if name == "visits":
            s.add_argument("--csv")
        if name in ("drafts", "report"):
            s.add_argument("--file", required=True)
        if name == "report":
            s.add_argument("--tipo", required=True)
            s.add_argument("--titolo", required=True)
            s.add_argument("--periodo")
        if name == "export-visits":
            s.add_argument("--days", type=int, default=7)
    a = ap.parse_args()
    api = Api(a.dry_run)
    {"client": cmd_client, "visits": cmd_visits, "drafts": cmd_drafts, "report": cmd_report, "export-visits": cmd_export}[a.cmd](a, api)


if __name__ == "__main__":
    main()
