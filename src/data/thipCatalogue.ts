import { fiscalMonthLabels, groupMeta } from '@/data/thipData';
import type { Indicator, IndicatorGroup, MonthlyResult } from '@/types/thip';

export type ThipCatalogueEntry = {
  code: string;
  group: IndicatorGroup;
  title: string;
};

// Extracted from the 232 indicator entries listed in THIP KPI Dictionary 2025.
// Monthly observations are intentionally not fabricated; un-wired entries render as no-data.
export const thipCatalogue: readonly ThipCatalogueEntry[] = [
  {
    "code": "AA0101",
    "group": "A",
    "title": "Epilepsy: Hospitalization rate"
  },
  {
    "code": "AA0102",
    "group": "A",
    "title": "COPD: Hospitalization rate"
  },
  {
    "code": "AA0103",
    "group": "A",
    "title": "Asthma: Hospitalization rate"
  },
  {
    "code": "AA0104",
    "group": "A",
    "title": "Diabetes Mellitus (DM): Hospitalization rate"
  },
  {
    "code": "AA0105",
    "group": "A",
    "title": "Hypertension: Hospitalization rate"
  },
  {
    "code": "CA0101",
    "group": "C",
    "title": "physical status I, II ÖŠĂîñŠćêĆé Anesthesia: Intra-operative cardiac arrest ASA physical status I, II"
  },
  {
    "code": "CA0102",
    "group": "C",
    "title": "Anesthesia: Percent of pre-anesthetic visit elective in-patient cases"
  },
  {
    "code": "CA0103",
    "group": "C",
    "title": "Anesthesia: Percent of patients observed in recovery room"
  },
  {
    "code": "CA0104",
    "group": "C",
    "title": "Anesthesia: Percent of re-intubation within 2 hours after extubation"
  },
  {
    "code": "CA0105",
    "group": "C",
    "title": "Anesthesia: Percent of using capnometry during general anesthesia"
  },
  {
    "code": "CE0101",
    "group": "C",
    "title": "Sepsis: Percent of broad-spectrum antibiotic receiving within 3 hours"
  },
  {
    "code": "CE0102",
    "group": "C",
    "title": "ER: Average Emergency Department (ED) TIME-IN, TIME-OUT"
  },
  {
    "code": "CE0103",
    "group": "C",
    "title": "ER: Percent of Emergency patients recieveing emergency service (ED TIME-IN, TIME-OUT) within 60 minutes"
  },
  {
    "code": "CE0104",
    "group": "C",
    "title": "Sepsis: Percent of broad-spectrum antibiotic received within 1 hour in emergency room"
  },
  {
    "code": "CG0101",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Rate of Pressure ulcer"
  },
  {
    "code": "CG0102",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Rate of Pressure ulcer in risk patients"
  },
  {
    "code": "CG0103",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury"
  },
  {
    "code": "CG0104",
    "group": "C",
    "title": "Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury (HAPI) rate"
  },
  {
    "code": "CI0101",
    "group": "C",
    "title": "Sepsis: Percent of mortality"
  },
  {
    "code": "CM0101",
    "group": "C",
    "title": "Maternal: Mortality rate of mother from pregnancy and/or labour"
  },
  {
    "code": "CM0104",
    "group": "C",
    "title": "Maternal: Percent of unplanned re-admission of caesarean section within 28 days"
  },
  {
    "code": "CM0105",
    "group": "C",
    "title": "Maternal: Average length of stay of caesarean section"
  },
  {
    "code": "CM0107",
    "group": "C",
    "title": "Maternal: Percent of immediate postpartum hemorrhage (Vaginal delivery)"
  },
  {
    "code": "CM0109",
    "group": "C",
    "title": "Maternal: Percent of eclampsia in pregnancy induce Hypertension"
  },
  {
    "code": "CM0110",
    "group": "C",
    "title": "Maternal: Percent of gestational DM"
  },
  {
    "code": "CM0116",
    "group": "C",
    "title": "hysterectomy Maternal: Percent of patients who received antibiotic prophylaxis in abdominal hysterectomy"
  },
  {
    "code": "CM0117",
    "group": "C",
    "title": "øšĂ÷úąÖćøêĉéđßČĚĂĒñúñŠćêĆéAbdominal hysterectomy Maternal: Percent of abdominal hysterectomy associated infection"
  },
  {
    "code": "CM0118",
    "group": "C",
    "title": "Maternal: Percent of primary cesarean section"
  },
  {
    "code": "CM0119",
    "group": "C",
    "title": "êĆüĀćøPdx = O80-O84 ĀøČĂ Sdx = O80-O84 Benchmark (ĒĀúŠÜĂšćÜĂĉÜ/ ðŘ) øć÷ÜćîêĆüßĊĚüĆéïøĉÖćøÿč×õćó ×ĂÜÿðÿß. (NHSO health service indicator)"
  },
  {
    "code": "CM0201",
    "group": "C",
    "title": "Child: Perinatal mortality rate (24 weeks)"
  },
  {
    "code": "CM0202",
    "group": "C",
    "title": "Child: Perinatal mortality rate (28 weeks)"
  },
  {
    "code": "CM0203",
    "group": "C",
    "title": "Child: Neonatal mortality rate"
  },
  {
    "code": "CM0204",
    "group": "C",
    "title": "Child: Birth asphyxia rate"
  },
  {
    "code": "CM0205",
    "group": "C",
    "title": "Child: Severe birth asphyxia rate"
  },
  {
    "code": "CM0206",
    "group": "C",
    "title": "Child: Percent of low birth weight < 2500 grams"
  },
  {
    "code": "CM0207",
    "group": "C",
    "title": "Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days"
  },
  {
    "code": "CM0208",
    "group": "C",
    "title": "Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days"
  },
  {
    "code": "CM0209",
    "group": "C",
    "title": "Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days"
  },
  {
    "code": "CO0101",
    "group": "C",
    "title": "Operation: Percent of using surgical safety check list"
  },
  {
    "code": "CO0105",
    "group": "C",
    "title": "Operation: Percent of peri-operative mortality within 24 hours"
  },
  {
    "code": "CO0107",
    "group": "C",
    "title": "Operation: Percent of re-operation"
  },
  {
    "code": "CP0101",
    "group": "C",
    "title": "Percent of carers of children with ADHD/LD/MDD having good compliance to treatment"
  },
  {
    "code": "CP0201",
    "group": "C",
    "title": "Percent of children with Neurodevelopmental Disorder being diagnosed within 90 days after registration"
  },
  {
    "code": "DC0103",
    "group": "D",
    "title": "DM: Percent of diabetic retinopathy screening"
  },
  {
    "code": "DC0107",
    "group": "D",
    "title": "DM: Percent of lower-extremity amputation among patients with diabetes"
  },
  {
    "code": "DC0108",
    "group": "D",
    "title": "DM: Percent of good controlled of blood sugar in adult"
  },
  {
    "code": "DC0108.1",
    "group": "D",
    "title": "DM: Percent of good controlled of blood sugar in adult aged œ 60 years old"
  },
  {
    "code": "DC0108.2",
    "group": "D",
    "title": "DM: Percent of good controlled of blood sugar in adult aged < 60 years old"
  },
  {
    "code": "DC0201",
    "group": "D",
    "title": "HT: Percent of good controlled of blood pressure"
  },
  {
    "code": "DC0201.1",
    "group": "D",
    "title": "HT: Percent of good controlled of blood pressure of patient aged < 65 years old"
  },
  {
    "code": "DC0201.2",
    "group": "D",
    "title": "HT: Percent of good controlled of blood pressure of patient aged œ 65 years old"
  },
  {
    "code": "DC0301",
    "group": "D",
    "title": "HIV: Percent of people living with HIV with at least one test viral load (VL) after ARV treatment"
  },
  {
    "code": "DC0302",
    "group": "D",
    "title": "HIV: Percent of people living with HIV with viral load (VL) < 50 copies/ml after ARV treatment 12 months ago"
  },
  {
    "code": "DC0306",
    "group": "D",
    "title": "HIV: Percent of people living with HIV screening PAP smear"
  },
  {
    "code": "DC0307",
    "group": "D",
    "title": "HIV: Percent of people living with HIV newly registered who were tested for syphilis"
  },
  {
    "code": "DC0308",
    "group": "D",
    "title": "HIV: Percent of people living with HIV who were currently receiving antiretroviral therapy"
  },
  {
    "code": "DC0309",
    "group": "D",
    "title": "(Tuberculosis preventive therapy: TPT) ĕéšøĆï÷ćTPT HIV: Percent of newly diagnosed people living with HIV were receiving tuberculosis preventive therapy"
  },
  {
    "code": "DC0401",
    "group": "D",
    "title": "Cancer: Percent of mortality"
  },
  {
    "code": "DC0402",
    "group": "D",
    "title": "Cancer: Percent of unplanned re-admission"
  },
  {
    "code": "DC0403",
    "group": "D",
    "title": "Liver Cancer: Percent of mortality"
  },
  {
    "code": "DC0501",
    "group": "D",
    "title": "CKD: Percent of patients who achieve the kidney function deterioration delayed target"
  },
  {
    "code": "DC0502",
    "group": "D",
    "title": "CKD: Percent of patients who are receiving ACEIs or ARBs"
  },
  {
    "code": "DE0101",
    "group": "D",
    "title": "Breast Cancer: Consultation time in patient with BIRADS 4 or greater mammography result"
  },
  {
    "code": "DE0103",
    "group": "D",
    "title": "Breast Cancer: Percent of early diagnosis of stage 1, 2"
  },
  {
    "code": "DE0501",
    "group": "D",
    "title": "ĂĆêøćÖćøðúĎÖëŠć÷êĉé(Engraftment) ×ĂÜñĎšðśü÷Stem cell Stem Cell Transplantation: Engraftment rate within 45 days"
  },
  {
    "code": "DE0801",
    "group": "D",
    "title": "øšĂ÷úą×ĂÜñĎšðśü÷ Transfusion Dependent Thalassemia (TDT) ìĊęĂć÷č TDT in Pediatrics Patient: Percent of received iron chelator in patient with iron overload (serum ferrous > 1000 ug/L)"
  },
  {
    "code": "DE1201",
    "group": "D",
    "title": "Cleft Lip: Percent of patients who had cleft lip repair with under 6 months of age"
  },
  {
    "code": "DE1202",
    "group": "D",
    "title": "Cleft Palate: Percent of patients who had cleft Palate repair with under 18 months of age"
  },
  {
    "code": "DE1301",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per Embryo Transfer following IVF/ICSI and Fresh embryo transfer (age < 34 years)"
  },
  {
    "code": "DE1302",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age 34 - 39 Years)"
  },
  {
    "code": "DE1303",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age > 40 years)"
  },
  {
    "code": "DE1304",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years)"
  },
  {
    "code": "DE1305",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age 34 - 39 years)"
  },
  {
    "code": "DE1306",
    "group": "D",
    "title": "Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)"
  },
  {
    "code": "DE1401",
    "group": "D",
    "title": "øšĂ÷úąñĎšðśü÷ Upper GI Hemorrhage (UGIH) ĕéšøĆïÖćøÿŠĂÜÖúšĂÜõć÷Ĕî 24 Upper Gastrointestinal Hemorrhage (UGIH): Percent of patients who had underwent EGD within 24 hours"
  },
  {
    "code": "DE1402",
    "group": "D",
    "title": "øšĂ÷úąñĎšðśü÷Upper GI Hemorrhage (UGIH) ÖúčŠöHigh Risk ĕéšøĆïÖćøÿŠĂÜ"
  },
  {
    "code": "DE1403",
    "group": "D",
    "title": "Non-variceal Upper Gastrointestinal Hemorrhage (UGIH): Percent of hemostatic success by endoscopic approach"
  },
  {
    "code": "DE1404",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Recurrent rates of UGIH after upper endoscopic treatment"
  },
  {
    "code": "DE1405",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Complication rates of upper endoscopic treatment"
  },
  {
    "code": "DE1601",
    "group": "D",
    "title": "New born: Percent of hearing screening within 30 days"
  },
  {
    "code": "DG0101",
    "group": "D",
    "title": "Upper Gastrointestinal Hemorrhage (UGIH): Percent of unplanned re-admission into the hospital within 28 days after last discharge"
  },
  {
    "code": "DG0102",
    "group": "D",
    "title": "øą÷ąđüúćüĆîîĂîđÞúĊę÷ñĎšðśü÷Upper GI Hemorrhage (UGIH) Upper Gastrointestinal Hemorrhage (UGIH): Average length of stay"
  },
  {
    "code": "DG0201",
    "group": "D",
    "title": "Acute Appendicitis: Percent of abruption"
  },
  {
    "code": "DG0202",
    "group": "D",
    "title": "Acute Appendicitis: Percent of mortality"
  },
  {
    "code": "DH0101",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of mortality"
  },
  {
    "code": "DH0101.1",
    "group": "D",
    "title": "segment ÷Ö×ċĚî (STEMI) Acute coronary syndrome (STEMI): Percent of mortality"
  },
  {
    "code": "DH0101.2",
    "group": "D",
    "title": "segment ĕöŠ÷Ö×ċĚî (NSTE-ACS) Acute coronary syndrome (NSTE-ACSI): Percent of mortality"
  },
  {
    "code": "DH0102",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of patient receiving Aspirin within"
  },
  {
    "code": "DH0103",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Aspirin prescribed at discharge"
  },
  {
    "code": "DH0104",
    "group": "D",
    "title": "inhibitors ĀøČĂARB Acute coronary syndrome: Percent of ACE inhibitors or ARB received for patient who have LVSD"
  },
  {
    "code": "DH0105",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of smoking cessation advice given"
  },
  {
    "code": "DH0106",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Beta-blocker receiving during hospital admitted"
  },
  {
    "code": "DH0107",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Beta-blocker prescribed at discharge"
  },
  {
    "code": "DH0108",
    "group": "D",
    "title": "Acute coronary syndrome: Average door to EKG time"
  },
  {
    "code": "DH0109",
    "group": "D",
    "title": "Acute coronary syndrome: Average door to refer time"
  },
  {
    "code": "DH0110",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of Primary Percutaneous Coronary Intervention (PCI) given within 120 minutes or received Fibrinolytic agent within 30 minutes of arrival"
  },
  {
    "code": "DH0111",
    "group": "D",
    "title": "Acute coronary syndrome: Percent of unplanned re-admission within"
  },
  {
    "code": "DH0112",
    "group": "D",
    "title": "Acute coronary syndrome: Average length of stay"
  },
  {
    "code": "DH0113",
    "group": "D",
    "title": "(STEMI) ìĊęĕéšøĆïFibrinolytic agent õć÷Ĕî 30 îćìĊđöČęĂöćëċÜēøÜó÷ćïćú Acute coronary syndrome: Percent of time to Fibrinolytic administration agents within 30 minutes of arrival"
  },
  {
    "code": "DH0201",
    "group": "D",
    "title": "øšĂ÷úąÖćøđÿĊ÷ßĊüĉê×ĂÜñĎšðśü÷ìĊęìĈCoronary Artery Bypass Graft (CABG) Coronary Artery Bypass Graft (CABG): Percent of mortality"
  },
  {
    "code": "DH0202",
    "group": "D",
    "title": "øšĂ÷úąÖćøĕéšøĆï÷ćðäĉßĊüîąĒïïðŜĂÜÖĆîĔîÖćøñŠćêĆéCoronary Artery Bypass Graft Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis"
  },
  {
    "code": "DH0203",
    "group": "D",
    "title": "øšĂ÷úąÖćøêĉéđßČĚĂĒñúñŠćêĆéCoronary Artery Bypass Graft (CABG) Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection"
  },
  {
    "code": "DH0204",
    "group": "D",
    "title": "Coronary Artery Bypass Graft (CABG): percent of 30-days hospital mortality"
  },
  {
    "code": "DH0301",
    "group": "D",
    "title": "Fraction (HFREF) received Angiotensin II Converting Enzyme inhibitors (ACEIs) or Angiotensin II Receptor Blockers (ARBs) or Mineralocorticoid Receptor Antagonists (MRA)"
  },
  {
    "code": "DH0302",
    "group": "D",
    "title": "Heart failure: Percent of smoking cessation advice given"
  },
  {
    "code": "DH0401",
    "group": "D",
    "title": "øšĂ÷úą×ĂÜñĎšðśü÷ Atrial fibrillation ĕéšøĆï÷ć Warfarin öĊøąéĆïINR êćö Atrial fibrillation: Percent of patient received Warfarin within target"
  },
  {
    "code": "DH0402",
    "group": "D",
    "title": "øšĂ÷úą×ĂÜÖćøđÖĉé Adverse event (major bleeding) ×ĂÜñĎšðśü÷ Atrial fibrillation ìĊęĕéšøĆï÷ć Warfarin Atrial Fibrillation: Percent of major bleeding (intracranial hemorrhage"
  },
  {
    "code": "DM0101",
    "group": "D",
    "title": "øšĂ÷úąđéĘÖóĆçîćÖćøúŠćßšćøĂïéšćî(Global development delay: GDD) GDD: Percent of children with global development delay that improved after intervented"
  },
  {
    "code": "DM0102",
    "group": "D",
    "title": "øšĂ÷úąđéĘÖóĆçîćÖćøúŠćßšćøĂïéšćî(Global development delay: GDD) GDD: Percent of children with Global development delay that improved after intervented with TEDA4I"
  },
  {
    "code": "DM0103",
    "group": "D",
    "title": "øšĂ÷úąđéĘÖóĆçîćÖćøúŠćßšćøĂïéšćî(Global development delay: GDD)"
  },
  {
    "code": "DM0201",
    "group": "D",
    "title": "ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement"
  },
  {
    "code": "DM0202",
    "group": "D",
    "title": "ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement with TEDA4I"
  },
  {
    "code": "DM0203",
    "group": "D",
    "title": "ASD: Percent of children with autism spectrum disorder (ASD) that are included in educational system for at least 1 year"
  },
  {
    "code": "DM0301",
    "group": "D",
    "title": "Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented"
  },
  {
    "code": "DM0302",
    "group": "D",
    "title": "Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented"
  },
  {
    "code": "DM0401",
    "group": "D",
    "title": "Child and adolescent psychiatry: Percent of children with Attention- Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6"
  },
  {
    "code": "DM0402",
    "group": "D",
    "title": "Child and adolescent psychiatry: Percent of children and adolescents with Major Depressive Disorder (MDD) improved after intervented for"
  },
  {
    "code": "DN0101",
    "group": "D",
    "title": "Stroke: Percent of mortality"
  },
  {
    "code": "DN0102",
    "group": "D",
    "title": "Ischemic stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission"
  },
  {
    "code": "DN0103",
    "group": "D",
    "title": "(Antiplatelet) ĀøČĂ÷ćêšćîõćüąĒ×ĘÜêĆü×ĂÜđúČĂé (Anticoagulant) ×èą Ischemic stroke: Percent of Antiplatelet or Anticoagulant therapy prescribed at discharge"
  },
  {
    "code": "DN0104",
    "group": "D",
    "title": "Ischemic stroke: Percent of patient with Atrial fibrillation/Flutter receiving Anticoagulation therapy"
  },
  {
    "code": "DN0105",
    "group": "D",
    "title": "Stroke: Percent of patients who were given stroke education during their hospital stay"
  },
  {
    "code": "DN0106",
    "group": "D",
    "title": "Stroke: Percent of treatment, physiotherapy or rehabilitation in stroke or paralytic syndrome within 72 hours"
  },
  {
    "code": "DN0107",
    "group": "D",
    "title": "Stroke: Percent of unplanned re-admission of stroke within 28 days"
  },
  {
    "code": "DN0109",
    "group": "D",
    "title": "Stroke: Average length of stay"
  },
  {
    "code": "DN0110",
    "group": "D",
    "title": "øšĂ÷úąñĎšðśü÷Ischemic Stroke ìĊęĕéšøĆïThrombolytic Agents õć÷Ĕî 60 Ischemic Stroke: Percent of time to Thrombolytic administration agents within 60 minutes of arrival"
  },
  {
    "code": "DN0301",
    "group": "D",
    "title": "Head Injury: Percent of unplanned re-admission of Craniotomy within"
  },
  {
    "code": "DN0302",
    "group": "D",
    "title": "Head Injury: Percent of mortality within 48 hours"
  },
  {
    "code": "DN0303",
    "group": "D",
    "title": "Head Injury: Percent of patient underwent craniotomy for Intracranial"
  },
  {
    "code": "DO0202",
    "group": "D",
    "title": "øšĂ÷úą×ĂÜñĎšðśü÷ñŠćêĆéđðúĊę÷î×šĂÿąēóÖ ĕéšøĆïProphylactic antibiotic Hip arthroplasty: Percent of patients who received antibiotic prophylaxis in Hip arthroplasty"
  },
  {
    "code": "DO0204",
    "group": "D",
    "title": "Hip arthroplasty: Percent of hip arthroplasty associated infection within 1 Year"
  },
  {
    "code": "DO0205",
    "group": "D",
    "title": "Hip arthroplasty: Percent of hip arthroplasty associated infection within 90 days"
  },
  {
    "code": "DO0302",
    "group": "D",
    "title": "øšĂ÷úą×ĂÜñĎšðśü÷ñŠćêĆéđðúĊę÷î×šĂđ×Šćĕ éšøĆïProphylactic Antibiotic Knee Arthroplasty: Percent of patients who received antibiotic prophylaxis"
  },
  {
    "code": "DO0303",
    "group": "D",
    "title": "Knee Arthroplasty: Percent of surgical infection within 1 year"
  },
  {
    "code": "DO0304",
    "group": "D",
    "title": "Knee Arthroplasty: Percent of surgical infection within 90 days"
  },
  {
    "code": "DP0101",
    "group": "D",
    "title": "Diabetes in child and adolescent: Percent of good controlled of blood sugar (age < 18 years)"
  },
  {
    "code": "DR0101",
    "group": "D",
    "title": "Pneumonia: Percent of mortality after hospital admission"
  },
  {
    "code": "DR0102",
    "group": "D",
    "title": "Pneumonia: Percent of unplanned re-admission within 28 days after last discharge"
  },
  {
    "code": "DR0103",
    "group": "D",
    "title": "Pneumonia: Percent of smoking cessation advice given"
  },
  {
    "code": "DR0201",
    "group": "D",
    "title": "ßČęĂêĆüßĊĚüĆé (õćþćĂĆÜÖùþ) TB: Percent of mortality during 12 months Benchmark (ĒĀúŠÜĂšćÜĂĉÜ/ ðŘ) * ìĊęöć/ Reference ÿðÿß."
  },
  {
    "code": "DR0202",
    "group": "D",
    "title": "TB: Percentage of people living with HIV having a TB screening"
  },
  {
    "code": "DR0203",
    "group": "D",
    "title": "TB: Percent of treatment success"
  },
  {
    "code": "DR0204",
    "group": "D",
    "title": "TB: Percent of TB having a HIV screening"
  },
  {
    "code": "DR0205",
    "group": "D",
    "title": "Antiretroviral therapy (ART) TB: Percent of HIV-positive TB patients started on Antiretroviral therapy (ART)"
  },
  {
    "code": "DR0301",
    "group": "D",
    "title": "Asthma: Percent of unplanned re-admission within 28 days after last discharge"
  },
  {
    "code": "DR0302",
    "group": "D",
    "title": "Asthma: Percent of smoking cessation advice given"
  },
  {
    "code": "DR0401",
    "group": "D",
    "title": "COPD: Percent of unplanned re-admission into the hospital within 28 days after last discharge"
  },
  {
    "code": "DR0403",
    "group": "D",
    "title": "COPD: Percent of mortality"
  },
  {
    "code": "DR0404",
    "group": "D",
    "title": "COPD: Percent of patient with ongoing smoking"
  },
  {
    "code": "DS0101",
    "group": "D",
    "title": "Methamphetamine Group: 3 months total remission rate"
  },
  {
    "code": "DS0201",
    "group": "D",
    "title": "Alcohol Group: 3 months total remission rate"
  },
  {
    "code": "DS0301",
    "group": "D",
    "title": "Tobacco Group: 3 months total remission rate"
  },
  {
    "code": "DS0401",
    "group": "D",
    "title": "Opioid Group: 1 year retention rate of opioid in methadone maintenance program"
  },
  {
    "code": "HC0101",
    "group": "H",
    "title": "Customer: Asthma patients or their relative(s) who are able to care for the patient's needs"
  },
  {
    "code": "HC0102",
    "group": "H",
    "title": "Customer: COPD patients or their relative(s) who are able to care for the patient's needs"
  },
  {
    "code": "HE0101",
    "group": "H",
    "title": "Employee: Percent of employee check-up"
  },
  {
    "code": "HE0102",
    "group": "H",
    "title": "Employee: Percent of employee have exceeding BMI"
  },
  {
    "code": "HE0103",
    "group": "H",
    "title": "Employee: Percent of employee have behavior-smoky"
  },
  {
    "code": "HE0104",
    "group": "H",
    "title": "Employee: Percent of employee (male) obesity"
  },
  {
    "code": "HE0105",
    "group": "H",
    "title": "Employee: Percent of employee (female) obesity"
  },
  {
    "code": "HE0106",
    "group": "H",
    "title": "Employee: Percent of employee received Influenza immunization"
  },
  {
    "code": "HH0101.1",
    "group": "H",
    "title": "ตภัณฑยาสูบทั้งชนิดมีควัน (Smoking tobacco Benchmark (แหลงอางอิง/ป)* ที่มา/ Reference"
  },
  {
    "code": "HH0101.2",
    "group": "H",
    "title": "Tobacco Use: Percent of Tobacco Use Screened of Service Recipients aged ≥ 15 years old at the Outpatient Service."
  },
  {
    "code": "HH0102",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence patients receiving nicotine dependence treatment."
  },
  {
    "code": "HH0103.1",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in DM patients receiving nicotine dependence treatment."
  },
  {
    "code": "HH0103.2",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Hypertension patients receiving nicotine dependence treatment."
  },
  {
    "code": "HH0103.3",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment"
  },
  {
    "code": "HH0103.4",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in COPD patients receiving nicotine dependence treatment."
  },
  {
    "code": "HH0103.5",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Pregnant patients receiving nicotine dependence treatment."
  },
  {
    "code": "HH0103.6",
    "group": "H",
    "title": "Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment."
  },
  {
    "code": "HH0104.1",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (DM Patients)"
  },
  {
    "code": "HH0104.2",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (Hypertension Patients)"
  },
  {
    "code": "HH0104.3",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (Asthma Patients)"
  },
  {
    "code": "HH0104.4",
    "group": "H",
    "title": "Tobacco use: continuous abstinence rate (CAR) at 6 months (COPD Patients)"
  },
  {
    "code": "HH0104.5",
    "group": "H",
    "title": "Tobacco use: Tobacco use: continuous abstinence rate (CAR) at 6 months (Pregnant Patients)"
  },
  {
    "code": "SC0101",
    "group": "S",
    "title": "Customer: Percent of outpatient satisfaction (overall)"
  },
  {
    "code": "SC0102",
    "group": "S",
    "title": "Customer: Percent of inpatient satisfaction (overall)"
  },
  {
    "code": "SC0103",
    "group": "S",
    "title": "Customer: Percent of outpatients who return to receive care"
  },
  {
    "code": "SC0104",
    "group": "S",
    "title": "Customer: Percent of inpatients who return to receive care"
  },
  {
    "code": "SC0105",
    "group": "S",
    "title": "Customer: Percent of outpatients who would recommend friends or family to receive care at this facility"
  },
  {
    "code": "SC0106",
    "group": "S",
    "title": "Customer: Percent of inpatients who would recommend friends or family to receive care at this facility"
  },
  {
    "code": "SF0101",
    "group": "S",
    "title": "Financial: Current ratio"
  },
  {
    "code": "SF0102",
    "group": "S",
    "title": "Financial: Quick ratio"
  },
  {
    "code": "SF0103",
    "group": "S",
    "title": "Financial: Fixed asset turnover"
  },
  {
    "code": "SF0104",
    "group": "S",
    "title": "Financial: Day in account receivable (average collection period for account receivables)"
  },
  {
    "code": "SF0105",
    "group": "S",
    "title": "Financial: Net profit margin"
  },
  {
    "code": "SF0106",
    "group": "S",
    "title": "Financial: Return on asset (ROA)"
  },
  {
    "code": "SG0104",
    "group": "S",
    "title": "Governance: Percent of recycled waste"
  },
  {
    "code": "SH0101",
    "group": "S",
    "title": "HRM: Turnover rate"
  },
  {
    "code": "SH0102",
    "group": "S",
    "title": "HRM: Percent of employee work-related Injury"
  },
  {
    "code": "SH0103",
    "group": "S",
    "title": "HRM: Percent of employee work-related Illness"
  },
  {
    "code": "SH0104",
    "group": "S",
    "title": "HRM: Turnover rate of physician and dentist"
  },
  {
    "code": "SH0105",
    "group": "S",
    "title": "HRM: Turnover rate of nurses"
  },
  {
    "code": "SH0106",
    "group": "S",
    "title": "ĂĆêøćÖćøúćĂĂÖ ×ĂÜïčÙúćÖøÿć÷Allied Health HRM: Turnover rate of allied health personnel"
  },
  {
    "code": "SH0107",
    "group": "S",
    "title": "HRM: Turnover rate of back office personnel"
  },
  {
    "code": "SH0201",
    "group": "S",
    "title": "HRD: Percent of physician/dentist satisfaction (level 4-5)"
  },
  {
    "code": "SH0202",
    "group": "S",
    "title": "HRD: Percent of nurse satisfaction (level 4-5)"
  },
  {
    "code": "SH0203",
    "group": "S",
    "title": "Allied Health (øąéĆï 4-5) HRD: Percent of allied health personel satisfaction (level 4-5)"
  },
  {
    "code": "SH0204",
    "group": "S",
    "title": "HRD: Training hour per person per year of physician/dentist"
  },
  {
    "code": "SH0205",
    "group": "S",
    "title": "HRD: HRD: Training hour per person per Year of nurse"
  },
  {
    "code": "SH0206",
    "group": "S",
    "title": "HRD: Percent of physician and dentist satisfaction (average)"
  },
  {
    "code": "SH0207",
    "group": "S",
    "title": "HRD: Percent of physician and dentist satisfaction (level 1-2)"
  },
  {
    "code": "SH0208",
    "group": "S",
    "title": "HRD: Percentage of nurse satisfaction (average)"
  },
  {
    "code": "SH0209",
    "group": "S",
    "title": "HRD: Percentage of nurse satisfaction (level 1-2)"
  },
  {
    "code": "SH0210",
    "group": "S",
    "title": "Allied Health (ÙŠćđÞúĊę÷) HRD: Percent of allied health personnel satisfaction (average)"
  },
  {
    "code": "SH0211",
    "group": "S",
    "title": "Allied health (øąéĆï 1-2) HRD: Percent of allied health personnel satisfaction (level 1-2)"
  },
  {
    "code": "SH0212",
    "group": "S",
    "title": "HRD: Percent of back office personnel satisfaction (average)"
  },
  {
    "code": "SH0213",
    "group": "S",
    "title": "HRD: Percentage of back office personnel satisfaction (level 4-5)"
  },
  {
    "code": "SH0214",
    "group": "S",
    "title": "HRD: Percentage of back office personnel satisfaction (level 1-2)"
  },
  {
    "code": "SH0215",
    "group": "S",
    "title": "HRD: Training hour per person per year of allied health personnel"
  },
  {
    "code": "SH0216",
    "group": "S",
    "title": "HRD: Training hour per person per year of back office personnel"
  },
  {
    "code": "SH0301",
    "group": "S",
    "title": "HRH: Injury (Illnesses) Frequency Rate (IFR)"
  },
  {
    "code": "SH0302",
    "group": "S",
    "title": "HRH: Injury Severity Rate: ISR of Direct Contact with Patients"
  },
  {
    "code": "SH0303",
    "group": "S",
    "title": "HRH: Injury Severity Rate: ISRof non Direct Contact with Patients"
  },
  {
    "code": "SH0306",
    "group": "S",
    "title": "HRH: Injury (illnesses) Frequency Rate: IFR of direct contact with patients"
  },
  {
    "code": "SH0307",
    "group": "S",
    "title": "HRH: Injury (Illnesses) Frequency Rate : IFR of Non-direct Contact with Patients"
  },
  {
    "code": "SI0101",
    "group": "S",
    "title": "VAP: Rate of ventilator-associated pneumonia (All)"
  },
  {
    "code": "SI0102",
    "group": "S",
    "title": "VAP: Rate of ventilator-associated pneumonia in ICU"
  },
  {
    "code": "SI0103",
    "group": "S",
    "title": "VAP: Rate of ventilator-associated pneumonia outside ICU"
  },
  {
    "code": "SI0201",
    "group": "S",
    "title": "BSI: Rate of CABSI (All)"
  },
  {
    "code": "SI0202",
    "group": "S",
    "title": "BSI: Rate of CABSI in ICU"
  },
  {
    "code": "SI0203",
    "group": "S",
    "title": "BSI: Rate of CABSI outside ICU"
  },
  {
    "code": "SI0301",
    "group": "S",
    "title": "CAUTI: Rate of CAUTI (All)"
  },
  {
    "code": "SI0302",
    "group": "S",
    "title": "CAUTI: Rate of CAUTI in ICU"
  },
  {
    "code": "SI0303",
    "group": "S",
    "title": "CAUTI: Rate of CAUTI outside ICU"
  },
  {
    "code": "SL0101",
    "group": "S",
    "title": "Crossmatch-to-Transfusion ratios (C:T) in selective surgery cases"
  },
  {
    "code": "SM0102",
    "group": "S",
    "title": "Medication Use: Percent of Antibiotic prescribing rate on Upper respiratory infection"
  },
  {
    "code": "SM0103",
    "group": "S",
    "title": "Medication Use: Percent of Antibiotic prescribing on Acute diarrhea"
  },
  {
    "code": "SM0201",
    "group": "S",
    "title": "Medication management: Inventory turn"
  },
  {
    "code": "SS0101",
    "group": "S",
    "title": "CSSD: Percent of examination of effective sterilization"
  },
  {
    "code": "SS0102",
    "group": "S",
    "title": "CSSD: Percent of exact medical equipment prepared for specific procedures"
  },
  {
    "code": "SS0103",
    "group": "S",
    "title": "CSSD: Percent of medical supplies which are accurately provided by the CSSD"
  }
] as const;

export const thipCatalogueByCode = new Map(thipCatalogue.map((entry) => [entry.code, entry]));

export function createNoDataIndicator(entry: ThipCatalogueEntry): Indicator {
  const monthly: MonthlyResult[] = fiscalMonthLabels.map((label, index) => ({
    fiscalMonth: index + 1,
    label,
    numerator: null,
    denominator: null,
    value: null,
    target: null,
    percentile: null,
    status: 'no-data',
  }));

  return {
    code: entry.code,
    group: entry.group,
    category: groupMeta[entry.group].label,
    title: entry.title,
    titleTh: entry.title,
    unit: 'percent',
    direction: 'neutral',
    target: null,
    definition: 'ตัวชี้วัดนี้อยู่ใน THIP KPI Dictionary แต่ยังไม่ได้ผูก source view และนิยาม numerator/denominator ของโรงพยาบาล',
    formula: 'รอยืนยันจาก source view ของโรงพยาบาล',
    numeratorLabel: 'ยังไม่กำหนด',
    denominatorLabel: 'ยังไม่กำหนด',
    sourceTables: [],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025',
    monthly,
  };
}

