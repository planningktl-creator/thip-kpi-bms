"""Build the actionable 232-indicator worklist: CSV + markdown tables.

Every column is derived from repository facts and the measured live extraction:
the registry partition (HOSxP vs external), the extraction outcome per code (measured
rows, empty cohort, refused), the cadence, whether the PDF printed a benchmark, and
the branch's own approximation note (what the query approximates and what the hospital
owner must confirm). Nothing is inferred beyond those sources.
"""
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
TMP = ROOT / "tmp"

GROUPS = {
    "D": "D โรคไม่ติดต่อ/โรคเฉพาะทาง",
    "C": "C การดูแลต่อเนื่อง/โรคติดเชื้อ",
    "S": "S ความปลอดภัยผู้ป่วย",
    "H": "H ทรัพยากรบุคคล/อาคารสถานที่",
    "A": "A ระบบงานสนับสนุนอื่น",
}

ACTIONS = {
    "measured": "ใช้ได้ — มีผลลัพธ์จริงแล้ว",
    "measured-zero-cohort": "ใช้ได้ — cohort ว่างจริง (ไม่ใช่ข้อมูลหาย) ควรทบทวนว่าตัวกรองตรงคลินิกไหม",
    "needs-external-staging": "ต้องโหลดข้อมูลเข้า reporting.thip_external_facts ก่อน",
    "query-too-heavy-annual": "ต้อง rewrite query (annual แบ่งช่วงเวลาไม่ได้)",
    "query-too-heavy": "ต้อง rewrite query",
    "not-registered": "ต้องขึ้นทะเบียน query",
}

SOURCES = {
    "needs-external-staging": "นอก HOSxP (สำรวจ/ทะเบียน/การเงิน/ประชากร HDC)",
    "query-too-heavy-annual": "HOSxP (query หนักเกินเพดาน)",
}


def load(name: str):
    return json.loads((TMP / name).read_text(encoding="utf-8"))


def main() -> int:
    status = load("kpi232_status.json")
    partition = load("registry_partition.json")
    approximations = load("approximations.json")
    dictionary = json.loads((ROOT / "src" / "data" / "thipKpiDictionary.json").read_text(encoding="utf-8"))

    rows = []
    for code in sorted(status):
        info = status[code]
        entry = dictionary.get(code, {})
        rows.append({
            "code": code,
            "group": info["group"],
            "group_name": GROUPS.get(info["group"], info["group"]),
            "title_th": (entry.get("titleTh") or entry.get("title") or "").strip(),
            "cadence": info["cadence"] or "",
            "source": "HOSxP" if not info["external"] else "นอก HOSxP (staging)",
            "status": info["reason"],
            "action": ACTIONS.get(info["reason"], info["reason"]),
            "measured_cells": info["measured_cells"],
            "zero_cohort_cells": info["zero_cohort_cells"],
            "benchmark": info["benchmark_target"] or "ให้โรงพยาบาลกำหนด",
            "unit": entry.get("unit") or "",
            "direction": entry.get("direction") or "",
            "note": (approximations.get(code) or "").strip(),
        })

    tmp_path = TMP / "kpi232_worklist.csv"
    with tmp_path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    by_status: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_status[row["status"]].append(row)

    lines = [
        "# รายการ 232 ตัวชี้วัด — ต้องทำอะไรต่อ (ปีงบประมาณ 2569)",
        "",
        "ทุกคอลัมน์มาจากข้อเท็จจริงใน repo + ผลวัดจริงจาก HOSxP: ขึ้นทะเบียน/แหล่งข้อมูลจาก registry,",
        "สถานะจากผล extraction รายตัวชี้วัด, Benchmark จากเอกสาร THIP 2025, note จาก `*_APPROXIMATIONS` ของ branch",
        "ที่ query เขียนไว้เอง (สิ่งที่ยัง approximate + ที่ต้องให้เจ้าของงานยืนยัน)",
        "",
        "## ภาพรวม",
        "",
        "| สถานะ | จำนวน | ต้องทำอะไร |",
        "| --- | --- | --- |",
    ]
    for reason, items in sorted(by_status.items(), key=lambda item: -len(item[1])):
        lines.append(f"| {reason} | {len(items)} | {ACTIONS.get(reason, '-')} |")
    lines += ["", f"รวม **{len(rows)}** ตัวชี้วัด", ""]

    # Actionable sections first, then the working set.
    for reason, title in (
        ("needs-external-staging", "1) ต้องโหลดข้อมูลจากภายนอก HOSxP (55 ตัว)"),
        ("query-too-heavy-annual", "2) ต้อง rewrite query — annual ที่ยังเกินเพดาน"),
        ("measured-zero-cohort", "3) วัดได้เป็นศูนย์ — ทบทวนตัวกรองกับคลินิก"),
    ):
        items = by_status.get(reason, [])
        if not items:
            continue
        lines += [f"## {title}", ""]
        if reason == "needs-external-staging":
            lines += [
                "ข้อมูลต้นทางไม่ได้อยู่ใน HOSxP (แบบสำรวจความพึงพอใจ, ทะเบียนอุบัติการณ์, การเงิน, ประชากร HDC)",
                "ต้องโหลดเข้า `reporting.thip_external_facts` แล้ว query จะอ่านได้ทันที",
                "",
            ]
        lines += ["| รหัส | ชื่อตัวชี้วัด | กลุ่ม | รอบ | แหล่งข้อมูล |", "| --- | --- | --- | --- | --- |"]
        for row in items:
            lines.append(f"| {row['code']} | {row['title_th'][:70]} | {row['group']} | {row['cadence']} | {SOURCES.get(reason, '-')} |")
        lines.append("")

    lines += ["## 4) ตัวที่ยังไม่มี Benchmark ในเอกสาร", ""]
    no_bench = [row for row in rows if row["benchmark"] == "ให้โรงพยาบาลกำหนด"]
    lines += [f"มี **{len(no_bench)}** ตัว (เอกสารพิมพ์ค่าเป้าหมายจริง {len(rows) - len(no_bench)} ตัว) — แอปแสดง \"ให้โรงพยาบาลกำหนด\" ไม่เดาตัวเลข", ""]

    lines += ["## ตารางเต็ม 232 ตัว", "", "| รหัส | ชื่อ | กลุ่ม | รอบ | สถานะ | Benchmark |", "| --- | --- | --- | --- | --- | --- |"]
    for row in rows:
        lines.append(
            f"| {row['code']} | {row['title_th'][:58]} | {row['group']} | {row['cadence']} | {row['action'][:44]} | {row['benchmark'][:26]} |"
        )
    lines.append("")
    lines += [
        "## ไฟล์ที่เกี่ยวข้อง",
        "",
        "- `tmp/kpi232_worklist.csv` — ตารางเดียวจบ (มี note รายตัว + จำนวนเซลล์ที่วัดได้) เปิดใน Excel ได้",
        "- `docs/THIP-232-STATUS.md` — รายละเอียดรายตัวชี้วัด",
        "- `tmp/live_facts_fy2026_full.json` — ผล aggregate จริงที่ใช้สร้างรายงานนี้",
    ]

    report = "\n".join(lines)
    (DOCS / "THIP-232-WORKLIST.md").write_text(report, encoding="utf-8")
    print("by status:", {k: len(v) for k, v in by_status.items()})
    print("csv:", tmp_path)
    print("md:", DOCS / "THIP-232-WORKLIST.md", len(report), "chars")
    print("groups:", dict(Counter(row["group"] for row in rows)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
