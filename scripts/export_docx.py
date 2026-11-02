#!/usr/bin/env python3
"""Converte un report Markdown in .docx client-ready (copertina + stile pulito).
Uso: export_docx.py <input.md> --cliente "Nome" [--titolo "Titolo"] [--out file.docx]
Supporta: # ## ### titoli, liste (-, 1.), tabelle pipe, **grassetto**, `codice`, > citazioni.
Richiede python-docx."""
import argparse
import re
import sys
from datetime import date
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor, Cm

ACCENT = RGBColor(0x1F, 0x3A, 0x5F)


def add_runs(par, text):
    for part in re.split(r"(\*\*[^*]+\*\*|`[^`]+`)", text):
        if not part:
            continue
        if part.startswith("**") and part.endswith("**"):
            par.add_run(part[2:-2]).bold = True
        elif part.startswith("`") and part.endswith("`"):
            r = par.add_run(part[1:-1])
            r.font.name = "Consolas"
        else:
            par.add_run(part)


def shade(cell, color):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:fill"), color)
    tcPr.append(shd)


def flush_table(doc, rows):
    rows = [r for r in rows if not re.fullmatch(r"\|?[\s:\-|]+\|?", r)]
    cells = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows]
    if not cells:
        return
    n = max(len(r) for r in cells)
    t = doc.add_table(rows=len(cells), cols=n)
    t.style = "Table Grid"
    for i, row in enumerate(cells):
        for j in range(n):
            c = t.cell(i, j)
            c.text = ""
            p = c.paragraphs[0]
            add_runs(p, row[j] if j < len(row) else "")
            for r in p.runs:
                r.font.size = Pt(8.5)
                if i == 0:
                    r.bold = True
                    r.font.color.rgb = RGBColor(255, 255, 255)
            if i == 0:
                shade(c, "1F3A5F")
    doc.add_paragraph()


def build(md, cliente, titolo, out):
    doc = Document()
    sec = doc.sections[0]
    sec.left_margin = sec.right_margin = Cm(2.2)
    st = doc.styles["Normal"]
    st.font.name = "Calibri"
    st.font.size = Pt(10.5)
    for name, size in (("Heading 1", 18), ("Heading 2", 14), ("Heading 3", 12)):
        h = doc.styles[name]
        h.font.name = "Calibri"
        h.font.size = Pt(size)
        h.font.color.rgb = ACCENT

    # Copertina
    for _ in range(7):
        doc.add_paragraph()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r = p.add_run(titolo)
    r.bold = True
    r.font.size = Pt(30)
    r.font.color.rgb = ACCENT
    p = doc.add_paragraph()
    r = p.add_run(cliente)
    r.font.size = Pt(18)
    p = doc.add_paragraph()
    r = p.add_run(date.today().strftime("%d/%m/%Y"))
    r.font.size = Pt(12)
    r.font.color.rgb = RGBColor(0x66, 0x66, 0x66)
    doc.add_page_break()

    table, in_code = [], False
    for line in md.splitlines():
        if line.strip().startswith("<!--"):
            continue
        if line.startswith("|"):
            table.append(line)
            continue
        if table:
            flush_table(doc, table)
            table = []
        if line.strip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            q = doc.add_paragraph()
            q.add_run(line).font.name = "Consolas"
            continue
        s = line.rstrip()
        if not s.strip() or s.strip() == "---":
            continue
        m = re.match(r"(#{1,3})\s+(.*)", s)
        if m:
            doc.add_heading(m.group(2), level=len(m.group(1)))
        elif re.match(r"\s*[-*]\s+", s):
            add_runs(doc.add_paragraph(style="List Bullet"), re.sub(r"^\s*[-*]\s+", "", s))
        elif re.match(r"\s*\d+[.)]\s+", s):
            add_runs(doc.add_paragraph(style="List Number"), re.sub(r"^\s*\d+[.)]\s+", "", s))
        elif s.startswith(">"):
            q = doc.add_paragraph()
            q.paragraph_format.left_indent = Cm(0.8)
            add_runs(q, s.lstrip("> ").strip())
            for r in q.runs:
                r.italic = True
        else:
            add_runs(doc.add_paragraph(), s)
    if table:
        flush_table(doc, table)

    footer = sec.footer.paragraphs[0]
    footer.text = f"{cliente} — {titolo}"
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    doc.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("--cliente", required=True)
    ap.add_argument("--titolo")
    ap.add_argument("--out")
    a = ap.parse_args()
    src = Path(a.input)
    if not src.is_file():
        print(f"File non trovato: {src}", file=sys.stderr)
        return 2
    md = src.read_text(encoding="utf-8")
    titolo = a.titolo
    if not titolo:
        m = re.search(r"^#\s+(.+)$", md, re.M)
        titolo = m.group(1) if m else src.stem
    out = Path(a.out) if a.out else src.with_suffix(".docx")
    build(md, a.cliente, titolo, out)
    print(f"Creato {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
