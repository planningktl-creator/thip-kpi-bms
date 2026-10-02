# THIP KPI source notes

These notes record the source boundary for the first implementation slice.

## Monitoring release boundary — 2026-10-01

The complete [audit matrix](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json) records all 232 definitions/pages and candidate table/column/PK joins against `HOSxP Structure with primary key.json` (6,109 tables / 56,891 columns; no declared foreign keys). Shared column names remain unconfirmed relations. Monitoring capability totals are 101 candidate monthly, 71 additional-rule design, 55 external aggregate and 5 external population. Compact page/unit/path evidence and generated rule registry are checked for drift against the full matrix.

Official THIP cadence stays 1,552 cells. Monthly monitoring is an independent 2,784-cell series with NULL/reasons, versioned accumulation and target provenance; see [contract](THIP-MONITORING-CONTRACT.md). Every real rule is unapproved for publication. Seven development-only synthetic examples illustrate behavior without claiming clinical correctness.

Local PostgreSQL 16 tests used a disposable empty schema and synthetic episode/event/aggregate rows only. They verified a complete 1,552-cell refresh, retained DE1601 external facts, discharge-period DH0101 without duplicate detail counts, and a SH0104 full-window/partial-window counterexample that justifies disabling date bisection. They also executed the offline monitoring DDL. This validates selected SQL mechanics, not hospital cohort definitions or all clinical formulas. No real BMS/HOSxP connection, database migration or deployment occurred.

## THIP KPI Dictionary 2025

- Source for the complete audit and first monitoring release: `C:/Users/KTLho/Desktop/02_PDF/THIP KPI.pdf` (317 pages).
- The document describes 232 benchmark indicators for the 2025 dictionary.
- The catalogue is organised into five groups: Disease (D), Care process (C), System (S), Health promotion (H), and Ambulatory care (A).
- Indicator codes use two group/category letters followed by two two-digit sequences, for example `DH0101`.
- Indicator reporting uses a numerator and denominator, commonly expressed as `(a/b) x 100`; the dictionary includes monthly, quarterly, semiannual, and annual cadences recorded in `src/data/thipReporting.ts`.
- The database boundary remains ISO and fiscal years run October through September; the frontend maps the ISO period to Thai Buddhist Era labels (for example, `2025-10-01` becomes `ต.ค. 2568`).
- HOSxP stores ICD-10 codes without the decimal point (for example `A409` instead of `A40.9`). Every registered query compares diagnosis and death-cause codes through `REPLACE(UPPER(TRIM(col)), '.', '')` against dotless literals so both dotted and dotless source values match.
- The detail page in the dashboard keeps the numerator, denominator, formula, frequency, and reference visible so a reviewer can trace the result.

## HOSxP Structure

- Source: `C:/Users/KTLho/Desktop/HOSxP Structure.xlsx`.
- The workbook is a schema inventory, not a result dataset.
- Relevant columns observed for the BMS read-only foundation include `ipt.an`, `ipt.regdate`, `ipt.dchdate`, `ipt.ward`, `ipt.drg`, `ipt.rw`, `ipt.adjrw`, `an_stat.item_money`, `iptdiag.icd10`, `iptoprt.icd9`, `iptbedmove.movedate`, `ward.name`, `opitemrece.vstdate`, `opitemrece.vsttime`, `opitemrece.icode`, and `drugitems.name`, `drugitems.antibiotic`, `drugitems.drugcategory`.
- The inventory alone does not establish local business meaning, ICD inclusion/exclusion lists, or THIP numerator/denominator logic. Those must be validated against anonymised staging data before live KPI queries are enabled.

## Current product decision

The UI ships with the full 232-entry catalogue in a no-data state and replaces indicators with live BMS results when the session is healthy. The first query implements `DH0101`, `DH0101.1`, `DH0101.2`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, `DN0109`, and `DN0302` from the PDF definitions using `ipt`, `an_stat`, `iptdiag`, `death`, `opitemrece`, and `drugitems`, returning one row per indicator and reporting period. `DH0101.1`/`DH0101.2` separate STEMI and NSTE-ACS cohorts using the printed pages 40/41; `DG0102` is a Pdx-based UGIH length-of-stay aggregate from printed page 121; `DN0302` measures head-injury mortality within 48 hours of admit using printed page 77 and the HOSxP admission/death timestamps; `CE0101`/`CI0101` use the PDF sepsis code sets (printed pages 194/199), and the `DR0102`/`DN0107` re-admission rule currently uses a documented approximation because the supplied schema inventory does not provide a signed local mapping for the THIP `status=improve`/unplanned exclusion. The app keeps the other indicators on the no-data contract until their hospital-specific numerator/denominator rules are confirmed.

For a complete hospital implementation, register a normalized read-only source view and set `VITE_BMS_KPI_SOURCE_VIEW`. All 232 codes now have registered fact branches: the in-registry family queries cover the original core (shared IPD base cohort in `src/services/thipIpdBase.ts`), the batch modules in `src/services/thipFamilies/` cover the remaining 171 codes with per-code documented approximations (`*_APPROXIMATIONS`, pending clinical sign-off), and 55 codes whose source is outside HOSxP (population, audited finance, survey instruments, device-days, custom registries) read the hospital-loaded `reporting.thip_external_facts` staging table. `pnpm sourceview:build` generates the reporting-layer DDL (including the staging table) and per-fiscal-year refresh into `reporting/thip_kpi_monthly.sql`: HOSxP codes receive measured numerator/denominator/value with cadence-aware period buckets (a quarterly fact covers its quarter, an annual fact the fiscal year), an empty cohort is a measured zero (0 facts, NULL value), and a missing source or unloaded staging row is an explicit `unavailable` row with a `pending_reason` — never a fabricated zero. The official browser reporting path retains its configured source/foundation and publication gates; Docker can also build the separate unapproved Step candidate page without a source view, and the frontend accepts a complete result only when the view covers every applicable reporting period for all 232 codes (1,552 cadence-aware cells per fiscal year). The view contract is recorded in `docs/THIP-DATA-CONTRACT.md`; it allows the same frontend to replace all catalogue entries without exposing raw patient rows. `src/data/thipImplementation.ts` is the single source of truth for which codes are `registered` versus `pending-local-source`.

The sequential candidate validation page is documented in [THIP-STEP-LOADING.md](THIP-STEP-LOADING.md). It reads registered single-code aggregates with the full observation window, one request at a time and a one-second gap. These facts never become approved reporting/monitoring results automatically. No DDL, refresh or sample INSERT is executed by that path.
## Cohort evidence update (2026-10-01)

For this work the primary structural source is `HOSxP Structure with primary key.json` (6,109 tables, 56,891 columns). Obsidian's July table notes describe a different snapshot (6,617 tables, 81,554 columns). Neither inventory confirms live cardinality or clinical meaning. Use patient.hn for registry counts, ovst.vn/hn for services/people, ipt.an/hn for admissions/people, person.patient_hn for patient linkage, emp.emp_id/emp_cid for candidate HR and opduser.loginname/cid for accounts. `patient.hn` is not the declared PK; it must not be assumed unique in joins. Profile counts and all 232 candidate cohort definitions are detailed in [THIP-COHORT-PROFILES.md](THIP-COHORT-PROFILES.md) and [THIP-COHORT-MAPPING.md](THIP-COHORT-MAPPING.md). No HN/CID/VN/AN values are sent to UI/cache.

## Shared SPA owner — 2 ตุลาคม 2569

[THIP-SHARED-DATA.md](THIP-SHARED-DATA.md) กำหนด root-owned queue/cache, strict draft projection, review/approved selectors และ explicit monthly bridge. Route ไม่โหลดข้อมูลซ้ำ; publication/completeness/cadence เดิมคงอยู่. ใช้ mocked BMS เท่านั้นสำหรับรอบนี้.
