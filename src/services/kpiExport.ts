import { escapeCsv } from '@/utils/export';
import {
  formatThaiDate,
  formatThaiDateTime,
  toBuddhistYear,
} from '@/utils/fiscal';
import type { KpiGridRow, KpiMode, KpiSeries } from './kpiTypes';
import { runtimeMonitoringRules } from '@/data/thipRuntime';
const rules = new Map(runtimeMonitoringRules.map((rule) => [rule.code, rule]));
export function sharedKpiCsv(
  rows: readonly KpiGridRow[],
  fiscalYear: number,
  series: KpiSeries,
  mode: KpiMode
): string {
  const header = [
    'series',
    'data_label',
    'code',
    'fiscal_year_be',
    'fiscal_month',
    'period_start_iso',
    'period_end_exclusive_iso',
    'period_start_be',
    'period_end_exclusive_be',
    'value',
    'numerator',
    'denominator',
    'derived_comparison',
    'arithmetic_discrepancy',
    'unit',
    'data_status',
    'approval',
    'assessment',
    'target',
    'target_lower',
    'target_upper',
    'target_source',
    'ytd_value',
    'ytd_numerator',
    'ytd_denominator',
    'ytd_complete',
    'accumulation',
    'formula',
    'method',
    'rule_version',
    'lineage',
    'reason',
    'origin',
    'observed_at_iso',
    'observed_at_be',
    'source_refreshed_at_iso',
    'source_refreshed_at_be',
    'data_through_iso',
    'data_through_be',
    'cache_expires_at_be',
  ];
  const data = rows.flatMap((row) =>
    row.cells
      .filter(
        (cell) =>
          series === 'monthly-monitoring' || cell.status !== 'not-applicable'
      )
      .map((cell) => {
        if (
          cell.fiscalYear !== fiscalYear ||
          cell.series !== series ||
          (mode === 'approved' &&
            cell.value !== null &&
            cell.approval !== 'approved')
        )
          throw new Error('KPI export context/approval mismatch');
        const rule = rules.get(cell.code)!;
        return [
          series,
          mode === 'review'
            ? 'ข้อมูลสอบทาน — ยังไม่รับรอง / UNAPPROVED REVIEW'
            : 'ผลที่ผ่าน publication gate',
          cell.code,
          toBuddhistYear(fiscalYear),
          cell.fiscalMonth,
          cell.periodStart,
          cell.periodEnd,
          formatThaiDate(cell.periodStart),
          formatThaiDate(cell.periodEnd),
          cell.value,
          cell.numerator,
          cell.denominator,
          cell.derivedValue,
          cell.discrepancy,
          cell.unit,
          cell.status,
          cell.approval,
          cell.assessment,
          cell.target?.value,
          cell.target?.lower,
          cell.target?.upper,
          cell.target?.source,
          cell.cumulative.value,
          cell.cumulative.numerator,
          cell.cumulative.denominator,
          cell.cumulative.complete,
          cell.accumulation,
          cell.formula,
          cell.method,
          cell.ruleVersion,
          cell.lineage,
          cell.reason,
          cell.origin,
          cell.observedAt,
          cell.observedAt ? formatThaiDateTime(cell.observedAt) : null,
          cell.refreshedAt,
          cell.refreshedAt ? formatThaiDateTime(cell.refreshedAt) : null,
          cell.dataThrough,
          cell.dataThrough ? formatThaiDate(cell.dataThrough) : null,
          cell.expiresAt ? formatThaiDateTime(cell.expiresAt) : null,
        ];
      })
  );
  return (
    '\uFEFF' +
    [header, ...data]
      .map((row) =>
        row
          .map((value) =>
            escapeCsv(
              typeof value === 'boolean' ? String(value) : (value ?? null)
            )
          )
          .join(',')
      )
      .join('\r\n')
  );
}
export function downloadSharedKpiCsv(
  rows: readonly KpiGridRow[],
  year: number,
  series: KpiSeries,
  mode: KpiMode
) {
  const url = URL.createObjectURL(
    new Blob([sharedKpiCsv(rows, year, series, mode)], {
      type: 'text/csv;charset=utf-8',
    })
  );
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `${series}-${toBuddhistYear(year)}-${mode === 'review' ? 'unapproved-review' : 'approved'}.csv`;
  anchor.click();
  URL.revokeObjectURL(url);
}
