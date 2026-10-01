import { escapeCsv } from '@/utils/export';
import { toBuddhistYear } from '@/utils/fiscal';
import type { MonitoringLoadResult, MonthlyMonitoringResult } from './types';

export function monitoringCsv(snapshot: MonitoringLoadResult, rows: readonly MonthlyMonitoringResult[], fiscalYear: number): string {
  if (snapshot.fiscalYear !== fiscalYear || rows.some((row) => row.fiscalYear !== fiscalYear)) throw new Error('Monitoring export snapshot year mismatch');
  const header = ['series', 'data_label', 'code', 'fiscal_year', 'fiscal_year_be', 'fiscal_month', 'period_start', 'period_end_exclusive', 'data_through', 'numerator', 'denominator', 'value', 'unit', 'target', 'target_lower', 'target_upper', 'target_source', 'target_valid_from', 'target_valid_to', 'ytd_numerator', 'ytd_denominator', 'ytd_value', 'ytd_through', 'ytd_complete', 'accumulation', 'formula', 'method', 'data_status', 'assessment', 'reason', 'rule_version', 'refreshed_at'];
  const data = rows.map((row) => [snapshot.series, snapshot.preview ? 'ข้อมูลสังเคราะห์ / SYNTHETIC DEVELOPMENT PREVIEW' : 'ผลติดตามรายเดือน', row.code, fiscalYear, toBuddhistYear(fiscalYear), row.fiscalMonth, row.periodStart, row.periodEnd, row.dataThrough, row.numerator, row.denominator, row.value, row.unit, row.target?.value ?? null, row.target?.lower ?? null, row.target?.upper ?? null, row.target?.source ?? null, row.target?.validFrom ?? null, row.target?.validTo ?? null, row.cumulative.numerator, row.cumulative.denominator, row.cumulative.value, row.cumulative.through, row.cumulative.complete ? 'true' : 'false', row.accumulation, row.formula, row.method, row.dataStatus, row.assessment, row.reason, row.ruleVersion, row.refreshedAt]);
  return '\uFEFF' + [header, ...data].map((row) => row.map(escapeCsv).join(',')).join('\r\n');
}
export function downloadMonitoringCsv(snapshot: MonitoringLoadResult, rows: MonthlyMonitoringResult[], fiscalYear: number): void {
  const url = URL.createObjectURL(new Blob([monitoringCsv(snapshot, rows, fiscalYear)], { type: 'text/csv;charset=utf-8' }));
  const anchor = document.createElement('a'); anchor.href = url;
  anchor.download = `thip-monthly-monitoring-${toBuddhistYear(fiscalYear)}${snapshot.preview ? '-synthetic-preview' : ''}.csv`;
  anchor.click(); URL.revokeObjectURL(url);
}
