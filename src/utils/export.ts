import type { Indicator } from '@/types/thip';

function escapeCsv(value: string | number | null): string {
  if (value === null) return '';
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

export function exportIndicatorCsv(indicator: Indicator): void {
  const header = ['indicator_code', 'fiscal_month', 'month_label', 'numerator', 'denominator', 'value', 'target', 'status'];
  const rows = indicator.monthly.map((month) => [
    indicator.code,
    month.fiscalMonth,
    month.label,
    month.numerator,
    month.denominator,
    month.value,
    month.target,
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
