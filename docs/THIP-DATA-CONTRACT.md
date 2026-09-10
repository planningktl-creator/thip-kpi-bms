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

## Monthly result

Each row is one fiscal month. `numerator` and `denominator` are preserved as source facts; `value` is derived from them and is null when the denominator is zero or unavailable.

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
  status: 'on-track' | 'watch' | 'action' | 'no-data';
};
```

`AnnualResult` preserves the fiscal-year rollup separately from the twelve monthly rows. The annual result can carry an annual target even when a KPI has no monthly target line.

```ts
type AnnualResult = {
  fiscalYear: number;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  status: 'on-track' | 'watch' | 'action' | 'no-data';
};
```

## Fiscal year and display boundary

The BMS/database boundary keeps ISO dates such as `2025-10-01`. The frontend must not expose that Gregorian date as a user-facing month/year: `src/utils/fiscal.ts` maps the October–September fiscal year to Thai Buddhist Era labels, so `2025-10-01` appears as `ต.ค. 2568` and fiscal-year key `2026` appears as `ปีงบประมาณ 2569`. CSV export uses `fiscal_year_be` and `month_label_be` for the same reason.

## Source catalogue

`src/data/thipCatalogue.ts` contains the 232 indicator definitions extracted from the THIP KPI Dictionary 2025. A catalogue entry is enough to navigate to a detail route, but it is not evidence that the hospital has a queryable result. Until an entry is mapped to a registered read-only source view, `createNoDataIndicator()` returns twelve monthly rows with null numerator, denominator, value, target, and percentile fields.

## Live query requirements

Before replacing demo data, confirm:

1. Source table/view and refresh timestamp.
2. One row per `indicator_code x fiscal_year x fiscal_month`.
3. Numerator/denominator definition and ICD/procedure inclusion lists.
4. Missing, suppressed, and zero-denominator semantics.
5. Hospital/group benchmark source and percentile freshness.
6. PHI masking and export limits.

The UI should receive a normalized domain object, not raw HOSxP rows.
