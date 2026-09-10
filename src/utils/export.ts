import type { Indicator } from '@/types/thip';
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
