#!/usr/bin/env python3
"""MCP server LeadRadar. Espone lo storico locale (modalità B/C) come tool; modalità A è uno stub.
Avvio: python3 server.py   (stdio)   |   LEADRADAR_TRANSPORT=streamable-http python3 server.py"""
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "ingest"))
from common import read_visits  # noqa: E402
from mcp.server.fastmcp import FastMCP  # noqa: E402

mcp = FastMCP("leadradar")
HIGH_INTENT = ("prezz", "pric", "contatt", "contact", "preventiv", "quote", "demo", "serviz", "service", "acquist")


def _date(s: str):
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%d/%m/%Y", "%d/%m/%Y %H:%M", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(s.strip(), fmt)
        except ValueError:
            pass
    try:
        from email.utils import parsedate_to_datetime
        return parsedate_to_datetime(s).replace(tzinfo=None)
    except Exception:
        return None


def _num(s, default=0.0):
    try:
        return float(str(s).replace(",", "."))
    except ValueError:
        return default


def _intent(row) -> int:
    return sum(1 for k in HIGH_INTENT if k in (row.get("pagine") or "").lower())


@mcp.tool()
def list_visits(client: str, days: int = 7) -> list[dict]:
    """Visite aziendali dell'ultimo periodo per un cliente (slug). Righe senza data parsabile sono incluse con data_valida=false."""
    limit = datetime.now() - timedelta(days=days)
    out = []
    for r in read_visits(client):
        d = _date(r.get("ultima_visita", ""))
        if d is None or d >= limit:
            out.append({**r, "data_valida": d is not None})
    return out


@mcp.tool()
def get_company(client: str, name: str) -> list[dict]:
    """Tutte le righe dello storico per un'azienda (match parziale, case-insensitive)."""
    return [r for r in read_visits(client) if name.lower() in r["azienda"].lower()]


@mcp.tool()
def list_hot_companies(client: str, days: int = 7, limit: int = 10) -> list[dict]:
    """Aziende ordinate per ICP score, pagine ad alto intento e visite (euristica trasparente, vedi campo 'motivo')."""
    agg: dict[str, dict] = {}
    for r in list_visits(client, days):
        a = agg.setdefault(r["azienda"], {"azienda": r["azienda"], "icp_score": 0.0, "visite": 0, "intento": 0, "pagine": set()})
        a["icp_score"] = max(a["icp_score"], _num(r.get("icp_score")))
        a["visite"] += int(_num(r.get("visite"), 1))
        a["intento"] += _intent(r)
        a["pagine"].add(r.get("pagine", ""))
    ranked = sorted(agg.values(), key=lambda x: (x["icp_score"], x["intento"], x["visite"]), reverse=True)[:limit]
    for a in ranked:
        a["pagine"] = sorted(p for p in a["pagine"] if p)
        a["motivo"] = "ordinati per icp_score, poi pagine ad alto intento, poi visite"
    return ranked


if __name__ == "__main__":
    mcp.run(transport=os.environ.get("LEADRADAR_TRANSPORT", "stdio"))
