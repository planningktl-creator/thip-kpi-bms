"""Extract the complete THIP KPI 2025 dictionary from 'THIP KPI.pdf'.

Writes src/data/thipKpiDictionary.json: one entry per indicator code (the
same 232 codes as src/data/thipExtractedKpis.json) with definition, formula,
numerator/denominator, target, direction, frequency, source and notes.

Text decoding
-------------
The PDF's Thai text arrives either as raw glyph CIDs (custom-encoded fonts)
or as U+F7xx codes for the font's contextual '.altN' glyph variants. The
decode tables are built from C:\\Windows\\Fonts\\THSarabun.ttf exactly as in
scripts/extract_all_kpis.py (glyph order = CID order, 'uni0E..' names give
the Unicode); the extra loop adds the U+F700-U+F71F entries of the same
font's cmap (e.g. U+F70A -> 'uni0E48.alt2' -> U+0E48) which some pages use
directly.

Layout
------
Every KPI detail page is a two-column table: Thai field labels in the left
column (word x0 < 185pt), field values in the right column (word x0 >= 185pt).
Words are decoded, grouped into visual rows and split at the column boundary,
so pages where the extraction line interleaves a label and its value still
parse correctly. Labels are recognised with a lexicon (the exact phrases
printed in the label column) and multi-row labels are handled with per-field
wrap fragments (e.g. 'นิยาม คำอธิบาย ความหมายของ' + 'ตัวชี้วัด').

Run from the repo root with a Python that has pymupdf and fontTools:
    python scripts/extract_kpi_dictionary.py
"""

import json
import re
import sys

import fitz
from fontTools.ttLib import TTFont

sys.stdout.reconfigure(encoding='utf-8')

PDF_PATH = r'C:\Users\KTLho\Desktop\02_PDF\THIP KPI.pdf'
CODES_PATH = 'src/data/thipExtractedKpis.json'
OUT_PATH = 'src/data/thipKpiDictionary.json'

DEFAULT_LABEL_COL_MAX_X = 185.0  # fallback label/value split (word x0)
ROW_Y_TOLERANCE = 8.0             # word y0 gap that still counts as one row

# ---------------------------------------------------------------------------
# CID -> character tables (identical to scripts/extract_all_kpis.py)
# ---------------------------------------------------------------------------
font = TTFont(r'C:\Windows\Fonts\THSarabun.ttf')
order = font.getGlyphOrder()
cmap = font.getBestCmap()
rev_cmap = {v: k for k, v in cmap.items()}

cid_to_char = {}
for cid, gname in enumerate(order):
    if gname.startswith('uni0E'):
        base = gname.split('.')[0]
        code = int(base[3:], 16)
        cid_to_char[cid] = chr(code)
    elif gname == 'greaterequal':
        cid_to_char[cid] = '≥'
    elif gname == 'lessequal':
        cid_to_char[cid] = '≤'
    elif gname in rev_cmap:
        uni = rev_cmap[gname]
        if not (0xf700 <= uni <= 0xf71f):
            cid_to_char[cid] = chr(uni)

# Some pages use the font's contextual variant code points (U+F700-U+F71F,
# cmap entries like 'uni0E48.alt2') directly; decode them to their base
# Unicode character exactly as their glyph names indicate.
for uni, gname in cmap.items():
    if 0xF700 <= uni <= 0xF7FF:
        base = gname.split('.')[0]
        if base.startswith('uni'):
            cid_to_char[uni] = chr(int(base[3:], 16))


def decode_text(txt):
    res = []
    for ch in txt:
        c = ord(ch)
        if c in cid_to_char and (c >= 210 or c in [338, 339]):
            res.append(cid_to_char[c])
        else:
            res.append(ch)
    return ''.join(res)


def collapse(txt):
    return ' '.join(txt.split())


# ---------------------------------------------------------------------------
# Label lexicon: the exact phrases printed in the label column. Alternation
# order matters only for overlapping prefixes; matches are found with
# finditer so several labels sharing one row (e.g. 'ข้อมูลที่ต้องการ ตัวตั้ง')
# are all recognised.
# ---------------------------------------------------------------------------
LABEL_PATTERN = re.compile(
    r'(?P<code>รหัสตัวชี้วัด)'
    r'|(?P<title_th>ชื่อตัวชี้วัด\s*\(ภาษาไทย\))'
    r'|(?P<title_en>ชื่อตัวชี้วัด\s*\(ภาษาอังกฤษ\))'
    r'|(?P<definition>นิยาม(?:\s+คำอธิบาย)?(?:\s+ความหมาย(?:\s*ของ)?)?(?:\s+ตัวชี้วัด)?)'
    r'|(?P<objective>วัตถุประสงค์(?:\s*ของ)?(?:\s*ตัวชี้วัด)?)'
    r'|(?P<formula>สูตร(?:\s*ในการ)?\s*คำนวณ|สูตร)'
    r'|(?P<data>ข้อมูลที่ต้องการ)'
    r'|(?P<icd>รหัสโรค(?:\s*/\s*หัตถการ|\s*/|\s+หัตถการ)?)'
    r'|(?P<numerator>ตัวตั้ง)'
    r'|(?P<denominator>ตัวหาร)'
    r'|(?P<frequency>ความถี่ในการจัด(?:ทำ|เก็บ)?\s*(?:ข้อมูล)?)'
    r'|(?P<unit>หน่วยวัด)'
    r'|(?P<target>ค่าเป้าหมาย)'
    r'|(?P<inclusion>เกณฑ์คัดเข้า)'
    r'|(?P<exclusion>เกณฑ์คัดออก)'
    r'|(?P<benchmark>Benchmark(?:\s*\((?:ค่า\s*/)?\s*แหล่งอ้างอิง\s*/?\s*ปี\s*\)\s*\*?)?)'
    r'|(?P<interpretation>วิธีการแปลผล)'
    r'|(?P<source>ที่มา(?:\s*/\s*Reference|ของข้อมูล)?|แหล่งข้อมูล)'
    r'|(?P<date_start>วัน\s*เดือน\s*ปี\s*ที่เริ่มใช้)'
    r'|(?P<date_revised>วัน\s*เดือน\s*ปี\s*ที่ปรับปรุงครั้งล่าสุด)'
    r'|(?P<reason>เหตุผลของการปรับปรุง)'
    r'|(?P<note>หมายเหตุ)'
    r'|(?P<category>หมวดตัวชี้วัด|กลุ่มตัวชี้วัด)'
    r'|(?P<type>ประเภทตัวชี้วัด)'
)

# Allowed second-row fragments of two-row labels (label column wraps).
FRAGMENTS = {
    'code': {'ตัวชี้วัด'},
    'title_th': {'ตัวชี้วัด', 'ภาษาไทย', '(ภาษาไทย)'},
    'title_en': {'ตัวชี้วัด', 'ภาษาอังกฤษ', '(ภาษาอังกฤษ)'},
    'definition': {'ตัวชี้วัด', 'ของตัวชี้วัด', 'ความหมาย', 'ความหมายของ', 'คำอธิบาย'},
    'objective': {'ตัวชี้วัด', 'ของตัวชี้วัด'},
    'formula': {'คำนวณ', 'ในการคำนวณ'},
    'data': {'ต้องการ'},
    'icd': {'หัตถการ', 'ที่เกี่ยวข้อง'},
    'numerator': {'ตัวตั้ง'},
    'denominator': {'ตัวหาร'},
    'frequency': {'ข้อมูล', 'จัดทำข้อมูล', 'จัดเก็บข้อมูล'},
    'unit': {'วัด'},
    'target': {'เป้าหมาย'},
    'inclusion': {'คัดเข้า'},
    'exclusion': {'คัดออก'},
    'benchmark': {'แหล่งอ้างอิง/ปี', 'แหล่งอ้างอิง/', 'ปี)', 'ปี) *', 'ปี)*', '*'},
    'interpretation': {'แปลผล'},
    'source': {'Reference', 'อ้างอิง'},
    'date_start': {'ที่เริ่มใช้'},
    'date_revised': {'ที่ปรับปรุงครั้งล่าสุด', 'ครั้งล่าสุด', 'ล่าสุด'},
    'reason': {'ของการปรับปรุง', 'ปรับปรุง'},
    'note': {'เหตุ'},
    'category': {'ตัวชี้วัด'},
    'type': {'ตัวชี้วัด'},
    'unknown': set(),
}

TOKEN_CODE_RE = re.compile(r'^[A-Z]{2}\d{4}(?:\.\d+)?$')
MARGIN_TOKENS = {'BY', 'NC', 'SA', 'T', 'H', 'I', 'P', 'G'}
HEADER_PREFIX = 'Thailand Hospital Indicator Program'

# Tokens that belong to the printed field labels. Used to find where the
# value column starts on each page: the first non-label word after a run of
# label tokens sits at the value column's left edge.
LABEL_VOCAB = {
    'นิยาม', 'คำอธิบาย', 'ความหมาย', 'ความหมายของ', 'ตัวชี้วัด', 'วัตถุประสงค์',
    'ของตัวชี้วัด', 'สูตร', 'ในการคำนวณ', 'คำนวณ', 'ข้อมูลที่ต้องการ', 'ตัวตั้ง',
    'ตัวหาร', 'รหัสโรค', 'หัตถการ', 'ที่เกี่ยวข้อง', 'ความถี่',
    'ในการจัดทำข้อมูล', 'ในการจัดเก็บข้อมูล', 'จัดทำข้อมูล', 'จัดเก็บข้อมูล',
    'ข้อมูล', 'หน่วยวัด', 'Benchmark', 'วิธีการแปลผล', 'ที่มา', 'ที่มาของข้อมูล',
    'แหล่งข้อมูล', 'Reference', 'วัน', 'เดือน', 'ปี', 'ที่เริ่มใช้',
    'ที่ปรับปรุงครั้งล่าสุด', 'เหตุผลของการปรับปรุง', 'หมายเหตุ', 'รหัสตัวชี้วัด',
    'ชื่อตัวชี้วัด', 'ภาษาไทย', 'ภาษาอังกฤษ', 'หมวดตัวชี้วัด', 'ประเภทตัวชี้วัด',
    'กลุ่มตัวชี้วัด', 'ค่าเป้าหมาย', 'ค่า', 'เกณฑ์คัดเข้า', 'เกณฑ์คัดออก',
    'แหล่งอ้างอิง',
}
PUNCT_STRIP = '.,()*/:=“”"‘’-–[]{}%!?;<>'


def norm_token(tok):
    return tok.strip(PUNCT_STRIP)


def is_label_token(tok):
    t = norm_token(tok)
    if not t:
        return True   # punctuation-only tokens continue a label run
    return all(part in LABEL_VOCAB for part in t.split('/') if part)


class Field:
    def __init__(self, kind, label_text):
        self.kind = kind
        self.label_text = label_text
        self.rows = []

    @property
    def value(self):
        return collapse(' '.join(self.rows))


def row_text(words):
    return collapse(' '.join(t for _, t in words))


def is_furniture_row(words, label, value):
    joined = row_text(words)
    if joined.startswith(HEADER_PREFIX) or 'THIP BENCHMARK KPI DICTIONARY' in joined:
        return True
    if joined in {'BY NC SA', 'T H I P', 'G', 'BY', 'NC', 'SA'}:
        return True
    if not value and label in MARGIN_TOKENS:
        return True
    if not value and re.fullmatch(r'\d{1,3}', label):
        return True  # page number
    if not label and value and all(TOKEN_CODE_RE.fullmatch(t) for t in value.split()):
        return True  # repeated KPI-code watermark / footer
    return False


def page_rows(pno):
    """Decode one page into visual rows of (label_cell, value_cell)."""
    items = []
    for w in doc[pno].get_text('words'):
        text = collapse(decode_text(w[4]))
        if not text:
            continue
        if text in MARGIN_TOKENS and (w[0] < 76 or w[0] > 520):
            continue  # CC/watermark letters in the page margins
        if re.fullmatch(r'\d{1,3}', text) and (w[0] < 76 or w[0] > 545):
            continue  # printed page number in a margin
        items.append((w[1], w[0], text))
    items.sort()
    rows = []
    for y0, x0, text in items:
        # chain against the previous word's y0: one visual line mixes fonts
        # whose y0 differs by up to ~7pt (vertically centred label vs value)
        if rows and abs(y0 - rows[-1]['last_y']) <= ROW_Y_TOLERANCE:
            rows[-1]['words'].append((x0, text))
            rows[-1]['last_y'] = y0
        else:
            rows.append({'y': y0, 'last_y': y0, 'words': [(x0, text)]})
    # Per-page label column width: the value column's left edge is where the
    # first non-label word sits after a run of label tokens (pages differ).
    for row in rows:
        row['words'].sort()
    candidates = []
    for row in rows:
        ws = row['words']
        i = 0
        while i < len(ws):
            if is_label_token(ws[i][1]):
                j = i
                while j < len(ws) and is_label_token(ws[j][1]):
                    j += 1
                if j < len(ws) and j > i:
                    if ws[j][0] > ws[j - 1][0] + 2 and 120 <= ws[j][0] <= 260:
                        candidates.append(ws[j][0])
                i = j + 1
            else:
                i += 1
    split_x = min(candidates) - 4 if candidates else DEFAULT_LABEL_COL_MAX_X

    out = []
    for row in rows:
        row['words'].sort()
        label = collapse(' '.join(t for x, t in row['words'] if x < split_x))
        value = collapse(' '.join(t for x, t in row['words'] if x >= split_x))
        if not label and not value:
            continue
        if is_furniture_row(row['words'], label, value):
            continue
        out.append({'label': label, 'value': value})
    return out


def is_fragment(segment, field):
    seg_tokens = set(segment.split())
    if seg_tokens and seg_tokens <= FRAGMENTS.get(field.kind, set()):
        return True
    own = set(field.label_text.split())
    return bool(seg_tokens) and seg_tokens <= own


def parse_rows(rows):
    """Walk rows collecting labelled fields in reading order."""
    fields = []      # ordered Field objects
    current = None   # field currently receiving value rows
    for row in rows:
        label, value = row['label'], row['value']
        if not label:
            if current is not None and value:
                current.rows.append(value)
            continue
        matches = list(LABEL_PATTERN.finditer(label))
        target = current
        pos = 0
        for m in matches:
            seg = collapse(label[pos:m.start()])
            if seg:
                if current is not None and is_fragment(seg, current):
                    current.label_text += ' ' + seg
                else:
                    current = Field('unknown', seg)
                    fields.append(current)
                    target = current
            kind = m.lastgroup
            current = Field(kind, collapse(m.group(0)))
            fields.append(current)
            target = current
            pos = m.end()
        seg = collapse(label[pos:])
        if seg:
            if current is not None and is_fragment(seg, current):
                current.label_text += ' ' + seg
                target = current
            elif matches:
                # value text that spilled into the label cell (e.g. a formula
                # printed left of the value column) belongs to the field that
                # was just opened on this row
                target.rows.append(seg)
            else:
                current = Field('unknown', seg)
                fields.append(current)
                target = current
        if value:
            target.rows.append(value)
    return fields


def first_field(fields, kind, after=None, before=None):
    lo = fields.index(after) if after is not None else -1
    hi = fields.index(before) if before is not None else len(fields)
    for i, f in enumerate(fields):
        if f.kind == kind and lo < i < hi:
            return f
    return None


def infer_direction(interp, target):
    t = interp or ''
    if re.search(r'ยิ่งน้อย|ค่า\s*น้อย|น้อยกว่า.{0,12}ดี', t):
        return 'lower-is-better'
    if re.search(r'ยิ่งมาก|ค่า\s*มาก|มากกว่า.{0,12}ดี', t):
        return 'higher-is-better'
    if re.search(r'ช่วงที่กำหนด|ค่าเท่ากับ', t):
        return 'neutral'
    tgt = target or ''
    if '≥' in tgt or '>=' in tgt:
        return 'higher-is-better'
    if '≤' in tgt or '<=' in tgt:
        return 'lower-is-better'
    return None


def infer_target_scope(freq):
    f = freq or ''
    if re.search(r'รายเดือน|เดือนละครั้ง|ทุก\s*เดือน|ทุก\s*1\s*เดือน', f):
        return 'monthly'
    if re.search(r'รายปี|ปีละครั้ง|ทุก\s*ปี|ทุก\s*1\s*ปี', f):
        return 'annual'
    return None


def main():
    with open(CODES_PATH, encoding='utf-8') as f:
        kpi_index = json.load(f)

    page_to_code = {v['page']: k for k, v in kpi_index.items()}
    code_pages = sorted(page_to_code)
    page_set = set(code_pages)

    def continuation_pages(pno_1based):
        """Pages after this code page that continue the same KPI table."""
        pages = []
        for p in range(pno_1based + 1, len(doc) + 1):
            if p in page_set:
                break
            txt = decode_text(doc[p - 1].get_text())
            if 'ภาคผนวก' in txt or 'รหัสตัวชี้วัด' in txt:
                break
            pages.append(p)
        return pages

    out = {}
    problems = []
    cont_used = []

    for page in code_pages:
        code = page_to_code[page]
        rows = []
        for p in [page] + continuation_pages(page):
            rows.extend(page_rows(p - 1))
        if len([p for p in [page] + continuation_pages(page)]) > 1:
            cont_used.append((code, [page] + continuation_pages(page)))
        fields = parse_rows(rows)

        f_code = first_field(fields, 'code')
        got_code = re.search(r'([A-Z]{2}\d{4}(?:\.\d+)?)', f_code.value).group(1) if f_code and re.search(r'([A-Z]{2}\d{4}(?:\.\d+)?)', f_code.value) else None
        if got_code != code:
            problems.append(f'{code}: code on page {page} reads {got_code!r}')

        def field_value(kind):
            f = first_field(fields, kind)
            return f.value if f else ''

        title_th = field_value('title_th')
        title = field_value('title_en')
        if title_th != kpi_index[code]['titleTh']:
            problems.append(f'{code}: titleTh mismatch\n    got  {title_th!r}\n    json {kpi_index[code]["titleTh"]!r}')
        if title != kpi_index[code]['title']:
            problems.append(f'{code}: title mismatch\n    got  {title!r}\n    json {kpi_index[code]["title"]!r}')
        if not title_th:
            title_th = kpi_index[code]['titleTh']
        if not title:
            title = kpi_index[code]['title']

        f_data = first_field(fields, 'data')
        f_icd = first_field(fields, 'icd')
        f_num = first_field(fields, 'numerator', after=f_data, before=f_icd) or first_field(fields, 'numerator')
        f_den = first_field(fields, 'denominator', after=f_data, before=f_icd) or first_field(fields, 'denominator')

        num_val = f_num.value if f_num else ''
        den_val = f_den.value if f_den else ''
        m_num = re.match(r'^([A-Za-z])\s*=', num_val)
        m_den = re.match(r'^([A-Za-z])\s*=', den_val)

        f_target = first_field(fields, 'target')
        f_bench = first_field(fields, 'benchmark')
        target = f_target.value if f_target and f_target.value else (f_bench.value if f_bench else '')

        interp = field_value('interpretation')
        freq = field_value('frequency')
        source = field_value('source')
        notes = field_value('note')

        f_incl = first_field(fields, 'inclusion')
        f_excl = first_field(fields, 'exclusion')

        entry = {
            'code': code,
            'page': page,
            'titleTh': title_th,
            'title': title,
            'definition': field_value('definition') or None,
            'formula': field_value('formula') or None,
            'numeratorLabel': m_num.group(1) if m_num else None,
            'numeratorDefinition': num_val or None,
            'denominatorLabel': m_den.group(1) if m_den else None,
            'denominatorDefinition': den_val or None,
            'inclusion': [r for r in (f_incl.rows if f_incl else []) if r],
            'exclusion': [r for r in (f_excl.rows if f_excl else []) if r],
            'target': target or None,
            'direction': infer_direction(interp, target),
            'targetScope': infer_target_scope(freq),
            'frequency': freq or None,
            'source': source or None,
            'notes': notes or None,
        }
        out[code] = entry

    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f'Wrote {len(out)} entries to {OUT_PATH}')
    print(f'KPIs with continuation pages: {len(cont_used)}')
    for code, pages in cont_used:
        print(f'  {code}: pages {pages}')
    if problems:
        print(f'\nPROBLEMS ({len(problems)}):')
        for p in problems:
            print('  ' + p)
    else:
        print('\nAll titles/codes cross-check clean against thipExtractedKpis.json')


if __name__ == '__main__':
    doc = fitz.open(PDF_PATH)
    main()
