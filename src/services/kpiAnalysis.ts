import type { KpiCellViewModel } from './kpiTypes';
import { monitoringRulesByCode } from '@/monitoring/rules';
import { buildPeriodControlChart } from '@/utils/controlChartCore';

export function sharedControlChart(cells: readonly KpiCellViewModel[]) {
  const first = cells[0];
  const periods = cells.filter(cell => cell.status !== 'not-applicable');
  const eligible = periods.filter(cell => cell.status === 'measured' && cell.value !== null && !cell.discrepancy);
  const consistent = !first || eligible.every(cell => cell.code === first.code && cell.fiscalYear === first.fiscalYear &&
    cell.unit === first.unit && cell.ruleVersion === eligible[0].ruleVersion &&
    cell.lineage === eligible[0].lineage && cell.series === first.series);
  const rule = first && monitoringRulesByCode.get(first.code);
  const model = buildPeriodControlChart(periods.map(cell => ({
    fiscalMonth: cell.fiscalMonth, label: cell.label, periodStart: cell.periodStart, periodEnd: cell.periodEnd,
    value: consistent && cell.status === 'measured' && !cell.discrepancy ? cell.value : null,
    numerator: cell.numerator, denominator: cell.denominator,
  })), rule?.scale ?? 1, first?.unit === 'percent' && first.accumulation === 'weighted-ratio');
  return { model, reason: !consistent ? 'สูตร หน่วย หรือแหล่งข้อมูลเปลี่ยนระหว่างงวด จึงยังไม่รวมเป็นฐานควบคุมเดียวกัน'
    : !model.measuredPointCount ? 'ยังไม่มีค่ารายงวดที่พร้อมวิเคราะห์'
    : !model.hasLimits ? 'ต้องมีข้อมูลอย่างน้อย 2 งวด; Individuals ต้องมีงวดที่ต่อเนื่องกันเพื่อคำนวณ Moving Range'
    : '', excluded: periods.filter(cell => cell.discrepancy).length };
}
