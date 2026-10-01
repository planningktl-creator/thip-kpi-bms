# THIP data contract

This document describes the official THIP reporting series (232 codes / 1,552 cadence cells). The separate 232×12 monitoring series is specified in [THIP-MONITORING-CONTRACT.md](THIP-MONITORING-CONTRACT.md). `Indicator.monthly` retains its reporting-period meaning. SQL registration and structural completeness do not authorize publication.

The separate [Step validation page](THIP-STEP-LOADING.md) consumes seven-column candidates from registered per-code queries with progress/pause/resume/cancel. It never feeds candidate facts into official screens/export, and does not weaken this strict normalized source or publication contract. `observedAt` is query observation time; unknown source freshness remains NULL. Production Docker builds may include this page without source-view configuration; official runtime gates still apply.

Its [24-hour browser cache](THIP-CANDIDATE-CACHE.md) stores only validated aggregate projections after successful queries. Cache reads require a verified PostgreSQL session and matching context/query/rule versions. Cached candidates retain unapproved status and do not become official reporting or monitoring measurements.

## Indicator

```ts
type Indicator = {
  code: string;
  fiscalYear: number; // ISO-side fiscal-year key; 2026 displays as ปีงบประมาณ 2569
  group: 'D' | 'C' | 'S' | 'H' | 'A';
  category: string;
  title: string;
  titleTh: string;
  unit: 'percent' | 'rate' | 'ratio' | 'count';
  direction: 'higher-is-better' | 'lower-is-better' | 'neutral';
  target: number | null;
  targetScope: 'monthly' | 'annual';
  annual: AnnualResult;
  monthly: MonthlyResult[];
};
```

## Reporting-period result

Each row is one reported fiscal period. Monthly indicators use all twelve fiscal months; quarterly indicators use fiscal-month starts 1, 4, 7, 10; semiannual indicators use 1, 7; annual indicators use 1. `numerator` and `denominator` are preserved as source facts; `value` is derived from them and is null when the denominator is zero or unavailable. The frontend still renders a twelve-slot fiscal-year timeline, leaving non-applicable slots empty. The TypeScript name `MonthlyResult` is retained for UI compatibility, but it represents a reporting period rather than asserting that every KPI is monthly.

The dashboard month selector is a display boundary, not a request to invent a result: for a non-monthly KPI, the overview selects the latest applicable reporting period at or before the selected fiscal month. The detail page and CSV keep the original fiscal period of every source row.

```ts
type MonthlyResult = {
  periodStart: string; // ISO YYYY-MM-01 from the database boundary
  fiscalYear: number;
  fiscalMonth: number;
  label: string; // Thai Buddhist Era display label, e.g. ต.ค. 2568
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  percentile: number | null;
  status: 'on-track' | 'watch' | 'action' | 'no-data' | 'unbenchmarked';
};
```

`AnnualResult` preserves the fiscal-year rollup separately from the twelve monthly rows. The annual result can carry an annual target even when a KPI has no monthly target line.

When `target_scope` is `monthly`, the frontend keeps targets on their own reporting periods and does not promote one monthly target to the annual rollup. The annual result remains unbenchmarked unless the source explicitly supplies an annual target.

```ts
type AnnualResult = {
  fiscalYear: number;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  status: 'on-track' | 'watch' | 'action' | 'no-data' | 'unbenchmarked';
};
```

## Fiscal year and display boundary

The BMS/database boundary keeps ISO dates such as `2025-10-01`. The frontend must not expose that Gregorian date as a user-facing month/year: `src/utils/fiscal.ts` maps the October–September fiscal year to Thai Buddhist Era labels, so `2025-10-01` appears as `ต.ค. 2568` and fiscal-year key `2026` appears as `ปีงบประมาณ 2569`. CSV export uses `fiscal_year_be` and `month_label_be` for the same reason.

All operational dates in monitoring drill-through, Step validation, cohort profiles and refresh/cache metadata use the shared Buddhist Era formatters. Date-only ISO fields display as `1 ต.ค. พ.ศ. 2568` without timezone conversion. Offset-qualified timestamps and cache epoch milliseconds display with an explicit Buddhist calendar and `Asia/Bangkok`, regardless of the computer's timezone; invalid/ambiguous dates display `—`. Database, query parameters, validators and cache continue using Gregorian ISO dates. Rule versions and verbatim source references remain unchanged identifiers.

Aggregate CSV filenames use the Buddhist fiscal year. Aggregate and monitoring CSVs retain their original ISO machine columns for compatibility and add corresponding `_be` display columns (including monitoring target intervals, cutoff, cumulative cutoff and refresh). Missing dates remain empty fields; Buddhist years are never written into ISO machine columns.

## Source catalogue

`src/data/thipCatalogue.ts` contains the 232 indicator definitions extracted from the THIP KPI Dictionary 2025. `src/data/thipReporting.ts` records the dictionary reporting cadence for every code. A catalogue entry is enough to navigate to a detail route, but it is not evidence that the hospital has a queryable result. Until an entry is mapped to a registered read-only source view, `createNoDataIndicator()` returns twelve display slots with null numerator, denominator, value, target, and percentile fields.

## Live query requirements

Before enabling live data, confirm:

1. Source table/view and refresh timestamp.
2. One row per applicable `indicator_code x fiscal_year x fiscal_month` reporting period, according to `src/data/thipReporting.ts`.
3. Numerator/denominator definition and ICD/procedure inclusion lists.
4. Missing, suppressed, and zero-denominator semantics.
5. Hospital/group benchmark source and percentile freshness.
6. PHI masking and export limits.

The UI should receive a normalized domain object, not raw HOSxP rows.

## Normalized source view contract

Set `VITE_BMS_KPI_SOURCE_VIEW` to a registered read-only table or view when the hospital has a normalized result source. It must expose one row per applicable `indicator_code x fiscal_year x fiscal_month` reporting period and at least these columns:

```text
indicator_code, period_start, fiscal_year, fiscal_month,
numerator, denominator, value, target, target_scope, percentile,
indicator_group, unit, direction, category, title, title_th,
definition, formula, numerator_label, denominator_label,
source_tables, frequency, reference,
rule_version, pending_reason, tier, refreshed_at
```

`period_start` is the ISO first day of the month. `numerator` and `denominator` remain source facts; `value` is optional when the frontend can derive it from the unit. The app rejects duplicate indicator/month rows and unknown indicator codes rather than silently aggregating them.

`tier=registered` means an aggregate SQL branch exists, not that hospital owners certified the measure. `pending-local-source` requires NULL facts and a non-empty `pending_reason`. Missing external staging rows likewise remain unavailable; populated external aggregates are retained. Structural `complete` requires all 1,552 unique cadence cells; `availableCellCount` counts publishable measured cells after approval. Target/percentile-only rows are not measurements. DDL/refresh artifacts are generated by `pnpm sourceview:build`; the frontend never executes them.

The BMS loader reports covered/available/unavailable cells, measured indicators, expected 232 codes / 1,552 cells (`112×12 + 19×4 + 31×2 + 70×1`), unexpected cells and structural `complete`. Production rejects an incomplete source response. A complete response containing only unavailable facts has 0% measurement coverage and is not labelled live. Missing periods remain no-data; values without approved targets are unbenchmarked.

For a configured source view, each returned row must also carry the descriptive metadata in the contract (`indicator_group`, `unit`, `direction`, `target_scope`, `category`, `title`, `definition`, `formula`, numerator/denominator labels, `source_tables`, `frequency`, `reference`, `rule_version`, and `refreshed_at`). Descriptive metadata must be stable for all periods of one indicator; period-specific fields are limited to the measured facts, target, percentile, and period key. If percentile is supplied it must be between 0 and 100. The adapter fails closed when one of these fields is missing or invalid instead of silently applying a generic percent/neutral fallback. Numeric facts are validated, the formula multiplier must agree with the registered rule manifest, and a non-NULL `value` with a zero or missing denominator is rejected for non-count units. An explicit `target = NULL` remains NULL for that reporting period; it is not carried forward from another period or replaced by a frontend seed. `refreshed_at` is shown as the data refresh time; the browser load time is not used as a substitute when the source timestamp is present.

## Production completeness gate

Production requires configured reporting data boundaries and rejects incomplete/invalid cadence responses. Targets are never seeded from dictionary benchmarks. The preferred complete source is `VITE_BMS_KPI_SOURCE_VIEW`; any foundation validation path retains full observation windows and partitions by code only. A refused single-code query returns unavailable with `query-budget-exceeded: full observation window retained`, rather than using unproved date slicing.

`publishApprovedThip()` gates screens/export separately from adapter validation. Every code requires evidence readiness and `publicationApproval` with non-empty evidence, matching source/rule version, and effective interval covering the fiscal year. All current real approvals are absent. `hospitalTargetApproval` separately confirms target source/unit/effectivity; absent approval strips targets. Code completeness remains visible even while facts are withheld. A future approval must be reviewed against the hospital report; fixture success alone does not certify formulas.

Quarter target rollups retain a target only when all included period targets are present and identical; changed/missing monthly targets or an annual-only target do not become a quarter target. p-chart proportion calculations apply only to percent/rate units; a point equal to the center line resets an eight-point run.

When the source-view variable is empty during local development, the app uses the initial HOSxP foundation query for `DH0101`, `DH0101.1`, `DH0101.2`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, `DN0109`, and `DN0302`. That query is limited to the definitions confirmed in the supplied THIP dictionary and is not a substitute for the remaining hospital-specific KPI rules.

## Derived dashboard summaries

The dashboard may show a target-attainment summary, but it is not an additional THIP KPI and it is never sourced from a demo constant. It is the arithmetic mean of each visible KPI's real reporting-period result converted to a 0–100 attainment score against its approved target and direction. Indicators with no value, no target, or a neutral direction are excluded; the UI does not assign them a score.

Launcher credentials are transient capabilities. The app removes `bms-session-id` and marketplace tokens from the URL before the PasteJSON request, keeps them only in page memory for retry after a transient transport failure, and discards them after an explicit session rejection. They are not persisted or logged.

Transport deadlines cover fetch and response-body parsing and respond to cancellation. Year changes discard old data/coverage immediately; stale requests cannot replace the selected year's snapshot or enable export. Nginx access logs use method/URI path/status without query strings, Referer or headers; HTTP error logging is disabled to avoid raw capability-bearing request lines. Safe access logs and health checks remain available. CSV escapes formula-like text while retaining typed numeric values.
## Cohort profiles and rule evidence (2026-10-01)

Validation-only `cohort-profile` aggregates have an independent contract and cache namespace, documented in [THIP-COHORT-PROFILES.md](THIP-COHORT-PROFILES.md). Six registered SELECTs return only profile_key/metric_key/count_value, share the single-request Step lane, and never populate reporting or monitoring. Current registry snapshots are labelled at read time; monthly service/admission/headcount cohorts preserve their own dates and units. `CohortDefinition` evidence covers all 232 codes; structural mapping cannot satisfy publication approval or hospital readiness. Generated human/machine mapping and profile manifests are checked with `pnpm cohorts:check`.

## Runtime performance boundary (2026-10-02)

Session probing and transport/read-only checks live in `queryTransport.ts` without importing the full SQL registry. The compatibility exports from `queryRegistry.ts` retain the same API and BMS HTTP payload. Monitoring startup uses generated catalogue/rules/readiness metadata; reporting adapters, charts and validation load when their route opens. Dictionary/cohort detail evidence is generated in 29 family modules and fetched on demand in validation. Canonical dictionary and rich evidence remain available to build/audit tools and the official reporting adapter; they are excluded from monitoring startup.

`pnpm runtime:check` verifies all 232 rule records, 177 SQL/rule fingerprints and family evidence against canonical sources. The rule hash includes full cohort evidence even though the compact runtime record omits it. No generation or cache lookup grants publication approval.

Single-code foundation queries include only the registered CTE dependency closure recorded in `reporting/thip_step_queries.manifest.json`. They retain full fiscal-year parameters, facts, cadence grid, aggregates and NULL semantics. Synthetic PostgreSQL equivalence covers six representative branches; new query syntax/dependencies require review and generated checks. No date splitting or hospital index creation is introduced.

In-memory performance diagnostics retain at most 256 numeric duration/outcome samples with internal keys. They contain no URL, SQL parameters, credentials or measured values and are not sent to an analytics endpoint. Cache schema v2 and readonly progress references are described in [candidate cache](THIP-CANDIDATE-CACHE.md). Benchmark limits, reproduction and external acceptance still required are documented in [performance report](THIP-PERFORMANCE-2026-10-02.md).
