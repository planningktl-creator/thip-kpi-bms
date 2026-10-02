import type { MonitoringAssessment, MonitoringCumulative, MonitoringRule, MonthlyMonitoringResult } from './types';

export function assessMonitoring(row: Pick<MonthlyMonitoringResult, 'dataStatus' | 'value' | 'target' | 'unit' | 'periodStart' | 'periodEnd'>, rule: MonitoringRule): MonitoringAssessment {
  if (row.dataStatus !== 'measured' || row.value === null) return 'not-assessable';
  const target = row.target;
  if (!target || target.unit !== row.unit || !target.mappingConfirmed || !target.source.trim() || target.validFrom > row.periodStart || target.validTo < row.periodEnd) return 'no-target';
  const value = row.value;
  if (rule.direction === 'range') {
    if (target.lower === null || target.upper === null) return 'no-target';
    if (value >= target.lower && value <= target.upper) return 'on-track';
    const distance = value < target.lower ? target.lower - value : value - target.upper;
    return rule.watchMargin !== null && distance <= rule.watchMargin ? 'watch' : 'action';
  }
  if (target.value === null || rule.direction === 'neutral') return 'no-target';
  if (rule.direction === 'higher-is-better' ? value >= target.value : value <= target.value) return 'on-track';
  // Explicit system criterion, never a dictionary benchmark.
  const margin = rule.watchMargin ?? Math.max(Math.abs(target.value) * .08, .02);
  return Math.abs(value - target.value) <= margin ? 'watch' : 'action';
}

/** Distinct cohorts/custom formula aggregates must be supplied by the source. */
export function accumulateMonitoring(rows: readonly MonthlyMonitoringResult[], rule: MonitoringRule): MonitoringCumulative {
  const last = rows.at(-1);
  const empty: MonitoringCumulative = { numerator: null, denominator: null, value: null, through: null, complete: false };
  if (!last) return empty;
  if (rule.accumulation === 'distinct-cohort' || rule.accumulation === 'custom') return last.cumulative;
  if (rule.accumulation === 'snapshot') return { numerator: last.numerator, denominator: last.denominator, value: last.value, through: last.dataThrough, complete: last.dataStatus === 'measured' };
  // A partial YTD is not quietly reported as the complete YTD.
  if (rows.some((row) => !['measured', 'zero-cohort'].includes(row.dataStatus))) return empty;
  const sum = (field: 'numerator' | 'denominator' | 'value') => rows.every((row) => row[field] !== null) ? rows.reduce((total, row) => total + row[field]!, 0) : null;
  const numerator = sum('numerator');
  const denominator = rule.accumulation === 'fixed-denominator'
    ? rows.every((row) => row.denominator === last.denominator) ? last.denominator : null
    : sum('denominator');
  const value = rule.accumulation === 'sum' || rule.accumulation === 'count' ? sum('value') : numerator !== null && denominator !== null && denominator > 0 ? numerator / denominator * rule.scale : null;
  return { numerator, denominator, value, through: last.dataThrough, complete: value !== null };
}
