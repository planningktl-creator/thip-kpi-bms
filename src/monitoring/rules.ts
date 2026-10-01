import evidence from './evidence.json';
import { thipCatalogue } from '@/data/thipCatalogue';
import { getDictionaryEntry } from '@/data/thipDictionary';
import { getFormulaScale, getRuleUnit, thipKpiRulesByCode } from '@/data/thipKpiRules';
import type { MonitoringRule, MonitoringUnit } from './types';

const reasons: Record<string, string> = {
  'candidate-native-monthly-period': 'มี monthly candidate แต่ยังรอยืนยัน cohort, join, วันที่จัดงวด และรับรองสูตร',
  'requires-approved-monthly-monitoring-rule': 'ต้องกำหนดสูตรติดตามรายเดือนเพิ่มเติม แยกจากรอบรายงาน THIP เดิม',
  'requires-external-aggregate': 'ต้องใช้ aggregate ภายนอกและรับรองสูตรติดตามรายเดือน',
  'requires-external-population-aggregate': 'ต้องใช้ population denominator ภายนอกที่ได้รับการยืนยัน',
};
const evidenceByCode = new Map(evidence.map((row) => [row.code, row]));
function displayUnit(code: string): MonitoringUnit {
  const text = evidenceByCode.get(code)?.pdfUnit ?? '';
  if (/ชั่วโมง/.test(text)) return 'hour-per-person';
  if (/นาที/.test(text)) return 'minute';
  if (/วัน/.test(text)) return 'day';
  if (/เดือน/.test(text)) return 'month';
  if (/ร้อยละ/.test(text)) return 'percent';
  if (/จำนวน|ครั้ง|คน/.test(text) && !/ต่อ|อัตรา/.test(text)) return 'count';
  return getRuleUnit(thipKpiRulesByCode.get(code) ?? { formulaScale: 'a/b' });
}
export const monitoringRules: readonly MonitoringRule[] = thipCatalogue.map((entry) => {
  const dictionary = getDictionaryEntry(entry.code)!;
  const mapping = evidenceByCode.get(entry.code)!;
  const unit = displayUnit(entry.code);
  const candidate = mapping.path === 'candidate-native-monthly-period';
  const special = entry.code === 'SH0101' || entry.code === 'SM0201';
  return {
    code: entry.code, group: entry.group, title: entry.titleTh || entry.title,
    version: 'monitoring-draft-1', approval: 'unapproved', approvalEvidence: null,
    effectiveFrom: null, effectiveTo: null,
    unit, precision: unit === 'count' ? 0 : 2,
    scale: getFormulaScale(thipKpiRulesByCode.get(entry.code)?.formulaScale ?? dictionary.formula),
    direction: dictionary.direction, watchMargin: null,
    accumulation: special || !candidate ? 'custom' : unit === 'count' ? 'count' : 'weighted-ratio',
    formula: candidate ? dictionary.formula : 'ยังไม่มีสูตรรายเดือนที่รับรอง — ห้ามแบ่งผล THIP เป็นเดือนโดยปริยาย',
    method: entry.code === 'SM0201' ? 'snapshot มูลค่าคงคลังสิ้นเดือน / มูลค่าจ่ายเดือนนั้น; ต้องรับรองวิธีสะสมแยก' : entry.code === 'SH0101' ? 'ต้องกำหนดสูตรรายเดือนเพิ่มเติม; รายปีใช้ค่าเฉลี่ยตามพจนานุกรม ห้ามหาร 12' : candidate ? 'ข้อเสนอ: ใช้ aggregate ของเดือนตามนิยาม; สะสมเฉพาะเมื่อรับรอง cohort และวิธีแล้ว' : 'รอเจ้าของ KPI ระบุ cohort และวิธีสะสม; distinct/custom ให้ source ส่ง aggregate สำเร็จ',
    capability: mapping.path, reason: reasons[mapping.path], dictionaryBenchmark: dictionary.target,
    reference: `THIP KPI.pdf · หน้าพิมพ์ ${mapping.printedPages.join(', ')} · PDF ${dictionary.page}`,
  };
});
export const monitoringRulesByCode: ReadonlyMap<string, MonitoringRule> = new Map(monitoringRules.map((rule) => [rule.code, rule]));
export const monitoringUnitLabels: Record<MonitoringUnit, string> = {
  percent: '%', rate: 'อัตรา', count: 'จำนวน', ratio: 'อัตราส่วน', minute: 'นาที', day: 'วัน', month: 'เดือน', 'hour-per-person': 'ชั่วโมง/คน',
};
