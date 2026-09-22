/**
 * THIP KPI family batch `ncd_mental`: HIV, TB, CKD, mental and development
 * fact branches (28 codes, exactly one branch per code).
 *
 * Grain and anchor: `chronic_periodized` (one `clinicmember` registration per
 * row, periodized on `regdate`), so `COUNT(DISTINCT clinicmember_id)` counts
 * members and every one-to-many HOSxP table is reached through correlated
 * inline subqueries (`EXISTS`, or `LEFT JOIN LATERAL (... LIMIT 1)` / aggregate
 * laterals) that can never fan out the base row. The helpers in
 * `thipFamilyBase` own the cadence bucketing; the gap between that anchor and
 * each printed definition is recorded per code in `NCD_MENTAL_APPROXIMATIONS`.
 *
 * Every table.column referenced below was verified against the `HOSxP
 * Structure` workbook (sheet `HOSxP Structure`): clinicmember, clinic_visit,
 * clinicmember_tb, clinicmember_tb_patient_type, tb_register,
 * tb_register_visit, tb_lab_examination_sputum, tb_result_sputum,
 * tb_discharge_type, arv_tx, arv_lab_map, clinic_ckd_member,
 * clinic_ckd_member_visit, lab_head, lab_order, lab_items, opitemrece,
 * drugitems, ovstdiag, ovst, psych_assess_head, psych_assess_child,
 * psych_assess_topic, psych_plan, psych_therapy, psych_screen_child.
 *
 * SQL contract: read-only aggregates, dotless ICD literals compared via
 * REPLACE(UPPER(TRIM(icd10)), '.', ''), the only division is the NULLIF
 * guarded value ratio, the outer projection stays within the seven contract
 * columns and carries no patient identifier, and no base row is multiplied.
 */

import { branchExternal, branchFact } from '@/services/thipFamilyBase';

const SOURCE = 'chronic_periodized';
const R = 'chronic_periodized.regdate';

type Window = { from: string; to: string };

const TRAIL_12M: Window = { from: `${R} - INTERVAL '12 months'`, to: R };
const TRAIL_6M: Window = { from: `${R} - INTERVAL '6 months'`, to: R };
const AFTER_6M: Window = { from: R, to: `${R} + INTERVAL '6 months'` };
const AFTER_12M: Window = { from: R, to: `${R} + INTERVAL '12 months'` };
const AROUND_3M: Window = { from: `${R} - INTERVAL '3 months'`, to: `${R} + INTERVAL '3 months'` };
const AFTER_90D: Window = { from: R, to: `${R} + INTERVAL '90 days'` };
const RETAIN_1Y: Window = { from: `${R} + INTERVAL '11 months'`, to: `${R} + INTERVAL '15 months'` };

/** Safe numeric cast over `lab_order.lab_order_result`, as in queryRegistry. */
const LAB_NUMERIC =
  "CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END";

const VL_NAME = `li.lab_items_name ILIKE '%viral%'`;
const PAP_NAME = `li.lab_items_name ILIKE '%pap%'`;
const SYPH_NAME =
  "li.lab_items_name ILIKE '%vdrl%' OR li.lab_items_name ILIKE '%rpr%' OR li.lab_items_name ILIKE '%tpha%' OR li.lab_items_name ILIKE '%tppa%' OR li.lab_items_name ILIKE '%syphilis%' OR li.lab_items_name ILIKE '%ซิฟิลิส%'";
const HIV_LAB_NAME = `li.lab_items_name ILIKE '%hiv%' OR li.lab_items_name ILIKE '%เอชไอวี%'`;
const EGFR_NAME = `li.lab_items_name ILIKE '%egfr%' OR li.lab_items_name ILIKE '%gfr%'`;

const ARV_DRUG =
  "di.name ILIKE '%tenofovir%' OR di.name ILIKE '%lamivudine%' OR di.name ILIKE '%zidovudine%' OR di.name ILIKE '%emtricitabine%' OR di.name ILIKE '%abacavir%' OR di.name ILIKE '%efavirenz%' OR di.name ILIKE '%nevirapine%' OR di.name ILIKE '%lopinavir%' OR di.name ILIKE '%atazanavir%' OR di.name ILIKE '%darunavir%' OR di.name ILIKE '%dolutegravir%' OR di.name ILIKE '%raltegravir%'";
const TPT_DRUG =
  "di.name ILIKE '%isoniazid%' OR di.name ILIKE '%rifapentine%' OR di.name ILIKE '%rifampicin%' OR di.name ILIKE '%inah%'";
const ACE_ARB_DRUG =
  "di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%' OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%' OR di.name ILIKE '%benazepril%' OR di.name ILIKE '%imidapril%' OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%' OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%'";
const METHADONE_DRUG = `di.name ILIKE '%methadone%'`;

const HIV_DX_3 = ['B20', 'B21', 'B22', 'B23', 'B24'];
const HIV_DX_EXACT = ['Z21'];

/** Correlated diagnosis probe over `ovstdiag` (own `hn`, `vstdate`, `icd10`). */
function dxExists(alias: string, codes3: readonly string[], exact: readonly string[] = []): string {
  const parts: string[] = [];
  if (codes3.length > 0) {
    parts.push(
      `LEFT(REPLACE(UPPER(TRIM(${alias}.icd10)), '.', ''), 3) IN (${codes3.map((c) => `'${c}'`).join(', ')})`,
    );
  }
  if (exact.length > 0) {
    parts.push(
      `REPLACE(UPPER(TRIM(${alias}.icd10)), '.', '') IN (${exact.map((c) => `'${c}'`).join(', ')})`,
    );
  }
  return `EXISTS (
      SELECT 1
      FROM ovstdiag ${alias}
      WHERE ${alias}.hn = chronic_periodized.hn
        AND (${parts.join(' OR ')})
    )`;
}

/** PLHIV cohort: ARV registry entry or an HIV ICD-10 diagnosis (B20-B24, Z21). */
function hivCohort(): string {
  return `EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR ${dxExists('sdh', HIV_DX_3, HIV_DX_EXACT)}`;
}

/** One-row boolean flag lateral over lab items; keeps the base grain intact. */
function labFlagLateral(alias: string, nameCond: string, w: Window, extra = ''): string {
  const extraLine = extra ? `\n          AND ${extra}` : '';
  return `LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (${nameCond})
          AND lh.order_date >= ${w.from}
          AND lh.order_date <= ${w.to}${extraLine}
      ) AS flagged
    ) ${alias} ON TRUE`;
}

/** One-row boolean flag lateral over outpatient dispensing (`opitemrece`). */
function drugFlagLateral(alias: string, nameCond: string, w: Window): string {
  return `LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (${nameCond})
          AND oi.vstdate >= ${w.from}
          AND oi.vstdate <= ${w.to}
      ) AS flagged
    ) ${alias} ON TRUE`;
}

/** One-row eGFR summary lateral (count, first and last numeric result). */
function egfrLateral(alias: string, w: Window): string {
  return `LEFT JOIN LATERAL (
      SELECT
        COUNT(${LAB_NUMERIC}) AS n,
        (array_agg(${LAB_NUMERIC} ORDER BY lh.order_date))[1] AS first_val,
        (array_agg(${LAB_NUMERIC} ORDER BY lh.order_date DESC))[1] AS last_val
      FROM lab_head lh
      JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
      JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
      WHERE lh.hn = chronic_periodized.hn
        AND (${EGFR_NAME})
        AND lh.order_date >= ${w.from}
        AND lh.order_date <= ${w.to}
    ) ${alias} ON TRUE`;
}

/** Nearest `tb_register` episode around the clinic registration date. */
const TB_REGISTER_JOIN = `LEFT JOIN LATERAL (
      SELECT
        tbr.tb_register_id,
        tbr.tb_register_date,
        tbr.tb_register_start_date_treatment,
        tbr.tb_discharge_type_id,
        tbr.clinicmember_tb_patient_type_id,
        tbr.tb_result_sputum_id,
        tbr.tb_register_receive_recomment_hiv_date
      FROM tb_register tbr
      WHERE tbr.hn = chronic_periodized.hn
        AND tbr.tb_register_date >= ${AROUND_3M.from}
        AND tbr.tb_register_date <= ${AROUND_3M.to}
      ORDER BY ABS(tbr.tb_register_date - chronic_periodized.regdate)
      LIMIT 1
    ) tbr ON TRUE
    LEFT JOIN clinicmember_tb_patient_type tpt
      ON tpt.clinicmember_tb_patient_type_id = tbr.clinicmember_tb_patient_type_id
    LEFT JOIN tb_result_sputum trs
      ON trs.tb_result_sputum_id = tbr.tb_result_sputum_id
    LEFT JOIN tb_discharge_type tdt
      ON tdt.tb_discharge_type_id = tbr.tb_discharge_type_id`;

const TB_NEW_CASE =
  "(tpt.clinicmember_tb_patient_type_name ILIKE '%ใหม่%' OR tpt.clinicmember_tb_patient_type_name ILIKE '%new%')";
const TB_SMEAR_POSITIVE =
  "(trs.tb_result_sputum_name ILIKE '%บวก%' OR trs.tb_result_sputum_name ILIKE '%pos%')";
const TB_SUCCESS_OUTCOME =
  "tdt.tb_discharge_type_name ILIKE '%หาย%' OR tdt.tb_discharge_type_name ILIKE '%ครบ%' OR tdt.tb_discharge_type_name ILIKE '%cure%' OR tdt.tb_discharge_type_name ILIKE '%complete%'";

/** Not currently treated for TB: no recent `tb_register` episode. */
function notActiveTb(): string {
  return `NOT EXISTS (
      SELECT 1
      FROM tb_register tba
      WHERE tba.hn = chronic_periodized.hn
        AND tba.tb_register_date >= ${R} - INTERVAL '12 months'
        AND tba.tb_register_date <= ${R} + INTERVAL '6 months'
    )`;
}

const TEDA_TOPIC_1 = `JOIN psych_assess_topic tpa ON tpa.psych_assess_topic_id = h1.psych_assess_topic_id AND tpa.psych_assess_topic_name ILIKE '%teda%'`;
const TEDA_TOPIC_2 = `JOIN psych_assess_topic tpb ON tpb.psych_assess_topic_id = h2.psych_assess_topic_id AND tpb.psych_assess_topic_name ILIKE '%teda%'`;

/** Developmental age in months for one domain of `psych_assess_child`. */
function dom(alias: string, d: string): string {
  return `(${alias}.psych_assess_child_${d}_year * 12 + ${alias}.psych_assess_child_${d}_month)`;
}
const DOMAINS = ['gm', 'fm', 'rl', 'el', 'ps'] as const;

/** At least one of the five domains up and none of them down. */
function anyDomainImproved(c1: string, c2: string): string {
  const ups = DOMAINS.map((d) => `${dom(c2, d)} > ${dom(c1, d)}`).join(' OR ');
  const noneDown = DOMAINS.map((d) => `${dom(c2, d)} >= ${dom(c1, d)}`).join(' AND ');
  return `((${ups}) AND (${noneDown}))`;
}

/** Receptive or expressive language up together with personal and social up. */
function languageSocialImproved(c1: string, c2: string): string {
  const noneDown = DOMAINS.map((d) => `${dom(c2, d)} >= ${dom(c1, d)}`).join(' AND ');
  return `(((${dom(c2, 'rl')} > ${dom(c1, 'rl')} OR ${dom(c2, 'el')} > ${dom(c1, 'el')}) AND ${dom(c2, 'ps')} > ${dom(c1, 'ps')}) AND (${noneDown}))`;
}

/**
 * Paired-assessment improvement flag: a follow-up assessment one to six months
 * after the baseline assessment improves over the baseline on the supplied
 * domain condition (optionally restricted to TEDA4I topics).
 */
function improveFlagLateral(
  alias: string,
  condition: (c1: string, c2: string) => string,
  w: Window,
  tedaOnly: boolean,
): string {
  return `LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        ${tedaOnly ? TEDA_TOPIC_1 : ''}
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        ${tedaOnly ? TEDA_TOPIC_2 : ''}
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= ${w.from}
          AND h1.date_assessment <= ${w.to}
          AND (${condition('c1', 'c2')})
      ) AS flagged
    ) ${alias} ON TRUE`;
}

function assessedExists(w: Window, tedaOnly: boolean): string {
  const topicFilter = tedaOnly
    ? `\n        AND ha.psych_assess_topic_id IN (SELECT tpx.psych_assess_topic_id FROM psych_assess_topic tpx WHERE tpx.psych_assess_topic_name ILIKE '%teda%')`
    : '';
  return `EXISTS (
      SELECT 1
      FROM psych_assess_head ha
      JOIN psych_assess_child ca ON ca.psych_assess_head_id = ha.psych_assess_head_id
      WHERE ha.hn = chronic_periodized.hn
        AND ha.date_assessment >= ${w.from}
        AND ha.date_assessment <= ${w.to}${topicFilter}
    )`;
}

/** In treatment per programme: a therapy session or a psych plan in the window. */
function treatedExists(w: Window): string {
  return `(EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= ${w.from}
        AND th.psych_therapy_date <= ${w.to}
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= ${w.from}
        AND pp.psych_plan_date <= ${w.to}
    ))`;
}

function memberCount(flag?: string): string {
  return flag ? `COUNT(DISTINCT clinicmember_id) FILTER (WHERE ${flag})` : 'COUNT(DISTINCT clinicmember_id)';
}

function ratioValue(numExpr: string, denExpr: string): string {
  return `ROUND((${numExpr} * 100.0) / NULLIF(${denExpr}, 0), 2)`;
}

function memberBranch(code: string, den: string, num: string, where: string, join: string): string {
  return branchFact(code, num, den, ratioValue(num, den), where, { source: SOURCE, join });
}

// --- HIV cohort branches (annual) -------------------------------------------

const DC0301 = memberBranch(
  'DC0301',
  memberCount(),
  memberCount('vl_done.flagged'),
  `(${hivCohort()})
    AND EXISTS (
      SELECT 1
      FROM arv_tx ax
      WHERE ax.hn = chronic_periodized.hn
        AND ax.date_entry <= ${R} - INTERVAL '6 months'
    )`,
  labFlagLateral('vl_done', VL_NAME, TRAIL_12M),
);

const DC0302 = memberBranch(
  'DC0302',
  memberCount(),
  memberCount('vl50_done.flagged'),
  `(${hivCohort()})
    AND EXISTS (
      SELECT 1
      FROM arv_tx ax
      WHERE ax.hn = chronic_periodized.hn
        AND ax.date_entry <= ${R} - INTERVAL '12 months'
    )`,
  labFlagLateral('vl50_done', VL_NAME, TRAIL_12M, `${LAB_NUMERIC} IS NOT NULL AND ${LAB_NUMERIC} < 50`),
);

const DC0306 = memberBranch(
  'DC0306',
  memberCount(),
  memberCount('pap_done.flagged'),
  `chronic_periodized.sex = '2'
    AND (${hivCohort()})`,
  labFlagLateral('pap_done', PAP_NAME, TRAIL_12M),
);

const DC0307 = memberBranch(
  'DC0307',
  memberCount(),
  memberCount('syph_done.flagged'),
  `(${hivCohort()})`,
  labFlagLateral('syph_done', SYPH_NAME, AFTER_12M),
);

const DC0308 = memberBranch(
  'DC0308',
  memberCount(),
  memberCount('arv_pickup.flagged'),
  `(${hivCohort()})`,
  drugFlagLateral('arv_pickup', ARV_DRUG, TRAIL_12M),
);

const DC0309 = memberBranch(
  'DC0309',
  memberCount(),
  memberCount('tpt_done.flagged'),
  `(${hivCohort()})
    AND ${notActiveTb()}`,
  drugFlagLateral('tpt_done', TPT_DRUG, AFTER_6M),
);

// --- TB registry branches (annual) ------------------------------------------

const DR0202 = memberBranch(
  'DR0202',
  memberCount(),
  memberCount('tb_scr.flagged'),
  `(${hivCohort()})
    AND ${notActiveTb()}`,
  `LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM tb_lab_examination_sputum ts
        WHERE ts.tb_register_id IN (
            SELECT tbrs.tb_register_id FROM tb_register tbrs WHERE tbrs.hn = chronic_periodized.hn
          )
          AND ts.tb_lab_examination_sputum_date >= ${TRAIL_12M.from}
          AND ts.tb_lab_examination_sputum_date <= ${TRAIL_12M.to}
      ) OR EXISTS (
        SELECT 1
        FROM clinic_visit cv
        JOIN ovst cvv ON cvv.vn = cv.vn
        WHERE cv.hn = chronic_periodized.hn
          AND cv.afb_check = 'Y'
          AND cvv.vstdate >= ${TRAIL_12M.from}
          AND cvv.vstdate <= ${TRAIL_12M.to}
      ) OR EXISTS (
        SELECT 1
        FROM tb_register tbr2
        WHERE tbr2.hn = chronic_periodized.hn
          AND tbr2.tb_register_receive_recomment_tb_date >= ${TRAIL_12M.from}
          AND tbr2.tb_register_receive_recomment_tb_date <= ${TRAIL_12M.to}
      ) AS flagged
    ) tb_scr ON TRUE`,
);

const DR0203 = memberBranch(
  'DR0203',
  memberCount(),
  memberCount(TB_SUCCESS_OUTCOME),
  `tbr.tb_register_id IS NOT NULL
    AND ${TB_NEW_CASE}
    AND ${TB_SMEAR_POSITIVE}`,
  TB_REGISTER_JOIN,
);

const DR0204 = memberBranch(
  'DR0204',
  memberCount(),
  memberCount('hiv_scr.flagged'),
  `tbr.tb_register_id IS NOT NULL`,
  `${TB_REGISTER_JOIN}
    LEFT JOIN LATERAL (
      SELECT
        (tbr.tb_register_receive_recomment_hiv_date IS NOT NULL) OR EXISTS (
          SELECT 1
          FROM lab_head lh
          JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = chronic_periodized.hn
            AND (${HIV_LAB_NAME})
            AND lh.order_date >= ${TRAIL_12M.from}
            AND lh.order_date <= ${TRAIL_12M.to}
        ) AS flagged
    ) hiv_scr ON TRUE`,
);

const DR0205 = memberBranch(
  'DR0205',
  memberCount(),
  memberCount('art_started.flagged'),
  `tbr.tb_register_id IS NOT NULL
    AND (${hivCohort()})`,
  `${TB_REGISTER_JOIN}
    LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM arv_tx ax
        WHERE ax.hn = chronic_periodized.hn
          AND ax.date_entry <= ${AFTER_6M.to}
      ) AS flagged
    ) art_started ON TRUE`,
);

// --- CKD registry branches ---------------------------------------------------

const CKD_REGISTERED = `EXISTS (
      SELECT 1
      FROM clinic_ckd_member ck
      WHERE ck.clinicmember_id = chronic_periodized.clinicmember_id
    )`;

const DC0501 = memberBranch(
  'DC0501',
  memberCount(),
  memberCount('egfr.first_val - egfr.last_val < 4'),
  `${CKD_REGISTERED}
    AND egfr.n >= 2
    AND egfr.first_val IS NOT NULL
    AND egfr.last_val IS NOT NULL
    AND egfr.first_val >= 15
    AND egfr.first_val < 60`,
  egfrLateral('egfr', TRAIL_12M),
);

const DC0502 = memberBranch(
  'DC0502',
  memberCount(),
  memberCount('ace_arb.flagged'),
  `${CKD_REGISTERED}
    AND egfr.n >= 1
    AND egfr.last_val IS NOT NULL
    AND egfr.last_val >= 15`,
  `${egfrLateral('egfr', TRAIL_6M)}
    ${drugFlagLateral('ace_arb', ACE_ARB_DRUG, TRAIL_6M)}`,
);

// --- Mental and child development branches -----------------------------------

const CP0101 = memberBranch(
  'CP0101',
  memberCount(),
  memberCount('attended.flagged'),
  `chronic_periodized.age_y <= 18
    AND (${dxExists('sdc', ['F80', 'F81', 'F82', 'F83', 'F90', 'F32', 'F33'], ['F341'])})
    AND EXISTS (
      SELECT 1
      FROM psych_plan pps
      WHERE pps.hn = chronic_periodized.hn
        AND pps.psych_plan_date >= ${TRAIL_6M.from}
        AND pps.psych_plan_date <= ${TRAIL_6M.to}
    )`,
  `LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_therapy th
        JOIN ovst tv ON tv.vn = th.vn_an
        WHERE tv.hn = chronic_periodized.hn
          AND th.psych_therapy_date >= ${TRAIL_6M.from}
          AND th.psych_therapy_date <= ${TRAIL_6M.to}
      ) OR EXISTS (
        SELECT 1
        FROM psych_plan pf
        WHERE pf.hn = chronic_periodized.hn
          AND pf.psych_plan_finish_date IS NOT NULL
          AND pf.psych_plan_finish_date >= ${TRAIL_6M.from}
          AND pf.psych_plan_finish_date <= ${TRAIL_6M.to}
      ) AS flagged
    ) attended ON TRUE`,
);

const CP0201 = memberBranch(
  'CP0201',
  memberCount(),
  memberCount('dx90.flagged'),
  `chronic_periodized.age_y <= 6
    AND EXISTS (
      SELECT 1
      FROM psych_screen_child psc
      WHERE psc.hn = chronic_periodized.hn
        AND psc.psych_screen_child_date >= ${AROUND_3M.from}
        AND psc.psych_screen_child_date <= ${AROUND_3M.to}
    )`,
  `LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM ovstdiag sd9
        WHERE sd9.hn = chronic_periodized.hn
          AND LEFT(REPLACE(UPPER(TRIM(sd9.icd10)), '.', ''), 3) IN ('F83', 'R62', 'F84', 'G80')
          AND sd9.vstdate >= ${AFTER_90D.from}
          AND sd9.vstdate <= ${AFTER_90D.to}
      ) AS flagged
    ) dx90 ON TRUE`,
);

const DM0101 = memberBranch(
  'DM0101',
  memberCount(),
  memberCount('imp.flagged'),
  `chronic_periodized.age_y <= 6
    AND ${dxExists('sdg', ['F83', 'R62'])}
    AND ${assessedExists(TRAIL_6M, false)}`,
  improveFlagLateral('imp', anyDomainImproved, TRAIL_6M, false),
);

const DM0102 = memberBranch(
  'DM0102',
  memberCount(),
  memberCount('imp.flagged'),
  `chronic_periodized.age_y <= 6
    AND ${dxExists('sdg', ['F83', 'R62'])}
    AND ${assessedExists(TRAIL_6M, true)}`,
  improveFlagLateral('imp', anyDomainImproved, TRAIL_6M, true),
);

const DM0201 = memberBranch(
  'DM0201',
  memberCount(),
  memberCount('imp.flagged'),
  `${dxExists('sda', ['F84'])}
    AND ${treatedExists(TRAIL_6M)}`,
  improveFlagLateral('imp', languageSocialImproved, TRAIL_6M, false),
);

const DM0202 = memberBranch(
  'DM0202',
  memberCount(),
  memberCount('imp.flagged'),
  `${dxExists('sda', ['F84'])}
    AND ${treatedExists(TRAIL_6M)}`,
  improveFlagLateral('imp', languageSocialImproved, TRAIL_6M, true),
);

const DM0301 = memberBranch(
  'DM0301',
  memberCount(),
  memberCount('imp.flagged'),
  `chronic_periodized.age_y <= 18
    AND ${dxExists('sdp', ['G80'])}
    AND ${treatedExists(TRAIL_6M)}`,
  improveFlagLateral('imp', anyDomainImproved, TRAIL_6M, false),
);

const DM0302 = memberBranch(
  'DM0302',
  memberCount(),
  memberCount('imp.flagged'),
  `chronic_periodized.age_y <= 18
    AND ${dxExists('sdp', ['G80'])}
    AND ${treatedExists(TRAIL_6M)}`,
  improveFlagLateral('imp', anyDomainImproved, TRAIL_6M, true),
);

// --- Substance use branch ----------------------------------------------------

const DS0401 = memberBranch(
  'DS0401',
  memberCount(),
  memberCount('mmt_retained.flagged'),
  `EXISTS (
      SELECT 1
      FROM opitemrece oi0
      JOIN drugitems di0 ON di0.icode = oi0.icode
      WHERE oi0.hn = chronic_periodized.hn
        AND di0.name ILIKE '%methadone%'
        AND oi0.vstdate >= ${AROUND_3M.from}
        AND oi0.vstdate <= ${AROUND_3M.to}
    )`,
  drugFlagLateral('mmt_retained', METHADONE_DRUG, RETAIN_1Y),
);

// --- Hospital-loaded aggregates (branchExternal) -----------------------------
// DM0103 and DM0203 track retention in the education system, DM0401 needs the
// SNAP-IV parent questionnaire score, DM0402 needs the CDI score or documented
// clinical remission, and DS0101, DS0201, DS0301 need the three-month
// abstinence verdict from the national addiction programme follow-up forms.
// None of these instrument or external-system facts exist as structured
// HOSxP columns (verified against the HOSxP Structure workbook: the
// psych_assess family keeps only question and answer references), so the
// hospital loads one aggregate row per code per reporting anchor into
// `reporting.thip_external_facts` (numerator, denominator, value,
// source_system) and these branches read it back.

const BRANCHES: Readonly<Record<string, string>> = {
  DC0301,
  DC0302,
  DC0306,
  DC0307,
  DC0308,
  DC0309,
  DR0202,
  DR0203,
  DR0204,
  DR0205,
  DC0501,
  DC0502,
  CP0101,
  CP0201,
  DM0101,
  DM0102,
  DM0103: branchExternal('DM0103'),
  DM0201,
  DM0202,
  DM0203: branchExternal('DM0203'),
  DM0301,
  DM0302,
  DM0401: branchExternal('DM0401'),
  DM0402: branchExternal('DM0402'),
  DS0101: branchExternal('DS0101'),
  DS0201: branchExternal('DS0201'),
  DS0301: branchExternal('DS0301'),
  DS0401,
};

const CODE_ORDER = [
  'DC0301', 'DC0302', 'DC0306', 'DC0307', 'DC0308', 'DC0309',
  'DR0202', 'DR0203', 'DR0204', 'DR0205',
  'DC0501', 'DC0502',
  'CP0101', 'CP0201',
  'DM0101', 'DM0102', 'DM0103', 'DM0201', 'DM0202', 'DM0203',
  'DM0301', 'DM0302', 'DM0401', 'DM0402',
  'DS0101', 'DS0201', 'DS0301', 'DS0401',
] as const;

/** One fact branch per assigned code, in the caller-supplied code order. */
export const NCD_MENTAL_BRANCHES: readonly string[] = CODE_ORDER.map((code) => BRANCHES[code]);

const STAGING_NOTE =
  'Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system';

export const NCD_MENTAL_APPROXIMATIONS: Readonly<Record<string, string>> = {
  DC0301:
    "Measures clinicmember registrations of PLHIV (arv_tx row or B20-B24, Z21 diagnosis) whose ARV record predates registration by more than 6 months and who have at least one viral-load lab item (name match) in the trailing 12 months. The PDF wants all PLHIV on ARV for more than 6 months during the reporting year with one VL in that year; the hospital owner must confirm arv_tx.date_entry as the ARV start date, the VL lab item set (arv_lab_map is the candidate refinement) and whether the cohort must be widened from the registration year to every member active in the year.",
  DC0302:
    "Measures members on ARV for at least 12 months (arv_tx.date_entry) with a numeric viral-load result below 50 copies in the trailing 12 months. The PDF wants VL below 50 at 12 months after ART start; the branch cannot tie the lab to the exact ART month, so the owner must confirm the VL item codes, the numeric-cast tolerance for result text and the 12-month window anchor.",
  DC0306:
    "Measures female PLHIV registrations with a Pap-smear lab item (name match) in the trailing 12 months. The PDF accepts Pap smear or VIA and counts each woman once per year; VIA procedures recorded outside the lab (for example sti_patient_register_lab) are missed, so the owner must confirm the Pap and VIA procedure coding and the sex field mapping.",
  DC0307:
    "Measures newly registered PLHIV (registration rows in the period) with a syphilis serology lab item (VDRL, RPR, TPHA, TPPA or name match) within 12 months after registration. The PDF asks for syphilis screening within the reporting year for new cases; repeat registrations of the same member can double count and pre-registration tests are excluded, so the owner must confirm the new-case rule and the screening window.",
  DC0308:
    "Measures PLHIV registrations with at least one ARV dispensing (opitemrece plus drugitems name set) in the trailing 12 months. The PDF wants all registered PLHIV in the denominator and those collecting ARV at least once in the year in the numerator; the denominator is limited to members registered in the period and the ARV name list must be signed off against the local formulary (arv_tx rows are the alternative signal).",
  DC0309:
    "Measures newly registered PLHIV without concurrent TB who received TB preventive therapy (isoniazid, rifapentine, rifampicin or INAH dispensing) within 6 months after registration. The PDF denominator needs the TPT indication (CD4 below 200, TST above 5 mm, IGRA or doctor decision), which has no HOSxP column, so the denominator approximates all new PLHIV without active TB; the owner must confirm the indication register or accept external staging.",
  DR0202:
    "Measures PLHIV without recent TB treatment whose TB screening is on file in the trailing 12 months, where screening is an AFB sputum examination, an afb_check clinic visit or the tb_register TB-screening advice date. The PDF also accepts symptom history and CXR which are not separately structured; the owner must confirm those screening channels or accept the recorded subset.",
  DR0203:
    "Measures TB registrations whose nearest tb_register episode within 3 months of the clinic registration is a new case (patient type name) with a positive sputum result at registration and whose discharge type name signals cure or completion. The PDF evaluates treatment outcomes 12 months back and the anchor is the clinicmember registration date rather than tb_register_date; the owner must confirm the patient-type and outcome name matching in clinicmember_tb_patient_type, tb_result_sputum and tb_discharge_type.",
  DR0204:
    "Measures TB registrations whose tb_register episode records an HIV screening signal: the receive_recomment_hiv_date column or an HIV lab item in the trailing 12 months. The PDF counts VCT, DCT and PICT counselling channels which may not reach the lab or that date column, so the owner must confirm the counselling record source (for example arv_counselling).",
  DR0205:
    "Measures HIV-positive TB registrations (tb_register episode plus HIV cohort evidence) with an arv_tx record starting within 6 months after registration. The PDF wants ART started within 6 months of TB treatment and sustained more than 6 months; the branch only sees the ARV record start, so the owner must confirm arv_tx.date_entry semantics and the TB-to-ART clock start.",
  DC0501:
    "Measures CKD registry members (clinic_ckd_member) with at least two numeric eGFR lab results in the trailing 12 months and baseline eGFR between 15 and 59 (stages 3-4) whose first-to-last decline is below 4. The PDF wants the mean annual change in ml per min per 1.73 m2 below 4; the branch approximates the annual slope with first minus last over a 12-month window, so the owner must confirm the eGFR item set, the stage boundary values and the slope convention.",
  DC0502:
    "Measures CKD registry members with a last eGFR of at least 15 (stages 1-4) in the trailing 6 months who collected an ACE inhibitor or ARB (drugitems name set) in the same window. The PDF wants current use of ACEi or ARB among CKD stages 1-4; the owner must confirm the antihypertensive name list against the local formulary and the eGFR item set.",
  CP0101:
    "Measures members aged 18 or under with an ADHD, LD or MDD diagnosis (F80-F83, F90, F32, F33, F341) and a psych_plan in the trailing 6 months who attended care: a psych_therapy session or a finished psych_plan in the same window. The PDF is about carers keeping every scheduled appointment in the 6-month period; HOSxP has no appointment-kept ledger here, so attendance is approximated by recorded therapy or plan completion and the owner must confirm the appointment source (clinic_app or psychiatric_clinic_psychia_appointment).",
  CP0201:
    "Measures members aged 6 or under with a child development screen (psych_screen_child) around registration who received a neurodevelopmental diagnosis (F83, R62, F84, G80) within 90 days after registration. The PDF starts the 90-day clock at the first service visit for suspected delay and excludes therapy-only contacts; the screen date stands in for the suspicion entry, so the owner must confirm the suspicion flag and the first-visit anchor.",
  DM0101:
    "Measures members aged 6 or under with GDD (F83, R62) who had a developmental assessment in the trailing 6 months (denominator) and whose paired psych_assess_child records one to six months apart improve at least one of the five developmental-age domains with none worse (numerator). The PDF leaves the improvement instrument to context and needs clinical judgement over 6 months of treatment; the domain-month comparison is the closest structured aggregate, so the owner must confirm the domain columns and the pair window.",
  DM0102:
    "Same cohort and domain-pair rule as DM0101 but both assessments must sit under a psych_assess_topic named for TEDA4I. The PDF requires the TEDA4I instrument specifically; topic-name matching is the only instrument binding in HOSxP, so the owner must confirm the TEDA4I topic naming in psych_assess_topic.",
  DM0103:
    'GDD school retention for at least one year is school-system data, absent from HOSxP. ' +
    STAGING_NOTE +
    ', for example sourced from the education referral follow-up register.',
  DM0201:
    "Measures members with ASD (F84) in treatment per programme (psych_therapy or psych_plan in the trailing 6 months, denominator) whose paired psych_assess_child records improve receptive or expressive language together with personal and social, with no domain worse (numerator). The PDF wants clinician-judged social and communication improvement over 6 months; the owner must confirm the domain mapping and the treatment-programme evidence.",
  DM0202:
    "Same cohort and language-plus-social pair rule as DM0201 but both assessments must sit under a psych_assess_topic named for TEDA4I. The TEDA4I binding is topic-name matching only, so the owner must confirm the TEDA4I topic naming in psych_assess_topic.",
  DM0203:
    'ASD school retention for at least one year is school-system data, absent from HOSxP (person_wbc keeps only child health book growth and vaccine fields). ' +
    STAGING_NOTE +
    ', for example sourced from the education referral follow-up register.',
  DM0301:
    "Measures members aged 18 or under with cerebral palsy (G80) in treatment per programme (psych_therapy or psych_plan in the trailing 6 months, denominator) whose paired psych_assess_child records improve at least one of the five domains with none worse (numerator). The PDF leaves the instrument to context and spans 6 months of treatment; the owner must confirm the domain mapping and the treatment-programme evidence.",
  DM0302:
    "Same cohort and domain-pair rule as DM0301 but both assessments must sit under a psych_assess_topic named for TEDA4I. The TEDA4I binding is topic-name matching only, so the owner must confirm the TEDA4I topic naming in psych_assess_topic.",
  DM0401:
    'ADHD improvement needs a parent SNAP-IV score pair; HOSxP psych_assess stores only question and answer references with no verified SNAP-IV binding (psych_assess_list.psych_assess_evalueate is ambiguous). ' +
    STAGING_NOTE +
    ', computed from the SNAP-IV parent questionnaires.',
  DM0402:
    'MDD remission needs the CDI score at 6 months or a documented clinical remission; psych_assess_cdi stores answer-type references only and depression_screen holds the 9Q score, a different instrument. ' +
    STAGING_NOTE +
    ', computed from CDI follow-up scores or the clinic remission register.',
  DS0101:
    'Methamphetamine three-month abstinence after discharge is a verdict from the national addiction programme follow-up forms, not a structured HOSxP fact (psych_screen_addict holds screening, not the follow-up abstinence verdict). ' +
    STAGING_NOTE +
    ', from the addiction treatment database follow-up outcomes.',
  DS0201:
    'Alcohol three-month abstinence after discharge is a follow-up verdict outside HOSxP, same gap as DS0101. ' +
    STAGING_NOTE +
    ', from the addiction treatment database follow-up outcomes.',
  DS0301:
    'Tobacco three-month abstinence after discharge is a follow-up verdict outside HOSxP, same gap as DS0101. ' +
    STAGING_NOTE +
    ', from the addiction treatment database follow-up outcomes.',
  DS0401:
    "Measures members whose first methadone dispensing (opitemrece plus drugitems name match) falls within 3 months of the clinic registration (denominator: MMT starts) and who collect methadone again 11 to 15 months later (numerator: retained at one year). The PDF counts voluntary-system outpatients started in the previous fiscal year quarters, requires no gap longer than 1 month and excludes arrest, death and transfer; the branch cannot verify the gap rule or those exclusions, so the owner must confirm the methadone item set, the MMT start anchor and accept the retention proxy or stage the programme outcomes.",
};
