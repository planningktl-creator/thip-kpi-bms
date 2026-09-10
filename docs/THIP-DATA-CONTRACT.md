# THIP data contract

## Indicator

```ts
type Indicator = {
  code: string;
  group: 'D' | 'C' | 'S' | 'H' | 'A';
  category: string;
  title: string;
  titleTh: string;
  unit: 'percent' | 'rate' | 'ratio' | 'count';
  direction: 'higher-is-better' | 'lower-is-better' | 'neutral';
  monthly: MonthlyResult[];
};
```

## Monthly result

Each row is one fiscal month. `numerator` and `denominator` are preserved as source facts; `value` is derived from them and is null when the denominator is zero or unavailable.

```ts
type MonthlyResult = {
  fiscalMonth: number;
  label: string;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  percentile: number | null;
  status: 'on-track' | 'watch' | 'action' | 'no-data';
};
```

## Source catalogue

`src/data/thipCatalogue.ts` contains the 232 indicator definitions extracted from the THIP KPI Dictionary 2025. A catalogue entry is enough to navigate to a detail route, but it is not evidence that the hospital has a queryable result. Until an entry is mapped to a registered read-only source view, `createNoDataIndicator()` returns twelve monthly rows with null numerator, denominator, value, target, and percentile fields.

## Live query requirements

Before replacing demo data, confirm:

1. Source table/view and refresh timestamp.
2. One row per `indicator_code x fiscal_month`.
3. Numerator/denominator definition and ICD/procedure inclusion lists.
4. Missing, suppressed, and zero-denominator semantics.
5. Hospital/group benchmark source and percentile freshness.
6. PHI masking and export limits.

The UI should receive a normalized domain object, not raw HOSxP rows.
