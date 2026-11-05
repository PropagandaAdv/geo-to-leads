#!/usr/bin/env python3
"""Sincronizza dati del plugin verso il database della dashboard (Supabase / Lovable Cloud) via REST.
Variabili d'ambiente (segreti dell'ambiente cloud, mai nel repo): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
Comandi:
  client <slug>                         crea/aggiorna il record cliente da client.yaml
  visits <slug> [--csv file]            visite+aziende da <slug>/leadradar/visite.csv
  drafts <slug> --file bozze.json       bozze email (SEMPRE stato 'bozza': mai invio)
  report <slug> --file f --tipo T --titolo "..." [--periodo P]   carica il file nello Storage e lo registra
  export-visits <slug> [--days N]       legge le visite dal database (JSON su stdout)
  profile <slug>                        profilo Outreach attivo (ICP, tono di voce, offerta, limiti) in JSON su stdout
  icp-pending <slug>                    aziende senza valutazione ICP sulla versione attiva del profilo (JSON)
  icp <slug> --file valutazioni.json    scrive le valutazioni ICP [{azienda,stato,motivazione,evidenze[]}]; non tocca gli override del titolare
  visibility <slug> --file vis.json     posizionamento, visibilita' IA, citazioni, storico mensile (ogni dato con fonte e data)
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
STATI_ICP = {"in_target", "fuori_target", "da_verificare"}
PROVIDER_IA = {"openai", "gemini", "google_aio", "perplexity", "altro"}


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


def active_profile(api, cid):
    if api.dry:
        return {"id": "00000000-0000-0000-0000-000000000001", "versione": 0}
    r = api.call("GET", f"/rest/v1/v_outreach_attivo?client_id=eq.{cid}&select=*")
    if not r:
        sys.exit("ERRORE: nessun profilo Outreach attivo (ICP e tono di voce). Va definito dal titolare nelle Impostazioni Outreach della dashboard.")
    return r[0]


def cmd_drafts(a, api):
    items = json.loads(Path(a.file).read_text(encoding="utf-8"))
    cid = api.client_id(a.slug)
    prof = active_profile(api, cid)
    rows, rifiutate = [], []
    for it in items:
        for k in ("azienda", "destinatario", "oggetto", "corpo"):
            if not it.get(k):
                sys.exit(f"ERRORE: bozza senza '{k}': {it}")
        company_id = None
        if not api.dry:
            r = api.call("GET", f"/rest/v1/companies?client_id=eq.{cid}&nome=eq.{urllib.parse.quote(it['azienda'])}&select=id")
            if not r:
                rifiutate.append((it["azienda"], "azienda non presente nella dashboard"))
                continue
            company_id = r[0]["id"]
            st = api.call("GET", f"/rest/v1/v_company_icp?company_id=eq.{company_id}&select=stato_effettivo")
            stato = (st[0]["stato_effettivo"] if st else None) or "non valutata"
            if stato != "in_target":
                rifiutate.append((it["azienda"], f"stato ICP: {stato}"))
                continue
        rows.append({"client_id": cid, "company_id": company_id, "profile_id": prof["id"],
                     "destinatario": it["destinatario"], "oggetto": it["oggetto"], "corpo": it["corpo"],
                     "stato": "bozza"})  # forzato: mai invio dal plugin
    if rifiutate:
        print("NON scritte (il database accetta bozze solo per aziende in target):")
        for n, m in rifiutate:
            print(f"  - {n}: {m}")
    if rows:
        api.call("POST", "/rest/v1/email_messages", rows, {"Prefer": "return=minimal"})
    print(f"{len(rows)} bozze scritte in stato 'bozza' (da approvare dal cliente in dashboard); {len(rifiutate)} rifiutate.")


def cmd_profile(a, api):
    cid = api.client_id(a.slug)
    print(json.dumps(active_profile(api, cid), ensure_ascii=False, indent=1))


def cmd_icp_pending(a, api):
    cid = api.client_id(a.slug)
    prof = active_profile(api, cid)
    comps = api.call("GET", f"/rest/v1/companies?client_id=eq.{cid}&select=id,nome,dominio,settore,dimensione,paese,ultima_visita&order=ultima_visita.desc.nullslast") or []
    done = {e["company_id"] for e in (api.call("GET", f"/rest/v1/icp_evaluations?profile_id=eq.{prof['id']}&select=company_id") or [])}
    print(json.dumps([c for c in comps if c["id"] not in done], ensure_ascii=False, indent=1))


def cmd_icp(a, api):
    items = json.loads(Path(a.file).read_text(encoding="utf-8"))
    cid = api.client_id(a.slug)
    prof = active_profile(api, cid)
    rows = []
    for it in items:
        if it.get("stato") not in STATI_ICP:
            sys.exit(f"ERRORE: stato ICP non valido {it.get('stato')!r} (ammessi {sorted(STATI_ICP)}): {it.get('azienda')}")
        if not (it.get("motivazione") or "").strip():
            sys.exit(f"ERRORE: motivazione mancante: {it.get('azienda')}")
        ev = it.get("evidenze") or []
        if not ev or any(not (e.get("dato") and e.get("fonte") and e.get("data")) for e in ev):
            sys.exit(f"ERRORE: ogni valutazione richiede evidenze con dato, valore, fonte e data (usa valore 'n.d.' se manca): {it.get('azienda')}")
        company_id = "00000000-0000-0000-0000-000000000000"
        if not api.dry:
            r = api.call("GET", f"/rest/v1/companies?client_id=eq.{cid}&nome=eq.{urllib.parse.quote(it['azienda'])}&select=id")
            if not r:
                sys.exit(f"ERRORE: azienda '{it['azienda']}' non presente nella dashboard (importa prima le visite).")
            company_id = r[0]["id"]
        rows.append({"client_id": cid, "company_id": company_id, "profile_id": prof["id"], "stato": it["stato"],
                     "motivazione": it["motivazione"].strip(), "evidenze": ev})
    # merge-duplicates aggiorna solo le colonne inviate: gli override del titolare non vengono toccati
    api.upsert("icp_evaluations", rows, "company_id,profile_id")
    c = {s: sum(1 for r in rows if r["stato"] == s) for s in sorted(STATI_ICP)}
    print(f"Valutazioni scritte: {len(rows)} ({c}) sul profilo v{prof.get('versione')}.")


def cmd_visibility(a, api):
    d = json.loads(Path(a.file).read_text(encoding="utf-8"))
    cid = api.client_id(a.slug)

    def need(row, keys, tab):
        for k in keys:
            if row.get(k) in (None, ""):
                sys.exit(f"ERRORE: {tab}: campo '{k}' mancante (ogni dato richiede fonte e data; niente valori inventati): {row}")

    rk = []
    for r in d.get("rankings", []):
        need(r, ("keyword", "rilevato_il", "fonte"), "rankings")
        rk.append({"client_id": cid, "keyword": r["keyword"], "url": r.get("url"), "posizione": r.get("posizione"),
                   "volume": r.get("volume"), "difficolta": r.get("difficolta"), "lingua": r.get("lingua", "it"),
                   "paese": r.get("paese", "IT"), "rilevato_il": r["rilevato_il"], "fonte": r["fonte"]})
    sn = []
    for r in d.get("ai_snapshots", []):
        need(r, ("provider", "rilevato_il", "fonte"), "ai_snapshots")
        if r["provider"] not in PROVIDER_IA:
            sys.exit(f"ERRORE: provider IA non valido {r['provider']!r} (ammessi {sorted(PROVIDER_IA)})")
        sn.append({"client_id": cid, **{k: r.get(k) for k in ("provider", "visibilita_pct", "rank_medio", "share_of_voice",
                                                              "menzioni", "sentiment", "rilevato_il", "fonte")}})
    ct = []
    TIPI_FONTE = {"owned", "competitor", "social", "third_party"}
    for r in d.get("citations", []):
        need(r, ("rilevato_il", "fonte"), "citations")
        # riga per prompt: prompt + provider; riga aggregata per pagina: url_citato (prompt assente)
        if not r.get("prompt") and not r.get("url_citato"):
            sys.exit(f"ERRORE: citations: serve 'prompt' (per prompt) oppure 'url_citato' (aggregata per pagina): {r}")
        if r.get("prompt") and not r.get("provider"):
            sys.exit(f"ERRORE: citations: la citazione per prompt richiede 'provider': {r}")
        if r.get("provider") is not None and r["provider"] not in PROVIDER_IA:
            sys.exit(f"ERRORE: provider IA non valido {r['provider']!r}")
        piat = r.get("piattaforme") or []
        if any(x not in PROVIDER_IA for x in piat):
            sys.exit(f"ERRORE: citations: 'piattaforme' non valide {piat}")
        if r.get("tipo_fonte") is not None and r["tipo_fonte"] not in TIPI_FONTE:
            sys.exit(f"ERRORE: citations: tipo_fonte non valido {r['tipo_fonte']!r}")
        ct.append({"client_id": cid, "provider": r.get("provider"), "prompt": r.get("prompt"), "url_citato": r.get("url_citato"),
                   "dominio": r.get("dominio"), "cita_cliente": bool(r.get("cita_cliente")), "competitor": r.get("competitor"),
                   "piattaforme": piat, "argomenti": r.get("argomenti") or [], "titolo": r.get("titolo"), "tipo_fonte": r.get("tipo_fonte"),
                   "risposte_citanti": r.get("risposte_citanti"), "quota_citazione": r.get("quota_citazione"),
                   "rilevato_il": r["rilevato_il"], "fonte": r["fonte"]})
    tr = []
    for r in d.get("traffic", []):
        need(r, ("mese", "fonte"), "traffic")
        if not str(r["mese"]).endswith("-01"):
            sys.exit(f"ERRORE: traffic.mese deve essere il primo del mese (AAAA-MM-01): {r['mese']}")
        tr.append({"client_id": cid, **{k: r.get(k) for k in ("mese", "traffico_organico", "keyword_organiche", "domain_authority",
                                                              "backlink", "domini_referenti", "fonte")}})
    api.upsert("keyword_rankings", rk, "client_id,keyword,lingua,paese,rilevato_il")
    api.upsert("ai_visibility_snapshots", sn, "client_id,provider,rilevato_il")
    api.upsert("traffic_history", tr, "client_id,mese")
    if ct:  # si sostituisce la rilevazione dello stesso giorno (per prompt: per provider; aggregate: tutte)
        for prov, day in sorted({(c["provider"], c["rilevato_il"]) for c in ct if c["prompt"]}):
            api.call("DELETE", f"/rest/v1/ai_citations?client_id=eq.{cid}&provider=eq.{prov}&rilevato_il=eq.{day}&prompt=not.is.null")
        for day in sorted({c["rilevato_il"] for c in ct if not c["prompt"]}):
            api.call("DELETE", f"/rest/v1/ai_citations?client_id=eq.{cid}&rilevato_il=eq.{day}&prompt=is.null")
        api.call("POST", "/rest/v1/ai_citations", ct, {"Prefer": "return=minimal"})
    print(f"Visibilita': ranking {len(rk)} · snapshot IA {len(sn)} · citazioni {len(ct)} · mesi {len(tr)}")


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
    for name in ("client", "visits", "drafts", "report", "export-visits", "profile", "icp-pending", "icp", "visibility"):
        s = sp.add_parser(name)
        s.add_argument("slug")
        s.add_argument("--dry-run", action="store_true")
        if name == "visits":
            s.add_argument("--csv")
        if name in ("drafts", "report", "icp", "visibility"):
            s.add_argument("--file", required=True)
        if name == "report":
            s.add_argument("--tipo", required=True)
            s.add_argument("--titolo", required=True)
            s.add_argument("--periodo")
        if name == "export-visits":
            s.add_argument("--days", type=int, default=7)
    a = ap.parse_args()
    api = Api(a.dry_run)
    {"client": cmd_client, "visits": cmd_visits, "drafts": cmd_drafts, "report": cmd_report, "export-visits": cmd_export,
     "profile": cmd_profile, "icp-pending": cmd_icp_pending, "icp": cmd_icp, "visibility": cmd_visibility}[a.cmd](a, api)


if __name__ == "__main__":
    main()
