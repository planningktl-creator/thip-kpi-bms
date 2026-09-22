"""Validate src/data/thipKpiDictionary.json against src/data/thipExtractedKpis.json.

Checks:
- exactly 232 entries whose keys match thipExtractedKpis.json
- code/page/titleTh/title agree with thipExtractedKpis.json
- every entry has a non-empty definition and formula (missing count reported)
- coverage of the optional fields (target, direction, targetScope, frequency,
  source, notes, numerator/denominator, inclusion/exclusion)
- distribution of direction and targetScope

Run from the repo root:
    python scripts/check_kpi_dictionary.py
"""

import json
import sys
from collections import Counter

sys.stdout.reconfigure(encoding='utf-8')

DICT_PATH = 'src/data/thipKpiDictionary.json'
CODES_PATH = 'src/data/thipExtractedKpis.json'

REQUIRED_KEYS = [
    'code', 'page', 'titleTh', 'title', 'definition', 'formula',
    'numeratorLabel', 'numeratorDefinition', 'denominatorLabel',
    'denominatorDefinition', 'inclusion', 'exclusion', 'target', 'direction',
    'targetScope', 'frequency', 'source', 'notes',
]


def nonempty(v):
    return bool(v) and (not isinstance(v, str) or bool(v.strip()))


def main():
    with open(DICT_PATH, encoding='utf-8') as f:
        data = json.load(f)
    with open(CODES_PATH, encoding='utf-8') as f:
        index = json.load(f)

    failures = []
    expected = set(index)
    got = set(data)
    total = len(expected)

    print('THIP KPI dictionary check')
    print('=========================')
    print(f'entries: {len(data)} (expected {total} from thipExtractedKpis.json)')
    if expected != got:
        failures.append('key sets differ')
        print(f'  MISSING keys   : {sorted(expected - got)}')
        print(f'  UNEXPECTED keys: {sorted(got - expected)}')
    else:
        print('key set matches thipExtractedKpis.json: yes')

    # structural checks
    wrong_keys = [c for c, e in data.items() if list(e.keys()) != REQUIRED_KEYS]
    if wrong_keys:
        failures.append('entry schema mismatch')
        print(f'entries with wrong key list/order: {wrong_keys}')

    mismatches = []
    for code, e in data.items():
        ref = index.get(code, {})
        if e.get('page') != ref.get('page'):
            mismatches.append(f'{code}: page {e.get("page")} != {ref.get("page")}')
        if e.get('titleTh') != ref.get('titleTh'):
            mismatches.append(f'{code}: titleTh differs')
        if e.get('title') != ref.get('title'):
            mismatches.append(f'{code}: title differs')
        if e.get('code') != code:
            mismatches.append(f'{code}: code field {e.get("code")!r}')
    if mismatches:
        failures.append('cross-check mismatches')
        print(f'cross-check vs thipExtractedKpis.json: {len(mismatches)} mismatches')
        for m in mismatches[:10]:
            print('  ' + m)
    else:
        print('code/page/titleTh/title cross-check: clean')

    # coverage
    def cov(key):
        return sum(1 for e in data.values() if nonempty(e.get(key)))

    rows = [
        ('definition', cov('definition')),
        ('formula', cov('formula')),
        ('numeratorLabel', cov('numeratorLabel')),
        ('numeratorDefinition', cov('numeratorDefinition')),
        ('denominatorLabel', cov('denominatorLabel')),
        ('denominatorDefinition', cov('denominatorDefinition')),
        ('inclusion', sum(1 for e in data.values() if e.get('inclusion'))),
        ('exclusion', sum(1 for e in data.values() if e.get('exclusion'))),
        ('target', cov('target')),
        ('direction', cov('direction')),
        ('targetScope', cov('targetScope')),
        ('frequency', cov('frequency')),
        ('source', cov('source')),
        ('notes', cov('notes')),
    ]

    missing_def = total - rows[0][1]
    missing_formula = total - rows[1][1]
    print()
    print('field coverage')
    print(f'{"field":<22}{"present":>8}{"coverage":>14}')
    for key, n in rows:
        print(f'{key:<22}{n:>8}{f"{n}/{total}":>14}')

    dir_counts = Counter(e.get('direction') for e in data.values())
    scope_counts = Counter(e.get('targetScope') for e in data.values())
    print()
    print('direction distribution:')
    for k in ('higher-is-better', 'lower-is-better', 'neutral', None):
        print(f'  {str(k):<20}{dir_counts.get(k, 0)}')
    print('targetScope distribution:')
    for k in ('annual', 'monthly', None):
        print(f'  {str(k):<20}{scope_counts.get(k, 0)}')

    if missing_def:
        failures.append(f'{missing_def} entries without definition')
    if missing_formula:
        failures.append(f'{missing_formula} entries without formula')

    summary = ', '.join(f'{k} {n}/{total}' for k, n in rows)
    print()
    print('COVERAGE SUMMARY')
    print(summary)
    print(f'missing definition: {missing_def}, missing formula: {missing_formula}')

    if failures:
        print()
        print('RESULT: FAIL')
        for f_ in failures:
            print('  - ' + f_)
        return 1
    print()
    print('RESULT: PASS (232/232 keys, definitions and formulas complete)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
