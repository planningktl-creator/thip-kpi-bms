"""Explain why each of the 232 THIP indicators has or has not produced a result.

Every statement in this report is derived from repository facts plus the measured
live rows, so the report cannot claim a reason the data does not support:

- registered vs externally-sourced: the registered branch's source CTE
  (`periodized`, `opd_periodized`, ... vs `external_facts`),
- measured / measured-zero / refused: from the live aggregate rows and the
  adaptive-run outcomes,
- benchmark: whether the PDF's Benchmark field printed a target for the code.

Outputs a markdown report and a per-code JSON summary under docs/ and tmp/.
"""
from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
DOCS = ROOT / "docs"

CADENCE_FILE = SRC / "data" / "thipReporting.ts"
RULES_FILE = SRC / "data" / "thipKpiRules.ts"
DICTIONARY_FILE = SRC / "data" / "thipKpiDictionary.json"
REGISTRY_FILE = SRC / "services" / "queryRegistry.ts"
FAMILIES_DIR = SRC / "services" / "thipFamilies"

LIVE_FILES = [
    ROOT / "tmp" / "live_facts_fy2026_full.json",
    ROOT / "tmp" / "live_facts_fy2026.json",
]
WINDOW_PLAN = ROOT / "tmp" / "window_plan_fy2026.json"

GROUPS = {"D": "D - โรคไม่ติดต่อ/โรคเฉพาะทาง", "C": "C - การดูแลต่อเนื่อง/โรคติดต่อ", "S": "S - ความปลอดภัยผู้ป่วย", "H": "H - ทรัพยากรบุคคล/อาคารสถานที่", "A": "A - ระบบงานอื่น"}


def cadences() -> dict[str, str]:
    text = CADENCE_FILE.read_text(encoding="utf-8")
    return dict(re.findall(r'"([A-Z0-9.]+)":\s*\'(monthly|quarterly|semiannual|annual)\'', text))


def rule_codes() -> set[str]:
    text = RULES_FILE.read_text(encoding="utf-8")
    return set(re.findall(r'\{"code":"([A-Z0-9.]+)"', text))


def dictionary() -> dict[str, dict]:
    return json.loads(DICTIONARY_FILE.read_text(encoding="utf-8"))


def external_codes() -> set[str]:
    """Codes whose registered branch reads the hospital-loaded external staging table.

    Read from the registry dump (`tmp/registry_partition.json`) rather than by
    pattern-matching the sources: the batch modules build external branches through
    helper functions, so a regex over the .ts files undercounts them badly.
    """
    path = ROOT / "tmp" / "registry_partition.json"
    if not path.exists():
        raise SystemExit("run `npx vitest run tmp/dump_partition.test.ts` first (registry partition dump)")
    return set(json.loads(path.read_text(encoding="utf-8"))["external"])


def live_state() -> tuple[dict[str, dict], set[str]]:
    """Returns (per-code cell state, codes whose measurement was refused everywhere).

    A code counts as refused only when every attempt in the window plan failed, i.e.
    the adaptive bisect never produced a single row for it.
    """
    state: dict[str, dict] = defaultdict(lambda: {"rows": 0, "measured_cells": 0, "zero_cells": 0})
    seen: set[tuple[str, str]] = set()
    for path in LIVE_FILES:
        if not path.exists():
            continue
        for row in json.loads(path.read_text(encoding="utf-8")):
            if not isinstance(row, dict):
                continue
            code = row.get("indicator_code")
            if not code:
                continue
            key = (str(code), str(row.get("period_start")))
            if key in seen:
                continue
            seen.add(key)
            entry = state[code]
            entry["rows"] += 1
            if row.get("denominator") not in (None, 0):
                entry["measured_cells"] += 1
            else:
                entry["zero_cells"] += 1
    refused: set[str] = set()
    if WINDOW_PLAN.exists():
        for code, data in json.loads(WINDOW_PLAN.read_text(encoding="utf-8")).items():
            if data.get("status") != "ok":
                refused.add(code)
    return dict(state), refused


def main() -> int:
    cadence = cadences()
    rules = rule_codes()
    entries = dictionary()
    external = external_codes()
    state, refused = live_state()

    codes = sorted(entries)
    reasons = Counter()
    detail: dict[str, dict] = {}

    for code in codes:
        entry = entries[code]
        group = code[0]
        cells = state.get(code, {"rows": 0, "measured_cells": 0, "zero_cells": 0})
        benchmark = entry.get("target")
        scope = entry.get("targetScope")
        cadence_of_code = cadence.get(code)
        if code in refused:
            # Only annual-cadence codes can still be refused after the adaptive window
            # bisect: a year is one bucket, so halving it would report half a year as
            # the annual value. Everything else recovers at a narrower window.
            reason = "query-too-heavy-annual" if cadence_of_code == "annual" else "query-too-heavy"
        elif code not in rules:
            reason = "not-registered"
        elif code in external:
            reason = "needs-external-staging"
        elif cells["measured_cells"] > 0:
            reason = "measured"
        elif cells["zero_cells"] > 0:
            reason = "measured-zero-cohort"
        else:
            reason = "not-measured-yet"
        reasons[reason] += 1
        detail[code] = {
            "group": group,
            "cadence": cadence.get(code),
            "registered": code in rules,
            "external": code in external,
            "reason": reason,
            "rows": cells["rows"],
            "measured_cells": cells["measured_cells"],
            "zero_cohort_cells": cells["zero_cells"],
            "benchmark_target": benchmark,
            "benchmark_scope": scope,
        }

    # Group / cadence / benchmark breakdowns for the report body.
    by_group = Counter(entries[code].get("indicatorGroup") or code[0] for code in codes)
    by_cadence = Counter(cadence.get(code, "unknown") for code in codes)
    with_benchmark = [code for code in codes if entries[code].get("target")]
    definition_missing = [code for code in codes if not (entries[code].get("definition") or "").strip()]
    formula_missing = [code for code in codes if not (entries[code].get("formula") or "").strip()]

    lines = [
        "# สถานะผลลัพธ์ 232 ตัวชี้วัด THIP (ปีงบประมาณ 2569)",
        "",
        "รายงานนี้สร้างจากข้อเท็จจริงใน repository + ผลรวมที่วัดได้จริงจาก HOSxP (aggregate เท่านั้น)",
        "ทุกบรรทัดอ้างอิงได้ ไม่มีการคาดเดาเหตุผลที่ข้อมูลไม่รองรับ",
        "",
        "## สรุปภาพรวม",
        "",
        "| สถานะ | จำนวน | ความหมาย |",
        "| --- | --- | --- |",
        f"| วัดได้จริง (measured) | {reasons['measured']} | มีค่า aggregate จริงอย่างน้อยหนึ่งงวด |",
        f"| วัดได้เป็นศูนย์ (zero cohort) | {reasons['measured-zero-cohort']} | query รันสำเร็จ แต่ cohort ว่างจริงในทุกงวด (ไม่ใช่ข้อมูลหาย) |",
        f"| ยังวัดไม่ได้ (annual เกินเพดาน) | {reasons['query-too-heavy-annual'] + reasons['query-too-heavy']} | query เกินเพดานเวลา และเป็นรอบรายปีที่แบ่งช่วงเวลาไม่ได้ |",
        f"| ต้องโหลดข้อมูลจากภายนอก HOSxP | {reasons['needs-external-staging']} | ข้อมูลไม่อยู่ใน HOSxP ต้องโหลดเข้า `reporting.thip_external_facts` |",
        f"| ไม่ได้ขึ้นทะเบียน query | {reasons['not-registered']} | ไม่มี registered branch |",
        "",
        f"- ตัวชี้วัดทั้งหมด: **{len(codes)}** (พจนานุกรม PDF: {len(entries)})",
        f"- ขึ้นทะเบียน query: **{len(rules)}** · เป็นข้อมูลภายนอก HOSxP: **{len(external)}**",
        f"- มี Benchmark พิมพ์ในเอกสาร: **{len(with_benchmark)}** ตัว → ที่เหลือแอปแสดง \"ให้โรงพยาบาลกำหนด\"",
        f"- นิยามว่าง: {len(definition_missing)} · สูตรว่าง: {len(formula_missing)}",
        "",
        "### แยกตามกลุ่ม",
        "",
        "| กลุ่ม | จำนวน |",
        "| --- | --- |",
    ]
    for group, count in sorted(by_group.items()):
        lines.append(f"| {GROUPS.get(group, group)} | {count} |")
    lines += ["", "### แยกตามรอบการรายงาน", "", "| รอบ | จำนวน |", "| --- | --- |"]
    for name, count in sorted(by_cadence.items()):
        lines.append(f"| {name} | {count} |")

    lines += ["", "## รายตัวชี้วัด", ""]
    for code in codes:
        entry = entries[code]
        info = detail[code]
        title = entry.get("titleTh") or entry.get("title") or ""
        target = info["benchmark_target"] or "ให้โรงพยาบาลกำหนด"
        lines.append(
            f"### {code} — {title}",
        )
        lines.append("")
        lines.append(
            f"- กลุ่ม: {GROUPS.get(info['group'], info['group'])} · รอบ: {info['cadence']} · "
            f"ขึ้นทะเบียน: {'ใช่' if info['registered'] else 'ไม่'} · แหล่งข้อมูล: "
            f"{'ภายนอก HOSxP (staging)' if info['external'] else 'HOSxP'}"
        )
        lines.append(f"- Benchmark ในเอกสาร: {target}")
        if info["reason"] == "measured":
            lines.append(f"- ผลลัพธ์: **วัดได้จริง** {info['measured_cells']} งวด (จากทั้งหมด {info['rows']} เซลล์)")
        elif info["reason"] == "measured-zero-cohort":
            lines.append(f"- ผลลัพธ์: **วัดได้เป็นศูนย์** — query สำเร็จ {info['rows']} เซลล์ แต่ cohort ว่างจริงทุกงวด")
        elif info["reason"] == "query-too-heavy-annual":
            lines.append(
                "- ผลลัพธ์: **ยังไม่มี** — query เกินเพดานเวลา และเป็นรอบรายปี (1 ปี = 1 ช่วง) "
                "จึงแบ่งหน้าต่างเวลาไม่ได้ ต้องปรับ query ให้เบาลง"
            )
        elif info["reason"] == "query-too-heavy":
            lines.append("- ผลลัพธ์: **ยังไม่มี** — query เกินเพดานเวลา แม้แบ่งถึงหน้าต่าง 1 เดือน")
        elif info["reason"] == "needs-external-staging":
            lines.append("- ผลลัพธ์: **ยังไม่มี** — ข้อมูลต้นทางอยู่นอก HOSxP ต้องโหลดเข้า `reporting.thip_external_facts`")
        else:
            lines.append("- ผลลัพธ์: **ยังไม่มีแถวผลลัพธ์** — อยู่ในสัญญาแต่ยังไม่ถูกวัดในรอบนี้")
        lines.append("")

    report = "\n".join(lines)
    (DOCS / "THIP-232-STATUS.md").write_text(report, encoding="utf-8")
    (ROOT / "tmp" / "kpi232_status.json").write_text(json.dumps(detail, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in reasons.items()}, ensure_ascii=False, indent=2))
    print(f"\ncodes={len(codes)} registered={len(rules)} external={len(external)} benchmark={len(with_benchmark)}")
    print(f"report: {DOCS / 'THIP-232-STATUS.md'} ({len(report)} chars)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
