import { groupMeta } from '@/data/thipMeta';
import { getRuleUnit, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { getReportingCadence, reportingCadenceLabels } from '@/data/thipReporting';
import type { FiscalYear, Indicator, IndicatorGroup, MonthlyResult } from '@/types/thip';
import { getCurrentFiscalYear, getFiscalMonthPeriods } from '@/utils/fiscal';

export type ThipCatalogueEntry = {
  code: string;
  group: IndicatorGroup;
  title: string;
  titleTh: string;
};

// Extracted from the 232 indicator entries listed in THIP KPI Dictionary 2025.
// Reporting-period observations are intentionally not fabricated; un-wired entries render as no-data.
export const thipCatalogue: readonly ThipCatalogueEntry[] = [
  {
    "code": "AA0101",
    "group": "A",
    "title": "Epilepsy: Hospitalization rate",
    "titleTh": "อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคลมชัก)"
  },
  {
    "code": "AA0102",
    "group": "A",
    "title": "COPD: Hospitalization rate",
    "titleTh": "อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคปอดอุดกั้น เรื้อรัง)"
  },
  {
    "code": "AA0103",
    "group": "A",
    "title": "Asthma: Hospitalization rate",
    "titleTh": "อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคหืด)"
  },
  {
    "code": "AA0104",
    "group": "A",
    "title": "Diabetes Mellitus (DM): Hospitalization rate",
    "titleTh": "อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคเบาหวาน)"
  },
  {
    "code": "AA0105",
    "group": "A",
    "title": "Hypertension: Hospitalization rate",
    "titleTh": "อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคความดัน โลหิตสูง)"
  },
  {
    "code": "CA0101",
    "group": "C",
    "title": "Anesthesia: Intra-operative cardiac arrest ASA physical status I, II",
    "titleTh": "อัตราการเกิดภาวะหัวใจหยุดเต้นระหว่างผ่าตัดในผู้ป่วยที่มีระดับ ASA physical status I, II ก่อนผ่าตัด"
  },
  {
    "code": "CA0102",
    "group": "C",
    "title": "Anesthesia: Percent of pre-anesthetic visit elective in-patient cases",
    "titleTh": "ร้อยละของการเยี่ยมผู้ป่วยก่อนการให้ยาระงับความรู้สึกในผู้ป่วยในที่รับการผ่าตัดแบบไม่ ฉุกเฉิน"
  },
  {
    "code": "CA0103",
    "group": "C",
    "title": "Anesthesia: Percent of patients observed in recovery room",
    "titleTh": "ร้อยละของผู้ป่วยที่รับการให้ยาระงับความรู้สึกที่ได้รับการดูแลในห้องพักฟื้น"
  },
  {
    "code": "CA0104",
    "group": "C",
    "title": "Anesthesia: Percent of re-intubation within 2 hours after extubation",
    "titleTh": "ร้อยละของผู้ป่วยได้รับการใส่ท่อหายใจซ้ำภายใน 2 ชั่วโมงหลังการถอดท่อหายใจ"
  },
  {
    "code": "CA0105",
    "group": "C",
    "title": "Anesthesia: Percent of using capnometry during general anesthesia",
    "titleTh": "ร้อยละของผู้ป่วยที่ดมยาสลบได้รับการเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ ในลมหายใจออก"
  },
  {
    "code": "CE0101",
    "group": "C",
    "title": "Sepsis: Percent of broad-spectrum antibiotic receiving within 3 hours",
    "titleTh": "ร้อยละผู้ป่วยห้องฉุกเฉินที่มีภาวะติดเชื้อในกระแสโลหิตได้รับยาต้านจุลชีพ ภายใน 3 ชั่วโมง"
  },
  {
    "code": "CE0102",
    "group": "C",
    "title": "ER: Average Emergency Department (ED) TIME-IN, TIME-OUT",
    "titleTh": "ค่าเฉลี่ยระยะเวลาการเข้ารับ-ออกจากบริการของผู้ป่วยที่มารับบริการที่ห้องฉุกเฉิน"
  },
  {
    "code": "CE0103",
    "group": "C",
    "title": "ER: Percent of Emergency patients recieveing emergency service (ED TIME-IN, TIME-OUT) within 60 minutes",
    "titleTh": "ร้อยละของผู้ป่วยฉุกเฉินมากที่ได้รับบริการที่ห้องฉุกเฉินระยะเวลาภายใน 60 นาที"
  },
  {
    "code": "CE0104",
    "group": "C",
    "title": "Sepsis: Percent of broad-spectrum antibiotic received within 1 hour in emergency room",
    "titleTh": "ร้อยละผู้ป่วยห้องฉุกเฉิน ที่มีภาวะติดเชื้อในกระแสโลหิตได้รับยาต้านจุลชีพภายใน 1 ชั่วโมง"
  },
  {
    "code": "CG0101",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Rate of Pressure ulcer",
    "titleTh": "อัตราการเกิดแผลกดทับในโรงพยาบาล"
  },
  {
    "code": "CG0102",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Rate of Pressure ulcer in risk patients",
    "titleTh": "อัตราการเกิดแผลกดทับในโรงพยาบาลในผู้ป่วยกลุ่มเสี่ยง"
  },
  {
    "code": "CG0103",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury",
    "titleTh": "อัตราความชุกของแผลกดทับ"
  },
  {
    "code": "CG0104",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury (HAPI) rate",
    "titleTh": "อัตราความชุกของแผลกดทับที่เกิดในโรงพยาบาล"
  },
  {
    "code": "CI0101",
    "group": "C",
    "title": "Sepsis: Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยในจากภาวะติดเชื้อในกระแสโลหิต"
  },
  {
    "code": "CM0101",
    "group": "C",
    "title": "Maternal: Mortality rate of mother from pregnancy and/or labour",
    "titleTh": "สัดส่วนการตายของมารดาจากการตั้งครรภ์ และ/หรือการคลอด (ต่อแสนทารกเกิดมีชีพ)"
  },
  {
    "code": "CM0104",
    "group": "C",
    "title": "Maternal: Percent of unplanned re-admission of caesarean section within 28 days",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้คลอด Caesarean section ภายใน 28 วัน โดย ไม่ได้วางแผน"
  },
  {
    "code": "CM0105",
    "group": "C",
    "title": "Maternal: Average length of stay of caesarean section",
    "titleTh": "ระยะเวลาวันนอนเฉลี่ยของผู้คลอดโดยการผ่าตัดคลอดทางหน้าท้อง"
  },
  {
    "code": "CM0107",
    "group": "C",
    "title": "Maternal: Percent of immediate postpartum hemorrhage (Vaginal delivery)",
    "titleTh": "ร้อยละการตกเลือดหลังคลอดเฉียบพลันกรณีคลอดทางช่องคลอด"
  },
  {
    "code": "CM0109",
    "group": "C",
    "title": "Maternal: Percent of eclampsia in pregnancy induce Hypertension",
    "titleTh": "ร้อยละการชักขณะตั้งครรภ์ คลอดหรือหลังคลอด"
  },
  {
    "code": "CM0110",
    "group": "C",
    "title": "Maternal: Percent of gestational DM",
    "titleTh": "อัตราหญิงตั้งครรภ์ที่มีภาวะเบาหวาน"
  },
  {
    "code": "CM0116",
    "group": "C",
    "title": "hysterectomy Maternal: Percent of patients who received antibiotic prophylaxis in abdominal hysterectomy",
    "titleTh": "ร้อยละการได้รับ prophylactic antibiotic ในการผ่าตัด abdominal hysterectomy"
  },
  {
    "code": "CM0117",
    "group": "C",
    "title": "Maternal: Percent of abdominal hysterectomy associated infection",
    "titleTh": "ร้อยละการติดเชื้อแผลผ่าตัด Abdominal hysterectomy"
  },
  {
    "code": "CM0118",
    "group": "C",
    "title": "Maternal: Percent of primary cesarean section",
    "titleTh": "ร้อยละการผ่าตัดคลอดบุตรปฐมภูมิของโรงพยาบาล"
  },
  {
    "code": "CM0119",
    "group": "C",
    "title": "Maternal: Percent of cesarean section with Pdx = O80-O84 and Sdx = O80-O84 (NHSO health service indicator)",
    "titleTh": "ร้อยละการผ่าตัดคลอดบุตรทั้งหมดของโรงพยาบาล"
  },
  {
    "code": "CM0201",
    "group": "C",
    "title": "Child: Perinatal mortality rate (24 weeks)",
    "titleTh": "อัตราการตายปริกำเนิด (อายุครรภ์ตั้งแต่ 24 สัปดาห์)"
  },
  {
    "code": "CM0202",
    "group": "C",
    "title": "Child: Perinatal mortality rate (28 weeks)",
    "titleTh": "อัตราการตายปริกำเนิด (อายุครรภ์ตั้งแต่ 28 สัปดาห์)"
  },
  {
    "code": "CM0203",
    "group": "C",
    "title": "Child: Neonatal mortality rate",
    "titleTh": "อัตราการตายของทารกแรกเกิด"
  },
  {
    "code": "CM0204",
    "group": "C",
    "title": "Child: Birth asphyxia rate",
    "titleTh": "อัตราการขาดออกซิเจนในทารกแรกเกิด"
  },
  {
    "code": "CM0205",
    "group": "C",
    "title": "Child: Severe birth asphyxia rate",
    "titleTh": "อัตราการขาดออกซิเจนรุนแรงในทารกแรกเกิด"
  },
  {
    "code": "CM0206",
    "group": "C",
    "title": "Child: Percent of low birth weight < 2500 grams",
    "titleTh": "ร้อยละทารกแรกเกิดน้ำหนักต่ำกว่า 2,500 กรัม"
  },
  {
    "code": "CM0207",
    "group": "C",
    "title": "Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days",
    "titleTh": "ร้อยละการเสียชีวิตในโรงพยาบาลของทารกแรกเกิดน้ำหนักต่ำกว่า 1,000 กรัมภายใน 28 วัน"
  },
  {
    "code": "CM0208",
    "group": "C",
    "title": "Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days",
    "titleTh": "ร้อยละการเสียชีวิตในโรงพยาบาลของทารกแรกเกิดน้ำหนัก 1,000-1,499 กรัม ภายใน 28 วัน"
  },
  {
    "code": "CM0209",
    "group": "C",
    "title": "Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days",
    "titleTh": "ร้อยละการเสียชีวิตในโรงพยาบาลของทารกแรกเกิดน้ำหนัก 1,500 - 2,499 กรัมภายใน 28 วัน"
  },
  {
    "code": "CO0101",
    "group": "C",
    "title": "Operation: Percent of using surgical safety check list",
    "titleTh": "ร้อยละของการใช้แบบตรวจสอบเพื่อความปลอดภัยของผู้ป่วยเมื่อมารับการตรวจรักษา ในห้องผ่าตัด"
  },
  {
    "code": "CO0105",
    "group": "C",
    "title": "Operation: Percent of peri-operative mortality within 24 hours",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยผ่าตัดใน 24 ชั่วโมง"
  },
  {
    "code": "CO0107",
    "group": "C",
    "title": "Operation: Percent of re-operation",
    "titleTh": "ร้อยละการผ่าตัดซ้ำ"
  },
  {
    "code": "CP0101",
    "group": "C",
    "title": "Percent of carers of children with ADHD/LD/MDD having good compliance to treatment",
    "titleTh": "ร้อยละผู้ปกครองของเด็กสมาธิสั้น/LD/MDD รายใหม่ที่มารับการบำบัดรักษาในรอบ 6 เดือน และมารับการรักษาตามนัด"
  },
  {
    "code": "CP0201",
    "group": "C",
    "title": "Percent of children with Neurodevelopmental Disorder being diagnosed within 90 days after registration",
    "titleTh": "ร้อยละเด็กที่สงสัยโรคในกลุ่มพัฒนาการได้รับการวินิจฉัยภายใน 90 วัน"
  },
  {
    "code": "DC0103",
    "group": "D",
    "title": "DM: Percent of diabetic retinopathy screening",
    "titleTh": "ร้อยละของผู้ป่วยเบาหวานได้รับการคัดกรองเบาหวานเข้าจอประสาทตา"
  },
  {
    "code": "DC0107",
    "group": "D",
    "title": "DM: Percent of lower-extremity amputation among patients with diabetes",
    "titleTh": "ร้อยละผู้ป่วยเบาหวานได้รับการตัดขาจากภาวะแทรกซ้อนของโรคเบาหวาน"
  },
  {
    "code": "DC0108",
    "group": "D",
    "title": "DM: Percent of good controlled of blood sugar in adult",
    "titleTh": "ร้อยละของผู้ป่วยเบาหวานผู้ใหญ่ที่ควบคุมระดับน้ำตาลในเลือดได้ดี"
  },
  {
    "code": "DC0108.1",
    "group": "D",
    "title": "DM: Percent of good controlled of blood sugar in adult aged ≥ 60 years old",
    "titleTh": "ร้อยละของผู้ป่วยเบาหวานผู้ใหญ่อายุเกินกว่า 60 ปี ที่ควบคุมระดับน้ำตาลในเลือดได้ดี"
  },
  {
    "code": "DC0108.2",
    "group": "D",
    "title": "DM: Percent of good controlled of blood sugar in adult aged < 60 years old",
    "titleTh": "ร้อยละของผู้ป่วยเบาหวานผู้ใหญ่อายุน้อยกว่า 60 ปี ที่ควบคุมระดับน้ำตาลในเลือดได้ดี"
  },
  {
    "code": "DC0201",
    "group": "D",
    "title": "HT: Percent of good controlled of blood pressure",
    "titleTh": "ร้อยละผู้ป่วยความดันโลหิตสูงที่ควบคุมความดันโลหิตได้ดี"
  },
  {
    "code": "DC0201.1",
    "group": "D",
    "title": "HT: Percent of good controlled of blood pressure of patient aged < 65 years old",
    "titleTh": "ร้อยละผู้ป่วยความดันโลหิตสูงอายุน้อยกว่า 65 ปี ที่ควบคุมความดันโลหิตได้ดี"
  },
  {
    "code": "DC0201.2",
    "group": "D",
    "title": "HT: Percent of good controlled of blood pressure of patient aged ≥ 65 years old",
    "titleTh": "ร้อยละผู้ป่วยความดันโลหิตสูงอายุเกินกว่า 65 ปี ที่ควบคุมความดันโลหิตได้ดี"
  },
  {
    "code": "DC0301",
    "group": "D",
    "title": "HIV: Percent of people living with HIV with at least one test viral load (VL) after ARV treatment",
    "titleTh": "ร้อยละของผู้ติดเชื้อเอชไอวีที่กินยาต้านไวรัส ได้รับการตรวจ Viral load (VL) อย่างน้อย 1 ครั้งต่อปี"
  },
  {
    "code": "DC0302",
    "group": "D",
    "title": "HIV: Percent of people living with HIV with viral load (VL) < 50 copies/ml after ARV treatment 12 months ago",
    "titleTh": "ร้อยละของผู้ติดเชื้อเอชไอวีที่มี Viral load (VL) < 50 copies/ml หลังจากกินยาต้านไวรัส มาแล้ว 12 เดือน"
  },
  {
    "code": "DC0306",
    "group": "D",
    "title": "HIV: Percent of people living with HIV screening PAP smear",
    "titleTh": "ร้อยละของผู้ติดเชื้อเอชไอวีเพศหญิงได้รับการคัดกรองมะเร็งปากมดลูก"
  },
  {
    "code": "DC0307",
    "group": "D",
    "title": "HIV: Percent of people living with HIV newly registered who were tested for syphilis",
    "titleTh": "ร้อยละของผู้ติดเชื้อเอชไอวีรายใหม่ที่ได้รับการตรวจคัดกรองโรคซิฟิลิส"
  },
  {
    "code": "DC0308",
    "group": "D",
    "title": "HIV: Percent of people living with HIV who were currently receiving antiretroviral therapy",
    "titleTh": "ร้อยละของผู้ติดเชื้อเอชไอวี/เอดส์ที่ได้รับการรักษาด้วยยาต้านไวรัส ณ ปัจจุบัน"
  },
  {
    "code": "DC0309",
    "group": "D",
    "title": "HIV: Percent of newly diagnosed people living with HIV were receiving tuberculosis preventive therapy (TPT)",
    "titleTh": "ร้อยละของผู้ติดเชื้อเอชไอวีรายใหม่ที่มีข้อบ่งชี้ในการรับยาป้องกันวัณโรค (Tuberculosis preventive therapy, TPT) ได้รับยา TPT"
  },
  {
    "code": "DC0401",
    "group": "D",
    "title": "Cancer: Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยโรคมะเร็ง"
  },
  {
    "code": "DC0402",
    "group": "D",
    "title": "Cancer: Percent of unplanned re-admission",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลก่อนวันนัดโดยไม่ได้วางแผนของผู้ป่วยมะเร็ง"
  },
  {
    "code": "DC0403",
    "group": "D",
    "title": "Liver Cancer: Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตด้วยโรคมะเร็งตับ"
  },
  {
    "code": "DC0501",
    "group": "D",
    "title": "CKD: Percent of patients who achieve the kidney function deterioration delayed target",
    "titleTh": "ร้อยละของผู้ป่วยโรคไตเรื้อรังที่สามารถชะลอความเสื่อมของไตได้ตามเป้าหมาย"
  },
  {
    "code": "DC0502",
    "group": "D",
    "title": "CKD: Percent of patients who are receiving ACEIs or ARBs",
    "titleTh": "ร้อยละของผู้ป่วยโรคไตเรื้อรังที่ได้รับยา ACEIs หรือ ARBs"
  },
  {
    "code": "DE0101",
    "group": "D",
    "title": "Breast Cancer: Consultation time in patient with BIRADS 4 or greater mammography result",
    "titleTh": "ระยะเวลาการรอตรวจภายหลังการส่งปรึกษาของผู้ป่วยที่มีผลเมมโมแกรมตั้งแต่ BI-RADS 4 ขึ้นไป"
  },
  {
    "code": "DE0103",
    "group": "D",
    "title": "Breast Cancer: Percent of early diagnosis of stage 1, 2",
    "titleTh": "ร้อยละการตรวจพบผู้ป่วยมะเร็งเต้านมระยะแรก Stage 1, 2"
  },
  {
    "code": "DE0501",
    "group": "D",
    "title": "Stem Cell Transplantation: Engraftment rate within 45 days",
    "titleTh": "อัตราการปลูกถ่ายติด (engraftment) ของผู้ป่วย Stem cell transplantation ภายใน 45 วัน หลังการปลูกถ่ายไขกระดูก"
  },
  {
    "code": "DE0801",
    "group": "D",
    "title": "TDT in Pediatrics Patient: Percent of received iron chelator in patient with iron overload (serum ferrous > 1000 ug/L)",
    "titleTh": "ร้อยละของผู้ป่วย transfusion dependent thalassemia (TDT) ที่อายุมากกว่า 2 ปี และถึง 15 ปี มีภาวะธาตุเหล็กเกิน (Serum ferritin > 1000 ug/L) ที่ได้รับยาขับธาตุเหล็ก"
  },
  {
    "code": "DE1201",
    "group": "D",
    "title": "Cleft Lip: Percent of patients who had cleft lip repair with under 6 months of age",
    "titleTh": "ร้อยละผู้ป่วยที่เข้ารับการผ่าตัดซ่อมแซมปากแหว่งตามเกณฑ์ช่วงอายุไม่เกิน 6 เดือน"
  },
  {
    "code": "DE1202",
    "group": "D",
    "title": "Cleft Palate: Percent of patients who had cleft Palate repair with under 18 months of age",
    "titleTh": "ร้อยละผู้ป่วยที่เข้ารับการผ่าตัดซ่อมแซมเพดานโหว่ตามช่วงอายุไม่เกิน 18 เดือน"
  },
  {
    "code": "DE1301",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per Embryo Transfer following IVF/ICSI and Fresh embryo transfer (age < 34 years)",
    "titleTh": "อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบสด (กลุ่มอายุน้อยกว่า 34 ปี)"
  },
  {
    "code": "DE1302",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age 34 - 39 Years)",
    "titleTh": "อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบสด (กลุ่มอายุ 34 - 39 ปี)"
  },
  {
    "code": "DE1303",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age > 40 years)",
    "titleTh": "อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบสด (กลุ่มอายุ 40 ปีขึ้นไป)"
  },
  {
    "code": "DE1304",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years)",
    "titleTh": "อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุน้อยกว่า 34 ปี)"
  },
  {
    "code": "DE1305",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age 34 - 39 years)",
    "titleTh": "อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุ 34 - 39 ปี)"
  },
  {
    "code": "DE1306",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)",
    "titleTh": "อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุ 40 ปีขึ้นไป)"
  },
  {
    "code": "DE1401",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Percent of patients who had underwent EGD within 24 hours",
    "titleTh": "ร้อยละผู้ป่วย Upper GI hemorrhage (UGIH) ได้รับการส่องกล้องภายใน 24 ชั่วโมง"
  },
  {
    "code": "DE1402",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Percent of high risk patients who had underwent EGD within 24 hours",
    "titleTh": "ร้อยละผู้ป่วย Upper GI hemorrhage (UGIH) กลุ่ม high risk ได้รับการส่องกล้องทางเดิน อาหารส่วนต้น ภายใน 24 ชั่วโมง"
  },
  {
    "code": "DE1403",
    "group": "D",
    "title": "Non-variceal Upper Gastrointestinal Hemorrhage (UGIH): Percent of hemostatic success by endoscopic approach",
    "titleTh": "ร้อยละผู้ป่วย Non-variceal UGIH สามารถหยุดเลือดด้วยวิธีการส่องกล้องได้สำเร็จ"
  },
  {
    "code": "DE1404",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Recurrent rates of UGIH after upper endoscopic treatment",
    "titleTh": "ร้อยละผู้ป่วยที่เกิดภาวะเลือดออกซ้ำจากแผลในระบบทางเดินอาหารส่วนต้นภายหลังจาก การหยุดเลือดด้วยการส่องกล้อง"
  },
  {
    "code": "DE1405",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Complication rates of upper endoscopic treatment",
    "titleTh": "อัตราการเกิดภาวะแทรกซ้อนจากการส่องกล้องทางเดินอาหารส่วนต้นเพื่อรักษา UGIH"
  },
  {
    "code": "DE1601",
    "group": "D",
    "title": "New born: Percent of hearing screening within 30 days",
    "titleTh": "ร้อยละของทารกแรกเกิดที่ได้รับการตรวจคัดกรองการได้ยิน ภายใน 30 วัน"
  },
  {
    "code": "DG0101",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Percent of unplanned re-admission into the hospital within 28 days after last discharge",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย Upper GI Hemorrhage ภายใน 28 วัน โดย ไม่ได้วางแผน"
  },
  {
    "code": "DG0102",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Average length of stay",
    "titleTh": "ระยะเวลาวันนอนเฉลี่ยผู้ป่วย Upper GI hemorrhage (UGIH)"
  },
  {
    "code": "DG0201",
    "group": "D",
    "title": "Acute Appendicitis: Percent of abruption",
    "titleTh": "ร้อยละการเกิดไส้ติ่งทะลุในผู้ป่วยโรคไส้ติ่งอักเสบ"
  },
  {
    "code": "DG0202",
    "group": "D",
    "title": "Acute Appendicitis: Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตจากไส้ติ่งอักเสบ"
  },
  {
    "code": "DH0101",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน"
  },
  {
    "code": "DH0101.1",
    "group": "D",
    "title": "Acute coronary syndrome (STEMI): Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI)"
  },
  {
    "code": "DH0101.2",
    "group": "D",
    "title": "Acute coronary syndrome (NSTE-ACS): Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS)"
  },
  {
    "code": "DH0102",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of patient receiving Aspirin within",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่ได้รับยา Aspirin ภายใน 24 ชั่วโมงเมื่อมาถึง โรงพยาบาล"
  },
  {
    "code": "DH0103",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Aspirin prescribed at discharge",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับการสั่งยา Aspirin เมื่อจำหน่ายออก จากโรงพยาบาล"
  },
  {
    "code": "DH0104",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of ACE inhibitors or ARB received for patient who have LVSD",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่มี LVSD และได้รับยา ACE inhibitors หรือ ARBs"
  },
  {
    "code": "DH0105",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of smoking cessation advice given",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่สูบบุหรี่และได้รับการแนะนำให้งดบุหรี่ ระหว่างการอยู่โรงพยาบาล"
  },
  {
    "code": "DH0106",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Beta-blocker receiving during hospital admitted",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับยา Beta-blocker ระหว่างรับไว้รักษา ในโรงพยาบาล"
  },
  {
    "code": "DH0107",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Beta-blocker prescribed at discharge",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับการสั่งยา Beta-blocker เมื่อจำหน่าย จากโรงพยาบาล"
  },
  {
    "code": "DH0108",
    "group": "D",
    "title": "Acute coronary syndrome: Average door to EKG time",
    "titleTh": "ระยะเวลาเฉลี่ยที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับการทำ EKG เมื่อมาถึง โรงพยาบาล"
  },
  {
    "code": "DH0109",
    "group": "D",
    "title": "Acute coronary syndrome: Average door to refer time",
    "titleTh": "ระยะเวลาเฉลี่ยที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน มาถึงโรงพยาบาลจนได้รับการส่งต่อ"
  },
  {
    "code": "DH0110",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Primary Percutaneous Coronary Intervention (PCI) given within 120 minutes or received Fibrinolytic agent within 30 minutes of arrival",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น (STEMI) ที่ได้รับ Primary Percutaneous Coronary Intervention (PPCI) ภายใน 120 นาที หรือ Fibrinolytic Agent ภายใน 30 นาทีเมื่อแรกรับ"
  },
  {
    "code": "DH0111",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of unplanned re-admission within",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ภายใน 28 วัน โดยไม่ได้วางแผน"
  },
  {
    "code": "DH0112",
    "group": "D",
    "title": "Acute coronary syndrome: Average length of stay",
    "titleTh": "ระยะเวลาวันนอนเฉลี่ยผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน"
  },
  {
    "code": "DH0113",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of time to Fibrinolytic administration agents within 30 minutes of arrival",
    "titleTh": "ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น (STEMI) ที่ได้รับ Fibrinolytic agent ภายใน 30 นาทีเมื่อมาถึงโรงพยาบาล"
  },
  {
    "code": "DH0201",
    "group": "D",
    "title": "Coronary Artery Bypass Graft (CABG): Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยที่ทำ Coronary Artery Bypass Graft (CABG)"
  },
  {
    "code": "DH0202",
    "group": "D",
    "title": "Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis",
    "titleTh": "ร้อยละการได้รับยาปฏิชีวนะแบบป้องกันในการผ่าตัด Coronary Artery Bypass Graft (CABG)"
  },
  {
    "code": "DH0203",
    "group": "D",
    "title": "Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection",
    "titleTh": "ร้อยละการติดเชื้อแผลผ่าตัด Coronary Artery Bypass Graft (CABG)"
  },
  {
    "code": "DH0204",
    "group": "D",
    "title": "Coronary Artery Bypass Graft (CABG): percent of 30-days hospital mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยที่ทำCABG ภายใน30 วันหลังรับการรักษาแบบผู้ป่วยในวันแรก"
  },
  {
    "code": "DH0301",
    "group": "D",
    "title": "Fraction (HFREF) received Angiotensin II Converting Enzyme inhibitors (ACEIs) or Angiotensin II Receptor Blockers (ARBs) or Mineralocorticoid Receptor Antagonists (MRA)",
    "titleTh": "ร้อยละผู้ป่วยในที่มีหัวใจล้มเหลวที่เป็น Heart Failure Reduced Ejection Fraction (HFREF) ได้รับยา Angiotensin II Converting Enzyme inhibitors (ACEIs) หรือ Angiotensin II Receptor Blockers (ARBs) หรือ Mineralocorticoid Receptor Antagonists (MRA)"
  },
  {
    "code": "DH0302",
    "group": "D",
    "title": "Heart failure: Percent of smoking cessation advice given",
    "titleTh": "ร้อยละของผู้ป่วยที่มีภาวะหัวใจล้มเหลว ที่สูบบุหรี่ ได้รับการแนะนำให้งดบุหรี่ ระหว่างการ อยู่โรงพยาบาล"
  },
  {
    "code": "DH0401",
    "group": "D",
    "title": "Atrial fibrillation: Percent of patient received Warfarin within target",
    "titleTh": "ร้อยละของผู้ป่วย AF ได้รับยา Warfarin มีระดับ INR ตามเป้าหมายการรักษา"
  },
  {
    "code": "DH0402",
    "group": "D",
    "title": "Atrial Fibrillation: Percent of major bleeding (intracranial hemorrhage)",
    "titleTh": "ร้อยละของการเกิด adverse event (major bleeding) ของผู้ป่วย AF ที่ได้รับยา Warfarin"
  },
  {
    "code": "DM0101",
    "group": "D",
    "title": "GDD: Percent of children with global development delay that improved after intervented",
    "titleTh": "ร้อยละเด็กพัฒนาการล่าช้ารอบด้าน (Global development delay: GDD) มีพัฒนาการดี ขึ้น"
  },
  {
    "code": "DM0102",
    "group": "D",
    "title": "GDD: Percent of children with Global development delay that improved after intervented with TEDA4I",
    "titleTh": "ร้อยละเด็กพัฒนาการล่าช้ารอบด้าน (Global development delay: GDD) มีพัฒนาการดี ขึ้น จากการประเมินโดยใช้เครื่องมือ TEDA4I"
  },
  {
    "code": "DM0103",
    "group": "D",
    "title": "GDD: Percent of children with global development delay that improved after intervented",
    "titleTh": "ร้อยละเด็กพัฒนาการล่าช้ารอบด้าน (Global development delay: GDD) คงอยู่ใน ระบบการศึกษาได้อย่างน้อย 1 ปี"
  },
  {
    "code": "DM0201",
    "group": "D",
    "title": "ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement",
    "titleTh": "ร้อยละเด็กออทิสติกมีพัฒนาการด้านภาษาและสังคมดีขึ้น"
  },
  {
    "code": "DM0202",
    "group": "D",
    "title": "ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement with TEDA4I",
    "titleTh": "ร้อยละเด็กออทิสติกมีพัฒนาการด้านภาษาและสังคมดีขึ้น จากการประเมินโดยใช้เครื่องมือ TEDA4I"
  },
  {
    "code": "DM0203",
    "group": "D",
    "title": "ASD: Percent of children with autism spectrum disorder (ASD) that are included in educational system for at least 1 year",
    "titleTh": "ร้อยละเด็กออทิสติกคงอยู่ในระบบการศึกษาได้อย่างน้อย 1 ปี"
  },
  {
    "code": "DM0301",
    "group": "D",
    "title": "Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented",
    "titleTh": "ร้อยละผู้ป่วยเด็กสมองพิการ (Cerebral palsy) มีพัฒนาการดีขึ้น"
  },
  {
    "code": "DM0302",
    "group": "D",
    "title": "Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented",
    "titleTh": "ร้อยละผู้ป่วยเด็กสมองพิการ (Cerebral palsy) มีพัฒนาการดีขึ้น จากการประเมินโดยใช้ เครื่องมือ TEDA4I"
  },
  {
    "code": "DM0401",
    "group": "D",
    "title": "Child and adolescent psychiatry: Percent of children with Attention- Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6",
    "titleTh": "ร้อยละผู้ป่วยเด็กสมาธิสั้นรายใหม่อาการดีขึ้นภายใน 6 เดือน"
  },
  {
    "code": "DM0402",
    "group": "D",
    "title": "Child and adolescent psychiatry: Percent of children and adolescents with Major Depressive Disorder (MDD) improved after intervented for",
    "titleTh": "ร้อยละผู้ป่วยเด็กซึมเศร้าอาการดีขึ้นภายใน 6 เดือน"
  },
  {
    "code": "DN0101",
    "group": "D",
    "title": "Stroke: Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วย Stroke"
  },
  {
    "code": "DN0102",
    "group": "D",
    "title": "Ischemic stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission",
    "titleTh": "ร้อยละผู้ป่วยโรคสมองขาดเลือดที่ได้รับยาต้านเกล็ดเลือด (Antiplatelet) ภายใน 2 วัน หลังเข้ารับการรักษาในโรงพยาบาล"
  },
  {
    "code": "DN0103",
    "group": "D",
    "title": "Ischemic stroke: Percent of Antiplatelet or Anticoagulant therapy prescribed at discharge",
    "titleTh": "ร้อยละผู้ป่วยโรคหลอดเลือดสมองขาดเลือดที่ได้รับการสั่งยาต้านเกล็ดเลือด (Antiplatelet) หรือยาต้านภาวะแข็งตัวของเลือด (Anticoagulant) ขณะจำหน่ายออกจากโรงพยาบาล"
  },
  {
    "code": "DN0104",
    "group": "D",
    "title": "Ischemic stroke: Percent of patient with Atrial fibrillation/Flutter receiving Anticoagulation therapy",
    "titleTh": "ร้อยละผู้ป่วยโรคหลอดเลือดสมองขาดเลือดที่มีภาวะหัวใจห้องบนเต้นระริกหรือหัวใจห้อง บนเต้นระรัวได้รับยาต้านภาวะแข็งตัวของเลือด (Anticoagulant)"
  },
  {
    "code": "DN0105",
    "group": "D",
    "title": "Stroke: Percent of patients who were given stroke education during their hospital stay",
    "titleTh": "ร้อยละผู้ป่วยโรคหลอดเลือดสมองได้รับความรู้ในขณะอยู่ที่โรงพยาบาล"
  },
  {
    "code": "DN0106",
    "group": "D",
    "title": "Stroke: Percent of treatment, physiotherapy or rehabilitation in stroke or paralytic syndrome within 72 hours",
    "titleTh": "ร้อยละผู้ป่วยโรคหลอดเลือดสมองได้รับการประเมินและได้รับการรักษาด้านเวชศาสตร์ ฟื้นฟูเพื่อฟื้นฟูสมรรถภาพภายใน 72 ชั่วโมง"
  },
  {
    "code": "DN0107",
    "group": "D",
    "title": "Stroke: Percent of unplanned re-admission of stroke within 28 days",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย Stroke ด้วยโรคหลอดเลือดสมองเดิม ภายใน 28 วัน โดยไม่ได้วางแผน"
  },
  {
    "code": "DN0109",
    "group": "D",
    "title": "Stroke: Average length of stay",
    "titleTh": "ระยะเวลาวันนอนเฉลี่ยของผู้ป่วย Stroke"
  },
  {
    "code": "DN0110",
    "group": "D",
    "title": "Ischemic Stroke: Percent of time to Thrombolytic administration agents within 60 minutes of arrival",
    "titleTh": "ร้อยละผู้ป่วย Ischemic stroke ที่ได้รับ Thrombolytic agents ภายใน 60 นาที เมื่อ มาถึงโรงพยาบาล"
  },
  {
    "code": "DN0301",
    "group": "D",
    "title": "Head Injury: Percent of unplanned re-admission of Craniotomy within",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วยที่ทำ Craniotomy โดยมีสาเหตุจากการ บาดเจ็บที่ศีรษะ ภายใน 28 วัน โดยไม่ได้วางแผน"
  },
  {
    "code": "DN0302",
    "group": "D",
    "title": "Head Injury: Percent of mortality within 48 hours",
    "titleTh": "ร้อยละของผู้ป่วยบาดเจ็บที่ศีรษะที่เสียชีวิตภายใน 48 ชั่วโมง ภายหลังการบาดเจ็บ (เฉพาะผู้ป่วยบาดเจ็บต่อสมอง)"
  },
  {
    "code": "DN0303",
    "group": "D",
    "title": "Head Injury: Percent of patient underwent craniotomy for Intracranial",
    "titleTh": "ร้อยละการผ่าตัดสมองในผู้ป่วยบาดเจ็บที่ศีรษะที่มี Intracranial injury"
  },
  {
    "code": "DO0202",
    "group": "D",
    "title": "Hip arthroplasty: Percent of patients who received antibiotic prophylaxis in Hip arthroplasty",
    "titleTh": "ร้อยละของผู้ป่วยผ่าตัดเปลี่ยนข้อสะโพก ได้รับ prophylactic antibiotic"
  },
  {
    "code": "DO0204",
    "group": "D",
    "title": "Hip arthroplasty: Percent of hip arthroplasty associated infection within 1 Year",
    "titleTh": "ร้อยละการติดเชื้อแผลผ่าตัดเปลี่ยนข้อสะโพกภายใน 1 ปี"
  },
  {
    "code": "DO0205",
    "group": "D",
    "title": "Hip arthroplasty: Percent of hip arthroplasty associated infection within 90 days",
    "titleTh": "ร้อยละการติดเชื้อแผลผ่าตัดเปลี่ยนข้อสะโพกภายใน 90 วัน"
  },
  {
    "code": "DO0302",
    "group": "D",
    "title": "Knee Arthroplasty: Percent of patients who received antibiotic prophylaxis",
    "titleTh": "ร้อยละของผู้ป่วยผ่าตัดเปลี่ยนข้อเข่า ได้รับ prophylactic antibiotic"
  },
  {
    "code": "DO0303",
    "group": "D",
    "title": "Knee Arthroplasty: Percent of surgical infection within 1 year",
    "titleTh": "ร้อยละการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่าภายใน 1 ปี"
  },
  {
    "code": "DO0304",
    "group": "D",
    "title": "Knee Arthroplasty: Percent of surgical infection within 90 days",
    "titleTh": "ร้อยละการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่าภายใน 90 วัน"
  },
  {
    "code": "DP0101",
    "group": "D",
    "title": "Diabetes in child and adolescent: Percent of good controlled of blood sugar (age < 18 years)",
    "titleTh": "ร้อยละของผู้ป่วยเบาหวานชนิดที่ 1 ในเด็กและวัยรุ่นอายุน้อยกว่า 18 ปีที่ควบคุมระดับ น้ำตาลได้ดี"
  },
  {
    "code": "DR0101",
    "group": "D",
    "title": "Pneumonia: Percent of mortality after hospital admission",
    "titleTh": "ร้อยละการเสียชีวิตหลังจากเข้ารับการรักษาของผู้ป่วยโรคปอดบวม"
  },
  {
    "code": "DR0102",
    "group": "D",
    "title": "Pneumonia: Percent of unplanned re-admission within 28 days after last discharge",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วยโรคปอดบวมภายใน 28 วัน โดยไม่ได้วางแผน"
  },
  {
    "code": "DR0103",
    "group": "D",
    "title": "Pneumonia: Percent of smoking cessation advice given",
    "titleTh": "ร้อยละผู้ป่วยโรคปอดบวมได้รับคำแนะนำให้อดหรือเลิกบุหรี่ ระหว่างอยู่ในโรงพยาบาล"
  },
  {
    "code": "DR0201",
    "group": "D",
    "title": "TB: Percent of mortality during 12 months",
    "titleTh": "ร้อยละการเสียชีวิตของผู้ป่วยวัณโรคปอดในช่วง 12 เดือน"
  },
  {
    "code": "DR0202",
    "group": "D",
    "title": "TB: Percentage of people living with HIV having a TB screening",
    "titleTh": "ร้อยละของผู้ติดเชื้อเอชไอวี ได้รับการคัดกรองวัณโรคปอด"
  },
  {
    "code": "DR0203",
    "group": "D",
    "title": "TB: Percent of treatment success",
    "titleTh": "ร้อยละความสำเร็จการรักษาวัณโรค"
  },
  {
    "code": "DR0204",
    "group": "D",
    "title": "TB: Percent of TB having a HIV screening",
    "titleTh": "ร้อยละผู้ป่วยวัณโรคได้รับการตรวจคัดกรอง HIV"
  },
  {
    "code": "DR0205",
    "group": "D",
    "title": "Antiretroviral therapy (ART) TB: Percent of HIV-positive TB patients started on Antiretroviral therapy (ART)",
    "titleTh": "ร้อยละผู้ป่วยวัณโรคที่มีผลเลือดเอชไอวีบวกได้รับการรักษาด้วย Antiretroviral therapy (ART)"
  },
  {
    "code": "DR0301",
    "group": "D",
    "title": "Asthma: Percent of unplanned re-admission within 28 days after last discharge",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย Asthma ภายใน 28 วัน โดยไม่ได้วางแผน"
  },
  {
    "code": "DR0302",
    "group": "D",
    "title": "Asthma: Percent of smoking cessation advice given",
    "titleTh": "ร้อยละผู้ป่วย Asthma ได้รับคำแนะนำให้อดหรือเลิกบุหรี่ ระหว่างอยู่ในโรงพยาบาล"
  },
  {
    "code": "DR0401",
    "group": "D",
    "title": "COPD: Percent of unplanned re-admission into the hospital within 28 days after last discharge",
    "titleTh": "ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย COPD ภายใน 28 วัน โดยไม่ได้วางแผน"
  },
  {
    "code": "DR0403",
    "group": "D",
    "title": "COPD: Percent of mortality",
    "titleTh": "ร้อยละการเสียชีวิตจากโรคปอดอุดกั้นเรื้อรัง"
  },
  {
    "code": "DR0404",
    "group": "D",
    "title": "COPD: Percent of patient with ongoing smoking",
    "titleTh": "ร้อยละของผู้ป่วยโรคปอดอุดกั้นเรื้อรังที่ยังสูบบุหรี่"
  },
  {
    "code": "DS0101",
    "group": "D",
    "title": "Methamphetamine Group: 3 months total remission rate",
    "titleTh": "ร้อยละของผู้ติดยาเสพติดกลุ่ม Methamphetamine โดยรวมที่หยุดเสพต่อเนื่อง 3 เดือน"
  },
  {
    "code": "DS0201",
    "group": "D",
    "title": "Alcohol Group: 3 months total remission rate",
    "titleTh": "ร้อยละของผู้ติดสุราโดยรวม ที่หยุดเสพต่อเนื่อง 3 เดือน"
  },
  {
    "code": "DS0301",
    "group": "D",
    "title": "Tobacco Group: 3 months total remission rate",
    "titleTh": "ร้อยละของผู้ติดยาสูบโดยรวม ที่หยุดเสพต่อเนื่อง 3 เดือน"
  },
  {
    "code": "DS0401",
    "group": "D",
    "title": "Opioid Group: 1 year retention rate of opioid in methadone maintenance program",
    "titleTh": "อัตราคงอยู่ในการบำบัดรักษา 1 ปีด้วยเมทาโดนระยะยาว ของผู้ติดสารเสพติดในกลุ่ม opioid"
  },
  {
    "code": "HC0101",
    "group": "H",
    "title": "Customer: Asthma patients or their relative(s) who are able to care for the patient's needs",
    "titleTh": "ความสามารถในการดูแลตนเอง/การดูแลผู้ป่วยของญาติโรค Asthma"
  },
  {
    "code": "HC0102",
    "group": "H",
    "title": "Customer: COPD patients or their relative(s) who are able to care for the patient's needs",
    "titleTh": "ความสามารถในการดูแลตนเอง/ การดูแลผู้ป่วยของญาติโรค COPD"
  },
  {
    "code": "HE0101",
    "group": "H",
    "title": "Employee: Percent of employee check-up",
    "titleTh": "ร้อยละบุคลากรได้รับการตรวจร่างกายประจำปี"
  },
  {
    "code": "HE0102",
    "group": "H",
    "title": "Employee: Percent of employee have exceeding BMI",
    "titleTh": "ร้อยละบุคลากรที่มีดัชนีมวลกาย (BMI) เกินเกณฑ์มาตรฐาน"
  },
  {
    "code": "HE0103",
    "group": "H",
    "title": "Employee: Percent of employee have behavior-smoky",
    "titleTh": "ร้อยละบุคลากรที่มีพฤติกรรมการสูบบุหรี่"
  },
  {
    "code": "HE0104",
    "group": "H",
    "title": "Employee: Percent of employee (male) obesity",
    "titleTh": "ร้อยละบุคลากรเพศชายมีภาวะอ้วนลงพุง"
  },
  {
    "code": "HE0105",
    "group": "H",
    "title": "Employee: Percent of employee (female) obesity",
    "titleTh": "ร้อยละบุคลากรเพศหญิงมีภาวะอ้วนลงพุง"
  },
  {
    "code": "HE0106",
    "group": "H",
    "title": "Employee: Percent of employee received Influenza immunization",
    "titleTh": "ร้อยละบุคลากรได้รับวัคซีนไข้หวัดใหญ่"
  },
  {
    "code": "HH0101.1",
    "group": "H",
    "title": "Tobacco Use: Percent of smoking tobacco products used by service recipients",
    "titleTh": "ร้อยละการคัดกรองสถานะการบริโภคยาสูบของผู้รับบริการที่มีอายุ 15 ปีขึ้นไปที่มาใช้ บริการผู้ป่วยนอกของสถานพยาบาล"
  },
  {
    "code": "HH0101.2",
    "group": "H",
    "title": "Tobacco Use: Percent of Tobacco Use Screened of Service Recipients aged ≥ 15 years old at the Outpatient Service.",
    "titleTh": "ร้อยละการคัดกรองสถานะการบริโภคยาสูบของผู้รับบริการที่มีอายุ 15 ปีขึ้นไปที่มาใช้ บริการผู้ป่วยในของสถานพยาบาล"
  },
  {
    "code": "HH0102",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence patients receiving nicotine dependence treatment.",
    "titleTh": "ร้อยละของผู้รับบริการที่มีภาวะติดนิโคตินที่ได้รับบริการบำบัดภาวะติดนิโคติน"
  },
  {
    "code": "HH0103.1",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in DM patients receiving nicotine dependence treatment.",
    "titleTh": "ร้อยละของผู้รับบริการกลุ่มโรคเบาหวานที่มีภาวะติดนิโคตินและได้รับบริการบำบัดภาวะติด นิโคติน"
  },
  {
    "code": "HH0103.2",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Hypertension patients receiving nicotine dependence treatment.",
    "titleTh": "ร้อยละของผู้รับบริการกลุ่มโรคความดันโลหิตสูงที่มีภาวะติดนิโคตินและได้รับบริการบำบัด ภาวะติดนิโคติน"
  },
  {
    "code": "HH0103.3",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment",
    "titleTh": "ร้อยละของผู้รับบริการกลุ่มโรคหืดที่มีภาวะติดนิโคตินและได้รับบริการบำบัดภาวะติด นิโคติน"
  },
  {
    "code": "HH0103.4",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in COPD patients receiving nicotine dependence treatment.",
    "titleTh": "ร้อยละของผู้รับบริการกลุ่มโรคถุงลมโป่งพองที่มีภาวะติดนิโคตินและได้รับบริการบำบัด ภาวะติดนิโคติน"
  },
  {
    "code": "HH0103.5",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Pregnant patients receiving nicotine dependence treatment.",
    "titleTh": "ร้อยละของผู้รับบริการกลุ่มหญิงตั้งครรภ์ที่มีภาวะติดนิโคตินและได้รับบริการบำบัดภาวะติด นิโคติน"
  },
  {
    "code": "HH0103.6",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment.",
    "titleTh": "ร้อยละของผู้รับบริการกลุ่มโรคถุงลมโป่งพองที่มีภาวะติดนิโคตินและได้รับบริการบำบัด ภาวะติดนิโคติน"
  },
  {
    "code": "HH0104.1",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (DM Patients)",
    "titleTh": "ร้อยละของผู้ป่วยกลุ่มโรคเบาหวานที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถ หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน"
  },
  {
    "code": "HH0104.2",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (Hypertension Patients)",
    "titleTh": "ร้อยละของผู้ป่วยกลุ่มโรคความดันโลหิตสูงที่รับบริการบำบัดรักษาภาวะติดนิโคตินและ สามารถหยุดบริโภคยาสูบต่อเนื่อง 6 เดือน"
  },
  {
    "code": "HH0104.3",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (Asthma Patients)",
    "titleTh": "ร้อยละของผู้ป่วยกลุ่มโรคหืดที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถหยุด บริโภคยาสูบต่อเนื่อง 6 เดือน"
  },
  {
    "code": "HH0104.4",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (COPD Patients)",
    "titleTh": "ร้อยละของผู้ป่วยกลุ่มโรคถุงลมโป่งพองที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถ หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน"
  },
  {
    "code": "HH0104.5",
    "group": "H",
    "title": "Tobacco use: Tobacco use: continuous abstinence rate (CAR) at 6 months (Pregnant Patients)",
    "titleTh": "ร้อยละของผู้ป่วยกลุ่มหญิงตั้งครรภ์ที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถ หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน"
  },
  {
    "code": "SC0101",
    "group": "S",
    "title": "Customer: Percent of outpatient satisfaction (overall)",
    "titleTh": "ร้อยละความพึงพอใจของผู้ป่วยนอก (ภาพรวม)"
  },
  {
    "code": "SC0102",
    "group": "S",
    "title": "Customer: Percent of inpatient satisfaction (overall)",
    "titleTh": "ร้อยละความพึงพอใจของผู้ป่วยใน (ภาพรวม)"
  },
  {
    "code": "SC0103",
    "group": "S",
    "title": "Customer: Percent of outpatients who return to receive care",
    "titleTh": "ร้อยละของผู้ป่วยนอกที่จะกลับมาใช้บริการซ้ำ"
  },
  {
    "code": "SC0104",
    "group": "S",
    "title": "Customer: Percent of inpatients who return to receive care",
    "titleTh": "ร้อยละของผู้ป่วยในที่จะกลับมาใช้บริการซ้ำ"
  },
  {
    "code": "SC0105",
    "group": "S",
    "title": "Customer: Percent of outpatients who would recommend friends or family to receive care at this facility",
    "titleTh": "ร้อยละผู้ป่วยนอกที่จะแนะนำญาติหรือคนรู้จักมาใช้บริการ"
  },
  {
    "code": "SC0106",
    "group": "S",
    "title": "Customer: Percent of inpatients who would recommend friends or family to receive care at this facility",
    "titleTh": "ร้อยละของผู้ป่วยในที่จะแนะนำญาติหรือคนรู้จักมาใช้บริการ"
  },
  {
    "code": "SF0101",
    "group": "S",
    "title": "Financial: Current ratio",
    "titleTh": "อัตราส่วนทุนหมุนเวียน"
  },
  {
    "code": "SF0102",
    "group": "S",
    "title": "Financial: Quick ratio",
    "titleTh": "อัตราส่วนทุนหมุนเวียนเร็ว (อัตราส่วนสินทรัพย์สภาพคล่อง)"
  },
  {
    "code": "SF0103",
    "group": "S",
    "title": "Financial: Fixed asset turnover",
    "titleTh": "อัตราหมุนเวียนของสินทรัพย์ถาวร"
  },
  {
    "code": "SF0104",
    "group": "S",
    "title": "Financial: Day in account receivable (average collection period for account receivables)",
    "titleTh": "ระยะเวลาถัวเฉลี่ยในการเรียกเก็บลูกหนี้ค่ารักษาสุทธิ"
  },
  {
    "code": "SF0105",
    "group": "S",
    "title": "Financial: Net profit margin",
    "titleTh": "อัตราส่วนระหว่างกำไรสุทธิ กับยอดขายสุทธิ"
  },
  {
    "code": "SF0106",
    "group": "S",
    "title": "Financial: Return on asset (ROA)",
    "titleTh": "อัตราผลตอบแทนจากสินทรัพย์รวม"
  },
  {
    "code": "SG0104",
    "group": "S",
    "title": "Governance: Percent of recycled waste",
    "titleTh": "สัดส่วนของขยะรีไซเคิล"
  },
  {
    "code": "SH0101",
    "group": "S",
    "title": "HRM: Turnover rate",
    "titleTh": "อัตราการลาออกของบุคลากร"
  },
  {
    "code": "SH0102",
    "group": "S",
    "title": "HRM: Percent of employee work-related Injury",
    "titleTh": "ร้อยละบุคลากรที่บาดเจ็บจากการทำงาน"
  },
  {
    "code": "SH0103",
    "group": "S",
    "title": "HRM: Percent of employee work-related Illness",
    "titleTh": "ร้อยละบุคลากรที่เจ็บป่วยจากการทำงาน"
  },
  {
    "code": "SH0104",
    "group": "S",
    "title": "HRM: Turnover rate of physician and dentist",
    "titleTh": "อัตราการลาออก ของแพทย์/ทันตแพทย์"
  },
  {
    "code": "SH0105",
    "group": "S",
    "title": "HRM: Turnover rate of nurses",
    "titleTh": "อัตราการลาออก ของพยาบาลวิชาชีพ"
  },
  {
    "code": "SH0106",
    "group": "S",
    "title": "HRM: Turnover rate of allied health personnel",
    "titleTh": "อัตราการลาออก ของบุคลากรสาย allied health"
  },
  {
    "code": "SH0107",
    "group": "S",
    "title": "HRM: Turnover rate of back office personnel",
    "titleTh": "อัตราการลาออก ของบุคลากรสายสนับสนุน"
  },
  {
    "code": "SH0201",
    "group": "S",
    "title": "HRD: Percent of physician/dentist satisfaction (level 4-5)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของแพทย์/ทันตแพทย์ (ระดับ 4-5)"
  },
  {
    "code": "SH0202",
    "group": "S",
    "title": "HRD: Percent of nurse satisfaction (level 4-5)",
    "titleTh": "ร้อยละความพึงพอใจ ของบุคลากรในองค์กรในภาพรวมของพยาบาลวิชาชีพ (ระดับ 4-5)"
  },
  {
    "code": "SH0203",
    "group": "S",
    "title": "HRD: Percent of allied health personel satisfaction (level 4-5)",
    "titleTh": "ร้อยละความพึงพอใจ ของบุคลากรในองค์กรในภาพรวมของบุคลากรสาย Allied Health (ระดับ 4-5)"
  },
  {
    "code": "SH0204",
    "group": "S",
    "title": "HRD: Training hour per person per year of physician/dentist",
    "titleTh": "สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของแพทย์/ ทันตแพทย์"
  },
  {
    "code": "SH0205",
    "group": "S",
    "title": "HRD: HRD: Training hour per person per Year of nurse",
    "titleTh": "สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของพยาบาลวิชาชีพ"
  },
  {
    "code": "SH0206",
    "group": "S",
    "title": "HRD: Percent of physician and dentist satisfaction (average)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของแพทย์/ทันตแพทย์ (ค่าเฉลี่ย)"
  },
  {
    "code": "SH0207",
    "group": "S",
    "title": "HRD: Percent of physician and dentist satisfaction (level 1-2)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของแพทย์/ทันตแพทย์(ระดับ 1-2)"
  },
  {
    "code": "SH0208",
    "group": "S",
    "title": "HRD: Percentage of nurse satisfaction (average)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของพยาบาลวิชาชีพ (ค่าเฉลี่ย)"
  },
  {
    "code": "SH0209",
    "group": "S",
    "title": "HRD: Percentage of nurse satisfaction (level 1-2)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของพยาบาลวิชาชีพ (ระดับ 1-2)"
  },
  {
    "code": "SH0210",
    "group": "S",
    "title": "HRD: Percent of allied health personnel satisfaction (average)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสาย allied health (ค่าเฉลี่ย)"
  },
  {
    "code": "SH0211",
    "group": "S",
    "title": "HRD: Percent of allied health personnel satisfaction (level 1-2)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสาย allied health (ระดับ 1-2)"
  },
  {
    "code": "SH0212",
    "group": "S",
    "title": "HRD: Percent of back office personnel satisfaction (average)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสายสนับสนุน(ค่าเฉลี่ย)"
  },
  {
    "code": "SH0213",
    "group": "S",
    "title": "HRD: Percentage of back office personnel satisfaction (level 4-5)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสายสนับสนุน (ระดับ 4-5)"
  },
  {
    "code": "SH0214",
    "group": "S",
    "title": "HRD: Percentage of back office personnel satisfaction (level 1-2)",
    "titleTh": "ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสายสนับสนุน (ระดับ 1-2)"
  },
  {
    "code": "SH0215",
    "group": "S",
    "title": "HRD: Training hour per person per year of allied health personnel",
    "titleTh": "สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของบุคลากรสาย allied health"
  },
  {
    "code": "SH0216",
    "group": "S",
    "title": "HRD: Training hour per person per year of back office personnel",
    "titleTh": "สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของบุคลากรสายสนับสนุน"
  },
  {
    "code": "SH0301",
    "group": "S",
    "title": "HRH: Injury (Illnesses) Frequency Rate (IFR)",
    "titleTh": "อัตราความถี่การบาดเจ็บ/ เจ็บป่วยของบุคลากรที่เกี่ยวเนื่องจากงาน"
  },
  {
    "code": "SH0302",
    "group": "S",
    "title": "HRH: Injury Severity Rate: ISR of Direct Contact with Patients",
    "titleTh": "อัตราความรุนแรงของการบาดเจ็บของบุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรง"
  },
  {
    "code": "SH0303",
    "group": "S",
    "title": "HRH: Injury Severity Rate: ISRof non Direct Contact with Patients",
    "titleTh": "อัตราความรุนแรงของการบาดเจ็บของบุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรง"
  },
  {
    "code": "SH0306",
    "group": "S",
    "title": "HRH: Injury (illnesses) Frequency Rate: IFR of direct contact with patients",
    "titleTh": "อัตราความถี่การบาดเจ็บ/เจ็บป่วยของบุคลากรที่เกี่ยวเนื่องจากงาน ของบุคลากรกลุ่ม สัมผัสผู้ป่วยโดยตรง"
  },
  {
    "code": "SH0307",
    "group": "S",
    "title": "HRH: Injury (Illnesses) Frequency Rate : IFR of Non-direct Contact with Patients",
    "titleTh": "อัตราความถี่การบาดเจ็บ/เจ็บป่วยของบุคลากรที่เกี่ยวเนื่องจากงานของบุคลากรกลุ่มที่ ไม่ได้สัมผัสผู้ป่วยโดยตรง"
  },
  {
    "code": "SI0101",
    "group": "S",
    "title": "VAP: Rate of ventilator-associated pneumonia (All)",
    "titleTh": "อัตราการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจ (ภาพรวม)"
  },
  {
    "code": "SI0102",
    "group": "S",
    "title": "VAP: Rate of ventilator-associated pneumonia in ICU",
    "titleTh": "อัตราการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจ ของผู้ป่วยที่นอนรักษาใน ICU"
  },
  {
    "code": "SI0103",
    "group": "S",
    "title": "VAP: Rate of ventilator-associated pneumonia outside ICU",
    "titleTh": "อัตราการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจ ของผู้ป่วยที่นอนรักษานอก ICU ของโรงพยาบาล"
  },
  {
    "code": "SI0201",
    "group": "S",
    "title": "BSI: Rate of CABSI (All)",
    "titleTh": "อัตราการติดเชื้อในกระแสเลือดจากการคาสายสวนหลอดเลือดส่วนกลาง (ภาพรวม)"
  },
  {
    "code": "SI0202",
    "group": "S",
    "title": "BSI: Rate of CABSI in ICU",
    "titleTh": "อัตราการติดเชื้อในกระแสเลือดจากการคาสายสวนหลอดเลือดส่วนกลาง ของผู้ป่วยที่นอน รักษาใน ICU"
  },
  {
    "code": "SI0203",
    "group": "S",
    "title": "BSI: Rate of CABSI outside ICU",
    "titleTh": "อัตราการติดเชื้อในกระแสเลือดจากการคาสายสวนหลอดเลือดส่วนกลาง ของผู้ป่วยที่นอน รักษานอก ICU ของโรงพยาบาล"
  },
  {
    "code": "SI0301",
    "group": "S",
    "title": "CAUTI: Rate of CAUTI (All)",
    "titleTh": "อัตราการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะ (ภาพรวม)"
  },
  {
    "code": "SI0302",
    "group": "S",
    "title": "CAUTI: Rate of CAUTI in ICU",
    "titleTh": "อัตราการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะ ของผู้ป่วยที่นอนรักษา ใน ICU"
  },
  {
    "code": "SI0303",
    "group": "S",
    "title": "CAUTI: Rate of CAUTI outside ICU",
    "titleTh": "อัตราการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะ ของผู้ป่วยที่นอนรักษา นอก ICU ของโรงพยาบาล"
  },
  {
    "code": "SL0101",
    "group": "S",
    "title": "Crossmatch-to-Transfusion ratios (C:T) in selective surgery cases",
    "titleTh": "อัตราส่วนการขอใช้โลหิตต่อการใช้โลหิตจริงในกลุ่มผู้ป่วยผ่าตัดประเภทต่าง ๆ"
  },
  {
    "code": "SM0102",
    "group": "S",
    "title": "Medication Use: Percent of Antibiotic prescribing rate on Upper respiratory infection",
    "titleTh": "ร้อยละการใช้ยาปฏิชีวนะในผู้ป่วยโรคติดเชื้อทางเดินหายใจส่วนบน"
  },
  {
    "code": "SM0103",
    "group": "S",
    "title": "Medication Use: Percent of Antibiotic prescribing on Acute diarrhea",
    "titleTh": "ร้อยละการใช้ยาปฏิชีวนะในผู้ป่วยอุจจาระร่วงเฉียบพลัน"
  },
  {
    "code": "SM0201",
    "group": "S",
    "title": "Medication management: Inventory turn",
    "titleTh": "จำนวนเดือนสำรองคลังยา"
  },
  {
    "code": "SS0101",
    "group": "S",
    "title": "CSSD: Percent of examination of effective sterilization",
    "titleTh": "ร้อยละการตรวจสอบประสิทธิภาพการทำปราศจากเชื้อผ่านเกณฑ์"
  },
  {
    "code": "SS0102",
    "group": "S",
    "title": "CSSD: Percent of exact medical equipment prepared for specific procedures",
    "titleTh": "ร้อยละการจัดอุปกรณ์เครื่องมือทางการแพทย์ ถูกต้องครบถ้วน"
  },
  {
    "code": "SS0103",
    "group": "S",
    "title": "CSSD: Percent of medical supplies which are accurately provided by the CSSD",
    "titleTh": "ร้อยละการจ่ายอุปกรณ์เครื่องมือทางการแพทย์ให้หน่วยงานถูกต้อง"
  }
] as const;

export const thipCatalogueByCode = new Map(thipCatalogue.map((entry) => [entry.code, entry]));

export function createNoDataIndicator(entry: ThipCatalogueEntry, fiscalYear: FiscalYear = getCurrentFiscalYear()): Indicator {
  const periods = getFiscalMonthPeriods(fiscalYear);
  const rule = thipKpiRulesByCode.get(entry.code);
  const targetScope = rule && getReportingCadence(entry.code) === 'annual' ? 'annual' : 'monthly';
  const ruleStatus = rule?.status === 'foundation' ? 'มี foundation query สำหรับตรวจสอบ' : 'ยังต้องทำ local mapping และ source view';
  const monthly: MonthlyResult[] = periods.map((period) => ({
    periodStart: period.periodStart,
    fiscalYear: period.fiscalYear,
    fiscalMonth: period.fiscalMonth,
    label: period.label,
    numerator: null,
    denominator: null,
    value: null,
    target: null,
    percentile: null,
    status: 'no-data',
  }));

  return {
    code: entry.code,
    dataSource: 'no-data',
    fiscalYear,
    group: entry.group,
    category: groupMeta[entry.group].label,
    title: entry.title,
    titleTh: entry.titleTh,
    unit: rule ? getRuleUnit(rule) : 'percent',
    direction: 'neutral',
    target: null,
    targetScope,
    definition: rule
      ? `ตัวชี้วัดกลุ่ม ${rule.queryFamily} อยู่ใน THIP KPI Dictionary; ${ruleStatus} ก่อนเปิดใช้งาน production ต้องยืนยัน cohort, numerator/denominator, event time และ local code set ของโรงพยาบาล`
      : 'ตัวชี้วัดนี้อยู่ใน THIP KPI Dictionary แต่ยังไม่ได้ผูก source view และนิยาม numerator/denominator ของโรงพยาบาล',
    formula: rule?.formulaScale ?? 'รอยืนยันจาก source view ของโรงพยาบาล',
    numeratorLabel: 'ต้องยืนยันตามนิยาม PDF และ local rule',
    denominatorLabel: 'ต้องยืนยันตามนิยาม PDF และ local rule',
    sourceTables: [],
    frequency: rule ? reportingCadenceLabels[getReportingCadence(entry.code)] : 'ต้องยืนยันจาก dictionary/local mapping',
    reference: rule ? `THIP KPI Dictionary 2025 · หน้า ${rule.pdfPage}` : 'THIP KPI Dictionary 2025',
    annual: {
      fiscalYear,
      numerator: null,
      denominator: null,
      value: null,
      target: null,
      status: 'no-data',
    },
    monthly,
  };
}
