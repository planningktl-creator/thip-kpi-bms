import json
import re
import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('src/data/thipExtractedKpis.json', 'r', encoding='utf-8') as f:
    kpis = json.load(f)

count_suspicious = 0
for code, d in sorted(kpis.items()):
    th = d['titleTh']
    en = d['title']
    # Check for any suspicious characters
    suspicious = [c for c in th if ord(c) < 32 or (127 <= ord(c) < 0x0E01) or (ord(c) > 0x0E5B and ord(c) not in [0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2026, 0x2264, 0x2265])]
    if suspicious:
        print(f"Suspicious in {code} TH: {suspicious} (ord={[ord(c) for c in suspicious]}) in '{th}'")
        count_suspicious += 1
    suspicious_en = [c for c in en if ord(c) < 32 or (127 <= ord(c) <= 160)]
    if suspicious_en:
        print(f"Suspicious in {code} EN: {suspicious_en} in '{en}'")
        count_suspicious += 1

print(f"Total suspicious items: {count_suspicious}")
