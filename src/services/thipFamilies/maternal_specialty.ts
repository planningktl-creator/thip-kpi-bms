/**
 * Maternal specialty family batch (batch name: maternal_specialty).
 *
 * Read-only HOSxP fact branches for 19 THIP KPI codes:
 * perinatal and maternal (CM0101, CM0201, CM0202, CM0203), newborn hearing
 * screening (DE1601), breast cancer (DE0101, DE0103), cancer outcomes
 * (DC0402, DC0403), stem cell transplantation (DE0501), thalassemia TDT
 * (DE0801), cleft repair (DE1201, DE1202) and infertility (DE1301 to DE1306).
 *
 * Every branch follows the thipFamilyBase contract: one row per indicator code
 * x reporting period anchor, outer projection limited to
 * (indicator_code, period_start, fiscal_month, fiscal_year, numerator,
 * denominator, value), dotless ICD literals compared through
 * REPLACE(UPPER(TRIM(col)), '.', ''), and divisions written as
 * `X / NULLIF(Y, 0)` only. All HOSxP tables and columns referenced here were
 * verified against `01_Excel HOSxP Structure.xlsx`.
 *
 * Codes whose source genuinely does not exist in HOSxP use `branchExternal`
 * and document their staging requirement in
 * MATERNAL_SPECIALTY_APPROXIMATIONS (as do the closest-HOSxP-aggregate codes,
 * with the gap the printed definition still needs).
 */

import { branchExternal, branchFact, branchIpd } from '@/services/thipFamilyBase';

/** Ratio-style value per the shared contract: X * multiplier over NULLIF(den, 0). */
function ratioValue(numerator: string, denominator: string, multiplier: string): string {
  return `ROUND(${numerator} * ${multiplier} / NULLIF(${denominator}, 0), 2)`;
}

const DOTLESS = (col: string): string => `REPLACE(UPPER(TRIM(${col})), '.', '')`;

// ---------------------------------------------------------------------------
// Shared predicates and subqueries (verified columns only)
// ---------------------------------------------------------------------------

/** Maternal death linked to a delivery record: pregnancy-related cause, within 42 days. */
const maternalDeathFilter = `EXISTS (
          SELECT 1
          FROM ipt m
          JOIN death d ON (d.an = m.an OR d.hn = m.hn)
          WHERE m.an = delivery_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= COALESCE(delivery_periodized.labour_startdate, d.death_date)
            AND d.death_date <= COALESCE(delivery_periodized.labour_finishdate, delivery_periodized.labour_startdate, d.death_date) + INTERVAL '42 days'
            AND (
              d.death_preg_42_day = 'Y'
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_icd10, '')`)}, 1) = 'O'
              OR LEFT(${DOTLESS(`COALESCE(d.death_cause, '')`)}, 1) = 'O'
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_1, '')`)}, 1) = 'O'
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_2, '')`)}, 1) = 'O'
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_3, '')`)}, 1) = 'O'
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_4, '')`)}, 1) = 'O'
            )
            AND NOT (
              LEFT(${DOTLESS(`COALESCE(d.death_diag_icd10, '')`)}, 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(${DOTLESS(`COALESCE(d.death_cause, '')`)}, 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_1, '')`)}, 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_2, '')`)}, 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_3, '')`)}, 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(${DOTLESS(`COALESCE(d.death_diag_4, '')`)}, 1) IN ('V', 'W', 'X', 'Y')
            )
        )`;

/** Live newborns delivered by the mother of the delivery record (babies, not deliveries). */
const liveNewbornCount = `(
          SELECT COUNT(*)
          FROM ipt_newborn nb
          WHERE nb.mother_an = delivery_periodized.an
            AND COALESCE(nb.dead, 'N') <> 'Y'
        )`;

/** Gestational age evidence from the mother pregnancy record (ipt_pregnancy.ga, weeks). */
const gaAtLeast = (weeks: number): string => `EXISTS (
          SELECT 1
          FROM ipt_pregnancy pg
          WHERE pg.an = newborn_periodized.mother_an
            AND COALESCE(pg.ga, 0) >= ${weeks}
        )`;

const stillborn = `COALESCE(newborn_periodized.dead, 'N') = 'Y'`;

const diedWithinDays = (days: number): string => `EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '${days} days'
        )`;

/** Perinatal case threshold: birth weight in grams, or GA weeks when weight is missing. */
const perinatalThreshold = (grams: number, weeks: number): string =>
  `(COALESCE(newborn_periodized.birth_weight, 0) >= ${grams} OR (newborn_periodized.birth_weight IS NULL AND ${gaAtLeast(weeks)}))`;

/** Days from the BI-RADS 4 or higher mammogram to the first recorded doctor consultation. */
const biradsConsultDays = `(
          SELECT MIN(pcr.patient_cancer_first_meet_doctor_date - bc.screen_date)
          FROM person pp
          JOIN person_bc_screen bc ON bc.person_id = pp.person_id
          JOIN patient_cancer_registeration pcr ON pcr.hn = pp.patient_hn
          WHERE pp.patient_hn = opd_periodized.hn
            AND bc.screen_date = opd_periodized.event_date
            AND COALESCE(bc.mamogram_birads_result_integer, 0) >= 4
            AND pcr.patient_cancer_first_meet_doctor_date IS NOT NULL
            AND pcr.patient_cancer_first_meet_doctor_date >= bc.screen_date
        )`;

/** Malignant neoplasm (C00 to C97), in situ (D00 to D09) or chemo radiotherapy (Z510, Z511). */
const cancerDiagnosis = (col: string): string =>
  `(LEFT(${DOTLESS(col)}, 1) = 'C' OR LEFT(${DOTLESS(col)}, 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR ${DOTLESS(col)} IN ('Z510', 'Z511'))`;

/** Inpatient episode cohort: malignant or in situ neoplasm, or chemo radiotherapy coding. */
const cancerEpisodeCohort = `(${cancerDiagnosis('pdx')} OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND ${cancerDiagnosis(`sd.icd10`)}
        ))`;

/** Unplanned re-admission proxy: cancer admission within 28 days after a cancer discharge. */
const cancerReadmissionFilter = `EXISTS (
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.dchdate IS NOT NULL
            AND periodized.regdate > r.dchdate
            AND periodized.regdate <= r.dchdate + INTERVAL '28 days'
            AND (
              ${cancerDiagnosis('rs.pdx')}
              OR EXISTS (
                SELECT 1
                FROM iptdiag rd
                WHERE rd.an = r.an
                  AND ${cancerDiagnosis('rd.icd10')}
              )
            )
        )`;

const liverCancerCohort = `((LEFT(pdx, 3) IN ('C220', 'C222', 'C223', 'C224', 'C225', 'C226', 'C227', 'C228', 'C229')) OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(${DOTLESS('sd.icd10')}, 3) IN ('C220', 'C222', 'C223', 'C224', 'C225', 'C226', 'C227', 'C228', 'C229')
        ))`;

/** Stem cell or bone marrow transplant (ICD-9 41.0x) on the admission. */
const transplantFilter = `EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          WHERE ol.an = periodized.an
            AND LEFT(${DOTLESS(`COALESCE(od.icdcode, oi.icd9, '')`)}, 3) = '410'
        )`;

/** Engraftment proxy: neutrophil recovery lab at or above 500 within 45 days of the transplant. */
const engraftmentFilter = `EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          WHERE ol.an = periodized.an
            AND LEFT(${DOTLESS(`COALESCE(od.icdcode, oi.icd9, '')`)}, 3) = '410'
            AND EXISTS (
              SELECT 1
              FROM lab_head lh
              JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
              JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
              WHERE lh.hn = ol.hn
                AND li.lab_items_name ILIKE '%neutrophil%'
                AND lh.order_date IS NOT NULL
                AND ol.operation_date IS NOT NULL
                AND lh.order_date >= ol.operation_date
                AND lh.order_date <= ol.operation_date + INTERVAL '45 days'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '') ~ '^[0-9]+(\\.[0-9]+)?$'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '')::numeric >= 500
            )
        )`;

/** Serum ferritin over 1000 on an order in the patient month (numeric result text only). */
const ferritinOverloadFilter = `EXISTS (
          SELECT 1
          FROM lab_head lh
          JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = opd_periodized.hn
            AND lh.order_date >= opd_periodized.period_start
            AND lh.order_date < opd_periodized.period_start + INTERVAL '1 month'
            AND li.lab_items_name ILIKE '%ferritin%'
            AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '') ~ '^[0-9]+(\\.[0-9]+)?$'
            AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '')::numeric > 1000
        )`;

/** Iron chelator dispensed to the patient inside the same month. */
const chelatorFilter = `EXISTS (
          SELECT 1
          FROM ovst v2
          JOIN opitemrece oi ON oi.vn = v2.vn
          JOIN drugitems di ON di.icode = oi.icode
          WHERE v2.hn = opd_periodized.hn
            AND v2.vstdate >= opd_periodized.period_start
            AND v2.vstdate < opd_periodized.period_start + INTERVAL '1 month'
            AND (
              di.name ILIKE '%deferasirox%'
              OR di.name ILIKE '%deferoxamine%'
              OR di.name ILIKE '%deferiprone%'
            )
        )`;

const thalassemiaVisit = `(LEFT(pdx, 3) = 'D56' OR EXISTS (
          SELECT 1
          FROM ovstdiag sd
          WHERE sd.vn = opd_periodized.vn
            AND LEFT(${DOTLESS('sd.icd10')}, 3) = 'D56'
        ))`;

const cleftCohort = `(LEFT(pdx, 3) IN ('Q35', 'Q36', 'Q37') OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(${DOTLESS('sd.icd10')}, 3) IN ('Q35', 'Q36', 'Q37')
        ))`;

/** Cleft repair operation on the admission; lip uses ICD-9 30.4x, palate ICD-9 27.54. */
const cleftRepairFilter = (kind: 'lip' | 'palate', ageMonths: number | null): string => {
  const codePred =
    kind === 'lip'
      ? `LEFT(${DOTLESS(`COALESCE(od.icdcode, oi.icd9, '')`)}, 3) = '304'`
      : `${DOTLESS(`COALESCE(od.icdcode, oi.icd9, '')`)} IN ('2754')`;
  const namePred =
    kind === 'lip'
      ? `oi.name ILIKE '%cleft lip%' OR oi.name ILIKE '%ปากแหว่ง%'`
      : `oi.name ILIKE '%cleft palate%' OR oi.name ILIKE '%เพดานโหว่%'`;
  const agePred =
    ageMonths === null
      ? ''
      : `
            AND ol.operation_date IS NOT NULL
            AND pd.birthday IS NOT NULL
            AND ol.operation_date >= pd.birthday
            AND ol.operation_date <= pd.birthday + INTERVAL '${ageMonths} months'`;
  return `EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          ${ageMonths === null ? '' : 'JOIN patient pd ON pd.hn = ol.hn'}
          WHERE ol.an = periodized.an
            AND ((${codePred}) OR (${namePred}))${agePred}
        )`;
};

// ---------------------------------------------------------------------------
// Branches (assigned order: CM0101, CM0201, CM0202, CM0203, DE1601, DE0101,
// DE0103, DC0402, DC0403, DE0501, DE0801, DE1201, DE1202, DE1301 to DE1306)
// ---------------------------------------------------------------------------

const cm0101Num = `COUNT(*) FILTER (WHERE ${maternalDeathFilter})`;
const cm0101Den = `SUM(${liveNewbornCount})`;

const cm0201Num = `COUNT(*) FILTER (WHERE (${stillborn} OR ${diedWithinDays(7)}) AND ${perinatalThreshold(500, 24)})`;
const cm0202Num = `COUNT(*) FILTER (WHERE (${stillborn} OR ${diedWithinDays(7)}) AND ${perinatalThreshold(1000, 28)})`;
const cm0203Num = `COUNT(*) FILTER (WHERE ${diedWithinDays(28)})`;

const de0101Num = `SUM(${biradsConsultDays})`;
const de0101Den = 'COUNT(*)';

const de0103Num = `COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM patient_cancer_registeration pcr
          WHERE pcr.clinicmember_id = chronic_periodized.clinicmember_id
            AND COALESCE(pcr.m_value, 0) = 0
            AND COALESCE(pcr.n_value, 99) <= 1
            AND COALESCE(pcr.t_value, 99) <= 2
        ))`;

const dc0402Num = `COUNT(*) FILTER (WHERE ${cancerReadmissionFilter})`;

const de0501Num = `COUNT(*) FILTER (WHERE ${engraftmentFilter})`;

const de0801Num = `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${chelatorFilter})`;
const de0801Den = `COUNT(DISTINCT opd_periodized.hn)`;

const de1201Num = `COUNT(DISTINCT periodized.hn) FILTER (WHERE ${cleftRepairFilter('lip', 6)})`;
const de1201Den = `COUNT(DISTINCT periodized.hn)`;

const de1202Num = `COUNT(DISTINCT periodized.hn) FILTER (WHERE ${cleftRepairFilter('palate', 18)})`;
const de1202Den = `COUNT(DISTINCT periodized.hn)`;

export const MATERNAL_SPECIALTY_BRANCHES: readonly string[] = [
  // CM0101: maternal deaths around delivery per 100,000 live newborns (annual).
  branchFact(
    'CM0101',
    cm0101Num,
    cm0101Den,
    ratioValue(cm0101Num, cm0101Den, '100000.0'),
    'TRUE',
    { source: 'delivery_periodized' },
  ),
  // CM0201: perinatal deaths (500 g or 24 weeks) per 1,000 births (monthly).
  branchFact(
    'CM0201',
    cm0201Num,
    'COUNT(*)',
    ratioValue(cm0201Num, 'COUNT(*)', '1000.0'),
    'TRUE',
    { source: 'newborn_periodized' },
  ),
  // CM0202: perinatal deaths (1000 g or 28 weeks) per 1,000 births (monthly).
  branchFact(
    'CM0202',
    cm0202Num,
    'COUNT(*)',
    ratioValue(cm0202Num, 'COUNT(*)', '1000.0'),
    'TRUE',
    { source: 'newborn_periodized' },
  ),
  // CM0203: neonatal deaths within 28 days per 1,000 live births (monthly).
  branchFact(
    'CM0203',
    cm0203Num,
    'COUNT(*)',
    ratioValue(cm0203Num, 'COUNT(*)', '1000.0'),
    `COALESCE(newborn_periodized.dead, 'N') <> 'Y'`,
    { source: 'newborn_periodized' },
  ),
  // DE1601: newborn hearing screening within 30 days (annual, external).
  branchExternal('DE1601'),
  // DE0101: mean wait days after BI-RADS 4 or higher mammogram (annual).
  branchFact(
    'DE0101',
    de0101Num,
    de0101Den,
    ratioValue(de0101Num, de0101Den, '1.0'),
    `${biradsConsultDays} IS NOT NULL`,
    { source: 'opd_periodized' },
  ),
  // DE0103: percent of new breast cancer cases staged 1 or 2 (annual).
  branchFact(
    'DE0103',
    de0103Num,
    'COUNT(*)',
    ratioValue(de0103Num, 'COUNT(*)', '100.0'),
    `EXISTS (
          SELECT 1
          FROM clinicmember_cancer cc
          WHERE cc.clinicmember_id = chronic_periodized.clinicmember_id
            AND LEFT(${DOTLESS(`COALESCE(cc.f53_topography, '')`)}, 3) = 'C50'
        )`,
    { source: 'chronic_periodized' },
  ),
  // DC0402: percent unplanned cancer re-admission (monthly).
  branchIpd(
    'DC0402',
    dc0402Num,
    'COUNT(*)',
    ratioValue(dc0402Num, 'COUNT(*)', '100.0'),
    cancerEpisodeCohort,
  ),
  // DC0403: percent liver cancer episodes discharged dead (monthly).
  branchIpd(
    'DC0403',
    'COUNT(*) FILTER (WHERE died)',
    'COUNT(*)',
    ratioValue('COUNT(*) FILTER (WHERE died)', 'COUNT(*)', '100.0'),
    liverCancerCohort,
  ),
  // DE0501: percent transplants with engraftment evidence in 45 days (annual).
  branchIpd(
    'DE0501',
    de0501Num,
    'COUNT(*)',
    ratioValue(de0501Num, 'COUNT(*)', '100.0'),
    transplantFilter,
  ),
  // DE0801: percent TDT iron overload patients on chelator (monthly).
  branchFact(
    'DE0801',
    de0801Num,
    de0801Den,
    ratioValue(de0801Num, de0801Den, '100.0'),
    `age_y > 2 AND age_y <= 15 AND ${thalassemiaVisit} AND ${ferritinOverloadFilter}`,
    { source: 'opd_periodized' },
  ),
  // DE1201: percent cleft lip repairs done by 6 months of age (quarterly).
  branchIpd(
    'DE1201',
    de1201Num,
    de1201Den,
    ratioValue(de1201Num, de1201Den, '100.0'),
    `${cleftCohort} AND ${cleftRepairFilter('lip', null)}`,
  ),
  // DE1202: percent cleft palate repairs done by 18 months of age (quarterly).
  branchIpd(
    'DE1202',
    de1202Num,
    de1202Den,
    ratioValue(de1202Num, de1202Den, '100.0'),
    `${cleftCohort} AND ${cleftRepairFilter('palate', null)}`,
  ),
  // DE1301 to DE1306: IVF or ICSI clinical pregnancy per embryo transfer
  // cycle by age band and cycle type (annual, external).
  branchExternal('DE1301'),
  branchExternal('DE1302'),
  branchExternal('DE1303'),
  branchExternal('DE1304'),
  branchExternal('DE1305'),
  branchExternal('DE1306'),
];

export const MATERNAL_SPECIALTY_APPROXIMATIONS: Readonly<Record<string, string>> = {
  CM0101:
    'Measures maternal deaths tied to a delivery record of this hospital from labour start to 42 days after delivery with a pregnancy related cause (death_preg_42_day flag or O cause code, external V W X Y causes excluded), per 100,000 live newborns counted from ipt_newborn rows not flagged dead (babies counted individually). The printed definition also needs deaths during pregnancy before any hospital delivery and deaths of mothers referred out and lost to follow up, which no HOSxP table links back to the delivery. Confirm with the hospital owner: death_preg_42_day flag semantics, ipt_newborn.dead values as the stillbirth marker, and how referred out maternal deaths are recorded.',
  CM0201:
    'Measures perinatal deaths per 1,000 births: newborn rows flagged dead (stillbirth proxy) or with a death record within 7 days of born_date among births of at least 500 g, or gestational age at least 24 weeks from ipt_pregnancy.ga of the mother admission when birth weight is missing. The printed WHO rule also needs follow up of transferred out infants to day 7 and exclusion of infants referred in from other hospitals, which HOSxP does not flag. Confirm ipt_newborn.dead semantics and that ipt_pregnancy.ga is gestational weeks at delivery.',
  CM0202:
    'Measures perinatal deaths per 1,000 births at the 28 week or 1000 g threshold: newborn rows flagged dead or with a death record within 7 days of born_date among births of at least 1000 g, or gestational age at least 28 weeks from ipt_pregnancy.ga when birth weight is missing. The printed definition adds sent out infant follow up and referred in exclusions that need local tracking. Confirm ipt_newborn.dead semantics and ipt_pregnancy.ga units with the hospital owner.',
  CM0203:
    'Measures neonatal deaths per 1,000 live births: newborn rows not flagged dead with a death record between born_date and 28 days after. The printed definition needs follow up of transferred out infants to day 28 including deaths after discharge, and excludes births referred in from other hospitals. Confirm that post discharge neonatal deaths land in the death table with the newborn admission number and that ipt_newborn.dead marks stillbirth only.',
  DE1601:
    'External branch: HOSxP has no OAE or AABR newborn hearing screening table (ckup_ear_* holds school audiometry only). Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1601, numerator equal to live newborns of gestational age 28 weeks or more screened by OAE or AABR within 30 days of birth, denominator equal to all live newborns in that fiscal year, value equal to numerator times 100 over denominator, and source_system naming the hearing screening system. Confirm the screening register, the 30 day window rule and the exclusion of infants transferred out before screening.',
  DE0101:
    'Measures mean waiting days from a BI-RADS 4 or higher mammogram (person_bc_screen.screen_date with mamogram_birads_result_integer at least 4) to the first doctor consultation date on patient_cancer_registeration, computed over screening visits whose consultation completed. The printed clock runs from the radiologist report time to the breast surgeon appointment and also counts BI-RADS 4 or higher patients whose biopsy was benign and who never reach a cancer registration. Confirm the BI-RADS integer coding, that patient_cancer_first_meet_doctor_date is the breast surgeon consultation, and where mammogram report timestamps live.',
  DE0103:
    'Measures percent of new breast cancer clinic registrations (clinicmember regdate inside the year with clinicmember_cancer.f53_topography starting C50) whose patient_cancer_registeration TNM values give an early stage reading (t_value at most 2, n_value at most 1, m_value 0 or null). The printed stage groups 1 and 2 per AJCC are broader (for example T3 N0 stage 2B) and the registry may encode the group directly in cancer_stage2_id or f53_cm_stage_code instead of TNM numbers. Confirm the TNM column coding and which field carries the final stage group at diagnosis.',
  DC0402:
    'Measures percent of cancer inpatient episodes (pdx or sdx malignant neoplasm C00 to C97, in situ D00 to D09, or Z510 Z511) that are readmissions within 28 days after a previous cancer discharge of the same patient. The printed definition counts unplanned returns BEFORE the booked appointment date, which HOSxP does not store. Confirm with the hospital owner the appointment date source and the planned versus unplanned flag; until then 28 days is the documented proxy used across this repo.',
  DC0403:
    'Measures percent of liver cancer inpatient episodes (pdx or sdx in C220, C222 to C229 per the thipKpiRules token list) discharged dead, all causes. The printed definition mixes death from any cause with death caused by liver cancer. Confirm whether C221 (intrahepatic bile duct carcinoma) belongs in the cohort, and whether deaths shortly after discharge should be attributed back to the admission.',
  DE0501:
    'Measures percent of stem cell or bone marrow transplant admissions (operation_detail.icdcode ICD-9 41.0x) showing an engraftment proxy within 45 days of the operation: a neutrophil lab item (name matching neutrophil) with numeric result at least 500. The printed definition needs true engraftment (ANC at least 500 for 3 consecutive days) and graft failure counting from a transplant registry that HOSxP lacks. Confirm the local lab item names for absolute neutrophil count, the value unit, and the procedure codes booked for transplants.',
  DE0801:
    'Measures percent of thalassemia patients older than 2 and up to 15 years with serum ferritin over 1000 in the month (lab item name matching ferritin with a numeric result) who received an iron chelator (deferasirox, deferoxamine or deferiprone in drugitems.name) within the same month, counted once per patient per month. The printed definition requires confirmed transfusion dependent thalassemia rather than any D56 code and an exact serum ferritin unit rule. Confirm the TDT cohort marking (clinic or registry) and the local chelator drug names.',
  DE1201:
    'Measures percent of patients with ICD-10 Q35 to Q37 (pdx or sdx) whose cleft lip repair on operation_list and operation_detail (ICD-9 30.4x or an operation_item name matching cleft lip or the Thai term) happened at age 6 months or younger (operation_date versus patient.birthday), counted once per patient per quarter. The printed cohort also includes pre surgical alveolar moulding cases and referred in children born outside the district. Confirm the local procedure item names and icdcode values for cleft repair and how referred in cases are booked.',
  DE1202:
    'Measures percent of patients with ICD-10 Q35 to Q37 (pdx or sdx) whose cleft palate repair on operation_list and operation_detail (ICD-9 2754 or an operation_item name matching cleft palate or the Thai term) happened at age 18 months or younger, counted once per patient per quarter. The printed cohort counts complete and incomplete unilateral and bilateral cleft lip palate and excludes late presenters only from review, not from the denominator. Confirm the local procedure item names and icdcode values for palatoplasty.',
  DE1301:
    'External branch: fresh embryo transfer cycles and clinical pregnancy confirmations live in the IVF clinic system, not HOSxP (no embryo, fertilisation or transfer tables exist). Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1301, numerator equal to women under 34 years with clinical pregnancy (fetal heartbeat at 6 to 8 weeks) after a fresh embryo transfer, denominator equal to fresh embryo transfer cycles in the same age band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age cut off (strictly under 34) and that one denominator row means one transfer cycle.',
  DE1302:
    'External branch: IVF or ICSI fresh embryo transfer cycles for the 34 to 39 year band are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1302, numerator equal to women aged 34 to 39 with clinical pregnancy after a fresh embryo transfer, denominator equal to fresh transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age band boundaries and the clinical pregnancy (fetal heartbeat) rule.',
  DE1303:
    'External branch: IVF or ICSI fresh embryo transfer cycles for the 40 years and older band are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1303, numerator equal to women aged 40 or more with clinical pregnancy after a fresh embryo transfer, denominator equal to fresh transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age rule (age at oocyte retrieval versus transfer) with the IVF team.',
  DE1304:
    'External branch: frozen thawed embryo transfer cycles (age under 34) are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1304, numerator equal to women under 34 with clinical pregnancy after a frozen embryo transfer, denominator equal to frozen transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm that thawed and cultured after thaw transfers both count as frozen cycles.',
  DE1305:
    'External branch: frozen thawed embryo transfer cycles (age 34 to 39) are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1305, numerator equal to women aged 34 to 39 with clinical pregnancy after a frozen embryo transfer, denominator equal to frozen transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age band boundaries and the pregnancy confirmation window.',
  DE1306:
    'External branch: frozen thawed embryo transfer cycles (age 40 and over) are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1306, numerator equal to women aged 40 or more with clinical pregnancy after a frozen embryo transfer, denominator equal to frozen transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age rule and that cancelled or thaw failed cycles are excluded from the denominator.',
};
