# -*- coding: utf-8 -*-
"""Builds a printable Word version of docs/DEMO_FLOW.md."""
from __future__ import annotations

import re
from pathlib import Path

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs" / "DEMO_FLOW.md"
OUT = ROOT / "docs" / "submission" / "IT107_Tahanan_Demo_Flow.docx"

GREEN = RGBColor(0x1F, 0x5C, 0x3A)
GREY = RGBColor(0x5A, 0x5A, 0x5A)
HEAD = "1F5C3A"
LIGHT = "EAF2EC"


def shade(cell, color: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), color)
    tc_pr.append(shd)


def add_field(paragraph, instr: str) -> None:
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    text = OxmlElement("w:instrText")
    text.set(qn("xml:space"), "preserve")
    text.text = instr
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.append(begin)
    run._r.append(text)
    run._r.append(end)


def rich(paragraph, text: str, size: float | None = None) -> None:
    """Adds text with **bold**, *italic* and `code` segments, including code inside bold."""
    for token in re.split(r"(\*\*.+?\*\*|\*[^*\n]+\*)", text):
        if not token:
            continue
        bold = token.startswith("**") and token.endswith("**") and len(token) > 4
        italic = (not bold) and token.startswith("*") and token.endswith("*") and len(token) > 2
        inner = token[2:-2] if bold else (token[1:-1] if italic else token)
        for part in re.split(r"(`.+?`)", inner):
            if not part:
                continue
            if part.startswith("`") and part.endswith("`"):
                run = paragraph.add_run(part[1:-1])
                run.font.name = "Consolas"
                run.font.size = Pt((size or 9.5) - 1)
            else:
                run = paragraph.add_run(part)
                if size:
                    run.font.size = Pt(size)
            if bold:
                run.bold = True
            if italic:
                run.italic = True


def repeat_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    node = OxmlElement("w:tblHeader")
    node.set(qn("w:val"), "true")
    tr_pr.append(node)


def add_table(doc, rows: list[list[str]]) -> None:
    table = doc.add_table(rows=1, cols=len(rows[0]))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True
    header = table.rows[0]
    repeat_header(header)
    for i, text in enumerate(rows[0]):
        cell = header.cells[i]
        cell.text = ""
        p = cell.paragraphs[0]
        run = p.add_run(re.sub(r"\*\*", "", text))
        run.bold = True
        run.font.size = Pt(8.5)
        run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        p.paragraph_format.space_after = Pt(0)
        shade(cell, HEAD)
    for r, row in enumerate(rows[1:]):
        cells = table.add_row().cells
        for i, text in enumerate(row[: len(rows[0])]):
            cells[i].text = ""
            p = cells[i].paragraphs[0]
            rich(p, text, size=8.5)
            p.paragraph_format.space_after = Pt(0)
            if r % 2 == 1:
                shade(cells[i], LIGHT)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)


def build() -> None:
    doc = Document()
    section = doc.sections[0]
    section.page_width, section.page_height = Cm(21), Cm(29.7)
    section.top_margin = Cm(1.6); section.bottom_margin = Cm(1.4)
    section.left_margin = section.right_margin = Cm(1.7)
    section.header_distance = section.footer_distance = Cm(0.8)

    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(9.5)
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Calibri")

    for name, size in (("Heading 1", 16), ("Heading 2", 12.5), ("Heading 3", 11)):
        st = doc.styles[name]
        st.font.name = "Calibri"
        st.font.size = Pt(size)
        st.font.bold = True
        st.font.color.rgb = GREEN

    header = section.header.paragraphs[0]
    header.text = ""
    run = header.add_run("Tahanan — Boarding House Tenant & Rent System")
    run.bold = True
    run.font.size = Pt(9.5)
    run.font.color.rgb = GREEN
    sub = section.header.add_paragraph()
    run = sub.add_run("IT 107 — Live Demo Flow · Jamester C. Mulato · 241-00315")
    run.font.size = Pt(7.5)
    run.font.color.rgb = GREY

    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("© 2026 Jamester C. Mulato. All rights reserved.   ·   Page ")
    run.font.size = Pt(8)
    run.font.color.rgb = GREY
    add_field(footer, "PAGE")
    run = footer.add_run(" of ")
    run.font.size = Pt(8)
    run.font.color.rgb = GREY
    add_field(footer, "NUMPAGES")

    lines = SRC.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]

        if line.startswith("```"):
            i += 1
            block = []
            while i < len(lines) and not lines[i].startswith("```"):
                block.append(lines[i])
                i += 1
            for code in block:
                p = doc.add_paragraph()
                p.paragraph_format.left_indent = Cm(0.5)
                p.paragraph_format.space_after = Pt(0)
                p.paragraph_format.line_spacing = 1.0
                r = p.add_run(code if code else " ")
                r.font.name = "Consolas"
                r.font.size = Pt(8)
            doc.add_paragraph().paragraph_format.space_after = Pt(2)
            i += 1
            continue

        if line.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|$", lines[i + 1]):
            rows = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not re.match(r"^[\s:|-]+$", "".join(cells)):
                    rows.append(cells)
                i += 1
            add_table(doc, rows)
            continue

        if line.startswith("# "):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(2)
            r = p.add_run(line[2:])
            r.bold = True
            r.font.size = Pt(20)
            r.font.color.rgb = GREEN
        elif line.startswith("## "):
            h = doc.add_heading(line[3:], level=1)
            h.paragraph_format.space_before = Pt(11)
            h.paragraph_format.space_after = Pt(5)
        elif line.startswith("### "):
            h = doc.add_heading(line[4:], level=2)
            h.paragraph_format.space_before = Pt(9)
            h.paragraph_format.space_after = Pt(3)
        elif line.strip() == "---":
            p = doc.add_paragraph()
            p.paragraph_format.space_after = Pt(0)
            pPr = p._p.get_or_add_pPr()
            border = OxmlElement("w:pBdr")
            bottom = OxmlElement("w:bottom")
            bottom.set(qn("w:val"), "single")
            bottom.set(qn("w:sz"), "4")
            bottom.set(qn("w:space"), "1")
            bottom.set(qn("w:color"), "C9DCCF")
            border.append(bottom)
            pPr.append(border)
        elif line.startswith("> "):
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Cm(0.6)
            p.paragraph_format.space_after = Pt(5)
            rich(p, line[2:], size=9.5)
            for run in p.runs:
                run.italic = True
                run.font.color.rgb = GREY
        elif re.match(r"^- \[ \] ", line):
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Cm(0.4)
            p.paragraph_format.space_after = Pt(2)
            box = p.add_run("\u2610  ")
            box.font.size = Pt(11)
            rich(p, line[6:])
        elif line.startswith("- "):
            p = doc.add_paragraph(style="List Bullet")
            p.paragraph_format.space_after = Pt(2)
            rich(p, line[2:])
        elif re.match(r"^\s+- ", line):
            indent = len(line) - len(line.lstrip())
            p = doc.add_paragraph(style="List Bullet")
            p.paragraph_format.left_indent = Cm(0.6 + 0.6 * (indent // 2))
            p.paragraph_format.space_after = Pt(2)
            rich(p, re.sub(r"^\s+- ", "", line))
        elif re.match(r"^\d+\. ", line):
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Cm(0.5)
            p.paragraph_format.first_line_indent = Cm(-0.5)
            p.paragraph_format.space_after = Pt(2)
            num, rest = line.split(". ", 1)
            r = p.add_run(f"{num}.  ")
            r.bold = True
            rich(p, rest)
        elif line.strip():
            p = doc.add_paragraph()
            p.paragraph_format.space_after = Pt(5)
            p.paragraph_format.line_spacing = 1.08
            rich(p, line)
        else:
            doc.add_paragraph().paragraph_format.space_after = Pt(0)
        i += 1

    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    build()
