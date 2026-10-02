import type { KpiCellViewModel } from './kpiTypes';
import type { MonitoringCumulative, MonitoringRule } from '@/monitoring/types';

const empty: MonitoringCumulative = Object.freeze({
  numerator: null, denominator: null, value: null, through: null, complete: false,
});
export const accumulationLabels: Record<string, string> = {
  sum: 'รวมค่ารายงวด', count: 'รวมจำนวนรายงวด',
  'weighted-ratio': 'รวมตัวตั้ง ÷ รวมตัวหาร',
  'fixed-denominator': 'รวมตัวตั้ง ใช้ฐานคงที่ครั้งเดียว',
  snapshot: 'ใช้ค่าล่าสุด ณ วันตัดยอด',
  'distinct-cohort': 'ใช้ยอดคน/ครั้งไม่ซ้ำจากแหล่งข้อมูล',
  custom: 'ใช้สูตรสะสมเฉพาะจากแหล่งข้อมูล',
  'source-period-result': 'ยังไม่มีสูตรสะสมสำหรับชุดรายงานนี้',
};

/** Only registered accumulation semantics are used; gaps never become zero. */
export function withKpiCumulative(
  cells: readonly KpiCellViewModel[], rule: MonitoringRule
): readonly KpiCellViewModel[] {
  return cells.map((cell, index) => {
    const unavailable = (reason: string): KpiCellViewModel => Object.freeze({
      ...cell, cumulative: empty, cumulativeBasis: null, cumulativeReason: reason,
    });
    if (!['measured', 'zero-cohort'].includes(cell.status))
      return unavailable(cell.reason);
    if (cell.discrepancy) return unavailable('ค่ารายงวดต่างจากตัวตั้ง/ตัวหาร ต้องสอบทานก่อนสะสม');
    // A validated source YTD can establish coverage even when period rows are absent.
    if (cell.cumulative.value !== null && cell.cumulativeBasis === 'source')
      return cell;
    const method = cell.accumulation;
    if (!(method in accumulationLabels)) return unavailable('ยังไม่มีกฎสะสมที่ลงทะเบียนสำหรับสูตรนี้');
    if (method === 'source-period-result') return unavailable(accumulationLabels[method]);
    if (method === 'distinct-cohort' || method === 'custom')
      return unavailable('ต้องมีผลสะสมจากแหล่งข้อมูลตามสูตรนี้ ไม่รวมค่ารายเดือนแทน');
    const prefix = method === 'snapshot' ? [cell] : cells.slice(0, index + 1).filter(point => point.status !== 'not-applicable');
    if (prefix.some(point => point.code !== cell.code || point.fiscalYear !== cell.fiscalYear ||
      point.series !== cell.series || point.unit !== cell.unit || point.ruleVersion !== cell.ruleVersion ||
      point.lineage !== cell.lineage || point.accumulation !== method))
      return unavailable('สูตร หน่วย หรือแหล่งข้อมูลเปลี่ยนระหว่างช่วงสะสม');
    if (method !== 'snapshot' && prefix.some(point =>
      !['measured', 'zero-cohort'].includes(point.status) || point.discrepancy))
      return unavailable('ข้อมูลตั้งแต่ ต.ค. ถึงงวดนี้ยังไม่ครบหรือมีค่าที่ต้องสอบทาน');
    const sum = (field: 'numerator' | 'denominator' | 'value') => {
      if (prefix.some(point => point[field] === null)) return null;
      const value = prefix.reduce((total, point) => total + point[field]!, 0);
      return Number.isFinite(value) ? value : null;
    };
    const numerator = method === 'snapshot' ? cell.numerator : sum('numerator');
    const denominator = method === 'snapshot' ? cell.denominator : method === 'fixed-denominator'
      ? prefix.every(point => point.denominator === cell.denominator) ? cell.denominator : null
      : sum('denominator');
    const value = method === 'snapshot' ? cell.value : method === 'sum' || method === 'count'
      ? sum('value') : numerator !== null && denominator !== null && denominator > 0
        ? numerator / denominator * rule.scale : null;
    if (value === null || !Number.isFinite(value))
      return unavailable(method === 'fixed-denominator'
        ? 'ฐานคงที่ขาด เปลี่ยนค่า หรือเป็นศูนย์ จึงคำนวณยอดสะสมไม่ได้'
        : 'ตัวตั้ง/ตัวหารหรือค่ารายงวดไม่พร้อมสำหรับคำนวณผลสะสม');
    return Object.freeze({
      ...cell,
      cumulative: Object.freeze({ numerator, denominator, value,
        through: cell.dataThrough, complete: false }),
      cumulativeBasis: 'period-facts' as const,
      cumulativeReason: method === 'snapshot'
        ? 'ค่าล่าสุดตามกฎ snapshot; ไม่ใช่ผลบวกของเดือน'
        : 'คำนวณจากงวดที่โหลดครบตั้งแต่ ต.ค.; ความครบของข้อมูลต้นทางยังไม่ยืนยัน',
    });
  });
}
