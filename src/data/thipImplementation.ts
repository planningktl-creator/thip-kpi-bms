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
 * Codes with a real registered read-only query. Every one of the 232 THIP codes
 * now resolves to exactly one fact branch: the legacy in-registry families
 * cover the registered core and the batch modules in `src/services/thipFamilies`
 * cover the remaining 171 codes (see `thipBatchBranchByCode`). A code whose
 * branch reads `reporting.thip_external_facts` measures only after the hospital
 * loads its staging rows; until then the reporting layer emits explicit
 * unavailable rows for it (never a fabricated zero). Documented per-code
 * approximations live in `src/services/thipFamilies/*_APPROXIMATIONS` and still
 * need clinical/quality owner sign-off before being called `ready`.
 */
export const registeredRuleCodes: readonly string[] = thipKpiRules.map((rule) => rule.code);

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
  ACS: 'ต้องยืนยัน door-to-EKG/needle/balloon timestamp, ผล LVEF/LVSD และรายการยา discharge (Aspirin/Beta-blocker/ACEI/ARB)',
  APPENDICITIS: 'ต้องยืนยัน diagnostic code ไส้ติ่งแตก (perforated appendicitis) และบันทึกเวลาผ่าตัด',
  SEPSIS_ER: 'ต้องยืนยันเวลา triage, ER order time และเวลาบริหารยา antibiotic ภายใน 1 ชั่วโมง',
  STROKE: 'ต้องยืนยัน door-to-needle time, NIHSS score, dysphagia screening, รายการยา antiplatelet/anticoagulant และ physiotherapy window ภายใน 72 ชั่วโมง',
};

/**
 * Optional code-specific pending reason overrides.
 * Provides highly specific, clinically accurate explanations for individual indicators
 * that require confirmation beyond the family-level rule/source baseline.
 */
export const pendingReasonByCode: Readonly<Record<string, string>> = {
  // Sepsis 1-hour ER antibiotic
  CE0104: 'ต้องยืนยันเวลา triage, ER order time และเวลาบริหารยา broad-spectrum antibiotic ภายใน 1 ชั่วโมง',
  // ACS discharge meds and timestamps
  DH0103: 'ต้องยืนยันรายการยา Aspirin ที่สั่งจ่าย ณ วันจำหน่าย (discharge prescription)',
  DH0104: 'ต้องยืนยันผลตรวจ LVEF < 40% (LVSD) และรายการยา ACEI/ARB ที่ได้รับ',
  DH0105: 'ต้องยืนยันแบบบันทึกคำแนะนำการเลิกบุหรี่ (smoking cessation counseling) ในผู้ป่วย ACS',
  DH0106: 'ต้องยืนยันการบริหารยากลุ่ม Beta-blocker ระหว่างรับไว้รักษาในโรงพยาบาล',
  DH0107: 'ต้องยืนยันรายการยา Beta-blocker ที่สั่งจ่าย ณ วันจำหน่าย',
  DH0108: 'ต้องยืนยัน timestamp เวลาถึงโรงพยาบาล (door time) และเวลาทำ EKG 12-lead แผ่นแรก',
  DH0109: 'ต้องยืนยัน door-to-refer timestamp และเวลาส่งตัวผู้ป่วย ACS',
  DH0110: 'ต้องยืนยัน door-to-balloon time ภายใน 120 นาที หรือ door-to-needle time ภายใน 30 นาที',
  DH0113: 'ต้องยืนยัน door-to-needle timestamp ในการให้ยาละลายลิ่มเลือด (Fibrinolytic) ภายใน 30 นาที',
  // Stroke acute therapies, education, and rehab
  DN0102: 'ต้องยืนยันการบริหารยา Antiplatelet ภายใน 2 วัน (48 ชั่วโมง) แรกหลังรับไว้รักษา',
  DN0103: 'ต้องยืนยันรายการยา Antiplatelet หรือ Anticoagulant ที่สั่งจ่าย ณ วันจำหน่าย',
  DN0104: 'ต้องยืนยันผล EKG ภาวะ Atrial Fibrillation/Flutter และการสั่งจ่ายยา Anticoagulation',
  DN0105: 'ต้องยืนยันแบบประเมินและบันทึกการให้สุขศึกษาโรคหลอดเลือดสมอง (Stroke education)',
  DN0106: 'ต้องยืนยันบันทึกการเริ่มทำกายภาพบำบัดหรือเวชศาสตร์ฟื้นฟูภายใน 72 ชั่วโมงหลังรับไว้รักษา',
  DN0110: 'ต้องยืนยัน door-to-needle timestamp ในการให้ยา Thrombolytic (rtPA) ภายใน 60 นาที',
  // Pneumonia smoking cessation
  DR0103: 'ต้องยืนยันแบบบันทึกคำแนะนำการเลิกบุหรี่ (smoking cessation counseling) ในผู้ป่วยปอดอักเสบ',
  // Maternal & Perinatal mortality population denominators
  CM0101: 'ต้องยืนยัน mother-infant linkage และฐานข้อมูลการเกิดมีชีพ (live births) ในพื้นที่รับผิดชอบ',
  CM0201: 'ต้องยืนยันการบันทึกอายุครรภ์ >= 24 สัปดาห์ และการจำแนกทารกตายคลอด (stillbirth)',
  CM0202: 'ต้องยืนยันการบันทึกอายุครรภ์ >= 28 สัปดาห์ และการเสียชีวิตของทารกภายใน 7 วันหลังคลอด',
  CM0203: 'ต้องยืนยันฐานข้อมูลการเกิดมีชีพ (live births) และการเสียชีวิตของทารกภายใน 28 วันหลังคลอด',
  // Newborn screening
  DE1601: 'ต้องยืนยันเครื่องมือตรวจคัดกรองการได้ยิน (OAE/AABR) และบันทึกผลภายใน 30 วันหลังเกิด',
  // ACSC population denominators and criteria
  AA0101: 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และเกณฑ์คัดแยก Epilepsy ACSC',
  AA0102: 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และเกณฑ์คัดแยก Asthma ACSC',
  AA0103: 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และเกณฑ์คัดแยก COPD ACSC',
  AA0104: 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และการคัดแยกภาวะแทรกซ้อน DM ACSC',
  AA0105: 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และการคัดแยกภาวะแทรกซ้อน HT ACSC',
  // Non-urgent ED & follow-up
  HC0101: 'ต้องยืนยันระดับความเร่งด่วน triage ของห้องฉุกเฉิน (Non-urgent triage) และเกณฑ์ Asthma/COPD',
  HC0102: 'ต้องยืนยันนัดตรวจติดตาม OPD follow-up ภายใน 30 วันหลังจำหน่าย',
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
  if (pendingReasonByCode[code]) return pendingReasonByCode[code];
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
