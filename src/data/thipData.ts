import type {
  AnnualResult,
  GroupMeta,
  FiscalYear,
  Indicator,
  IndicatorDirection,
  IndicatorGroup,
  IndicatorStatus,
  IndicatorUnit,
  MonthlyResult,
  TargetScope,
} from '@/types/thip';
import { getFiscalMonthPeriods } from '@/utils/fiscal';

export const DEMO_FISCAL_YEAR: FiscalYear = 2026;
export const fiscalMonthPeriods = getFiscalMonthPeriods(DEMO_FISCAL_YEAR);
export const fiscalMonthLabels = fiscalMonthPeriods.map((period) => period.monthLabel);

export const groupMeta: Record<IndicatorGroup, GroupMeta> = {
  D: {
    key: 'D',
    label: 'Disease',
    shortLabel: 'รายโรค',
    description: 'ผลลัพธ์จำแนกตามกลุ่มโรคสำคัญ',
    color: '#2dc9c5',
  },
  C: {
    key: 'C',
    label: 'Care process',
    shortLabel: 'กระบวนการดูแล',
    description: 'คุณภาพกระบวนการดูแลผู้ป่วย',
    color: '#f4b942',
  },
  S: {
    key: 'S',
    label: 'System',
    shortLabel: 'ระบบงาน',
    description: 'ตัวชี้วัดระบบสนับสนุนสำคัญ',
    color: '#8c7cff',
  },
  H: {
    key: 'H',
    label: 'Health promotion',
    shortLabel: 'สร้างเสริมสุขภาพ',
    description: 'การสร้างเสริมสุขภาพบุคลากรและผู้รับบริการ',
    color: '#ef7b68',
  },
  A: {
    key: 'A',
    label: 'Ambulatory care',
    shortLabel: 'ผู้ป่วยนอก',
    description: 'โรคที่ควรดูแลด้วยบริการผู้ป่วยนอก',
    color: '#5d9cec',
  },
};

type Seed = Omit<
  Indicator,
  'annual' | 'monthly' | 'target' | 'targetScope' | 'fiscalYear'
> & {
  values: Array<number | null>;
  denominators: Array<number | null>;
  target: number | null;
  targetScope?: TargetScope;
};

function getStatus(
  value: number | null,
  target: number | null,
  direction: IndicatorDirection,
): IndicatorStatus {
  if (value === null) return 'no-data';
  if (target === null || direction === 'neutral') return 'on-track';
  const margin = Math.max(Math.abs(target) * 0.08, 0.02);
  if (direction === 'higher-is-better') {
    if (value >= target) return 'on-track';
    if (value >= target - margin) return 'watch';
    return 'action';
  }
  if (value <= target) return 'on-track';
  if (value <= target + margin) return 'watch';
  return 'action';
}

function makeMonthly(
  values: Array<number | null>,
  denominators: Array<number | null>,
  unit: IndicatorUnit,
  target: number | null,
  targetScope: TargetScope,
  direction: IndicatorDirection,
): MonthlyResult[] {
  return values.map((inputValue, index) => {
    const period = fiscalMonthPeriods[index];
    const denominator = denominators[index] ?? null;
    const isEmpty = inputValue === null || denominator === null || denominator === 0;
    const scale = unit === 'percent' || unit === 'rate' ? 100 : 1;
    const numerator = isEmpty ? null : Math.round(inputValue * denominator / scale);
    const value = isEmpty || numerator === null
      ? null
      : Number(((numerator / denominator) * scale).toFixed(2));

    return {
      periodStart: period.periodStart,
      fiscalYear: period.fiscalYear,
      fiscalMonth: index + 1,
      label: period.label,
      numerator,
      denominator,
      value,
      target: targetScope === 'monthly' ? target : null,
      percentile: value === null ? null : Math.max(42, Math.min(96, Math.round(72 + (value - (target ?? value)) * 2))),
      status: getStatus(value, target, direction),
    };
  });
}

function makeAnnual(
  monthly: MonthlyResult[],
  fiscalYear: FiscalYear,
  unit: IndicatorUnit,
  target: number | null,
  direction: IndicatorDirection,
): AnnualResult {
  const rows = monthly.filter((month) => month.numerator !== null && month.denominator !== null);
  const numerator = rows.length ? rows.reduce((sum, month) => sum + (month.numerator ?? 0), 0) : null;
  const denominator = rows.length ? rows.reduce((sum, month) => sum + (month.denominator ?? 0), 0) : null;
  const scale = unit === 'percent' || unit === 'rate' ? 100 : 1;
  const value = unit === 'count'
    ? (rows.length ? Number(rows.reduce((sum, month) => sum + (month.value ?? 0), 0).toFixed(2)) : null)
    : numerator !== null && denominator
      ? Number(((numerator / denominator) * scale).toFixed(2))
      : null;

  return {
    fiscalYear,
    numerator,
    denominator,
    value,
    target,
    status: getStatus(value, target, direction),
  };
}

const seeds: Seed[] = [
  {
    code: 'DH0101',
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน',
    unit: 'percent',
    direction: 'lower-is-better',
    target: 3.5,
    values: [2.8, 2.5, 3.2, 2.9, 2.4, 2.1, 2.7, 3.0, 2.6, 2.2, 2.5, 2.3],
    denominators: [142, 160, 154, 171, 168, 188, 176, 181, 194, 201, 196, 207],
    definition: 'ผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis เป็น Acute coronary syndrome และเสียชีวิตจากทุกสาเหตุ',
    formula: '(จำนวนผู้ป่วย ACS ที่เสียชีวิต ÷ จำนวนผู้ป่วย ACS ที่จำหน่ายทุกสถานะ) × 100',
    numeratorLabel: 'จำหน่ายด้วยการเสียชีวิต',
    denominatorLabel: 'ผู้ป่วย ACS ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 39',
  },
  {
    code: 'DH0102',
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome: Aspirin within 24 hours',
    titleTh: 'ร้อยละผู้ป่วย ACS ที่ได้รับ Aspirin ภายใน 24 ชั่วโมง',
    unit: 'percent',
    direction: 'higher-is-better',
    target: 90,
    values: [84, 86, 87, 89, 91, 90, 92, 93, 92, 94, 93, 88],
    denominators: [122, 138, 131, 145, 141, 159, 151, 154, 169, 174, 171, 183],
    definition: 'ผู้ป่วย ACS ที่ได้รับ Aspirin ภายใน 24 ชั่วโมงเมื่อมาถึงโรงพยาบาล',
    formula: '(จำนวนผู้ป่วยที่ได้รับ Aspirin ภายใน 24 ชั่วโมง ÷ จำนวนผู้ป่วย ACS ที่เข้าเกณฑ์) × 100',
    numeratorLabel: 'ได้รับ Aspirin ภายใน 24 ชั่วโมง',
    denominatorLabel: 'ผู้ป่วย ACS ที่เข้าเกณฑ์',
    sourceTables: ['ipt', 'iptdiag', 'ipd_doctor_order', 'opitemrece'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 42',
  },
  {
    code: 'DN0101',
    group: 'D',
    category: 'Neurovascular disease · Stroke',
    title: 'Stroke: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย Stroke',
    unit: 'percent',
    direction: 'lower-is-better',
    target: 5,
    values: [5.8, 5.4, 5.1, 4.9, 5.3, 4.7, 4.5, 4.8, 4.6, 4.3, 4.2, 4.1],
    denominators: [330, 348, 361, 355, 372, 384, 391, 402, 410, 424, 432, 447],
    definition: 'ผู้ป่วยในที่มี Principal diagnosis หรือโรคร่วมตามกลุ่มรหัส Stroke และจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Stroke ที่เสียชีวิต ÷ จำนวนผู้ป่วย Stroke ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Stroke ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Stroke ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 67',
  },
  {
    code: 'DR0101',
    group: 'D',
    category: 'Respiratory disease · Pneumonia',
    title: 'Pneumonia: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วยปอดบวม',
    unit: 'percent',
    direction: 'lower-is-better',
    target: 8,
    values: [7.6, 7.2, 8.4, 7.9, 7.1, 6.8, 7.3, 6.9, 6.6, 6.3, 6.4, 6.1],
    denominators: [224, 239, 251, 244, 260, 271, 264, 278, 285, 291, 302, 314],
    definition: 'ผู้ป่วยในที่เข้าเกณฑ์ Pneumonia ตามนิยามและจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Pneumonia ที่เสียชีวิต ÷ จำนวนผู้ป่วย Pneumonia ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Pneumonia ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Pneumonia ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 79',
  },
  {
    code: 'CA0105',
    group: 'C',
    category: 'Anesthesia care process',
    title: 'Anesthesia: Capnometry during general anesthesia',
    titleTh: 'ร้อยละผู้ป่วยที่ได้รับการเฝ้าระวัง Capnometry ระหว่างดมยาสลบ',
    unit: 'percent',
    direction: 'higher-is-better',
    target: 95,
    values: [91, 92, 94, 93, 95, 95, 96, 97, 96, 97, 98, 98],
    denominators: [188, 196, 204, 199, 212, 218, 221, 229, 233, 241, 247, 253],
    definition: 'ผู้ป่วยที่ได้รับยาสลบและได้รับการเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ในลมหายใจออก',
    formula: '(จำนวนผู้ป่วยที่ได้รับ Capnometry ÷ จำนวนผู้ป่วยที่ได้รับ general anesthesia) × 100',
    numeratorLabel: 'ได้รับการเฝ้าระวัง Capnometry',
    denominatorLabel: 'ผู้ป่วยที่ได้รับ general anesthesia',
    sourceTables: ['ipt', 'iptoprt', 'ipd_doctor_order'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 184',
  },
  {
    code: 'CO0101',
    group: 'C',
    category: 'Operative care process',
    title: 'Operation: Surgical safety checklist',
    titleTh: 'ร้อยละการใช้แบบตรวจสอบเพื่อความปลอดภัยของผู้ป่วยผ่าตัด',
    unit: 'percent',
    direction: 'higher-is-better',
    target: 98,
    values: [96, 96, 97, 97, 98, 98, 98, 99, 99, 99, 99, 99],
    denominators: [144, 150, 155, 149, 162, 168, 172, 179, 185, 190, 196, 201],
    definition: 'การใช้แบบตรวจสอบความปลอดภัยของผู้ป่วยเมื่อเข้ารับการตรวจรักษาในห้องผ่าตัด',
    formula: '(จำนวนครั้งที่ใช้ surgical safety checklist ÷ จำนวนการผ่าตัดที่เข้าเกณฑ์) × 100',
    numeratorLabel: 'ใช้ surgical safety checklist',
    denominatorLabel: 'การผ่าตัดที่เข้าเกณฑ์',
    sourceTables: ['ipt', 'iptoprt'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 185',
  },
  {
    code: 'CG0101',
    group: 'C',
    category: 'General care process',
    title: 'Pressure ulcer/injury: Rate of pressure ulcer',
    titleTh: 'อัตราการเกิดแผลกดทับในโรงพยาบาล',
    unit: 'rate',
    direction: 'lower-is-better',
    target: 1.5,
    values: [1.8, 1.6, 1.7, 1.5, 1.4, 1.3, 1.4, 1.2, 1.3, 1.1, 1.2, 1.8],
    denominators: [820, 844, 861, 878, 892, 918, 937, 954, 976, 991, 1014, 1032],
    definition: 'ผู้ป่วยที่เกิดแผลกดทับระหว่างนอนโรงพยาบาลตามระดับที่กำหนด',
    formula: '(จำนวนผู้ป่วยที่เกิดแผลกดทับ ÷ จำนวนวันนอนหรือผู้ป่วยที่อยู่ในกลุ่มเสี่ยง) × 100',
    numeratorLabel: 'ผู้ป่วยที่เกิดแผลกดทับ',
    denominatorLabel: 'ผู้ป่วย/วันนอนที่อยู่ในกลุ่มเสี่ยง',
    sourceTables: ['ipt', 'iptbedmove', 'ipd_doctor_order'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 188',
  },
  {
    code: 'SI0101',
    group: 'S',
    category: 'Infection control system',
    title: 'Infection control: VAP prevention signal',
    titleTh: 'สัญญาณการป้องกันการติดเชื้อในระบบทางเดินหายใจ',
    unit: 'rate',
    direction: 'lower-is-better',
    target: 2,
    values: [2.4, 2.2, 2.5, 2.1, 2.0, 1.9, 2.1, 1.8, 1.7, 1.8, 1.6, 1.5],
    denominators: [510, 524, 535, 548, 561, 578, 589, 604, 620, 633, 648, 659],
    definition: 'อัตราเหตุการณ์ติดเชื้อที่สัมพันธ์กับการใช้เครื่องช่วยหายใจตามนิยามของระบบควบคุมการติดเชื้อ',
    formula: '(จำนวนเหตุการณ์ติดเชื้อ ÷ จำนวนวันใช้เครื่องช่วยหายใจ) × 1,000',
    numeratorLabel: 'เหตุการณ์ติดเชื้อ',
    denominatorLabel: 'วันใช้เครื่องช่วยหายใจ',
    sourceTables: ['ipt', 'ipd_doctor_order', 'ipd_doctor_order_detail'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หมวด SI',
  },
  {
    code: 'SF0101',
    group: 'S',
    category: 'Financial system · Finance and accounting',
    title: 'Financial: Current ratio',
    titleTh: 'อัตราส่วนทุนหมุนเวียน',
    unit: 'ratio',
    direction: 'higher-is-better',
    target: 1.5,
    values: [1.32, 1.36, 1.39, 1.42, 1.45, 1.48, 1.52, 1.55, 1.58, 1.61, 1.63, 1.66],
    denominators: [100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100],
    definition: 'ความสามารถของโรงพยาบาลในการชำระหนี้สินหมุนเวียนด้วยสินทรัพย์หมุนเวียน',
    formula: 'สินทรัพย์หมุนเวียน ÷ หนี้สินหมุนเวียน',
    numeratorLabel: 'สินทรัพย์หมุนเวียน',
    denominatorLabel: 'หนี้สินหมุนเวียน',
    sourceTables: ['income'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 244',
  },
  {
    code: 'HE0101',
    group: 'H',
    category: 'Employee health promotion',
    title: 'Employee health: Annual screening completion',
    titleTh: 'ร้อยละบุคลากรที่ได้รับการตรวจสุขภาพประจำปี',
    unit: 'percent',
    direction: 'higher-is-better',
    targetScope: 'annual',
    target: 90,
    values: [72, 76, 78, 81, 83, 86, 88, 89, 91, 92, 93, 94],
    denominators: [620, 620, 620, 620, 620, 620, 620, 620, 620, 620, 620, 620],
    definition: 'บุคลากรที่ได้รับการตรวจสุขภาพประจำปีครบถ้วนตามสิทธิและช่วงเวลาที่กำหนด',
    formula: '(จำนวนบุคลากรที่ตรวจสุขภาพครบถ้วน ÷ จำนวนบุคลากรเป้าหมาย) × 100',
    numeratorLabel: 'บุคลากรที่ตรวจสุขภาพครบถ้วน',
    denominatorLabel: 'บุคลากรเป้าหมาย',
    sourceTables: ['patient'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หมวด HE',
  },
  {
    code: 'HH0101',
    group: 'H',
    category: 'Health promotion · Tobacco use',
    title: 'Tobacco use: Smoking cessation advice',
    titleTh: 'ร้อยละผู้รับบริการที่ได้รับคำแนะนำเลิกบุหรี่',
    unit: 'percent',
    direction: 'higher-is-better',
    target: 85,
    values: [76, 78, 80, 81, 82, 84, 83, 86, 87, 88, 84, 82],
    denominators: [240, 253, 261, 258, 272, 281, 286, 294, 302, 309, 317, 325],
    definition: 'ผู้สูบบุหรี่ที่ได้รับการประเมินและคำแนะนำให้เลิกบุหรี่ระหว่างรับบริการ',
    formula: '(จำนวนผู้สูบบุหรี่ที่ได้รับคำแนะนำ ÷ จำนวนผู้สูบบุหรี่ที่เข้าเกณฑ์) × 100',
    numeratorLabel: 'ได้รับคำแนะนำเลิกบุหรี่',
    denominatorLabel: 'ผู้สูบบุหรี่ที่เข้าเกณฑ์',
    sourceTables: ['patient', 'ipt_doctor_diag', 'ipd_doctor_order'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 272',
  },
  {
    code: 'AA0101',
    group: 'A',
    category: 'Ambulatory care sensitive condition',
    title: 'Epilepsy: Hospitalization rate',
    titleTh: 'อัตราการนอนโรงพยาบาลด้วยภาวะลมชักที่ควบคุมได้ด้วยบริการผู้ป่วยนอก',
    unit: 'rate',
    direction: 'lower-is-better',
    target: 4,
    values: [4.8, 4.6, 4.7, 4.5, 4.3, 4.1, 4.2, 3.9, 3.8, 3.7, 3.6, 3.5],
    denominators: [12000, 12140, 12280, 12400, 12580, 12700, 12860, 13020, 13200, 13340, 13500, 13620],
    definition: 'การนอนโรงพยาบาลด้วยภาวะลมชักที่ควบคุมได้ด้วยบริการผู้ป่วยนอกตามรหัสโรคที่กำหนด',
    formula: '(จำนวนผู้ป่วยที่นอนโรงพยาบาลด้วย ACSC ÷ ประชากรกลุ่มเป้าหมาย) × 100,000',
    numeratorLabel: 'ผู้ป่วย ACSC ที่นอนโรงพยาบาล',
    denominatorLabel: 'ประชากรกลุ่มเป้าหมาย',
    sourceTables: ['ipt', 'iptdiag', 'patient'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 286',
  },
];

export const demoIndicators: Indicator[] = seeds.map((seed) => {
  const targetScope = seed.targetScope ?? 'monthly';
  const monthly = makeMonthly(seed.values, seed.denominators, seed.unit, seed.target, targetScope, seed.direction);
  return {
    code: seed.code,
    fiscalYear: DEMO_FISCAL_YEAR,
    group: seed.group,
    category: seed.category,
    title: seed.title,
    titleTh: seed.titleTh,
    unit: seed.unit,
    direction: seed.direction,
    target: seed.target,
    targetScope,
    definition: seed.definition,
    formula: seed.formula,
    numeratorLabel: seed.numeratorLabel,
    denominatorLabel: seed.denominatorLabel,
    sourceTables: seed.sourceTables,
    frequency: seed.frequency,
    reference: seed.reference,
    monthly,
    annual: makeAnnual(monthly, DEMO_FISCAL_YEAR, seed.unit, seed.target, seed.direction),
  };
});

export const sourceDictionaryCount = 232;

export const allDemoMonthlyResults = demoIndicators.flatMap((indicator) => indicator.monthly);
