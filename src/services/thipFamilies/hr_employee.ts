/**
 * THIP family batch `hr_employee`: employee health checks (HE0101 to HE0106)
 * and HR headcount, turnover, injury and training indicators (SH0101 to
 * SH0216, SH0301 to SH0307). One fact branch per code, UNION-ed into the
 * reporting-layer refresh like the other family batches.
 *
 * Read-only contract: aggregate only. The outer projection is exactly the
 * seven contract columns (the helpers render them) and carries no `hn`, `an`,
 * `vn`, `cid`, `emp_id`, names or birthdates; employee and patient keys are
 * only used inside the derived bases and correlated subqueries and are aliased
 * to `staff_key` there. No ICD literals appear (dotless or otherwise) and
 * every SQL division is written as `X divided by NULLIF(Y, 0)` with no other
 * slash character anywhere in the SQL.
 *
 * Base-grain evidence (HOSxP Structure workbook, verified column by column):
 *
 * - `emp_periodized` (emp) is hire-event grained (only employees with
 *   `emp_work_begindate` inside the parameter window), so headcount, turnover
 *   and event denominators cannot be aggregated over it. Every HOSxP branch of
 *   this batch therefore supplies its own derived base with the same
 *   `period_start` and `calendar_month` contract: one row per employee per
 *   active month (`GENERATE_SERIES` between `emp_work_begindate` and
 *   `emp_resign_enddate`, clamped to `:start_date`, `:end_date`), with
 *   correlated per-month subqueries for events. `branchFact` then buckets the
 *   rows with the shared cadence-aware helpers. All referenced columns were
 *   verified in the workbook: emp (emp_id, emp_cid, emp_sex_id,
 *   emp_position_main_id, emp_work_begindate, emp_resign_enddate),
 *   emp_position_main (emp_position_main_id, emp_position_main_name),
 *   emp_sex (emp_sex_id, emp_sex_name), emp_resign (emp_id, emp_resign_date,
 *   emp_resign_type_id), emp_resign_type (emp_resign_type_id,
 *   emp_resign_type_name), emp_work_sick (emp_id, emp_work_sick_type_id,
 *   emp_work_sick_sdatetime, emp_work_sick_countday), emp_work_sick_type
 *   (emp_work_sick_type_id, emp_work_sick_type_name), emp_work_schedule
 *   (emp_id, emp_work_schedule_workdate, emp_work_status_id), emp_work_status
 *   (emp_work_status_id, emp_work_status_name), patient (hn, cid), opdscreen
 *   (hn, vstdate, checkup, bmi, waist, smoking_type_id), ovst (vn, hn,
 *   vstdate), ovst_vaccine (vn, person_vaccine_id), person_vaccine
 *   (person_vaccine_id, vaccine_name).
 *
 * - HE0101 to HE0106 measure the employees' own screening visits in
 *   `opdscreen` and `ovst_vaccine`, reached through the `patient` row with the
 *   same citizen id (`emp.emp_cid = patient.cid`). That linkage is the closest
 *   HOSxP can get to an employee register; each entry documents the gap and
 *   the staging fallback into `reporting.thip_external_facts`.
 *
 * - SH0101 to SH0107 and SH0301 to SH0307 aggregate `emp_resign` (voluntary
 *   turnover), `emp_work_sick` (work-related injury and illness events and
 *   lost days) and `emp_work_schedule` (rostered shifts as work hours).
 *   Job-group split (physician and dentist, professional nurse, allied health,
 *   back office) is a documented keyword mapping over
 *   `emp_position_main.emp_position_main_name`.
 *
 * - SH0201 to SH0216 (employee satisfaction instrument and training-hour
 *   register) have no HOSxP source at all and are `branchExternal` over
 *   `reporting.thip_external_facts`; every entry states the exact staging rows
 *   the hospital must load.
 *
 * Approximations, staging requirements and the items the hospital owner must
 * confirm are recorded per code in `HR_EMPLOYEE_APPROXIMATIONS`.
 */

import { branchExternal, branchFact } from '@/services/thipFamilyBase';

/** The 34 assigned codes of this batch, in task order. */
const CODE_ORDER = [
  'HE0101', 'HE0102', 'HE0103', 'HE0104', 'HE0105', 'HE0106',
  'SH0101', 'SH0102', 'SH0103', 'SH0104', 'SH0105', 'SH0106', 'SH0107',
  'SH0201', 'SH0202', 'SH0203', 'SH0204', 'SH0205', 'SH0206', 'SH0207',
  'SH0208', 'SH0209', 'SH0210', 'SH0211', 'SH0212', 'SH0213', 'SH0214',
  'SH0215', 'SH0216', 'SH0301', 'SH0302', 'SH0303', 'SH0306', 'SH0307',
] as const;

/**
 * `branchExternal` renders the staging projection with bare column names; bind
 * them with the contract aliases so every branch carries `AS numerator`,
 * `AS denominator` and `AS value` like the helper-rendered fact branches.
 * Throws if `branchExternal` ever changes shape so the batch fails loudly
 * instead of silently losing the aliases.
 */
function externalBranch(code: string): string {
  const rendered = branchExternal(code);
  const stagingColumns = `        numerator,
        denominator,
        value`;
  const aliasedColumns = `        numerator AS numerator,
        denominator AS denominator,
        value AS value`;
  if (!rendered.includes(stagingColumns)) {
    throw new Error(
      `branchExternal shape changed: cannot bind staging column aliases for ${code}`,
    );
  }
  return rendered.replace(stagingColumns, aliasedColumns);
}

// ---------------------------------------------------------------------------
// Job-group predicates over emp_position_main.emp_position_main_name (all
// keyword mapping is documented and needs local confirmation; see the
// approximations entries of SH0104 to SH0107 and SH0302 to SH0307).
// ---------------------------------------------------------------------------

const POS = "COALESCE(pm.emp_position_main_name, '')";

const PHYSICIAN = `(${POS} ILIKE '%แพทย์%' AND ${POS} NOT ILIKE '%เทคนิคการแพทย์%' AND ${POS} NOT ILIKE '%ผู้ช่วยแพทย์%' AND ${POS} NOT ILIKE '%แพทย์แผน%')`;

const NURSE = `(${POS} ILIKE '%พยาบาลวิชาชีพ%' OR (${POS} ILIKE '%พยาบาล%' AND ${POS} NOT ILIKE '%ผู้ช่วย%' AND ${POS} NOT ILIKE '%พนักงาน%'))`;

const ALLIED_KEYWORDS = `${POS} ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%'])`;

const ALLIED_HEALTH = `((NOT ${PHYSICIAN}) AND (NOT ${NURSE}) AND (${ALLIED_KEYWORDS}))`;

const BACK_OFFICE = `((NOT ${PHYSICIAN}) AND (NOT ${NURSE}) AND (NOT (${ALLIED_KEYWORDS})))`;

const DIRECT_CONTACT = `(${PHYSICIAN} OR ${NURSE} OR ${ALLIED_HEALTH})`;

// ---------------------------------------------------------------------------
// emp_resign voluntary-resignation predicate (SH0101, SH0104 to SH0107).
// The printed definition counts the voluntary group only, excluding given-out,
// dismissed, discharged, retired, early-retired, deceased and transferred
// staff, so the predicate excludes those locally named resignation types.
// ---------------------------------------------------------------------------

const VOLUNTARY_RESIGN = `(rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))`;

// ---------------------------------------------------------------------------
// emp_work_sick_type classification (SH0102, SH0103, SH0301 to SH0307).
// ---------------------------------------------------------------------------

const INJURY_ILLNESS_EVENT = `(st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%' OR st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')`;

const INJURY_EVENT = `(st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')`;

const ILLNESS_EVENT = `(st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')`;

// ---------------------------------------------------------------------------
// Derived-base plumbing: one row per employee per active month, exposing the
// `period_start` and `calendar_month` contract plus per-month event columns.
// Inner subqueries are indented past the outer FROM marker so the outer
// projection stays machine-extractable.
// ---------------------------------------------------------------------------

/** Adds one computed column to the derived base select list. */
function column(expression: string, alias: string): string {
  return `,\n          (${expression}) AS ${alias}`;
}

/** Monthly screening predicate over the employee's own linked visits. */
function screeningExists(predicate: string): string {
  return `EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND ${predicate}
          )`;
}

/** Monthly influenza vaccination through the visit immunization register. */
const INFLUENZA_VACCINE_EXISTS = `EXISTS (
            SELECT 1
            FROM patient pp
            JOIN ovst vv ON vv.hn = pp.hn
            JOIN ovst_vaccine ovv ON ovv.vn = vv.vn
            JOIN person_vaccine pv ON pv.person_vaccine_id = ovv.person_vaccine_id
            WHERE pp.cid = e.emp_cid
              AND vv.vstdate >= months.work_month
              AND vv.vstdate < months.work_month + INTERVAL '1 month'
              AND (pv.vaccine_name ILIKE '%ไข้หวัดใหญ่%' OR pv.vaccine_name ILIKE '%influenza%')
          )`;

/** Monthly event count from the employee sick-leave registry. */
function workSickCountColumn(typePredicate: string, alias: string): string {
  return column(
    `SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND ${typePredicate}`,
    alias,
  );
}

/** Monthly lost workdays (sick-leave day count) from the same registry. */
function workSickDaysColumn(typePredicate: string, alias: string): string {
  return column(
    `SELECT COALESCE(SUM(es.emp_work_sick_countday), 0)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND ${typePredicate}`,
    alias,
  );
}

const VOLUNTARY_RESIGN_COUNT_COLUMN = column(
  `SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND ${VOLUNTARY_RESIGN}`,
  'voluntary_resign_cnt',
);

/** Monthly rostered shifts counted as eight-hour work shifts. */
const WORK_HOURS_COLUMN = column(
  `(SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8`,
  'work_hours',
);

/** First day of the fiscal year (October to September) of the row month. */
const FY_START = `CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END`;

const FY_END = `(${FY_START} + INTERVAL '1 year' - INTERVAL '1 day')`;

/** Last day of the reporting quarter of the row month (fiscal quarters are calendar quarters). */
const QUARTER_END = `(DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')`;

function activeAtColumn(boundaryExpression: string, alias: string): string {
  return column(
    `(e.emp_work_begindate IS NULL OR e.emp_work_begindate <= ${boundaryExpression}) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= ${boundaryExpression})`,
    alias,
  );
}

const ACTIVE_AT_FY_START_COLUMN = activeAtColumn(FY_START, 'active_at_fy_start');
const ACTIVE_AT_FY_END_COLUMN = activeAtColumn(FY_END, 'active_at_fy_end');
const ACTIVE_AT_PERIOD_END_COLUMN = activeAtColumn(QUARTER_END, 'active_at_period_end');

/** Derived employee-month base exposing `period_start`, `calendar_month`, `staff_key`. */
function empMonthSource(extraColumns: string, extraJoin = ''): string {
  const joinLines = extraJoin ? `\n        ${extraJoin}` : '';
  return `(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month${extraColumns}
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id${joinLines}
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr`;
}

// ---------------------------------------------------------------------------
// Aggregate expressions over the derived base (`hr`).
// ---------------------------------------------------------------------------

const ALL_STAFF = 'COUNT(DISTINCT hr.staff_key)';
const AVG_HEADCOUNT = `(${ALL_STAFF} FILTER (WHERE hr.active_at_fy_start) + ${ALL_STAFF} FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2, 0)`;
const QUARTER_END_HEADCOUNT = `${ALL_STAFF} FILTER (WHERE hr.active_at_period_end)`;

function ratioValue(numerator: string, denominator: string, multiplier: number): string {
  return `ROUND((${numerator}) * ${multiplier} / NULLIF(${denominator}, 0), 2)`;
}

// ---------------------------------------------------------------------------
// Branch assembly.
// ---------------------------------------------------------------------------

const MALE = `COALESCE(sx.emp_sex_name, '') ILIKE '%ชาย%'`;
const FEMALE = `COALESCE(sx.emp_sex_name, '') ILIKE '%หญิง%'`;
const EMP_SEX_JOIN = 'LEFT JOIN emp_sex sx ON sx.emp_sex_id = e.emp_sex_id';

function healthCheckBranch(
  code: string,
  numeratorExpression: string,
  denominatorExpression: string,
  sourceColumns: string,
  extraJoin = '',
): string {
  return branchFact(
    code,
    numeratorExpression,
    denominatorExpression,
    ratioValue(numeratorExpression, denominatorExpression, 100),
    'TRUE',
    { source: empMonthSource(sourceColumns, extraJoin) },
  );
}

function turnoverBranch(
  code: string,
  numeratorExpression: string,
  where: string,
  sourceColumns: string,
  denominatorExpression = QUARTER_END_HEADCOUNT,
  multiplier = 100,
): string {
  return branchFact(
    code,
    numeratorExpression,
    denominatorExpression,
    ratioValue(numeratorExpression, denominatorExpression, multiplier),
    where,
    { source: empMonthSource(sourceColumns) },
  );
}

const he0101Num = `${ALL_STAFF} FILTER (WHERE hr.had_checkup)`;
const he0102Num = `${ALL_STAFF} FILTER (WHERE hr.bmi_over)`;
const he0102Den = `${ALL_STAFF} FILTER (WHERE hr.bmi_measured)`;
const he0103Num = `${ALL_STAFF} FILTER (WHERE hr.smoker)`;
const he0104Num = `${ALL_STAFF} FILTER (WHERE hr.waist_over_male)`;
const he0104Den = `${ALL_STAFF} FILTER (WHERE hr.waist_measured_male)`;
const he0105Num = `${ALL_STAFF} FILTER (WHERE hr.waist_over_female)`;
const he0105Den = `${ALL_STAFF} FILTER (WHERE hr.waist_measured_female)`;
const he0106Num = `${ALL_STAFF} FILTER (WHERE hr.got_influenza_vaccine)`;

const workInjuryIllnessNum = `SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt)`;
const workInjuryDaysNum = 'SUM(hr.injury_lost_days)';
const workHoursDen = 'SUM(hr.work_hours)';

const BRANCHES: Record<string, string> = {
  // Employee annual health checks over the employees' own linked visits.
  HE0101: healthCheckBranch(
    'HE0101',
    he0101Num,
    ALL_STAFF,
    column(screeningExists(`scr.checkup = '1'`), 'had_checkup'),
  ),
  HE0102: healthCheckBranch(
    'HE0102',
    he0102Num,
    he0102Den,
    column(screeningExists('scr.bmi IS NOT NULL'), 'bmi_measured')
      + column(screeningExists('scr.bmi >= 23'), 'bmi_over'),
  ),
  HE0103: healthCheckBranch(
    'HE0103',
    he0103Num,
    ALL_STAFF,
    column(screeningExists('scr.smoking_type_id IN (2, 3)'), 'smoker'),
  ),
  HE0104: healthCheckBranch(
    'HE0104',
    he0104Num,
    he0104Den,
    column(`${MALE} AND ${screeningExists('scr.waist IS NOT NULL')}`, 'waist_measured_male')
      + column(`${MALE} AND ${screeningExists('scr.waist > 90')}`, 'waist_over_male'),
    EMP_SEX_JOIN,
  ),
  HE0105: healthCheckBranch(
    'HE0105',
    he0105Num,
    he0105Den,
    column(`${FEMALE} AND ${screeningExists('scr.waist IS NOT NULL')}`, 'waist_measured_female')
      + column(`${FEMALE} AND ${screeningExists('scr.waist > 80')}`, 'waist_over_female'),
    EMP_SEX_JOIN,
  ),
  HE0106: healthCheckBranch(
    'HE0106',
    he0106Num,
    ALL_STAFF,
    column(INFLUENZA_VACCINE_EXISTS, 'got_influenza_vaccine'),
  ),

  // Turnover and work-related injury and illness over the HR registries.
  SH0101: turnoverBranch(
    'SH0101',
    'SUM(hr.voluntary_resign_cnt) / NULLIF(12, 0)',
    'TRUE',
    VOLUNTARY_RESIGN_COUNT_COLUMN + ACTIVE_AT_FY_START_COLUMN + ACTIVE_AT_FY_END_COLUMN,
    AVG_HEADCOUNT,
  ),
  SH0102: turnoverBranch(
    'SH0102',
    'SUM(hr.work_injury_event_cnt)',
    'TRUE',
    workSickCountColumn(INJURY_EVENT, 'work_injury_event_cnt')
      + ACTIVE_AT_FY_START_COLUMN + ACTIVE_AT_FY_END_COLUMN,
    AVG_HEADCOUNT,
  ),
  SH0103: turnoverBranch(
    'SH0103',
    'SUM(hr.work_illness_event_cnt)',
    'TRUE',
    workSickCountColumn(ILLNESS_EVENT, 'work_illness_event_cnt')
      + ACTIVE_AT_FY_START_COLUMN + ACTIVE_AT_FY_END_COLUMN,
    AVG_HEADCOUNT,
  ),
  SH0104: turnoverBranch(
    'SH0104',
    'SUM(hr.voluntary_resign_cnt)',
    'hr.is_physician',
    VOLUNTARY_RESIGN_COUNT_COLUMN + ACTIVE_AT_PERIOD_END_COLUMN
      + column(PHYSICIAN, 'is_physician'),
  ),
  SH0105: turnoverBranch(
    'SH0105',
    'SUM(hr.voluntary_resign_cnt)',
    'hr.is_nurse',
    VOLUNTARY_RESIGN_COUNT_COLUMN + ACTIVE_AT_PERIOD_END_COLUMN
      + column(NURSE, 'is_nurse'),
  ),
  SH0106: turnoverBranch(
    'SH0106',
    'SUM(hr.voluntary_resign_cnt)',
    'hr.is_allied_health',
    VOLUNTARY_RESIGN_COUNT_COLUMN + ACTIVE_AT_PERIOD_END_COLUMN
      + column(ALLIED_HEALTH, 'is_allied_health'),
  ),
  SH0107: turnoverBranch(
    'SH0107',
    'SUM(hr.voluntary_resign_cnt)',
    'hr.is_back_office',
    VOLUNTARY_RESIGN_COUNT_COLUMN + ACTIVE_AT_PERIOD_END_COLUMN
      + column(BACK_OFFICE, 'is_back_office'),
  ),

  // Employee satisfaction instrument and training-hour register: outside HOSxP.
  SH0201: externalBranch('SH0201'),
  SH0202: externalBranch('SH0202'),
  SH0203: externalBranch('SH0203'),
  SH0204: externalBranch('SH0204'),
  SH0205: externalBranch('SH0205'),
  SH0206: externalBranch('SH0206'),
  SH0207: externalBranch('SH0207'),
  SH0208: externalBranch('SH0208'),
  SH0209: externalBranch('SH0209'),
  SH0210: externalBranch('SH0210'),
  SH0211: externalBranch('SH0211'),
  SH0212: externalBranch('SH0212'),
  SH0213: externalBranch('SH0213'),
  SH0214: externalBranch('SH0214'),
  SH0215: externalBranch('SH0215'),
  SH0216: externalBranch('SH0216'),

  // Injury and illness frequency and severity per one million work hours.
  SH0301: turnoverBranch(
    'SH0301',
    workInjuryIllnessNum,
    'TRUE',
    workSickCountColumn(INJURY_EVENT, 'work_injury_event_cnt')
      + workSickCountColumn(ILLNESS_EVENT, 'work_illness_event_cnt')
      + WORK_HOURS_COLUMN,
    workHoursDen,
    1000000,
  ),
  SH0302: turnoverBranch(
    'SH0302',
    workInjuryDaysNum,
    'hr.is_direct_contact',
    workSickDaysColumn(INJURY_EVENT, 'injury_lost_days')
      + WORK_HOURS_COLUMN + column(DIRECT_CONTACT, 'is_direct_contact'),
    workHoursDen,
    1000000,
  ),
  SH0303: turnoverBranch(
    'SH0303',
    workInjuryDaysNum,
    'hr.is_back_office',
    workSickDaysColumn(INJURY_EVENT, 'injury_lost_days')
      + WORK_HOURS_COLUMN + column(BACK_OFFICE, 'is_back_office'),
    workHoursDen,
    1000000,
  ),
  SH0306: turnoverBranch(
    'SH0306',
    workInjuryIllnessNum,
    'hr.is_direct_contact',
    workSickCountColumn(INJURY_EVENT, 'work_injury_event_cnt')
      + workSickCountColumn(ILLNESS_EVENT, 'work_illness_event_cnt')
      + WORK_HOURS_COLUMN + column(DIRECT_CONTACT, 'is_direct_contact'),
    workHoursDen,
    1000000,
  ),
  SH0307: turnoverBranch(
    'SH0307',
    workInjuryIllnessNum,
    'hr.is_back_office',
    workSickCountColumn(INJURY_EVENT, 'work_injury_event_cnt')
      + workSickCountColumn(ILLNESS_EVENT, 'work_illness_event_cnt')
      + WORK_HOURS_COLUMN + column(BACK_OFFICE, 'is_back_office'),
    workHoursDen,
    1000000,
  ),
};

export const HR_EMPLOYEE_BRANCHES: readonly string[] = CODE_ORDER.map((code) => {
  const branch = BRANCHES[code];
  if (!branch) throw new Error(`hr_employee batch is missing branch ${code}`);
  return branch;
});

// ---------------------------------------------------------------------------
// Approximations and staging documentation (every code needs an entry).
// ---------------------------------------------------------------------------

const EMPLOYEE_VISIT_LINK =
  'Confirm with the hospital owner: the employee to visit linkage runs emp.emp_cid = patient.cid and then patient.hn to the clinical rows; employees whose citizen id is missing or differs from their patient record are invisible to the numerator (they still count in b), and screening recorded outside the HOSxP visit flow is missed. If the linkage is not reliable in local data, stage the indicator from the employee health-check register into reporting.thip_external_facts instead (one row per annual reporting anchor with period_start, numerator, denominator, value, source_system).';

function healthEntry(input: {
  measures: string;
  pdfBeyond: string;
  confirm: string;
}): string {
  return [
    `Measures: ${input.measures}`,
    `PDF beyond the branch: ${input.pdfBeyond}`,
    input.confirm,
    EMPLOYEE_VISIT_LINK,
  ].join(' ');
}

const JOB_GROUP_MAPPING =
  'The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups.';

const PER_MILLION_SCALE =
  'ROUND(a times 1000000 divided by NULLIF(b, 0), 2) per formulaScale a over b times 1000000';

const RESIGN_TYPE_MAPPING =
  'Voluntary resignation is emp_resign rows whose emp_resign_type_name does not mark given-out, dismissed, discharged, retired, early-retired, deceased or transferred staff (name keywords). Confirm the installed emp_resign_type dictionary so only the voluntary group is counted.';

function turnoverEntry(input: {
  measures: string;
  numerator: string;
  denominator: string;
  extra: string;
  confirm: string;
  scale?: string;
}): string {
  return [
    `Measures: ${input.measures} numerator (a) = ${input.numerator} denominator (b) = ${input.denominator} value = ${input.scale ?? 'ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100'}.`,
    input.extra,
    `PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period.`,
    `Confirm with the hospital owner: ${input.confirm}`,
  ].join(' ');
}

const INJURY_ILLNESS_MAPPING =
  'Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined.';

const WORK_HOURS_MAPPING =
  'Work hours are the rostered shifts of emp_work_schedule per employee-month (rows whose emp_work_status_name marks leave or holiday are dropped) multiplied by eight hours per shift; the printed definition allows other shift lengths (eight or ten hours) and wants the real hours of each shift. If true shift lengths or clocked hours are maintained, stage the monthly work-hour totals instead.';

const INFLUENZA_NOTE =
  'The printed denominator covers the vaccination campaign from 1 June to 30 September; the branch buckets to the annual anchor, so a fiscal-year run reports the whole-year staff count against vaccinations given in the campaign window recorded inside the reporting window. Doses recorded only in the MoPH immunization registry or given outside the hospital are missed; confirm the person_vaccine catalog names for influenza (vaccine_name tokens) and stage the campaign result if doses are recorded elsewhere.';

const SURVEY_ANCHOR_NOTE =
  'Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system.';

const SURVEY_INSTRUMENT_NOTE =
  'No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.';

const TRAINING_ANCHOR_NOTE =
  'Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a (training hours), denominator = b (staff count of the group), value = ROUND(a times 1 divided by NULLIF(b, 0), 2) per formulaScale a over b, source_system = the human resources training register.';

const TRAINING_REGISTER_NOTE =
  'No HOSxP table holds the staff training-hour register (the emp_work_study and emp_education tables hold leave-for-study records and education-level lookups, and emp_educate_child and emp_wf_edu_regis cover children and welfare education, not staff training events with hours). Training hours must be aggregated by the human resources office and loaded into reporting.thip_external_facts.';

function surveyEntry(input: { group: string; level: string }): string {
  return [
    `Measures: ${input.level} of overall organizational satisfaction among ${input.group}, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts.`,
    `PDF beyond the branch: the ${input.level} response counts of ${input.group} from the employee satisfaction survey of the fiscal year.`,
    `Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group.`,
    SURVEY_ANCHOR_NOTE,
    SURVEY_INSTRUMENT_NOTE,
  ].join(' ');
}

function trainingEntry(input: { group: string }): string {
  return [
    `Measures: training hours per person per year of ${input.group} (counted events: study, training, short research, observation visits, academic services, meetings, seminars with explicit schedules; one training day is six hours). The branch is branchExternal over reporting.thip_external_facts.`,
    `PDF beyond the branch: total counted training hours and the staff count of ${input.group} for the fiscal year.`,
    `Confirm with the hospital owner: the counted-hour rules and the job-group roster used for the denominator.`,
    TRAINING_ANCHOR_NOTE,
    TRAINING_REGISTER_NOTE,
  ].join(' ');
}

export const HR_EMPLOYEE_APPROXIMATIONS: Readonly<Record<string, string>> = {
  HE0101: healthEntry({
    measures:
      'Employees active in the fiscal year with at least one linked screening visit flagged as a health check (opdscreen.checkup) in that month, over all employees active in the fiscal year (one row per employee per active month, COUNT(DISTINCT staff_key)).',
    pdfBeyond:
      'the printed entitlement split (civil servants and permanent staff under the Ministry of Finance entitlement, temporary staff under the organization policy) and the exact annual check-up items.',
    confirm:
      'that opdscreen.checkup = 1 marks the annual health check-up (otherwise point the numerator at the health-check clinic or visit type) and whether checks done under the Ministry of Finance entitlement are captured in HOSxP at all.',
  }),
  HE0102: healthEntry({
    measures:
      'Employees with at least one linked screening visit carrying opdscreen.bmi at or above 23.0, over employees with at least one linked BMI measurement, in the fiscal year.',
    pdfBeyond:
      'BMI measured together with the annual health check-up from weight and height, per the printed assessment protocol.',
    confirm:
      'that opdscreen.bmi is maintained for employee check-ups (or that height and weight are, so the ratio can be derived) and that the check-up window matches the annual campaign.',
  }),
  HE0103: healthEntry({
    measures:
      'Employees with at least one linked screening visit whose opdscreen.smoking_type_id marks a current smoker (the same smoking predicate as the registered query library), over all employees active in the fiscal year.',
    pdfBeyond:
      'smoking behavior as assessed in the annual health check-up questionnaire.',
    confirm:
      'the installed smoking_type_id dictionary (the branch assumes 2 and 3 are current-smoker values) and that the annual check-up records it.',
  }),
  HE0104: healthEntry({
    measures:
      'Male employees (emp_sex_name male token) with at least one linked screening visit carrying opdscreen.waist above 90 centimeters, over male employees with at least one linked waist measurement, in the fiscal year.',
    pdfBeyond:
      'waist measured at the navel at end-expiration with the printed technique, over male staff measured during the annual check-up.',
    confirm:
      'the emp_sex dictionary, that opdscreen.waist is centimeters measured at the navel, and that male staff waist is captured for the check-up cohort.',
  }),
  HE0105: healthEntry({
    measures:
      'Female employees (emp_sex_name female token) with at least one linked screening visit carrying opdscreen.waist above 80 centimeters, over female employees with at least one linked waist measurement, in the fiscal year.',
    pdfBeyond:
      'waist measured at the navel at end-expiration with the printed technique, over female staff measured during the annual check-up.',
    confirm:
      'the emp_sex dictionary, that opdscreen.waist is centimeters measured at the navel, and that female staff waist is captured for the check-up cohort.',
  }),
  HE0106: healthEntry({
    measures:
      'Employees with at least one linked visit carrying a seasonal influenza vaccination in the visit immunization register (ovst_vaccine joined to person_vaccine.vaccine_name), over all employees active in the fiscal year.',
    pdfBeyond:
      'seasonal influenza vaccination of employees during the printed campaign period, per the organization policy.',
    confirm: INFLUENZA_NOTE,
  }),
  SH0101: turnoverEntry({
    measures:
      'Voluntary turnover rate of all personnel over the fiscal year (annual anchor).',
    numerator:
      'voluntary resignation events of the fiscal year (emp_resign, monthly counts summed) divided by 12 per the printed average definition (written as SUM over NULLIF(12, 0))',
    denominator:
      'the average of the staff employed on the first and on the last day of the fiscal year (active_at_fy_start and active_at_fy_end from emp_work_begindate and emp_resign_enddate against the fiscal-year boundaries of the row month) divided by 2 (written as the sum over NULLIF(2, 0))',
    extra: RESIGN_TYPE_MAPPING,
    confirm:
      'the resignation-type dictionary, and that emp_work_begindate and emp_resign_enddate are complete for active and resigned staff so the boundary headcounts are exact.',
  }),
  SH0102: turnoverEntry({
    measures:
      'Work-related injury events per average fiscal-year headcount (annual anchor).',
    numerator:
      'emp_work_sick events whose type marks an accident, injury or danger event, summed over the fiscal year',
    denominator:
      'the average of the staff employed on the first and on the last day of the fiscal year, divided by 2 (sum over NULLIF(2, 0))',
    extra: INJURY_ILLNESS_MAPPING,
    confirm:
      'the emp_work_sick_type dictionary and how work-relatedness (a clear accident mechanism) is flagged locally; stage from the occupational health registry if injuries are recorded outside emp_work_sick.',
  }),
  SH0103: turnoverEntry({
    measures:
      'Work-related illness events per average fiscal-year headcount (annual anchor).',
    numerator:
      'emp_work_sick events whose type marks illness, back pain, work stress or occupational disease, summed over the fiscal year',
    denominator:
      'the average of the staff employed on the first and on the last day of the fiscal year, divided by 2 (sum over NULLIF(2, 0))',
    extra: INJURY_ILLNESS_MAPPING,
    confirm:
      'the emp_work_sick_type dictionary and how work-aggravated illness (back pain, work stress) is flagged locally; stage from the occupational health registry if such cases are recorded outside emp_work_sick.',
  }),
  SH0104: turnoverEntry({
    measures:
      'Quarterly voluntary turnover rate of physicians and dentists (quarterly anchor).',
    numerator: 'voluntary resignation events of physicians and dentists during the quarter',
    denominator: 'physicians and dentists employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month; fiscal quarters coincide with calendar quarters)',
    extra: RESIGN_TYPE_MAPPING + ' ' + JOB_GROUP_MAPPING,
    confirm: 'the resignation-type and position-name mapping for the physician and dentist group.',
  }),
  SH0105: turnoverEntry({
    measures:
      'Quarterly voluntary turnover rate of professional nurses (quarterly anchor).',
    numerator: 'voluntary resignation events of professional nurses during the quarter',
    denominator: 'professional nurses employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month)',
    extra: RESIGN_TYPE_MAPPING + ' ' + JOB_GROUP_MAPPING,
    confirm: 'the resignation-type and position-name mapping for the professional nurse group.',
  }),
  SH0106: turnoverEntry({
    measures:
      'Quarterly voluntary turnover rate of allied health personnel (quarterly anchor).',
    numerator: 'voluntary resignation events of allied health personnel during the quarter',
    denominator: 'allied health personnel employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month)',
    extra: RESIGN_TYPE_MAPPING + ' ' + JOB_GROUP_MAPPING,
    confirm: 'the resignation-type and position-name mapping for the allied health group.',
  }),
  SH0107: turnoverEntry({
    measures:
      'Quarterly voluntary turnover rate of back office personnel (quarterly anchor).',
    numerator: 'voluntary resignation events of back office personnel during the quarter',
    denominator: 'back office personnel employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month)',
    extra: RESIGN_TYPE_MAPPING + ' ' + JOB_GROUP_MAPPING,
    confirm: 'the resignation-type and position-name mapping for the back office group.',
  }),
  SH0201: surveyEntry({ group: 'physicians and dentists', level: 'the level 4 to 5 share' }),
  SH0202: surveyEntry({ group: 'professional nurses', level: 'the level 4 to 5 share' }),
  SH0203: surveyEntry({ group: 'allied health personnel', level: 'the level 4 to 5 share' }),
  SH0206: surveyEntry({ group: 'physicians and dentists', level: 'the average satisfaction share' }),
  SH0207: surveyEntry({ group: 'physicians and dentists', level: 'the level 1 to 2 share' }),
  SH0208: surveyEntry({ group: 'professional nurses', level: 'the average satisfaction share' }),
  SH0209: surveyEntry({ group: 'professional nurses', level: 'the level 1 to 2 share' }),
  SH0210: surveyEntry({ group: 'allied health personnel', level: 'the average satisfaction share' }),
  SH0211: surveyEntry({ group: 'allied health personnel', level: 'the level 1 to 2 share' }),
  SH0212: surveyEntry({ group: 'back office personnel', level: 'the average satisfaction share' }),
  SH0213: surveyEntry({ group: 'back office personnel', level: 'the level 4 to 5 share' }),
  SH0214: surveyEntry({ group: 'back office personnel', level: 'the level 1 to 2 share' }),
  SH0204: trainingEntry({ group: 'physicians and dentists' }),
  SH0205: trainingEntry({ group: 'professional nurses' }),
  SH0215: trainingEntry({ group: 'allied health personnel' }),
  SH0216: trainingEntry({ group: 'back office personnel' }),
  SH0301: turnoverEntry({
    measures:
      'Injury and illness frequency rate per one million work hours of all personnel (monthly anchor).',
    scale: PER_MILLION_SCALE,
    numerator: 'emp_work_sick injury and illness events of the month',
    denominator: 'work hours of the month (rostered shifts times 8 hours) of all personnel',
    extra: INJURY_ILLNESS_MAPPING + ' ' + WORK_HOURS_MAPPING,
    confirm: 'the emp_work_sick_type dictionary, the shift rostering convention and the hours per shift.',
  }),
  SH0302: turnoverEntry({
    measures:
      'Injury severity rate (lost workdays per one million work hours) of direct-contact personnel (monthly anchor).',
    scale: PER_MILLION_SCALE,
    numerator: 'lost workdays (emp_work_sick_countday) of injury events of direct-contact personnel in the month',
    denominator: 'work hours of the month of direct-contact personnel (rostered shifts times 8 hours)',
    extra:
      INJURY_ILLNESS_MAPPING + ' ' + WORK_HOURS_MAPPING + ' ' + JOB_GROUP_MAPPING + ' The printed 8000-lost-hours rule for work-related death cannot be implemented (no work-death registry exists in HOSxP); such cases must be corrected in the staged hours.',
    confirm: 'the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.',
  }),
  SH0303: turnoverEntry({
    measures:
      'Injury severity rate (lost workdays per one million work hours) of non-direct-contact personnel (monthly anchor).',
    scale: PER_MILLION_SCALE,
    numerator: 'lost workdays (emp_work_sick_countday) of injury events of back office personnel in the month',
    denominator: 'work hours of the month of back office personnel (rostered shifts times 8 hours)',
    extra:
      INJURY_ILLNESS_MAPPING + ' ' + WORK_HOURS_MAPPING + ' ' + JOB_GROUP_MAPPING + ' The printed 8000-lost-hours rule for work-related death cannot be implemented (no work-death registry exists in HOSxP); such cases must be corrected in the staged hours.',
    confirm: 'the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.',
  }),
  SH0306: turnoverEntry({
    measures:
      'Injury and illness frequency rate per one million work hours of direct-contact personnel (monthly anchor).',
    scale: PER_MILLION_SCALE,
    numerator: 'emp_work_sick injury and illness events of direct-contact personnel in the month',
    denominator: 'work hours of the month of direct-contact personnel (rostered shifts times 8 hours)',
    extra: INJURY_ILLNESS_MAPPING + ' ' + WORK_HOURS_MAPPING + ' ' + JOB_GROUP_MAPPING,
    confirm: 'the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.',
  }),
  SH0307: turnoverEntry({
    measures:
      'Injury and illness frequency rate per one million work hours of non-direct-contact personnel (monthly anchor).',
    scale: PER_MILLION_SCALE,
    numerator: 'emp_work_sick injury and illness events of back office personnel in the month',
    denominator: 'work hours of the month of back office personnel (rostered shifts times 8 hours)',
    extra: INJURY_ILLNESS_MAPPING + ' ' + WORK_HOURS_MAPPING + ' ' + JOB_GROUP_MAPPING,
    confirm: 'the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.',
  }),
};
