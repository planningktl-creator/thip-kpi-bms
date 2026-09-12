import sys
import re
import json
import fitz
from fontTools.ttLib import TTFont

sys.stdout.reconfigure(encoding='utf-8')

# 1. Build ground-truth CID -> character mapping from THSarabun.ttf
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

def decode_text(txt):
    res = []
    for ch in txt:
        c = ord(ch)
        if c in cid_to_char and (c >= 210 or c in [338, 339]):
            res.append(cid_to_char[c])
        else:
            res.append(ch)
    return ''.join(res)

doc = fitz.open(r'C:\Users\KTLho\Desktop\02_PDF\THIP KPI.pdf')

extracted = {}
for pno in range(47, len(doc)):
    txt = decode_text(doc[pno].get_text())
    if 'รหัสตัวชี้วัด' in txt:
        m = re.search(r'รหัสตัวชี้วัด\s*([A-Z]{2}\d{4}(?:\.\d+)?)', txt)
        if m:
            code = m.group(1).strip()
            m_th = re.search(r'ชื่อตัวชี้วัด\s*\(ภาษาไทย\)\s*(.*?)\s*ชื่อตัวชี้วัด\s*\(ภาษาอังกฤษ\)', txt, re.DOTALL)
            m_en = re.search(r'ชื่อตัวชี้วัด\s*\(ภาษาอังกฤษ\)\s*(.*?)\s*นิยาม', txt, re.DOTALL)
            th_title = ' '.join(m_th.group(1).split()) if m_th else ''
            en_title = ' '.join(m_en.group(1).split()) if m_en else ''
            # Clean trailing punctuation or weird artifacts
            th_title = th_title.strip()
            en_title = en_title.strip()
            extracted[code] = {
                'code': code,
                'page': pno + 1,
                'titleTh': th_title,
                'title': en_title
            }

with open('src/data/thipCatalogue.ts', 'r', encoding='utf-8') as f:
    cat_content = f.read()

pattern = r'"code":\s*"([^"]+)"'
cat_codes = re.findall(pattern, cat_content)

print(f"Total extracted: {len(extracted)}")
print(f"Total in catalogue: {len(cat_codes)}")
print(f"In catalogue but not extracted: {set(cat_codes) - set(extracted.keys())}")
print(f"Extracted but not in catalogue: {set(extracted.keys()) - set(cat_codes)}")

# Save to JSON
with open('src/data/thipExtractedKpis.json', 'w', encoding='utf-8') as f:
    json.dump(extracted, f, ensure_ascii=False, indent=2)

print("Saved extracted KPIs to src/data/thipExtractedKpis.json")
