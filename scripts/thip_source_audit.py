"""Validate a normalized THIP source-view export without reading patient rows.

The input is a JSON/CSV export of the reporting layer, not an HOSxP dump. The
script deliberately reports only code/period diagnostics and never echoes raw
row values. It parses the repository's catalogue/rule manifests so the audit
cannot silently drift from the frontend's 232-code contract.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
RULES_PATH = ROOT / "src" / "data" / "thipKpiRules.ts"
REPORTING_PATH = ROOT / "src" / "data" / "thipReporting.ts"

CADENCES = {
    "monthly": (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12),
    "quarterly": (1, 4, 7, 10),
    "semiannual": (1, 7),
    "annual": (1,),
}
GROUPS = {"A", "C", "D", "H", "S"}
UNITS = {"percent", "rate", "ratio", "count"}
DIRECTIONS = {"higher-is-better", "lower-is-better", "neutral"}
TARGET_SCOPES = {"monthly", "annual"}
REQUIRED_METADATA = (
    "indicator_group",
    "unit",
    "direction",
    "target_scope",
    "category",
    "title",
    "definition",
    "formula",
    "numerator_label",
    "denominator_label",
    "source_tables",
    "frequency",
    "reference",
    "rule_version",
    "refreshed_at",
)
STABLE_METADATA = tuple(field for field in REQUIRED_METADATA if field != "refreshed_at")
NUMERIC_FIELDS = ("numerator", "denominator", "value", "target", "percentile")


def load_manifests() -> tuple[dict[str, dict[str, str]], dict[str, str]]:
    """Read code/group/formula rules and reporting cadence from TypeScript."""

    rules: dict[str, dict[str, str]] = {}
    for line in RULES_PATH.read_text(encoding="utf-8").splitlines():
        match = re.search(
            r'\{"code":"([^"]+)".*?"group":"([A-Z])".*?"formulaScale":"([^"]*)"',
            line,
        )
        if match:
            code, group, formula = match.groups()
            rules[code] = {"group": group, "formula_scale": formula}

    cadence: dict[str, str] = {}
    for line in REPORTING_PATH.read_text(encoding="utf-8").splitlines():
        match = re.search(r'"([A-Z0-9.]+)":\s*\'(monthly|quarterly|semiannual|annual)\'', line)
        if match:
            cadence[match.group(1)] = match.group(2)

    if len(rules) != 232 or len(cadence) != 232:
        raise RuntimeError(
            f"repository manifest mismatch: rules={len(rules)}, cadence={len(cadence)}; expected 232 each"
        )
    if set(rules) != set(cadence):
        raise RuntimeError("repository rule and cadence code sets do not match")
    return rules, cadence


def expected_unit(formula_scale: str) -> str:
    normalized = formula_scale.replace(" ", "").replace(",", "").lower()
    if "x1000000" in normalized or "x100000" in normalized or "x1000" in normalized:
        return "rate"
    if "x100" in normalized:
        return "percent"
    return "ratio"


def formula_multiplier(formula: str) -> Decimal:
    match = re.search(r"[x×]\s*(\d+(?:\.\d+)?)", formula.replace(",", ""), re.IGNORECASE)
    if not match:
        return Decimal("1")
    try:
        parsed = Decimal(match.group(1))
    except InvalidOperation:
        return Decimal("1")
    return parsed if parsed.is_finite() and parsed > 0 else Decimal("1")


def fiscal_period_start(fiscal_year: int, fiscal_month: int) -> str:
    if not 1 <= fiscal_month <= 12:
        raise ValueError("fiscal_month must be between 1 and 12")
    calendar_year = fiscal_year - 1 if fiscal_month <= 3 else fiscal_year
    calendar_month = fiscal_month + 9 if fiscal_month <= 3 else fiscal_month - 3
    return date(calendar_year, calendar_month, 1).isoformat()


def load_rows(path: Path) -> list[dict[str, Any]]:
    if path.suffix.lower() == ".csv":
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            return [dict(row) for row in csv.DictReader(handle)]

    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if isinstance(payload, list):
        rows = payload
    elif isinstance(payload, dict):
        rows = payload.get("data")
        if not isinstance(rows, list):
            rows = payload.get("result")
    else:
        rows = None
    if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
        raise ValueError("input must be a JSON array or an object containing data/result rows")
    return [dict(row) for row in rows]


def lower_keys(row: dict[str, Any]) -> dict[str, Any]:
    return {str(key).lower(): value for key, value in row.items()}


def text(value: Any) -> str | None:
    if value is None or isinstance(value, (dict, list, tuple, bool)):
        return None
    value = str(value).strip()
    return value or None


def number(value: Any) -> Decimal | None:
    if value is None or value == "":
        return None
    if isinstance(value, bool) or isinstance(value, (dict, list, tuple)):
        return None
    try:
        parsed = Decimal(str(value).strip())
    except (InvalidOperation, ValueError):
        return None
    if not parsed.is_finite():
        return None
    return parsed


def source_tables(value: Any) -> list[str]:
    if isinstance(value, list):
        return [item.strip() for item in (text(item) for item in value) if item]
    raw = text(value)
    if not raw:
        return []
    if raw.startswith("{") and raw.endswith("}"):
        raw = raw[1:-1]
    return [item.strip().strip('"').replace('\\"', '"') for item in raw.split(",") if item.strip()]


def issue(sample: list[str], value: str, limit: int = 20) -> None:
    if value not in sample and len(sample) < limit:
        sample.append(value)


def audit(path: Path, fiscal_year: int) -> tuple[dict[str, Any], int]:
    rules, cadence = load_manifests()
    rows = [lower_keys(row) for row in load_rows(path)]
    expected_cells = {
        (code, month)
        for code, frequency in cadence.items()
        for month in CADENCES[frequency]
    }
    cells: set[tuple[str, int]] = set()
    duplicates: set[tuple[str, int]] = set()
    available_cells: set[tuple[str, int]] = set()
    unavailable_cells: set[tuple[str, int]] = set()
    unknown_codes: list[str] = []
    period_errors: list[str] = []
    unexpected_cells: list[str] = []
    metadata_errors: list[str] = []
    numeric_errors: list[str] = []
    metadata_by_code: dict[str, tuple[str, ...]] = {}
    refreshed_values: set[str] = set()

    for row_number, row in enumerate(rows, start=2):
        code = text(row.get("indicator_code"))
        if code not in rules:
            issue(unknown_codes, code or f"row {row_number}: missing code")
            continue

        raw_year = number(row.get("fiscal_year"))
        raw_month = number(row.get("fiscal_month"))
        period = text(row.get("period_start"))
        month = int(raw_month) if raw_month is not None and raw_month == int(raw_month) else None
        if month is not None and 1 <= month <= 12 and month not in CADENCES[cadence[code]]:
            issue(unexpected_cells, f"{code}:fiscal_month {month}")
        valid_period = (
            raw_year is not None
            and raw_year == fiscal_year
            and month in CADENCES[cadence[code]]
            and period is not None
            and period[:10] == fiscal_period_start(fiscal_year, month)
        )
        if not valid_period:
            issue(period_errors, f"{code}:row {row_number}")
        else:
            cell = (code, month)
            if cell in cells:
                duplicates.add(cell)
            cells.add(cell)
            # A NULL denominator is the contract's explicit unavailable state;
            # any other row (including a measured zero cohort) is available.
            if number(row.get("denominator")) is None:
                unavailable_cells.add(cell)
            else:
                available_cells.add(cell)

        unit = text(row.get("unit"))
        group = text(row.get("indicator_group"))
        direction = text(row.get("direction"))
        target_scope = text(row.get("target_scope"))
        if group not in GROUPS or group != rules[code]["group"]:
            issue(metadata_errors, f"{code}:indicator_group")
        if unit not in UNITS or unit != expected_unit(rules[code]["formula_scale"]):
            issue(metadata_errors, f"{code}:unit")
        if direction not in DIRECTIONS:
            issue(metadata_errors, f"{code}:direction")
        if target_scope not in TARGET_SCOPES:
            issue(metadata_errors, f"{code}:target_scope")
        for field in REQUIRED_METADATA:
            value = row.get(field)
            present = bool(source_tables(value)) if field == "source_tables" else text(value) is not None
            if not present:
                issue(metadata_errors, f"{code}:missing {field}")
        stable_signature = tuple(
            "|".join(sorted(source_tables(row.get(field))))
            if field == "source_tables"
            else text(row.get(field)) or ""
            for field in STABLE_METADATA
        )
        previous_signature = metadata_by_code.get(code)
        if previous_signature is not None and previous_signature != stable_signature:
            issue(metadata_errors, f"{code}:inconsistent metadata")
        metadata_by_code[code] = stable_signature
        refreshed_at = text(row.get("refreshed_at"))
        if refreshed_at is not None:
            refreshed_values.add(refreshed_at)
            try:
                datetime.fromisoformat(refreshed_at.replace("Z", "+00:00"))
            except ValueError:
                issue(metadata_errors, f"{code}:invalid refreshed_at")
        formula = text(row.get("formula"))
        if formula is not None and formula_multiplier(formula) != formula_multiplier(rules[code]["formula_scale"]):
            issue(metadata_errors, f"{code}:formula multiplier")

        for field in NUMERIC_FIELDS:
            raw = row.get(field)
            if raw not in (None, "") and number(raw) is None:
                issue(numeric_errors, f"{code}:non-numeric {field}")
        denominator = number(row.get("denominator"))
        numerator = number(row.get("numerator"))
        value = number(row.get("value"))
        percentile = number(row.get("percentile"))
        if denominator == 0 and value is not None:
            issue(numeric_errors, f"{code}:value must be NULL when denominator is zero")
        if percentile is not None and not Decimal("0") <= percentile <= Decimal("100"):
            issue(numeric_errors, f"{code}:percentile outside 0-100")
        if unit != "count" and denominator is None and value is not None:
            issue(numeric_errors, f"{code}:value has no denominator")
        if unit != "count" and numerator is not None and denominator not in (None, 0) and value is not None:
            expected_value = numerator / denominator * formula_multiplier(rules[code]["formula_scale"])
            tolerance = max(Decimal("0.02"), abs(expected_value) * Decimal("0.0001"))
            if abs(value - expected_value) > tolerance:
                issue(numeric_errors, f"{code}:value inconsistent with numerator/denominator")

    if len(refreshed_values) > 1:
        issue(metadata_errors, "source:inconsistent refreshed_at")

    missing = sorted(expected_cells - cells)
    status = "passed" if not (
        unknown_codes
        or period_errors
        or unexpected_cells
        or duplicates
        or metadata_errors
        or numeric_errors
        or missing
    ) else "failed"
    summary = {
        "status": status,
        "fiscal_year": fiscal_year,
        "input_rows": len(rows),
        "expected_indicators": len(rules),
        "expected_cells": len(expected_cells),
        "covered_cells": len(cells & expected_cells),
        "available_cells": len(available_cells & expected_cells),
        "unavailable_cells": len(unavailable_cells & expected_cells),
        "live_indicators": len({code for code, _ in cells & expected_cells}),
        "missing_cell_count": len(missing),
        "duplicate_cell_count": len(duplicates),
        "unexpected_cell_count": len(unexpected_cells),
        "unknown_code_count": len(unknown_codes),
        "metadata_error_count": len(metadata_errors),
        "numeric_error_count": len(numeric_errors),
        "samples": {
            "missing_cells": [f"{code}:fiscal_month {month}" for code, month in missing[:20]],
            "duplicates": [f"{code}:fiscal_month {month}" for code, month in sorted(duplicates)[:20]],
            "unexpected_cells": unexpected_cells,
            "unknown_codes": unknown_codes,
            "period_errors": period_errors,
            "metadata_errors": metadata_errors,
            "numeric_errors": numeric_errors,
        },
    }
    return summary, 0 if status == "passed" else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="normalized source-view JSON or CSV export")
    parser.add_argument("--fiscal-year", required=True, type=int, help="ISO-side fiscal year, e.g. 2026 for พ.ศ. 2569")
    args = parser.parse_args()
    try:
        summary, exit_code = audit(args.input, args.fiscal_year)
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "failed", "error": str(error)}, ensure_ascii=False))
        return 1
    print(json.dumps(summary, ensure_ascii=False))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
