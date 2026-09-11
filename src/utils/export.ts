import type { FiscalYear, Indicator } from '@/types/thip';
import { toBuddhistYear } from '@/utils/fiscal';

function escapeCsv(value: string | number | null): string {
  if (value === null) return '';
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

export function exportIndicatorCsv(indicator: Indicator): void {
  const header = ['indicator_code', 'fiscal_year_be', 'fiscal_month', 'month_label_be', 'numerator', 'denominator', 'value', 'target_scope', 'monthly_target', 'annual_target', 'status'];
  const rows = indicator.monthly.map((month) => [
    indicator.code,
    toBuddhistYear(month.fiscalYear),
    month.fiscalMonth,
    month.label,
    month.numerator,
    month.denominator,
    month.value,
    indicator.targetScope,
    month.target,
    indicator.annual.target,
    month.status,
  ]);
  const csv = [header, ...rows].map((row) => row.map(escapeCsv).join(',')).join('\n');
  const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `${indicator.code}-monthly.csv`;
  anchor.click();
  URL.revokeObjectURL(url);
}

/**
 * Exports only aggregate reporting-period rows for the supplied indicators.
 * It never includes patient-level fields, and it skips indicators that have no
 * real result so a no-data code is not written as a zero.
 */
export function exportAggregateCsv(indicators: Indicator[], fiscalYear: FiscalYear): void {
  const header = ['indicator_code', 'indicator_group', 'fiscal_year_be', 'fiscal_month', 'period_start', 'numerator', 'denominator', 'value', 'target', 'percentile', 'status', 'rule_reference'];
  const rows = indicators
    .filter((indicator) => indicator.dataSource === 'bms')
    .flatMap((indicator) => indicator.monthly
      .filter((month) => month.value !== null || month.denominator !== null)
      .map((month) => [
        indicator.code,
        indicator.group,
        toBuddhistYear(month.fiscalYear),
        month.fiscalMonth,
        month.periodStart,
        month.numerator,
        month.denominator,
        month.value,
        indicator.targetScope === 'monthly' ? month.target : indicator.annual.target,
        month.percentile,
        month.status,
        indicator.reference,
      ]));
  const csv = [header, ...rows].map((row) => row.map(escapeCsv).join(',')).join('\n');
  const blob = new Blob([`\uFEFF${csv}`], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `thip-kpi-aggregate-${fiscalYear}.csv`;
  anchor.click();
  URL.revokeObjectURL(url);
}
