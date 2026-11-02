#!/usr/bin/env python3
"""Modalità C — estrae azienda/pagine/orario dagli alert email LeadRadar e li aggiunge allo storico.
Sorgenti: cartella di file .eml (--eml-dir) oppure IMAP (--imap, credenziali da env LEADRADAR_IMAP_*).
Alternativa senza IMAP: l'agente legge gli alert con l'MCP Gmail e salva ogni corpo in un .eml/.txt, poi usa --eml-dir.

ATTENZIONE [INFERENZA]: il formato reale degli alert non è documentato pubblicamente. Il parser cerca
etichette comuni (Azienda/Company, Pagine/Pages, Settore/Industry, ICP). Alla prima email reale verifica
con --dry-run e adatta LABELS."""
import argparse
import email
import imaplib
import os
import re
import sys
from email import policy
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import COLUMNS, merge_rows  # noqa: E402

LABELS = {
    "azienda": r"(?:azienda|company(?: name)?|organization)",
    "settore": r"(?:settore|industry)",
    "paese": r"(?:paese|country)",
    "icp_score": r"(?:icp(?: score)?|score)",
    "pagine": r"(?:pagine(?: viste)?|pages(?: viewed)?|visited pages)",
    "decision_maker": r"(?:decision maker|contatto|contact)",
}


def parse_body(body: str, date_hdr: str):
    r = {c: "" for c in COLUMNS}
    for key, lab in LABELS.items():
        m = re.search(rf"(?im)^\s*{lab}\s*[:\-–]\s*(.+)$", body)
        if m:
            r[key] = m.group(1).strip()
    r["ultima_visita"] = date_hdr
    r["visite"] = "1"
    r["fonte"] = "alert_email"
    return r if r["azienda"] else None


def text_of(msg) -> str:
    part = msg.get_body(preferencelist=("plain", "html"))
    t = part.get_content() if part else ""
    return re.sub(r"<[^>]+>", "\n", t) if part and part.get_content_type() == "text/html" else t


def from_msg(msg):
    return parse_body(text_of(msg), msg.get("Date", ""))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("slug")
    ap.add_argument("--eml-dir")
    ap.add_argument("--imap", action="store_true")
    ap.add_argument("--from-contains", default="leadradar", help="filtro sul mittente (IMAP)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    rows = []
    if a.eml_dir:
        for f in sorted(Path(a.eml_dir).iterdir()):
            if f.suffix.lower() in (".eml", ".txt"):
                msg = email.message_from_bytes(f.read_bytes(), policy=policy.default)
                if r := from_msg(msg):
                    rows.append(r)
    elif a.imap:
        host, user, pw = (os.environ.get(k) for k in ("LEADRADAR_IMAP_HOST", "LEADRADAR_IMAP_USER", "LEADRADAR_IMAP_PASSWORD"))
        if not (host and user and pw):
            print("ERRORE: imposta LEADRADAR_IMAP_HOST/USER/PASSWORD.", file=sys.stderr)
            return 1
        with imaplib.IMAP4_SSL(host) as M:
            M.login(user, pw)
            M.select(os.environ.get("LEADRADAR_IMAP_FOLDER", "INBOX"), readonly=True)
            _, ids = M.search(None, "FROM", f'"{a.from_contains}"')
            for i in ids[0].split():
                _, data = M.fetch(i, "(RFC822)")
                msg = email.message_from_bytes(data[0][1], policy=policy.default)
                if r := from_msg(msg):
                    rows.append(r)
    else:
        ap.error("indica --eml-dir oppure --imap")
    print(f"Alert riconosciuti: {len(rows)}")
    if a.dry_run:
        for r in rows:
            print({k: v for k, v in r.items() if v})
        return 0
    added, total = merge_rows(a.slug, rows)
    print(f"Aggiunte {added} righe (totale storico: {total}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
