import { thipKpiRules } from '@/data/thipKpiRules';

/**
 * Implementation tier for each THIP code.
 *
 * - `registered`: a read-only registered query computes a real aggregate from
 *   HOSxP and the code has an evidence-backed rule version.
 * - `pending-local-source`: the code is in the 232-code contract, but the
 *   hospital rule/code-set/source is not yet confirmed. The reporting layer
 *   must emit an explicit `unavailable` row (denominator = NULL, value = NULL,
 *   with a reason) for every applicable reporting period; it must never emit a
 *   fabricated zero.
 */
export type ThipImplementationTier = 'registered' | 'pending-local-source';

/**
 * Codes with a real registered read-only query in this release. They are the
 * only codes whose source-view rows carry a measured numerator/denominator.
 */
export const registeredRuleCodes: readonly string[] = [
  'DH0101', 'DH0101.1', 'DH0101.2', 'DH0102', 'DH0112',
  'DN0101', 'DN0107', 'DN0109', 'DN0302',
  'DR0101', 'DR0102', 'DR0403',
  'CE0101', 'CI0101',
  'DG0102', 'DG0202',
  // Added from the reviewed hospital master evidence; Pdx-only cohorts.
  'DC0401', 'DR0201', 'DG0201', 'DH0111', 'DR0301', 'DR0401', 'DG0101', 'CM0105',
] as const;

export const registeredRuleCodeSet: ReadonlySet<string> = new Set(registeredRuleCodes);

/**
 * Why a family is not yet registered. Kept per family so the reporting layer
 * can attach a human-readable reason to every `unavailable` row.
 */
export const pendingReasonByFamily: Readonly<Record<string, string>> = {
  ACSC: 'ต้องยืนยัน population denominator, age band และพื้นที่รับผิดชอบ',
  ANESTHESIA: 'ต้องยืนยัน ASA, pre-anesthetic, recovery, re-intubation และ capnometry event',
  ED_FLOW: 'ต้องยืนยันความหมาย ER TIME-IN/TIME-OUT และเกณฑ์ emergency',
  PRESSURE_ULCER: 'ต้องยืนยัน stage, present-on-admission, risk population และ patient-days',
  MATERNAL_CHILD: 'ต้องยืนยัน mother-child linkage, อายุครรภ์, grain การคลอด และหน้าต่างทารก',
  SURGERY: 'ต้องยืนยัน surgical safety checklist, peri-op window และนิยาม re-operation',
  MENTAL_DEVELOPMENT: 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention',
  DM_HT: 'ต้องยืนยัน good-control threshold, lab ล่าสุดที่ใช้ได้ และช่วงอายุ',
  HIV_TB: 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result',
  CANCER: 'ต้องยืนยัน linkage ของ site/stage กับ mortality/re-admission',
  CKD: 'ต้องยืนยันสูตร eGFR, crosswalk ACEI/ARB และ longitudinal target',
  BREAST_CANCER: 'ต้องยืนยัน BIRADS, consultation clock และนิยาม stage',
  STEM_CELL: 'ต้องยืนยันวัน engraftment และ denominator',
  TDT: 'ต้องยืนยัน lab threshold iron overload และ chelator mapping',
  CLEFT: 'ต้องยืนยัน operation master ของ cleft และอายุขณะผ่าตัด',
  INFERTILITY: 'ต้องยืนยัน embryo transfer cycle และอายุขณะ transfer',
  UGIH: 'ต้องยืนยัน EGD/hemostasis event และ risk status',
  NEWBORN: 'ต้องยืนยัน hearing screening ภายใน 30 วัน และตัวตนทารก',
  CABG: 'ต้องยืนยันการระบุหัตถการ CABG และหน้าต่าง 30 วัน',
  HEART_FAILURE: 'ต้องยืนยันหลักฐาน LVSD/HFREF และ ACEI/ARB/MRA',
  ATRIAL_FIBRILLATION: 'ต้องยืนยัน anticoagulant target และนิยาม intracranial bleed',
  HEAD_INJURY: 'ต้องยืนยัน craniotomy และหน้าต่าง 48 ชั่วโมง',
  ARTHROPLASTY: 'ต้องยืนยัน hip/knee procedure, prophylaxis และ 90-day/1-year infection',
  PEDIATRIC_DM: 'ต้องยืนยันอายุเด็ก, control threshold และช่วง visit',
  PNEUMONIA: 'ต้องยืนยัน Pdx/Sdx และ 28-day readmission',
  ASTHMA_COPD: 'ต้องยืนยัน disease cohort, smoking status และ readmission',
  CHRONIC_ED: 'ต้องยืนยันเครื่องมือประเมิน self-care',
  EMPLOYEE: 'ต้องยืนยัน employee denominator, check-up, BMI และ influenza vaccine',
  TOBACCO: 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup',
  CUSTOMER: 'ต้องยืนยัน questionnaire version และ response denominator',
  FINANCE: 'HOSxP operational fields ไม่เท่ากับงบการเงินที่ตรวจสอบแล้ว',
  GOVERNANCE: 'แหล่ง recycled waste อาจเป็น custom/นอก HOSxP มาตรฐาน',
  HR: 'ต้องยืนยัน headcount/FTE, category, training และ injury',
  INFECTION: 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)',
  BLOOD: 'ต้องยืนยัน selective-surgery denominator และ transfusion event',
  MEDICATION: 'ต้องยืนยันนิยาม antibiotic prescribing และสูตร inventory turn',
  CSSD: 'ต้องยืนยัน sterilization test และ equipment/procedure request',
};

/** Family name lookup for a code, from the rule manifest. */
const familyByCode: ReadonlyMap<string, string> = new Map(
  thipKpiRules.map((rule) => [rule.code, rule.queryFamily]),
);

export function getImplementationTier(code: string): ThipImplementationTier {
  return registeredRuleCodeSet.has(code) ? 'registered' : 'pending-local-source';
}

export function getPendingReason(code: string): string | null {
  if (registeredRuleCodeSet.has(code)) return null;
  const family = familyByCode.get(code);
  return (family && pendingReasonByFamily[family]) || 'ยังไม่ยืนยัน local rule/source ของตัวชี้วัดนี้';
}

export type ThipImplementation = {
  code: string;
  family: string;
  tier: ThipImplementationTier;
  reason: string | null;
};

export const thipImplementation: readonly ThipImplementation[] = thipKpiRules.map((rule) => ({
  code: rule.code,
  family: rule.queryFamily,
  tier: getImplementationTier(rule.code),
  reason: getPendingReason(rule.code),
}));

export const pendingLocalSourceCodes: readonly string[] = thipImplementation
  .filter((entry) => entry.tier === 'pending-local-source')
  .map((entry) => entry.code);

export const thipImplementationByCode: ReadonlyMap<string, ThipImplementation> = new Map(
  thipImplementation.map((entry) => [entry.code, entry]),
);
