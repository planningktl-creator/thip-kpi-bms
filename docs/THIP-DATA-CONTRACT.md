# THIP data contract

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
rule_version, refreshed_at
```

`period_start` is the ISO first day of the month. `numerator` and `denominator` remain source facts; `value` is optional when the frontend can derive it from the unit. The app rejects duplicate indicator/month rows and unknown indicator codes rather than silently aggregating them.

The BMS loader also reports coverage counts: live indicator count, covered reporting cells, expected 232 indicators, expected 1,552 cadence-aware cells (`112×12 + 19×4 + 31×2 + 70×1`), unexpected-cell count, and a boolean `complete`. Local development uses `complete` for the `live` label and can show a smaller response as `partial`; production rejects a smaller response. Missing reporting periods remain `no-data`, while a measured value without an approved benchmark is `unbenchmarked` and is not presented as “on target”.

For a configured source view, each returned row must also carry the descriptive metadata in the contract (`indicator_group`, `unit`, `direction`, `target_scope`, `category`, `title`, `definition`, `formula`, numerator/denominator labels, `source_tables`, `frequency`, `reference`, `rule_version`, and `refreshed_at`). Descriptive metadata must be stable for all periods of one indicator; period-specific fields are limited to the measured facts, target, percentile, and period key. If percentile is supplied it must be between 0 and 100. The adapter fails closed when one of these fields is missing or invalid instead of silently applying a generic percent/neutral fallback. Numeric facts are validated, the formula multiplier must agree with the registered rule manifest, and a non-NULL `value` with a zero or missing denominator is rejected for non-count units. An explicit `target = NULL` remains NULL for that reporting period; it is not carried forward from another period or replaced by a frontend seed. `refreshed_at` is shown as the data refresh time; the browser load time is not used as a substitute when the source timestamp is present.

## Production completeness gate

The production Docker image fails at build time when `VITE_BMS_KPI_SOURCE_VIEW` is empty, and the browser runtime fails closed as a second guard. A production source view is accepted as complete only when it returns every catalogue code for every applicable reporting period of the selected fiscal year (1,552 unique code/period cells). A response with fewer cells or a row outside the code's reporting cadence is rejected as a data error in production; local development may opt into the visible `partial` state while a source view is being assembled. Targets are not seeded in the frontend: `target` and `target_scope` must come from the approved reporting source, and an explicit `target = NULL` stays unknown rather than being replaced by a benchmark guess. Local Vite development may omit the source-view variable to exercise the registered 16-indicator HOSxP foundation query, but that path is not a production substitute for the complete source view.

When the source-view variable is empty during local development, the app uses the initial HOSxP foundation query for `DH0101`, `DH0101.1`, `DH0101.2`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, `DN0109`, and `DN0302`. That query is limited to the definitions confirmed in the supplied THIP dictionary and is not a substitute for the remaining hospital-specific KPI rules.

## Derived dashboard summaries

The dashboard may show a target-attainment summary, but it is not an additional THIP KPI and it is never sourced from a demo constant. It is the arithmetic mean of each visible KPI's real reporting-period result converted to a 0–100 attainment score against its approved target and direction. Indicators with no value, no target, or a neutral direction are excluded; the UI does not assign them a score.

Launcher credentials are transient capabilities. The app removes `bms-session-id` and marketplace tokens from the URL before the PasteJSON request, keeps them only in page memory for retry after a transient transport failure, and discards them after an explicit session rejection. They are not persisted or logged.
