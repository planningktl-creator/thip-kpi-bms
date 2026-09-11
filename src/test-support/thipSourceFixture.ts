import { thipCatalogue } from '@/data/thipCatalogue';
import { getRuleUnit, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { getExpectedFiscalMonths, getReportingCadence, reportingCadenceLabels } from '@/data/thipReporting';
import type { IndicatorDirection, IndicatorGroup, IndicatorUnit, TargetScope } from '@/types/thip';
import { getFiscalMonthPeriods } from '@/utils/fiscal';

/**
 * Deterministic, synthetic normalized source-view rows for tests and CI audit.
 *
 * This module is a test-only source of truth: it derives every row from the
 * repository manifests (`thipCatalogue`, `thipKpiRules`, `thipReporting`) so a
 * fixture cannot silently drift from the 232-code/cadence contract. It never
 * contains patient data and must never be imported from a runtime path.
 */

export const FIXTURE_FISCAL_YEAR = 2026;
export const FIXTURE_REFRESHED_AT = '2026-09-11T08:00:00Z';
export const FIXTURE_RULE_VERSION = 'fixture-2026.1';
export const FIXTURE_DENOMINATOR = 1000;
export const FIXTURE_NUMERATOR = 800;
export const FIXTURE_COUNT_VALUE = 40;
export const FIXTURE_PERCENTILE = 75;

export type FixtureRow = {
  indicator_code: string;
  period_start: string;
  fiscal_year: number;
  fiscal_month: number;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  target_scope: TargetScope;
  percentile: number | null;
  indicator_group: IndicatorGroup;
  unit: IndicatorUnit;
  direction: IndicatorDirection;
  category: string;
  title: string;
  title_th: string;
  definition: string;
  formula: string;
  numerator_label: string;
  denominator_label: string;
  source_tables: string[];
  frequency: string;
  reference: string;
  rule_version: string;
  refreshed_at: string;
};

function scaledValue(unit: IndicatorUnit, formula: string): number | null {
  if (unit === 'count') return FIXTURE_COUNT_VALUE;
  const match = formula.replace(/,/g, '').match(/[x×]\s*(\d+(?:\.\d+)?)/i);
  const multiplier = match ? Number(match[1]) : 1;
  return Number(((FIXTURE_NUMERATOR / FIXTURE_DENOMINATOR) * multiplier).toFixed(4));
}

/** Builds one synthetic, contract-valid row for a code and its reporting period. */
export function buildSourceFixtureRow(code: string, fiscalMonth: number, fiscalYear = FIXTURE_FISCAL_YEAR): FixtureRow {
  const entry = thipCatalogue.find((candidate) => candidate.code === code);
  if (!entry) throw new Error(`Fixture requested an unknown catalogue code: ${code}`);
  const rule = thipKpiRulesByCode.get(code);
  if (!rule) throw new Error(`Fixture requested a code without a rule: ${code}`);
  const cadence = getReportingCadence(code);
  const periods = getFiscalMonthPeriods(fiscalYear);
  const period = periods[fiscalMonth - 1];
  if (!period) throw new Error(`Fixture requested an invalid fiscal month ${fiscalMonth} for ${code}`);
  const unit = getRuleUnit(rule);

  return {
    indicator_code: code,
    period_start: period.periodStart,
    fiscal_year: fiscalYear,
    fiscal_month: fiscalMonth,
    numerator: unit === 'count' ? FIXTURE_COUNT_VALUE : FIXTURE_NUMERATOR,
    denominator: unit === 'count' ? null : FIXTURE_DENOMINATOR,
    value: scaledValue(unit, rule.formulaScale),
    target: null,
    target_scope: cadence === 'annual' ? 'annual' : 'monthly',
    percentile: FIXTURE_PERCENTILE,
    indicator_group: entry.group,
    unit,
    direction: 'neutral',
    category: entry.title,
    title: entry.title,
    title_th: entry.title,
    definition: `Synthetic aggregate fixture for ${code}; not a hospital result.`,
    formula: rule.formulaScale,
    numerator_label: 'synthetic numerator (fixture only)',
    denominator_label: 'synthetic denominator (fixture only)',
    source_tables: rule.candidateSourceTables.length ? [...rule.candidateSourceTables] : ['thip_kpi_monthly'],
    frequency: reportingCadenceLabels[cadence],
    reference: `THIP KPI Dictionary 2025 · หน้า ${rule.pdfPage}`,
    rule_version: FIXTURE_RULE_VERSION,
    refreshed_at: FIXTURE_REFRESHED_AT,
  };
}

/** Builds every cadence-aware cell for the fiscal year: 1,552 rows for 232 codes. */
export function buildCompleteSourceFixture(fiscalYear = FIXTURE_FISCAL_YEAR): FixtureRow[] {
  return thipCatalogue.flatMap((entry) =>
    getExpectedFiscalMonths(entry.code).map((fiscalMonth) => buildSourceFixtureRow(entry.code, fiscalMonth, fiscalYear)),
  );
}

function clone(rows: FixtureRow[]): FixtureRow[] {
  return rows.map((row) => ({ ...row, source_tables: [...row.source_tables] }));
}

/** Appends a duplicate copy of an existing code/period cell. */
export function mutateDuplicate(rows: FixtureRow[]): FixtureRow[] {
  const next = clone(rows);
  next.push({ ...next[0]!, source_tables: [...next[0]!.source_tables] });
  return next;
}

/** Adds a row whose indicator_code is not part of the 232-code catalogue. */
export function mutateUnknownCode(rows: FixtureRow[]): FixtureRow[] {
  const next = clone(rows);
  next.push({ ...next[0]!, indicator_code: 'ZZ9999', source_tables: [...next[0]!.source_tables] });
  return next;
}

/** Drops the final cadence-aware cell so the export is incomplete. */
export function mutateMissingCell(rows: FixtureRow[]): FixtureRow[] {
  return clone(rows).slice(0, -1);
}

/** Sets a non-count cell to a zero denominator while keeping a non-NULL value. */
export function mutateZeroDenominatorWithValue(rows: FixtureRow[]): FixtureRow[] {
  const next = clone(rows);
  const index = next.findIndex((row) => row.unit !== 'count');
  if (index < 0) throw new Error('Fixture has no non-count row to mutate');
  next[index] = { ...next[index]!, denominator: 0, value: 50 };
  return next;
}

/** Rewrites a formula so its multiplier conflicts with the registered rule. */
export function mutateFormulaMultiplier(rows: FixtureRow[]): FixtureRow[] {
  const next = clone(rows);
  next[0] = { ...next[0]!, formula: 'a/b x 1000000' };
  return next;
}

/** Moves a cell to a fiscal month outside the code's reporting cadence. */
export function mutateOutOfCadence(rows: FixtureRow[]): FixtureRow[] {
  const next = clone(rows);
  const index = next.findIndex((row) => row.target_scope === 'annual');
  if (index < 0) throw new Error('Fixture has no annual row to mutate');
  const periods = getFiscalMonthPeriods(FIXTURE_FISCAL_YEAR);
  next[index] = { ...next[index]!, fiscal_month: 2, period_start: periods[1]!.periodStart };
  return next;
}

export const invalidFixtureMutations = {
  duplicate: mutateDuplicate,
  'unknown-code': mutateUnknownCode,
  'missing-cell': mutateMissingCell,
  'zero-denominator-value': mutateZeroDenominatorWithValue,
  'formula-multiplier': mutateFormulaMultiplier,
  'out-of-cadence': mutateOutOfCadence,
} as const;

export type InvalidFixtureName = keyof typeof invalidFixtureMutations;
