# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root, or
- **`CONTEXT-MAP.md`** at the repo root if it exists: it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

This repository is **single-context**. Before changing the data boundary, also read:

- `README.md` for the product boundary and local commands.
- `docs/THIP-DATA-CONTRACT.md` for the normalized indicator and reporting-period result contract.
- `docs/THIP-SOURCE-NOTES.md` for the evidence and limitations from the THIP KPI PDF and the HOSxP schema workbook.
- `docs/THIP-KPI-DICTIONARY-STRUCTURE.md` for the dictionary's own structure and measurement model.
- `AGENTS.md` for the read-only / no-PHI boundary every change must respect.

## File structure

Single-context repo:

```
/
├── CONTEXT.md          ← created lazily by /domain-modeling
├── docs/adr/           ← created lazily by /domain-modeling
└── src/
```

## Domain vocabulary

- **Indicator**: one THIP KPI code with its group, definition, formula, target, reporting cadence, and fiscal-year results.
- **Reporting-period result**: one `indicator_code × fiscal_year × fiscal_month` row preserving the ISO `periodStart`, Thai Buddhist display label, numerator, denominator, value, target, percentile, and status. The applicable fiscal months come from the indicator cadence (monthly, quarterly, semiannual, or annual).
- **Cadence anchor**: the fiscal month a reporting-period result is anchored to, derived from the code's cadence — monthly anchors on its calendar month, quarterly on 1/4/7/10, semiannual on 1/7, annual on 1. A quarterly fact covers its whole quarter; an annual fact covers the whole October–September fiscal year.
- **Cell**: one `indicator_code × cadence anchor` slot of a fiscal year. The 2025 dictionary has 1,552 cells per fiscal year.
- **Cell state**: which of four facts a cell carries — a **measured value**, a **measured zero cohort** (the registered query ran and found an empty cohort: 0 facts, `value` NULL), a **staged-and-missing** cell (the source row or external staging row has not arrived, so the reporting layer emits an explicit `unavailable` row with a `pending_reason`), or **not-measurable-with-reason**. A blank cell must be able to say which of these it is; it is never a fabricated zero.
- **Dictionary benchmark**: the comparison value the THIP PDF prints in its "Benchmark (แหล่งอ้างอิง/ปี)" field — an external reference (e.g. `U.S.A. National Median`, `UK 8%`), not a THIP-mandated target. Only 53 of the 232 codes print one.
- **Hospital target**: the target a hospital sets for a code that prints no dictionary benchmark (179 of 232 codes). The UI must keep the two distinct rather than presenting a benchmark as this hospital's target.
- **Fiscal-year rollup**: one annual numerator/denominator/value/target/status summary derived from a selected October–September fiscal year.
- **Reporting horizon**: the three views of one fiscal year's results — **monthly** (every fiscal month), **quarterly** (weighted Q1 ต.ค.–ธ.ค. … Q4 ก.ค.–ก.ย.), and **annual** (weighted over all measured periods). Every rollup is a weighted ratio over summed facts, never an average of period percentages.
- **Control chart**: the per-indicator statistical process control view — a **p-chart** (weighted center line, per-period 3-sigma limits `√(p(1−p)/n)`) for proportion indicators and an **individuals (I-MR)** chart for count/ratio indicators, with center line, upper/lower control limits, and special-cause signals (a point beyond its limits, or a run of eight consecutive points on one side of the center line).
- **Source view**: the hospital-specific BMS read-only table or view that supplies a normalized THIP reporting-period result.
- **No-data contract**: the explicit null-result state used when the app has no confirmed hospital source rows; it is never a fabricated metric.
- **Registered fact branch**: the read-only aggregate SQL fragment that computes one code's numerator/denominator/value for its cadence anchor. Every one of the 232 codes resolves to exactly one branch; the original families live in `src/services/queryRegistry.ts` and the remaining 171 in the batch modules under `src/services/thipFamilies/`.
- **Foundation query**: a registered query assembled from fact branches plus a cadence-aware expected grid, for local validation against HOSxP. `thipIpdFoundation` carries every HOSxP-backed code; `thipIpdDrgResultFoundation` is an opt-in variant for sites whose coded diagnosis lives in `ipt_drg_result`.
- **External-fact staging**: the hospital-loaded aggregate table `reporting.thip_external_facts`, one row per code × reporting-period anchor, carrying `numerator`, `denominator`, `value`, and `source_system`. It is how the 55 codes whose source is outside HOSxP (population denominators, audited finance, survey instruments, device-days, custom registries) become measurable; until the hospital loads those rows, their cells stay explicit `unavailable`.
- **Implementation tier**: the classification of a code recorded in `src/data/thipImplementation.ts`. After the 232-code integration every code is `registered` (it has a fact branch), so the tier no longer distinguishes readiness; `pending-local-source` remains only for a code whose hospital rule is withdrawn pending review.
- **Rule readiness / approximation note**: the honest statement of what each branch actually measures versus what the printed definition requires. `src/data/thipRuleEvidence.ts` holds the traceable evidence (episode grain, period field, code-set version, owner, rule version) and each batch module exports its `*_APPROXIMATIONS` map per code. Nothing is `ready` until a clinical/quality owner signs it off.
- **Reporting-layer artifact**: the generated `reporting/thip_kpi_monthly.sql` (DDL for the reporting table and the external-fact staging table + per-fiscal-year refresh) that provisions the normalized source view with measured rows for HOSxP codes and explicit `unavailable` rows wherever a source or staging row is missing.
- **Complete live coverage**: all 232 catalogue codes present for every applicable reporting period of the selected fiscal year (1,552 cadence-aware cells for the 2025 dictionary), split into measured (`availableCellCount`) and explicit `unavailableCellCount`.
- **Aggregate fixture**: a synthetic, PHI-free export of the normalized source-view contract derived from the repository manifests; used only by tests, the CI audit gate, and never by a runtime path.
- **Data freshness**: the classification of the last successful refresh as fresh, stale (past the SLA), or unavailable; the UI never renders an unavailable source as a zero result.
- **BMS data boundary**: session-scoped, read-only access to HOSxP through registered queries; no arbitrary SQL from the UI.
- **PHI**: any patient-level identifier or free text (`hn`, `an`, `vn`, `cid`, names, birthdates, addresses, note text). A fact branch projects aggregates only; PHI never leaves the database.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined above. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (…), but worth reopening because…_
