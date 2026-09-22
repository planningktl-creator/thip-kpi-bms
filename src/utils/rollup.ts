import type { Indicator, IndicatorStatus, MonthlyResult } from '@/types/thip';
import { getFormulaScale, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { getStatus } from '@/utils/status';

/**
 * Time rollups of one indicator's reporting-period facts.
 *
 * Every rollup is computed from the measured numerator/denominator facts with
 * the same weighted semantics as the annual result (a weighted ratio over summed
 * facts, never an average of period percentages). Periods without measured
 * facts contribute nothing and are reported through `measuredCellCount`.
 */
export type PeriodRollup = {
  key: string;
  label: string;
  hint: string;
  fiscalMonths: number[];
  measuredCellCount: number;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  targetLabel: string;
  status: IndicatorStatus;
};

export type QuarterDef = {
  key: string;
  label: string;
  hint: string;
  fiscalMonths: number[];
};

export const quarterDefs: readonly QuarterDef[] = [
  { key: 'Q1', label: 'ไตรมาส 1', hint: 'ต.ค. – ธ.ค.', fiscalMonths: [1, 2, 3] },
  { key: 'Q2', label: 'ไตรมาส 2', hint: 'ม.ค. – มี.ค.', fiscalMonths: [4, 5, 6] },
  { key: 'Q3', label: 'ไตรมาส 3', hint: 'เม.ย. – มิ.ย.', fiscalMonths: [7, 8, 9] },
  { key: 'Q4', label: 'ไตรมาส 4', hint: 'ก.ค. – ก.ย.', fiscalMonths: [10, 11, 12] },
];

type Facts = {
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  measuredCellCount: number;
};

/** Weighted aggregation of measured period facts; mirrors the annual rollup. */
export function aggregateFacts(months: readonly MonthlyResult[], indicator: Indicator): Facts {
  const rule = thipKpiRulesByCode.get(indicator.code);
  const unit = indicator.unit;
  const formulaScale = getFormulaScale(rule?.formulaScale ?? indicator.formula);
  const rows = unit === 'count'
    ? months.filter((month) => month.value !== null)
    : months.filter((month) => month.value !== null && month.numerator !== null && month.denominator !== null && month.denominator !== 0);
  const numeratorRows = rows.filter((month) => month.numerator !== null);
  const denominatorRows = rows.filter((month) => month.denominator !== null);
  const numerator = numeratorRows.length === rows.length && rows.length
    ? numeratorRows.reduce((sum, month) => sum + (month.numerator ?? 0), 0)
    : null;
  const denominator = denominatorRows.length === rows.length && rows.length
    ? denominatorRows.reduce((sum, month) => sum + (month.denominator ?? 0), 0)
    : null;
  const value = unit === 'count'
    ? (rows.length ? Number(rows.reduce((sum, month) => sum + (month.value ?? 0), 0).toFixed(2)) : null)
    : numerator !== null && denominator
      ? Number(((numerator / denominator) * formulaScale).toFixed(2))
      : null;
  return { numerator, denominator, value, measuredCellCount: rows.length };
}

function buildRollup(
  indicator: Indicator,
  key: string,
  label: string,
  hint: string,
  fiscalMonths: number[],
  target: number | null,
  targetLabel: string,
): PeriodRollup {
  const months = indicator.monthly.filter((month) => fiscalMonths.includes(month.fiscalMonth));
  const facts = aggregateFacts(months, indicator);
  return {
    key,
    label,
    hint,
    fiscalMonths,
    measuredCellCount: facts.measuredCellCount,
    numerator: facts.numerator,
    denominator: facts.denominator,
    value: facts.value,
    target,
    targetLabel,
    status: getStatus(facts.value, target, indicator.direction),
  };
}

/** One row per fiscal month (only the months that carry data show a value). */
export function rollupMonths(indicator: Indicator): PeriodRollup[] {
  return indicator.monthly.map((month) => {
    const target = indicator.targetScope === 'monthly' ? month.target : null;
    const measured = month.value !== null || month.denominator !== null;
    return {
      key: `M${month.fiscalMonth}`,
      label: month.label,
      hint: `งวดที่ ${month.fiscalMonth}`,
      fiscalMonths: [month.fiscalMonth],
      measuredCellCount: measured ? 1 : 0,
      numerator: month.numerator,
      denominator: month.denominator,
      value: month.value,
      target,
      targetLabel: indicator.targetScope === 'monthly' ? 'เป้าหมายรายเดือน' : 'เป้าหมายทั้งปี',
      status: month.value === null ? 'no-data' : getStatus(month.value, target, indicator.direction),
    };
  });
}

/** One row per fiscal quarter (Q1 = ต.ค.–ธ.ค. … Q4 = ก.ค.–ก.ย.), weighted. */
export function rollupQuarters(indicator: Indicator): PeriodRollup[] {
  const monthlyTarget = indicator.targetScope === 'monthly'
    ? indicator.monthly.find((month) => month.target !== null)?.target ?? null
    : null;
  const target = indicator.targetScope === 'monthly' ? monthlyTarget : indicator.annual.target;
  const targetLabel = indicator.targetScope === 'monthly' ? 'เป้าหมายรายเดือน' : 'เทียบเป้าหมายทั้งปี';
  return quarterDefs.map((quarter) =>
    buildRollup(indicator, quarter.key, quarter.label, quarter.hint, [...quarter.fiscalMonths], target, targetLabel),
  );
}

/** The single fiscal-year row (weighted over every measured period). */
export function rollupAnnual(indicator: Indicator): PeriodRollup {
  const allMonths = indicator.monthly.map((month) => month.fiscalMonth);
  const facts = aggregateFacts(indicator.monthly, indicator);
  return {
    key: 'FY',
    label: 'ทั้งปีงบประมาณ',
    hint: 'ต.ค. – ก.ย.',
    fiscalMonths: allMonths,
    measuredCellCount: facts.measuredCellCount,
    numerator: facts.numerator,
    denominator: facts.denominator,
    value: facts.value,
    target: indicator.annual.target,
    targetLabel: 'เป้าหมายทั้งปี',
    status: getStatus(facts.value, indicator.annual.target, indicator.direction),
  };
}
