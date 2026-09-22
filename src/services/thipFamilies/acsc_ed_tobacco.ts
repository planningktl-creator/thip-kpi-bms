/**
 * THIP family batch `acsc_ed_tobacco`: 26 read-only HOSxP fact branches.
 *
 * Covers ACSC hospitalization rates (AA0101-AA0105), ED flow (CE0102-CE0103),
 * chronic self-care / ER utilization (HC0101-HC0102), medication use and
 * inventory (SM0102, SM0103, SM0201), and tobacco / nicotine dependence
 * (HH0101.1-HH0104.5).
 *
 * Contract (docs/agents/thip-family-batch-contract.md):
 * - branches built only with `branchIpd` / `branchFact` (read-only aggregates,
 *   helper-owned outer projection),
 * - dotless ICD literals compared via REPLACE(UPPER(TRIM(col)), '.', ''),
 * - every division written literally as `X / NULLIF(Y, 0)`; no other slash
 *   appears anywhere in the SQL,
 * - one row per episode/visit grain: EXISTS / COUNT(DISTINCT key) subqueries
 *   instead of joining one-to-many tables (ovstdiag, iptdiag, opitemrece,
 *   stock_trancation) into the row set,
 * - approximation gaps recorded in ACSC_ED_TOBACCO_APPROXIMATIONS.
 *
 * All HOSxP table.column references were verified against
 * Desktop/01_Excel/HOSxP Structure.xlsx (sheet HOSxP Structure), including
 * the stock transaction table spelling `stock_trancation`.
 */

import { branchFact, branchIpd } from '@/services/thipFamilyBase';

// ---------------------------------------------------------------------------
// Shared SQL fragments. Aliases: `sd` ovstdiag, `idg` iptdiag, `scr` opdscreen,
// `oi` opitemrece + `di` drugitems. Correlation root for OPD branches is
// `opd_periodized` (one row per ovst visit, `pdx` already dotless uppercase).
// ---------------------------------------------------------------------------

const POP_DEN = "NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0)";
const POP_VALUE = "ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2)";

const opdSource = { source: 'opd_periodized' } as const;

function ratio100(numerator: string, denominator: string): string {
  return `ROUND((${numerator} * 100.0) / NULLIF(${denominator}, 0), 2)`;
}

function ratioPlain(numerator: string, denominator: string): string {
  return `ROUND((${numerator} * 1.0) / NULLIF(${denominator}, 0), 2)}`;
}

// --- ACSC diagnosis sets (dotless) -----------------------------------------

const DIABETES_ACSC =
  "pdx IN ('E100', 'E101', 'E106', 'E109', 'E110', 'E111', 'E116', 'E119', 'E130', 'E131', 'E136', 'E139', 'E140', 'E141', 'E146', 'E149')";
const HYPERTENSION_ACSC = "pdx IN ('I10', 'I110', 'I119')";
const EPILEPSY_ACSC = "LEFT(pdx, 3) IN ('G40', 'G41')";
const ASTHMA_ACSC = "LEFT(pdx, 3) IN ('J45', 'J46')";
const COPD_ACSC = `(
      LEFT(pdx, 3) IN ('J40', 'J41', 'J42', 'J43', 'J44', 'J47')
      OR (
        (pdx = 'J100' OR pdx = 'J110' OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18', 'J20', 'J21', 'J22'))
        AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'J44'
        )
      )
    )`;

// --- ED flow clocks --------------------------------------------------------

const ED_MINUTES = "EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) / NULLIF(60, 0)";
const ED_LEVEL1_WHERE =
  'opd_periodized.enter_er_time IS NOT NULL' +
  ' AND opd_periodized.finish_time IS NOT NULL' +
  ' AND opd_periodized.finish_time > opd_periodized.enter_er_time' +
  ' AND opd_periodized.er_emergency_level_id = 1';

// --- Medication use code sets (dotless, from thipKpiRules tokens) ----------

const URI_TOKENS =
  "'B053', 'H650', 'H651', 'H659', 'H660', 'H664', 'H669', 'H670', 'H671', 'H678'," +
  " 'H720', 'H722', 'H728', 'H729', 'J010', 'J014', 'J018', 'J019', 'J020', 'J029'," +
  " 'J030', 'J038', 'J039', 'J040', 'J042', 'J050', 'J051', 'J060', 'J068', 'J069'," +
  " 'J101', 'J111', 'J200', 'J209', 'J210', 'J218', 'J219'";
const DIARRHEA_TOKENS =
  "'A000', 'A001', 'A009', 'A020', 'A030', 'A033', 'A038', 'A039', 'A040', 'A049'," +
  " 'A050', 'A053', 'A054', 'A059', 'A080', 'A085', 'K521', 'K528', 'K529'";

const uriVisitWhere = `(
      LEFT(pdx, 3) = 'J00'
      OR pdx IN (${URI_TOKENS})
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'J00'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN (${URI_TOKENS})
          )
      )
    )`;

const diarrheaVisitWhere = `(
      LEFT(pdx, 3) = 'A09'
      OR pdx IN (${DIARRHEA_TOKENS})
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'A09'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN (${DIARRHEA_TOKENS})
          )
      )
    )`;

const antibioticItemExists = `EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
      )`;

// --- Chronic self-care cohort predicates (HC0101 / HC0102) ----------------

function chronicCohortWhere(codes3: string): string {
  return `(
      LEFT(pdx, 3) IN (${codes3})
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN (${codes3})
      )
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN (${codes3})
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN (${codes3})
      )
    )`;
}

const asthmaContinuityVisits2 = `(
      SELECT COUNT(DISTINCT v2.vn)
      FROM ovst v2
      JOIN ovstdiag sd2 ON sd2.vn = v2.vn
      WHERE v2.hn = opd_periodized.hn
        AND v2.vstdate >= :start_date
        AND v2.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd2.icd10)), '.', ''), 3) IN ('J45', 'J46')
    )`;

const copdContinuityVisits2 = `(
      SELECT COUNT(DISTINCT v4.vn)
      FROM ovst v4
      JOIN ovstdiag sd4 ON sd4.vn = v4.vn
      WHERE v4.hn = opd_periodized.hn
        AND v4.vstdate >= :start_date
        AND v4.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd4.icd10)), '.', ''), 3) = 'J44'
    )`;

const erVisitsByPatient3 = `(
      SELECT COUNT(DISTINCT v3.vn)
      FROM ovst v3
      JOIN er_regist er3 ON er3.vn = v3.vn
      WHERE v3.hn = opd_periodized.hn
        AND v3.vstdate >= :start_date
        AND v3.vstdate < :end_date
    )`;

// --- Tobacco / nicotine dependence fragments ------------------------------

const smokingScreened = `EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND scr.smoking_type_id IS NOT NULL
      )`;

const smokingScreenedIpd = `EXISTS (
        SELECT 1
        FROM ovst v
        JOIN opdscreen scr ON scr.vn = v.vn
        WHERE v.an = periodized.an
          AND scr.smoking_type_id IS NOT NULL
      )`;

const nicotineDxVisit = `(
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    )`;

const nicotineTreatment = `(
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )`;

const abstinence6m = `(
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )`;

function diseaseGroupWhere(codes3: string): string {
  return `(
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN (${codes3})
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN (${codes3})
      )
    )`;
}

const dmGroupWhere = diseaseGroupWhere("'E10', 'E11', 'E12', 'E13', 'E14'");
const htGroupWhere = diseaseGroupWhere("'I10', 'I11', 'I12', 'I13', 'I14', 'I15'");
const asthmaGroupWhere = diseaseGroupWhere("'J45', 'J46'");
const copdGroupWhere = diseaseGroupWhere("'J44'");
const pregnantGroupWhere = `(
      EXISTS (
        SELECT 1
        FROM opdscreen pg
        WHERE pg.vn = opd_periodized.vn
          AND pg.pregnancy = 'Y'
      )
      OR EXISTS (
        SELECT 1
        FROM opdscreen_pregnancy pg2
        WHERE pg2.vn = opd_periodized.vn
      )
      OR EXISTS (
          SELECT 1
          FROM ipt_pregnancy ipg
          WHERE ipg.an = opd_periodized.an
        )
      OR EXISTS (
        SELECT 1
        FROM clinicmember cm
        WHERE cm.hn = opd_periodized.hn
          AND cm.with_pregnancy = 'Y'
      )
    )`;

// --- Branch builders ------------------------------------------------------

function tobaccoTreatmentBranch(code: string, groupWhere: string): string {
  const numerator = `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${nicotineTreatment})`;
  const denominator = 'COUNT(DISTINCT opd_periodized.hn)';
  return branchFact(
    code,
    numerator,
    denominator,
    ratio100(numerator, denominator),
    `opd_periodized.age_y >= 15 AND ${nicotineDxVisit} AND ${groupWhere}`,
    opdSource,
  );
}

function tobaccoAbstinenceBranch(code: string, groupWhere: string): string {
  const numerator = `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${nicotineTreatment} AND ${abstinence6m})`;
  const denominator = `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${nicotineTreatment})`;
  return branchFact(
    code,
    numerator,
    denominator,
    ratio100(numerator, denominator),
    `opd_periodized.age_y >= 15 AND ${nicotineDxVisit} AND ${groupWhere}`,
    opdSource,
  );
}

const ALL_PATIENTS_WHERE = '1 = 1';
const ANY_VISIT_WHERE = 'opd_periodized.event_date IS NOT NULL';

// ---------------------------------------------------------------------------
// Branches (26 codes, one branch each)
// ---------------------------------------------------------------------------

const sm0201Numerator = `MAX((
        SELECT SUM(bal.left_value)
        FROM (
          SELECT DISTINCT ON (st.item_id) (st.left_qty * st.price) AS left_value
          FROM stock_trancation st
          WHERE st.transaction_date >= opd_periodized.period_start
            AND st.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          ORDER BY st.item_id, st.transaction_date DESC, st.stock_trancation_id DESC
        ) bal
      ))`;

const sm0201Denominator = `MAX((
        SELECT SUM(st2.out_qty * st2.price)
        FROM stock_trancation st2
        WHERE st2.transaction_date >= opd_periodized.period_start
          AND st2.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          AND COALESCE(st2.out_qty, 0) > 0
      ))`;

export const ACSC_ED_TOBACCO_BRANCHES: readonly string[] = [
  // --- ACSC hospitalization rates (registered AA0104/AA0105 precedent) ---
  branchIpd('AA0101', 'COUNT(*)', POP_DEN, POP_VALUE, EPILEPSY_ACSC),
  branchIpd('AA0102', 'COUNT(*)', POP_DEN, POP_VALUE, COPD_ACSC),
  branchIpd('AA0103', 'COUNT(*)', POP_DEN, POP_VALUE, ASTHMA_ACSC),
  branchIpd('AA0104', 'COUNT(*)', POP_DEN, POP_VALUE, DIABETES_ACSC),
  branchIpd('AA0105', 'COUNT(*)', POP_DEN, POP_VALUE, HYPERTENSION_ACSC),

  // --- ED flow (triage level 1 emergency patients) ---
  branchFact(
    'CE0102',
    `SUM(${ED_MINUTES})`,
    'COUNT(*)',
    ratioPlain(`SUM(${ED_MINUTES})`, 'COUNT(*)'),
    ED_LEVEL1_WHERE,
    opdSource,
  ),
  branchFact(
    'CE0103',
    `COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) <= 3600)`,
    'COUNT(*)',
    ratio100(
      `COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) <= 3600)`,
      'COUNT(*)',
    ),
    ED_LEVEL1_WHERE,
    opdSource,
  ),

  // --- Chronic self-care (asthma / COPD continuity of care) ---
  branchFact(
    'HC0101',
    "COUNT(*) FILTER (WHERE opd_periodized.enter_er_time IS NOT NULL)",
    `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${asthmaContinuityVisits2} >= 2)`,
    ratioPlain(
      "COUNT(*) FILTER (WHERE opd_periodized.enter_er_time IS NOT NULL)",
      `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${asthmaContinuityVisits2} >= 2)`,
    ),
    chronicCohortWhere("'J45', 'J46'"),
    opdSource,
  ),
  branchFact(
    'HC0102',
    `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${erVisitsByPatient3} >= 3)`,
    `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${copdContinuityVisits2} >= 2)`,
    ratio100(
      `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${erVisitsByPatient3} >= 3)`,
      `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${copdContinuityVisits2} >= 2)`,
    ),
    chronicCohortWhere("'J44'"),
    opdSource,
  ),

  // --- Medication use ---
  branchFact(
    'SM0102',
    `COUNT(*) FILTER (WHERE ${antibioticItemExists})`,
    'COUNT(*)',
    ratio100(`COUNT(*) FILTER (WHERE ${antibioticItemExists})`, 'COUNT(*)'),
    uriVisitWhere,
    opdSource,
  ),
  branchFact(
    'SM0103',
    `COUNT(*) FILTER (WHERE ${antibioticItemExists})`,
    'COUNT(*)',
    ratio100(`COUNT(*) FILTER (WHERE ${antibioticItemExists})`, 'COUNT(*)'),
    diarrheaVisitWhere,
    opdSource,
  ),
  branchFact(
    'SM0201',
    sm0201Numerator,
    sm0201Denominator,
    ratioPlain(sm0201Numerator, sm0201Denominator),
    ANY_VISIT_WHERE,
    opdSource,
  ),

  // --- Tobacco use screening ---
  branchFact(
    'HH0101.1',
    `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${smokingScreened})`,
    'COUNT(DISTINCT opd_periodized.hn)',
    ratio100(
      `COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE ${smokingScreened})`,
      'COUNT(DISTINCT opd_periodized.hn)',
    ),
    'opd_periodized.age_y >= 15',
    opdSource,
  ),
  branchIpd(
    'HH0101.2',
    `COUNT(DISTINCT periodized.hn) FILTER (WHERE ${smokingScreenedIpd})`,
    'COUNT(DISTINCT periodized.hn)',
    ratio100(
      `COUNT(DISTINCT periodized.hn) FILTER (WHERE ${smokingScreenedIpd})`,
      'COUNT(DISTINCT periodized.hn)',
    ),
    'periodized.age_y >= 15',
  ),

  // --- Nicotine dependence treatment ---
  tobaccoTreatmentBranch('HH0102', ALL_PATIENTS_WHERE),
  tobaccoTreatmentBranch('HH0103.1', dmGroupWhere),
  tobaccoTreatmentBranch('HH0103.2', htGroupWhere),
  tobaccoTreatmentBranch('HH0103.3', asthmaGroupWhere),
  tobaccoTreatmentBranch('HH0103.4', copdGroupWhere),
  tobaccoTreatmentBranch('HH0103.5', pregnantGroupWhere),
  tobaccoTreatmentBranch('HH0103.6', copdGroupWhere),

  // --- 6-month continuous abstinence after treatment ---
  tobaccoAbstinenceBranch('HH0104.1', dmGroupWhere),
  tobaccoAbstinenceBranch('HH0104.2', htGroupWhere),
  tobaccoAbstinenceBranch('HH0104.3', asthmaGroupWhere),
  tobaccoAbstinenceBranch('HH0104.4', copdGroupWhere),
  tobaccoAbstinenceBranch('HH0104.5', pregnantGroupWhere),
];

// ---------------------------------------------------------------------------
// Honesty record: what each branch measures vs the printed definition.
// ---------------------------------------------------------------------------

const popDenominatorGap =
  'Denominator follows the registered AA0104/AA0105 precedent ' +
  '(COUNT(DISTINCT patient.hn) over the whole patient table), not the printed mid-year ' +
  'population aged 15-74 in the responsible area, and the numerator is not filtered to ' +
  'ages 15-74; the hospital owner must confirm the official population denominator and ' +
  'age band (or load the population rate into reporting.thip_external_facts).';

export const ACSC_ED_TOBACCO_APPROXIMATIONS: Readonly<Record<string, string>> = {
  AA0101:
    'Counts discharges (>= 4h stay) with Pdx G40 or G41 per fiscal year, one row per admission. ' +
    popDenominatorGap,
  AA0102:
    'Counts discharges with Pdx in J40-J44 or J47, or Pdx J100, J110, J12-J16, J18, J20-J22 ' +
    'carrying a secondary diagnosis J44 (EXISTS over iptdiag). ' +
    popDenominatorGap,
  AA0103:
    'Counts discharges with Pdx J45 or J46 (asthma). ' +
    popDenominatorGap,
  AA0104:
    'Counts discharges with the printed DM Pdx set E100, E101, E106, E109, E110, E111, E116, ' +
    'E119, E130, E131, E136, E139, E140, E141, E146, E149 (registered precedent). ' +
    popDenominatorGap,
  AA0105:
    'Counts discharges with Pdx I10, I110, I119 (registered precedent). The printed definition ' +
    'also excludes admissions with cardiac procedures 33.6, 35, 36, 37.3, 37.5, 37.7, 37.8, ' +
    '37.94, 37.98 (dotless 336, 35, 36, 373, 375, 377, 378, 3794, 3798 in iptoprt); that ' +
    'exclusion is NOT applied here to stay identical to the registered branch - the hospital ' +
    'owner must confirm which variant governs. ' +
    popDenominatorGap,
  CE0102:
    'Mean minutes from ER time-in (er_regist.enter_er_time) to time-out (finish_time) for ER ' +
    'visits flagged er_emergency_level_id = 1 (triage level 1 / 1A emergency). The printed ' +
    'definition samples only days 5, 15, 25 of each month and excludes deaths, off-hour clinic ' +
    'patients and admissions held in the ED; the branch measures all level-1 visits with both ' +
    'clocks stamped. The hospital owner must confirm the er_emergency_level_id value that maps ' +
    'to triage 1A and whether the 3-day sampling window must be enforced.',
  CE0103:
    'Percent of level-1 (er_emergency_level_id = 1) ER visits whose time-in to time-out span is ' +
    'at most 3600 seconds. Same sampling-window gap as CE0102 (printed definition collects only ' +
    'days 5, 15, 25 and means 1A treated at the ED within 60 minutes); the hospital owner must ' +
    'confirm the 1A level mapping and the sampling days.',
  HC0101:
    'Per fiscal year: numerator = ER attendances (er_regist clock present on the ovst visit) of ' +
    'asthma patients (J45, J46 on the visit or anywhere in the reporting range, OPD or IPD); ' +
    'denominator = distinct asthma patients with at least 2 asthma-coded OPD visits in the ' +
    'reporting range. Value is a plain a over b (no x100 per thipKpiRules). The printed title ' +
    'is about self-care ability of patients or relatives while the printed numerator and ' +
    'denominator measure ER reliance versus continuous OPD follow-up; the hospital owner must ' +
    'confirm which reading governs and how continuous care (at least 2 visits per year) is ' +
    'certified locally. Person counts use the reporting-range params, so run one reporting ' +
    'period per execution for exact person denominators.',
  HC0102:
    'Per fiscal year: numerator = distinct COPD patients (J44) with at least 3 ER visits in the ' +
    'reporting range; denominator = distinct COPD patients with at least 2 COPD-coded OPD visits ' +
    'in the reporting range. Same title-versus-definition gap as HC0101 (self-care ability) and ' +
    'the same one-reporting-period execution caveat for person counts.',
  SM0102:
    'Percent of URI visits (Pdx or ovstdiag in the printed dotless token set from thipKpiRules: ' +
    'B053, H650-H678, H720-H729, J00, J010-J219 subset) that received at least one antibiotic ' +
    'item (drugitems.antibiotic = Y or drugcategory like antibio) on the same visit via ' +
    'opitemrece. One visit is treated as one prescription (ใบสั่งยา); a hospital issuing several ' +
    'prescription slips per visit must confirm the slip grain (e.g. via opitemreceh).',
  SM0103:
    'Percent of acute-diarrhea visits (printed dotless token set A000-A085, A09x, K521, K528, ' +
    'K529) that received at least one antibiotic item on the same visit. Same prescription-grain ' +
    'approximation as SM0102.',
  SM0201:
    'Monthly inventory ratio a over b: a = month-end remaining stock value (last stock_trancation ' +
    'row per item in the month, left_qty times price, summed across main and sub warehouses); ' +
    'b = dispensed value of the month (out_qty times price on stock_trancation). The formula ' +
    'direction follows thipKpiRules formulaScale a over b (inventory turn); classic inventory ' +
    'turn is consumption over stock, so the hospital owner must confirm the PDF formula ' +
    'direction, that price is the cost price (drugitems.unitcost or stock_item.unit_cost may be ' +
    'authoritative), and which stock classes count as safety/reserve drugs (no ยาสำรอง flag is ' +
    'verified in stock_item). A month with stock activity but zero OPD visits emits no row.',
  'HH0101.1':
    'Quarterly percent of distinct OPD recipients aged 15+ with at least one visit screen ' +
    'recording smoking status (opdscreen.smoking_type_id IS NOT NULL). Screening is per visit ' +
    'but the printed definition counts recipients; ER visits registered through ovst are also ' +
    'OPD rows here. Confirm the local smoking_type_id semantics (2, 3 = current smoker) and ' +
    'whether ER visits belong in the OPD service denominator.',
  'HH0101.2':
    'Quarterly percent of distinct inpatients aged 15+ whose admission has a smoking-status ' +
    'screen via the admitting ovst visit (ovst.an = periodized.an joined to opdscreen). HOSxP ' +
    'keeps no separate IPD smoking-screen table; the hospital owner must confirm the admitting ' +
    'visit screen is the official inpatient screening record.',
  HH0102:
    'Semiannual percent of distinct patients aged 15+ with a nicotine-dependence diagnosis ' +
    '(F17 or Z720 on Pdx, ovstdiag or iptdiag of the visit) who received treatment: Z716 ' +
    'counseling diagnosis, any opdscreen advice flag (advice1..advice8 or advice7_note smoke ' +
    'text), or a bupropion, varenicline or nicotine item on the visit. The printed definition ' +
    'needs a certified nicotine-dependence diagnosis and a treatment program per the hospital ' +
    'cessation guideline; Z720 and advice flags are proxies the owner must confirm.',
  'HH0103.1':
    'HH0102 restricted to the diabetes group (E10-E14 diagnosis anywhere in the reporting ' +
    'range, OPD or IPD). Group membership is diagnosis-based; the owner must confirm whether ' +
    'clinicmember DM registration should define the group instead.',
  'HH0103.2':
    'HH0102 restricted to the hypertension group (I10-I15 diagnosis anywhere in the reporting ' +
    'range). Same group-membership confirmation as HH0103.1.',
  'HH0103.3':
    'HH0102 restricted to the asthma group (J45, J46 diagnosis anywhere in the reporting range).',
  'HH0103.4':
    'HH0102 restricted to the COPD group (J44 diagnosis anywhere in the reporting range).',
  'HH0103.5':
    'HH0102 restricted to the pregnant group (opdscreen.pregnancy = Y or opdscreen_pregnancy ' +
    'row on the visit, ipt_pregnancy on the admission, or clinicmember.with_pregnancy = Y). ' +
    'person_anc-based ANC registration was not wired (person-to-hn linkage unverified); the ' +
    'owner must confirm how pregnancy status is recorded for smokers.',
  'HH0103.6':
    'Implemented as the COPD group (same predicate as HH0103.4) because the Thai definition and ' +
    'title of HH0103.6 both say ถุงลมโป่งพอง (COPD) while its English title says Asthma and the ' +
    'PDF repeats the COPD group; the hospital owner must confirm which group HH0103.6 really ' +
    'covers before publication.',
  'HH0104.1':
    'Annual percent of the treated diabetes-group nicotine-dependence cohort (HH0103.1 numerator ' +
    'grain) whose follow-up screens support 6-month abstinence: at least one screen 180-270 days ' +
    'after the treatment visit showing non-smoker (smoking_type_id not in 2, 3) and no screen in ' +
    'the 270-day window showing relapse (smoking_type_id in 2, 3). Continuous abstinence per the ' +
    'printed definition requires a certified cessation-program follow-up record that HOSxP does ' +
    'not hold; the window and self-report screens are an approximation the owner must confirm.',
  'HH0104.2':
    'HH0104.1 abstinence rule applied to the hypertension group (HH0103.2 cohort). Same ' +
    'follow-up-window approximation.',
  'HH0104.3':
    'HH0104.1 abstinence rule applied to the asthma group (HH0103.3 cohort). Same ' +
    'follow-up-window approximation.',
  'HH0104.4':
    'HH0104.1 abstinence rule applied to the COPD group (HH0103.4 cohort). Same ' +
    'follow-up-window approximation.',
  'HH0104.5':
    'HH0104.1 abstinence rule applied to the pregnant group (HH0103.5 cohort). Same ' +
    'follow-up-window approximation; confirm how pregnancy is tracked over the 6-month window.',
};
