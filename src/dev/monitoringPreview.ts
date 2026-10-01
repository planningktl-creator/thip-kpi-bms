// SYNTHETIC_MONITORING_FIXTURE_ONLY: dynamically imported only in development.
import { monitoringRules } from '@/monitoring/rules';
import { unavailableCell } from '@/monitoring/contract';
import { accumulateMonitoring, assessMonitoring } from '@/monitoring/calculation';
import { bangkokDate } from '@/utils/fiscal';
import type { MonitoringProvider, MonitoringRule, MonthlyMonitoringResult } from '@/monitoring/types';

const methods: Record<string, MonitoringRule['accumulation']> = {
  DH0101: 'weighted-ratio', DH0112: 'weighted-ratio', CE0102: 'weighted-ratio',
  HH0102: 'distinct-cohort', SH0101: 'custom', SM0201: 'snapshot', DE1601: 'distinct-cohort',
};
export function createPreviewProvider(now = new Date()): MonitoringProvider {
  const rules = new Map(monitoringRules.map((rule) => [rule.code, methods[rule.code] ? {
    ...rule, approval: 'synthetic' as const, version: 'synthetic-preview-1',
    accumulation: methods[rule.code],
    direction: rule.code === 'SM0201' ? 'range' as const : rule.direction,
    formula: rule.code === 'SH0101' ? 'PREVIEW ONLY: ผู้ลาออกเดือนนี้ / บุคลากรสิ้นเดือน × 100; ไม่ใช่สูตร THIP รายปี' : rule.formula,
    method: rule.code === 'SH0101' ? 'PREVIEW ONLY: สะสมผู้ลาออก / ค่าเฉลี่ย headcount รายเดือน จาก source aggregate; ต้องรับรองแยก' : `${rule.method} · approval จำลองสำหรับข้อมูลสังเคราะห์เท่านั้น`,
  } : rule]));
  return { preview: true, rules, async load(fiscalYear, signal) {
    if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
    const today = bangkokDate(now);
    const rows: MonthlyMonitoringResult[] = [];
    for (const rule of rules.values()) {
      const codeRows: MonthlyMonitoringResult[] = [];
      for (let month = 1; month <= 12; month++) {
        let row = unavailableCell(rule, fiscalYear, month, now, true);
        if (rule.approval === 'synthetic' && row.dataStatus !== 'future') {
          const denominator = rule.code === 'SM0201' ? 100000 : 100 + month * 5;
          const numerator = rule.code === 'DH0101' ? month % 3 + 2 : rule.code === 'DH0112' ? denominator * (4 + month % 3) : rule.code === 'CE0102' ? denominator * (55 + month * 4) : rule.code === 'SM0201' ? denominator * (.8 + month * .1) : rule.code === 'SH0101' ? month % 4 + 1 : denominator - month % 5;
          const through = row.periodEnd <= today ? new Date(Date.parse(row.periodEnd) - 86400000).toISOString().slice(0, 10) : today;
          row = { ...row, numerator, denominator, value: numerator / denominator * rule.scale,
            dataStatus: 'measured', dataThrough: through, refreshedAt: now.toISOString(), reason: null,
            target: month === 2 ? null : { value: rule.code === 'DH0101' ? 2.5 : rule.code === 'DH0112' ? 5 : rule.code === 'CE0102' ? 85 : rule.code === 'SH0101' ? 2 : 97,
              lower: rule.code === 'SM0201' ? .9 : null, upper: rule.code === 'SM0201' ? 1.4 : null,
              kind: 'hospital', unit: rule.unit, source: 'เป้าหมายจำลอง SYNTHETIC_MONITORING_FIXTURE_ONLY', mappingConfirmed: true, validFrom: row.periodStart, validTo: row.periodEnd },
          };
          if (month === 4) row = { ...row, numerator: 0, denominator: 0, value: null, dataStatus: 'zero-cohort', reason: 'aggregate จำลองยืนยันว่าไม่มีกลุ่มตัวอย่างในเดือนนี้' };
          if (month === 6) row = { ...unavailableCell(rule, fiscalYear, month, now, true), dataStatus: 'missing-source', reason: 'ตัวอย่างเดือนที่ยังไม่ได้โหลด aggregate' };
          if (row.dataStatus === 'measured' && (rule.accumulation === 'custom' || rule.accumulation === 'distinct-cohort')) {
            // Synthetic source-supplied YTD, intentionally different from summing monthly cohorts.
            const ytdNumerator = rule.code === 'SH0101' ? month * 2 : 90 + month * 2;
            const ytdDenominator = rule.code === 'SH0101' ? 130 : 105 + month * 2;
            row.cumulative = { numerator: ytdNumerator, denominator: ytdDenominator, value: ytdNumerator / ytdDenominator * rule.scale, through: row.dataThrough, complete: true };
          }
          row.assessment = assessMonitoring(row, rule);
        }
        codeRows.push(row);
        if (['measured', 'zero-cohort'].includes(row.dataStatus) && rule.approval === 'synthetic') row.cumulative = accumulateMonitoring(codeRows, rule);
        rows.push(row);
      }
    }
    return rows;
  } };
}
