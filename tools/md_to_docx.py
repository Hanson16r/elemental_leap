"""把 docs 下的 markdown 指南排版成 Word 文档（中文正文 + 代码块 + 表格）。

用法:  python md_to_docx.py <输入.md> <输出.docx> [文档标题]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

# ---- 配色 ----
C_HEAD1 = RGBColor(0x1F, 0x3B, 0x57)
C_HEAD2 = RGBColor(0x2E, 0x5C, 0x8A)
C_HEAD3 = RGBColor(0x3C, 0x3C, 0x3C)
C_BODY = RGBColor(0x1A, 0x1A, 0x1A)
C_MUTED = RGBColor(0x5A, 0x5A, 0x5A)
C_LINK = RGBColor(0x0B, 0x5C, 0xA8)
FILL_CODE = "F4F5F7"
FILL_QUOTE = "F7F9FC"
FILL_TH = "2E5C8A"
FILL_TD = "FBFCFD"
FILL_TD_ALT = "EFF3F8"

BODY_EA = "微软雅黑"
BODY_LATIN = "Segoe UI"
MONO = "Consolas"
SIZE_BODY = 10.5


# ------------------------------------------------------------------ 底层工具
def _set_run_fonts(run, latin: str, ea: str) -> None:
    run.font.name = latin
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    rfonts.set(qn("w:ascii"), latin)
    rfonts.set(qn("w:hAnsi"), latin)
    rfonts.set(qn("w:eastAsia"), ea)
    rfonts.set(qn("w:cs"), latin)


def _shade(element, fill: str) -> None:
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    element.append(shd)


def shade_run(run, fill: str) -> None:
    _shade(run._element.get_or_add_rPr(), fill)


def shade_paragraph(paragraph, fill: str) -> None:
    _shade(paragraph._p.get_or_add_pPr(), fill)


def shade_cell(cell, fill: str) -> None:
    _shade(cell._tc.get_or_add_tcPr(), fill)


def border_paragraph(paragraph, *, sides=("left",), color="D0D7DE", size=12, space=8) -> None:
    ppr = paragraph._p.get_or_add_pPr()
    pbdr = ppr.find(qn("w:pBdr"))
    if pbdr is None:
        pbdr = OxmlElement("w:pBdr")
        ppr.append(pbdr)
    for side in sides:
        el = OxmlElement(f"w:{side}")
        el.set(qn("w:val"), "single")
        el.set(qn("w:sz"), str(size))
        el.set(qn("w:space"), str(space))
        el.set(qn("w:color"), color)
        pbdr.append(el)


def set_table_borders(table, color="C9D3DF", size=6) -> None:
    tbl_pr = table._tbl.tblPr
    borders = OxmlElement("w:tblBorders")
    for side in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = OxmlElement(f"w:{side}")
        el.set(qn("w:val"), "single")
        el.set(qn("w:sz"), str(size))
        el.set(qn("w:space"), "0")
        el.set(qn("w:color"), color)
        borders.append(el)
    tbl_pr.append(borders)


def set_cell_margins(table, top=60, bottom=60, left=90, right=90) -> None:
    tbl_pr = table._tbl.tblPr
    mar = OxmlElement("w:tblCellMar")
    for side, val in (("top", top), ("left", left), ("bottom", bottom), ("right", right)):
        el = OxmlElement(f"w:{side}")
        el.set(qn("w:w"), str(val))
        el.set(qn("w:type"), "dxa")
        mar.append(el)
    tbl_pr.append(mar)


def repeat_header(row) -> None:
    """w:tblHeader 必须排在 w:cantSplit 之后（OOXML 对 trPr 子元素顺序敏感）。"""
    tr_pr = row._tr.get_or_add_trPr()
    el = OxmlElement("w:tblHeader")
    el.set(qn("w:val"), "true")
    existing = tr_pr.find(qn("w:cantSplit"))
    if existing is not None:
        existing.addnext(el)
    else:
        tr_pr.append(el)


def no_row_split(row) -> None:
    """禁止一行表格被分页切成两半。"""
    tr_pr = row._tr.get_or_add_trPr()
    el = OxmlElement("w:cantSplit")
    el.set(qn("w:val"), "true")
    tr_pr.append(el)


def add_hyperlink(paragraph, url: str, text: str) -> None:
    part = paragraph.part
    r_id = part.relate_to(
        url,
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink",
        is_external=True,
    )
    link = OxmlElement("w:hyperlink")
    link.set(qn("r:id"), r_id)
    run_el = OxmlElement("w:r")
    rpr = OxmlElement("w:rPr")
    color = OxmlElement("w:color")
    color.set(qn("w:val"), "0B5CA8")
    underline = OxmlElement("w:u")
    underline.set(qn("w:val"), "single")
    rfonts = OxmlElement("w:rFonts")
    rfonts.set(qn("w:ascii"), MONO)
    rfonts.set(qn("w:hAnsi"), MONO)
    rfonts.set(qn("w:eastAsia"), BODY_EA)
    for el in (rfonts, color, underline):
        rpr.append(el)
    run_el.append(rpr)
    t = OxmlElement("w:t")
    t.text = text
    t.set(qn("xml:space"), "preserve")
    run_el.append(t)
    link.append(run_el)
    paragraph._p.append(link)


# ------------------------------------------------------------------ 行内解析
TOKEN_RE = re.compile(r"(\*\*.+?\*\*|`[^`]+`|\[[^\]]+\]\([^)]*\))")


def add_inline(paragraph, text: str, *, size=SIZE_BODY, color=C_BODY, bold=False) -> None:
    for piece in TOKEN_RE.split(text):
        if not piece:
            continue
        if piece.startswith("**") and piece.endswith("**") and len(piece) > 4:
            # 粗体里可能还包着行内代码，递归处理
            add_inline(paragraph, piece[2:-2], size=size, color=color, bold=True)
        elif piece.startswith("`") and piece.endswith("`") and len(piece) > 2:
            run = paragraph.add_run(piece[1:-1])
            _set_run_fonts(run, MONO, MONO)
            run.font.size = Pt(size - 1)
            run.font.color.rgb = RGBColor(0xB3, 0x1D, 0x2A)
            run.bold = bold
            shade_run(run, "F0F1F3")
        elif piece.startswith("[") and "](" in piece:
            m = re.match(r"\[([^\]]+)\]\(([^)]*)\)", piece)
            label, target = m.group(1), m.group(2)
            if target.startswith("http"):
                add_hyperlink(paragraph, target, label)
            else:
                run = paragraph.add_run(label)
                _set_run_fonts(run, BODY_LATIN, BODY_EA)
                run.font.size = Pt(size)
                run.font.color.rgb = C_LINK
                run.bold = bold
        else:
            run = paragraph.add_run(piece)
            _set_run_fonts(run, BODY_LATIN, BODY_EA)
            run.font.size = Pt(size)
            run.font.color.rgb = color
            run.bold = bold


def strip_md_emphasis(text: str) -> str:
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)
    return text


# ------------------------------------------------------------------ 段落构件
def add_heading(doc, text: str, level: int) -> None:
    p = doc.add_paragraph(style=f"Heading {level}")
    pf = p.paragraph_format
    pf.keep_with_next = True
    if level == 1:
        pf.space_before = Pt(18)
        pf.space_after = Pt(8)
        size, color = 15, C_HEAD1
    elif level == 2:
        pf.space_before = Pt(14)
        pf.space_after = Pt(6)
        size, color = 12.5, C_HEAD2
    else:
        pf.space_before = Pt(12)
        pf.space_after = Pt(4)
        size, color = 11.5, C_HEAD3
    add_inline(p, text, size=size, color=color, bold=True)
    for run in p.runs:
        run.bold = True
    if level == 1:
        border_paragraph(p, sides=("bottom",), color="D8DEE6", size=8, space=4)
    elif level == 2:
        border_paragraph(p, sides=("left",), color="2E5C8A", size=18, space=6)


def add_body(doc, text: str) -> None:
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.space_before = Pt(2)
    pf.space_after = Pt(6)
    pf.line_spacing = 1.45
    add_inline(p, text)


def add_bullet(doc, text: str, marker: str = "•", level: int = 0) -> None:
    p = doc.add_paragraph()
    pf = p.paragraph_format
    indent = Cm(0.55 + 0.5 * level)
    pf.left_indent = indent + Cm(0.45)
    pf.first_line_indent = Cm(-0.45)
    pf.space_before = Pt(1)
    pf.space_after = Pt(3)
    pf.line_spacing = 1.4
    run = p.add_run(marker + "\u2002")
    _set_run_fonts(run, BODY_LATIN, BODY_EA)
    run.font.size = Pt(SIZE_BODY)
    run.font.color.rgb = C_HEAD2
    add_inline(p, text)


def add_code_block(doc, lines: list[str], extra_indent: Cm | None = None) -> None:
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.left_indent = Cm(0.4) + (extra_indent if extra_indent is not None else Cm(0))
    pf.right_indent = Cm(0.2) if extra_indent is not None else Cm(0)
    pf.space_before = Pt(6)
    pf.space_after = Pt(8)
    pf.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    pf.line_spacing = 1.15
    shade_paragraph(p, FILL_CODE)
    border_paragraph(p, sides=("left",), color="A9B6C6", size=18, space=6)
    for idx, line in enumerate(lines):
        if idx:
            p.add_run().add_break()
        run = p.add_run(line)
        _set_run_fonts(run, MONO, MONO)
        run.font.size = Pt(8.5)
        run.font.color.rgb = RGBColor(0x22, 0x28, 0x33)
    for run in p.runs:
        _set_run_fonts(run, MONO, MONO)
        run.font.size = Pt(8.5)


def add_quote(doc, lines: list[str]) -> None:
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.left_indent = Cm(0.5)
    pf.right_indent = Cm(0.2)
    pf.space_before = Pt(4)
    pf.space_after = Pt(8)
    pf.line_spacing = 1.4
    shade_paragraph(p, FILL_QUOTE)
    border_paragraph(p, sides=("left",), color="7FA8C9", size=18, space=8)
    for idx, line in enumerate(lines):
        if idx:
            p.add_run().add_break()
        add_inline(p, line, size=SIZE_BODY - 0.5, color=C_MUTED)


def add_quote_code(doc, lines: list[str]) -> None:
    """引用块里的代码围栏：比正文代码块再缩进一点，保持'在引文里'的观感。"""
    add_code_block(doc, lines, extra_indent=Cm(0.5))


def emit_quote(doc, lines: list[str]) -> None:
    """把一段 '>' 内容拆成 正文段 + 代码段，按顺序排版。"""
    segments: list[tuple[str, list[str]]] = []
    buffer: list[str] = []
    in_code = False
    for line in lines:
        if line.strip().startswith("```"):
            if in_code:
                segments.append(("code", buffer))
            elif any(l.strip() for l in buffer):
                segments.append(("text", buffer))
            buffer = []
            in_code = not in_code
            continue
        buffer.append(line)
    if buffer:
        segments.append(("code" if in_code else "text", buffer))

    for kind, block in segments:
        if kind == "code":
            trimmed = list(block)
            while trimmed and not trimmed[0].strip():
                trimmed.pop(0)
            while trimmed and not trimmed[-1].strip():
                trimmed.pop()
            add_quote_code(doc, trimmed or [""])
            continue
        paragraph: list[str] = []
        for line in block:
            if line.strip():
                paragraph.append(line)
            elif paragraph:
                add_quote(doc, paragraph)
                paragraph = []
        if paragraph:
            add_quote(doc, paragraph)


def add_rule(doc, page_break: bool = False) -> None:
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.space_before = Pt(4)
    pf.space_after = Pt(4)
    border_paragraph(p, sides=("bottom",), color="E1E6EC", size=6, space=1)
    if page_break:
        run = p.add_run()
        run.add_break(WD_BREAK.PAGE)


def add_table(doc, rows: list[list[str]]) -> None:
    header, body = rows[0], rows[1:]
    table = doc.add_table(rows=1 + len(body), cols=len(header))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True
    set_table_borders(table)
    set_cell_margins(table)

    widths = _column_widths(header, body)

    def fill_row(row, values, *, is_header, alt):
        for idx, value in enumerate(values):
            cell = row.cells[idx]
            cell.width = widths[idx]
            para = cell.paragraphs[0]
            pf = para.paragraph_format
            pf.space_before = Pt(2)
            pf.space_after = Pt(2)
            pf.line_spacing = 1.3
            if is_header:
                shade_cell(cell, FILL_TH)
                text = strip_md_emphasis(value)
                run = para.add_run(text)
                _set_run_fonts(run, BODY_LATIN, BODY_EA)
                run.font.size = Pt(9.5)
                run.bold = True
                run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
            else:
                shade_cell(cell, FILL_TD_ALT if alt else FILL_TD)
                add_inline(para, value, size=9.5)

    for row in table.rows:
        no_row_split(row)
    fill_row(table.rows[0], header, is_header=True, alt=False)
    repeat_header(table.rows[0])
    for i, values in enumerate(body):
        padded = values + [""] * (len(header) - len(values))
        fill_row(table.rows[i + 1], padded, is_header=False, alt=(i % 2 == 1))
    # LibreOffice 不看 w:cantSplit，用 keep_with_next 把整张表绑在同一页
    for row in table.rows[:-1]:
        for cell in row.cells:
            for para in cell.paragraphs:
                para.paragraph_format.keep_with_next = True

    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(2)
    spacer.paragraph_format.space_before = Pt(2)


def _column_widths(header, body):
    cols = len(header)
    lengths = []
    for c in range(cols):
        values = [header[c]] + [r[c] if c < len(r) else "" for r in body]
        lengths.append(max(len(strip_md_emphasis(v)) for v in values))
    total = sum(lengths) or 1
    usable_cm = 16.6
    raw = [usable_cm * max(0.10, min(0.45, length / total)) for length in lengths]
    scale = usable_cm / (sum(raw) or 1)
    return [Cm(value * scale) for value in raw]


# ------------------------------------------------------------------ 页面装修
def setup_document(doc: Document) -> None:
    section = doc.sections[0]
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    section.left_margin = Cm(2.2)
    section.right_margin = Cm(2.2)
    section.top_margin = Cm(2.2)
    section.bottom_margin = Cm(2.0)

    normal = doc.styles["Normal"]
    normal.font.name = BODY_LATIN
    normal.font.size = Pt(SIZE_BODY)
    normal.font.color.rgb = C_BODY
    rpr = normal.element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = OxmlElement("w:rFonts")
        rpr.append(rfonts)
    rfonts.set(qn("w:eastAsia"), BODY_EA)

    # 页脚：左标题 + 右页码
    footer = section.footer
    para = footer.paragraphs[0]
    para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = para.add_run("ice-tower-jump · Git 回退版本操作指南 · 第 ")
    _set_run_fonts(run, BODY_LATIN, BODY_EA)
    run.font.size = Pt(8.5)
    run.font.color.rgb = C_MUTED
    fld = OxmlElement("w:fldSimple")
    fld.set(qn("w:instr"), "PAGE")
    inner = OxmlElement("w:r")
    it = OxmlElement("w:t")
    it.text = "1"
    inner.append(it)
    fld.append(inner)
    para._p.append(fld)
    run2 = para.add_run(" 页")
    _set_run_fonts(run2, BODY_LATIN, BODY_EA)
    run2.font.size = Pt(8.5)
    run2.font.color.rgb = C_MUTED


def add_cover(doc, title: str, subtitle: str) -> None:
    for _ in range(2):
        doc.add_paragraph()

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    run = p.add_run("ice-tower-jump 开发文档")
    _set_run_fonts(run, BODY_LATIN, BODY_EA)
    run.font.size = Pt(10.5)
    run.font.color.rgb = C_MUTED
    run.bold = False
    for run in p.runs:
        run.font.all_caps = False

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(10)
    run = p.add_run(title)
    _set_run_fonts(run, BODY_LATIN, BODY_EA)
    run.font.size = Pt(30)
    run.bold = True
    run.font.color.rgb = C_HEAD1

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(18)
    border_paragraph(p, sides=("bottom",), color="2E5C8A", size=12, space=8)

    for line in subtitle.split("\n"):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(3)
        p.paragraph_format.line_spacing = 1.5
        add_inline(p, line, size=10, color=C_MUTED)

    doc.add_paragraph()
    add_rule(doc, page_break=True)


# ------------------------------------------------------------------ Markdown 解析
HEAD_RE = re.compile(r"^(#{1,6})\s+(.*)$")
BULLET_RE = re.compile(r"^(\s*)[-*+]\s+(.*)$")
ORDER_RE = re.compile(r"^(\s*)(\d+)[.)]\s+(.*)$")


def convert(md_path: Path, docx_path: Path, title: str) -> None:
    lines = md_path.read_text(encoding="utf-8").splitlines()
    doc = Document()
    setup_document(doc)

    subtitle_lines = []
    title_idx = -1
    for idx, line in enumerate(lines):
        if line.startswith("# "):
            title_idx = idx
            break

    # 标题下面那段 "> 项目 / 远端 / 环境 / 更新时间" 是封面信息，不能再进正文
    cursor = title_idx + 1 if title_idx >= 0 else 0
    n_total = len(lines)
    while cursor < n_total:
        stripped = lines[cursor].strip()
        if not stripped:
            cursor += 1
            continue
        if stripped.startswith(">"):
            subtitle_lines.append(strip_md_emphasis(stripped.lstrip(">").strip()))
            cursor += 1
            continue
        break
    if cursor < n_total and re.fullmatch(r"-{3,}|\*{3,}|_{3,}", lines[cursor].strip()):
        cursor += 1
    body_start = cursor

    add_cover(doc, title, "\n".join(subtitle_lines))

    i = body_start
    n = len(lines)
    first_h2 = True
    while i < n:
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        # 代码块
        if stripped.startswith("```"):
            i += 1
            block: list[str] = []
            while i < n and not lines[i].strip().startswith("```"):
                block.append(lines[i])
                i += 1
            i += 1
            while block and not block[0].strip():
                block.pop(0)
            while block and not block[-1].strip():
                block.pop()
            add_code_block(doc, block if block else [""])
            continue

        # 分隔线
        if re.fullmatch(r"-{3,}|\*{3,}|_{3,}", stripped):
            add_rule(doc)
            i += 1
            continue

        # 标题
        m = HEAD_RE.match(stripped)
        if m:
            level = len(m.group(1))
            text = m.group(2).strip()
            if level == 1:
                i += 1
                continue
            if first_h2 and level == 2:
                first_h2 = False
            add_heading(doc, text, min(level - 1, 3))
            i += 1
            continue

        # 表格
        if stripped.startswith("|") and i + 1 < n and re.match(r"^\|?[\s:|-]+\|?[\s:|-]*$", lines[i + 1].strip()):
            rows: list[list[str]] = []
            header_cells = _split_row(stripped)
            rows.append(header_cells)
            i += 2
            while i < n and lines[i].strip().startswith("|"):
                rows.append(_split_row(lines[i].strip()))
                i += 1
            add_table(doc, rows)
            continue

        # 引用块（内部可能夹着代码围栏）
        if stripped.startswith(">"):
            quote: list[str] = []
            while i < n and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:].lstrip())
                i += 1
            emit_quote(doc, quote)
            continue

        # 列表
        m = BULLET_RE.match(line)
        if m:
            indent = len(m.group(1)) // 2
            add_bullet(doc, m.group(2).strip(), marker="•", level=indent)
            i += 1
            continue

        m = ORDER_RE.match(line)
        if m:
            indent = len(m.group(1)) // 2
            add_bullet(doc, m.group(3).strip(), marker=f"{m.group(2)}.", level=indent)
            i += 1
            continue

        # 普通正文：markdown 里的软换行合并成一整段
        chunk = [stripped]
        i += 1
        while i < n and _is_plain(lines[i]):
            chunk.append(lines[i].strip())
            i += 1
        add_body(doc, _join_wrapped(chunk))

    props = doc.core_properties
    props.title = title
    props.subject = "Git 版本回退 / 撤销 / 恢复操作指南"
    props.author = "ice-tower-jump"
    doc.save(docx_path)


def _is_plain(line: str) -> bool:
    """这一行能不能并进上一段正文（markdown 软换行）。"""
    stripped = line.strip()
    if not stripped:
        return False
    if stripped.startswith(("#", ">", "```", "|")):
        return False
    if re.fullmatch(r"-{3,}|\*{3,}|_{3,}", stripped):
        return False
    if BULLET_RE.match(line) or ORDER_RE.match(line):
        return False
    return True


def _join_wrapped(chunk: list[str]) -> str:
    """合并软换行：中文直接拼，两侧都是拉丁字母/数字时补一个空格。"""
    out = chunk[0]
    for nxt in chunk[1:]:
        if out and nxt and re.match(r"[A-Za-z0-9]", out[-1]) and re.match(r"[A-Za-z0-9]", nxt[0]):
            out += " " + nxt
        else:
            out += nxt
    return out


def _split_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [cell.strip() for cell in line.split("|")]


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: md_to_docx.py <input.md> <output.docx> [title]")
    md_path = Path(sys.argv[1])
    docx_path = Path(sys.argv[2])
    title = sys.argv[3] if len(sys.argv) > 3 else md_path.stem
    convert(md_path, docx_path, title)
    print(f"written: {docx_path} ({docx_path.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
