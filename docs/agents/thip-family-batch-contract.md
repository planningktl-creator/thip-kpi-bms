# THIP family batch contract (for parallel batch authors)

Repo: `C:\Users\KTLho\Documents\THIP-KPI-BMS`. Python 3.11 = `python`.
The repo computes THIP KPI 2025 indicators (232 total) from HOSxP (PostgreSQL
dialect, **read-only**) through "fact branches": SQL fragments returning one row
per indicator code x reporting period.

## Read first (in order)

1. `src/services/thipFamilyBase.ts` — the branch helpers you **must** use:
   - `branchIpd(code, numerator, denominator, value, where, opts?)` over the
     `periodized` IPD base,
   - `branchFact(code, num, den, value, where, { source, join, groupBy? })`
     over any base CTE,
   - `branchExternal(code)` for hospital-loaded aggregates from
     `reporting.thip_external_facts`.
   The helpers perform cadence-aware period bucketing (monthly / quarterly /
   semiannual / annual anchors) automatically — **never** compute fiscal months
   yourself.
2. `src/services/thipIpdBase.ts` — `periodized` columns: `an, hn, age_y, los,
   pdx` (dotless uppercase), `died, died_from_acs, died_from_stemi,
   died_from_nste, died_from_pneumonia, died_within_48h, has_acs_sdx,
   has_stemi_sdx, has_nste_sdx, has_pneumonia_sdx, has_ce0101_sepsis,
   has_ci0101_sepsis, bw, regdate, regtime, dchdate, period_start,
   calendar_month`.
3. `EXTENDED_BASE_CTE` in `thipFamilyBase.ts`:
   - `opd_periodized`: `vn, hn, an, age_y, sex, pdx` (dotless), `event_date,
     enter_er_time, triage_datetime, doctor_tx_time, finish_time,
     antibiotics_datetime, stroke_needle_datetime, stemi_balloon_datetime,
     er_emergency_level_id, unplanned_return, news2_score, period_start,
     calendar_month`
   - `chronic_periodized`: `clinicmember_id, clinic, hn, regdate, lastvisit,
     dchdate, current_status, clinic_member_status_id, age_y, sex, chronic_type,
     begin_year, last_hba1c_value, last_hba1c_date, last_bp_bps_value,
     last_bp_bpd_value, last_bp_date, period_start, calendar_month`
   - `delivery_periodized`: `laborid, an, mother_age_y, labor_type,
     mother_method, infant_sex, infant_weight, infant_apgarscore1,
     infant_apgarscore5, infant_apgarscore10, placenta_bloodloss,
     labour_startdate, labour_finishdate, period_start, calendar_month`
   - `newborn_periodized`: `an, mother_an, born_date, birth_weight, apgar1,
     apgar2, dead, has_asphyxia, birthcondition1, birthcondition2, anc_complete,
     period_start, calendar_month`
   - `emp_periodized`: `emp_id, emp_sex_id, emp_birthdate, emp_status_id,
     emp_type_id, emp_dep_id, emp_position_main_id, emp_work_begindate,
     emp_resign_enddate, emp_resign_type_id, period_start, calendar_month`
4. `src/data/thipKpiDictionary.json` — **authoritative** KPI definitions per
   code (`definition`, `formula`, `numeratorDefinition` ("a = ..."),
   `denominatorDefinition` ("b = ..."), `frequency`, `target`, `direction`).
   Write each branch to match its printed definition as closely as HOSxP allows.
5. `src/data/thipKpiRules.ts` — per-code `formulaScale` (`a/b x 100` |
   `a/b x 1,000` | `a/b x 100,000` | count-style `a`) and
   `candidateSourceTables`.
6. `src/services/queryRegistry.ts` — read-only style reference (branch
   patterns, EXISTS drug/lab subqueries, readmission patterns).
7. `C:\Users\KTLho\Desktop\01_Excel\HOSxP Structure.xlsx`, sheet
   `HOSxP Structure` (openpyxl; Thai headers) — **verify every HOSxP
   table.column you reference** exists in this workbook (the stock transaction
   table is spelled `stock_trancation`). Never invent columns; if a needed
   column is absent, use a verified alternative or fall back to
   `branchExternal` with a documented staging requirement.

## Files you own

Create **exactly two new files**: your batch module and its vitest test (see the
task for names/exports). Never edit an existing file, never run git, and run
**only your own test file** (`npx vitest run src/services/thipFamilies/<your
test>.ts`) — other agents are changing the rest of the tree concurrently.

## Hard SQL rules (the repo security suite enforces these at integration)

- Read-only aggregates. Outer projection ONLY `indicator_code, period_start,
  fiscal_month, fiscal_year, numerator, denominator, value` (the helpers do
  this) and never `hn/an/vn/cid/emp_id/names/birthdates`.
- Dotless ICD-10/ICD-9 literals ONLY (`'I210'`, `'E119'` — never `'I21.0'`),
  compared via `REPLACE(UPPER(TRIM(col)), '.', '')`.
- Every division literally `X / NULLIF(Y, 0)` and **no other `/` character
  anywhere** in the SQL (no `mg/dl`, no `2025/01/01`, no slashes in comments or
  strings).
- Value expression: ratio-like units `ROUND(<num expr> * <multiplier from
  formulaScale> / NULLIF(<den expr>, 0), 2)`; count-kind units `value` = the
  numerator expression and `denominator` = `'NULL'`.
- Keep the helper's default `GROUP BY 2, 3, 4`.
- One row per episode/visit grain — never join one-to-many tables (`iptdiag`,
  `opitemrece`, `lab_order`) and `COUNT(*)`; use `COUNT(DISTINCT key)`,
  `COUNT(*) FILTER (WHERE EXISTS (...))`, or scalar/EXISTS subqueries like
  `queryRegistry` does.

## Honesty rule

Where the printed definition cannot be met exactly (event-time semantics,
questionnaires, device-days, population denominators), implement the closest
defensible aggregate **and** record the gap in `_APPROXIMATIONS` (every code
needs a non-empty entry: what the branch measures, what the PDF needs beyond
it, what the hospital owner must confirm). If the source genuinely is not in
HOSxP, use `branchExternal(code)` and document the exact staging rows the
hospital must load into `reporting.thip_external_facts` (one row per indicator
code x reporting-period anchor with `numerator, denominator, value,
source_system`).

## Test requirements (your test file)

Per assigned code assert:
1. exactly one branch contains `'CODE' AS indicator_code`;
2. the branch has `AS numerator`, `AS denominator`, `AS value`;
3. outer projection free of PHI tokens (`hn, an, vn, cid, patient_name,
   birthdate`);
4. no dotted ICD codes (regex `/\b[A-Z]\d{2}\./` must not match);
5. every `/` is a NULLIF-guarded division;
6. `isExternalBranch(branch)` matches your external list (import from
   `thipFamilyBase`);
7. `_APPROXIMATIONS` entry non-empty.

Include the real test output verbatim in your summary.

## Summary schema

`codes_covered` (exact list), `external_codes`, `files_created`,
`branch_summaries` (one line per code: what the branch measures), `test_output`
verbatim.
