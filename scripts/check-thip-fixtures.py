"""CI gate for the THIP source audit across the committed and invalid fixtures.

Runs `thip_source_audit.py` against the complete aggregate fixture (must pass)
and against every generated invalid fixture (must fail). It prints only the
audit status, never row values, so no patient data can leak into CI logs.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "scripts" / "thip_source_audit.py"
FIXTURES = ROOT / "test-fixtures"
FISCAL_YEAR = "2026"


def run_audit(input_path: Path) -> int:
    result = subprocess.run(
        [sys.executable, str(AUDIT), "--input", str(input_path), "--fiscal-year", FISCAL_YEAR],
        capture_output=True,
        text=True,
    )
    return result.returncode


def main() -> int:
    complete = FIXTURES / "thip-kpi-complete-2026.json"
    if not complete.exists():
        print(json.dumps({"status": "failed", "error": "complete fixture missing; run pnpm fixture:export"}))
        return 1

    failures: list[str] = []
    if run_audit(complete) != 0:
        failures.append("complete fixture unexpectedly failed the audit")

    invalid_dir = FIXTURES / "invalid"
    invalid_files = sorted(invalid_dir.glob("*.json")) if invalid_dir.exists() else []
    if not invalid_files:
        failures.append("no invalid fixtures found; run pnpm fixture:export")

    for invalid in invalid_files:
        if run_audit(invalid) == 0:
            failures.append(f"invalid fixture {invalid.name} unexpectedly passed the audit")

    if failures:
        print(json.dumps({"status": "failed", "failures": failures}, ensure_ascii=False))
        return 1

    print(json.dumps({
        "status": "passed",
        "complete_fixture": complete.name,
        "invalid_fixtures_checked": [path.name for path in invalid_files],
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
