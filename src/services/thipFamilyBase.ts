/**
 * Shared family-query plumbing for the THIP registered queries.
 *
 * Every fact branch returns exactly one row per indicator code x reporting
 * period anchor with the columns
 * `(indicator_code, period_start, fiscal_month, fiscal_year, numerator,
 * denominator, value)` and is UNION-ed into the `fact_events`/`facts` CTE of a
 * foundation query or the reporting-layer refresh.
 *
 * Cadence-aware periodization: the reporting anchor of a code comes from
 * `thipReporting` (monthly / quarterly / semiannual / annual). Rows are bucketed
 * to the cadence anchor (`fiscal_month` 1..12; quarterly anchors 1/4/7/10,
 * semiannual 1/7, annual 1) and `period_start` is the first month of the
 * bucket, so a quarterly fact covers its whole quarter and an annual fact
 * covers the whole fiscal year (Oct-Sep).
 *
 * Read-only contract for every branch:
 * - aggregate only; never project `hn`, `an`, `vn`, `cid`, names or any raw
 *   patient attribute in the outer SELECT,
 * - dotless ICD-10/ICD-9 comparison via
 *   `REPLACE(UPPER(TRIM(col)), '.', '')` against dotless literals,
 * - divisions guarded with `NULLIF(denominator, 0)`,
 * - event semantics that need local confirmation must be documented in the
 *   batch module's `approximations` export.
 */

import { getReportingCadence, type ThipReportingCadence } from '@/data/thipReporting';

const FM_EXPR = 'CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END';
const FY_EXPR = 'CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END';

function anchorExpr(cadence: ThipReportingCadence): string {
  const fm = `(${FM_EXPR})`;
  if (cadence === 'annual') return '1';
  if (cadence === 'semiannual') return `CASE WHEN ${fm} <= 6 THEN 1 ELSE 7 END`;
  if (cadence === 'quarterly') return `CASE WHEN ${fm} <= 3 THEN 1 WHEN ${fm} <= 6 THEN 4 WHEN ${fm} <= 9 THEN 7 ELSE 10 END`;
  return FM_EXPR;
}

function bucketPeriodStartExpr(cadence: ThipReportingCadence): string {
  const anchor = anchorExpr(cadence);
  return `DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (${FM_EXPR}) - (${anchor}))`;
}

export type FactBranchOptions = {
  /** Base CTE exposing (period_start, calendar_month). Default: `periodized`. */
  source?: string;
  /** Extra FROM/JOIN lines appended after the source, e.g. `JOIN x ON x.an = periodized.an`. */
  join?: string;
  /** Rare grouping override; positional GROUP BY is used by default. */
  groupBy?: string;
};

/**
 * Builds one cadence-aware aggregate fact branch over a base CTE. `where`
 * filters the source rows; `numerator`/`denominator`/`value` are aggregate
 * expressions evaluated over the filtered bucket rows.
 */
export function branchFact(
  code: string,
  numerator: string,
  denominator: string,
  value: string,
  where: string,
  options: FactBranchOptions = {},
): string {
  const cadence = getReportingCadence(code);
  const source = options.source ?? 'periodized';
  const join = options.join ? `\n      ${options.join}` : '';
  const periodStartExpr = bucketPeriodStartExpr(cadence);
  const anchor = anchorExpr(cadence);
  const groupBy = options.groupBy ?? '2, 3, 4';
  return `
      SELECT
        '${code}' AS indicator_code,
        ${periodStartExpr} AS period_start,
        ${anchor} AS fiscal_month,
        ${FY_EXPR} AS fiscal_year,
        ${numerator} AS numerator,
        ${denominator} AS denominator,
        ${value} AS value
      FROM ${source}${join}
      WHERE ${where}
      GROUP BY ${groupBy}`;
}

/** Fact branch over the shared IPD episode base (`periodized`). */
export function branchIpd(
  code: string,
  numerator: string,
  denominator: string,
  value: string,
  where: string,
  options: Omit<FactBranchOptions, 'source'> = {},
): string {
  return branchFact(code, numerator, denominator, value, where, { ...options, source: 'periodized' });
}

/**
 * Fact branch for codes whose aggregate is loaded by the hospital into the
 * `reporting.thip_external_facts` staging table (population denominators,
 * finance, survey, custom registries). The row already carries its reporting
 * period anchor, so no bucketing is applied. These branches are only valid in
 * the reporting-layer refresh and the `thipExternalFoundation` query; they are
 * excluded from the HOSxP-only foundation queries.
 */
export function branchExternal(code: string): string {
  return `
      SELECT
        '${code}' AS indicator_code,
        period_start,
        ${FM_EXPR} AS fiscal_month,
        ${FY_EXPR} AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = '${code}'`;
}

export function isExternalBranch(sql: string): boolean {
  return /\bFROM\s+external_facts\b/i.test(sql);
}

/**
 * Extended base CTEs shared by the non-IPD family branches. Each CTE exposes
 * `period_start` (first day of the anchor month) and `calendar_month` so the
 * cadence-aware `branchFact` bucketing works uniformly. Columns were taken
 * from the HOSxP Structure workbook; branches must reach any other column
 * through inline subqueries instead of editing this base.
 *
 * - `opd_periodized`    : one row per OPD/ER visit (`ovst` + Pdx + ER clocks)
 * - `chronic_periodized`: one row per chronic-clinic registration (`clinicmember`)
 * - `delivery_periodized`: one row per delivery record (`labor`)
 * - `newborn_periodized`: one row per newborn (`ipt_newborn`)
 * - `emp_periodized`    : one row per employee (`emp`)
 * - `external_facts`    : hospital-loaded aggregate staging (optional)
 */
export const EXTENDED_BASE_CTE = `
  opd_periodized AS (
    SELECT
      v.vn,
      v.hn,
      v.an,
      EXTRACT(YEAR FROM AGE(v.vstdate, pd.birthday))::integer AS age_y,
      pd.sex,
      (SELECT REPLACE(UPPER(TRIM(sd.icd10)), '.', '')
         FROM ovstdiag sd
        WHERE sd.vn = v.vn AND sd.diagtype = '1'
        ORDER BY sd.ovst_diag_id
        LIMIT 1) AS pdx,
      v.vstdate AS event_date,
      er.enter_er_time,
      er.triage_datetime,
      er.doctor_tx_time,
      er.finish_time,
      er.antibiotics_datetime,
      er.stroke_needle_datetime,
      er.stemi_balloon_datetime,
      er.er_emergency_level_id,
      er.unplanned_return,
      er.news2_score,
      DATE_TRUNC('month', v.vstdate)::date AS period_start,
      EXTRACT(MONTH FROM v.vstdate)::integer AS calendar_month
    FROM ovst v
    LEFT JOIN patient pd ON pd.hn = v.hn
    LEFT JOIN er_regist er ON er.vn = v.vn
    WHERE v.vstdate >= :start_date
      AND v.vstdate < :end_date
  ),
  chronic_periodized AS (
    SELECT
      cm.clinicmember_id,
      cm.clinic,
      cm.hn,
      cm.regdate,
      cm.lastvisit,
      cm.dchdate,
      cm.current_status,
      cm.clinic_member_status_id,
      cm.age_y,
      cm.sex,
      cm.chronic_type,
      cm.begin_year,
      cm.last_hba1c_value,
      cm.last_hba1c_date,
      cm.last_bp_bps_value,
      cm.last_bp_bpd_value,
      cm.last_bp_date,
      DATE_TRUNC('month', cm.regdate)::date AS period_start,
      EXTRACT(MONTH FROM cm.regdate)::integer AS calendar_month
    FROM clinicmember cm
    WHERE cm.regdate >= :start_date
      AND cm.regdate < :end_date
  ),
  delivery_periodized AS (
    SELECT
      l.laborid,
      l.an,
      l.hage AS mother_age_y,
      l.labor_type,
      l.mother_method,
      l.infant_sex,
      l.infant_weight,
      l.infant_apgarscore1,
      l.infant_apgarscore5,
      l.infant_apgarscore10,
      l.placenta_bloodloss,
      l.labour_startdate,
      l.labour_finishdate,
      DATE_TRUNC('month', COALESCE(l.labour_startdate, i.regdate))::date AS period_start,
      EXTRACT(MONTH FROM COALESCE(l.labour_startdate, i.regdate))::integer AS calendar_month
    FROM labor l
    LEFT JOIN ipt i ON i.an = l.an
    WHERE COALESCE(l.labour_startdate, i.regdate) >= :start_date
      AND COALESCE(l.labour_startdate, i.regdate) < :end_date
  ),
  newborn_periodized AS (
    SELECT
      nb.an,
      nb.mother_an,
      nb.born_date,
      nb.birth_weight,
      nb.apgar1,
      nb.apgar2,
      nb.dead,
      nb.has_asphyxia,
      nb.birthcondition1,
      nb.birthcondition2,
      nb.anc_complete,
      DATE_TRUNC('month', nb.born_date)::date AS period_start,
      EXTRACT(MONTH FROM nb.born_date)::integer AS calendar_month
    FROM ipt_newborn nb
    WHERE nb.born_date >= :start_date
      AND nb.born_date < :end_date
  ),
  emp_periodized AS (
    SELECT
      e.emp_id,
      e.emp_sex_id,
      e.emp_birthdate,
      e.emp_status_id,
      e.emp_type_id,
      e.emp_dep_id,
      e.emp_position_main_id,
      e.emp_work_begindate,
      e.emp_resign_enddate,
      e.emp_resign_type_id,
      DATE_TRUNC('month', e.emp_work_begindate)::date AS period_start,
      EXTRACT(MONTH FROM e.emp_work_begindate)::integer AS calendar_month
    FROM emp e
    WHERE e.emp_work_begindate >= :start_date
      AND e.emp_work_begindate < :end_date
  )`.trim();

export const EXTERNAL_FACTS_CTE = `
  external_facts AS (
    SELECT
      x.indicator_code,
      x.period_start,
      x.numerator,
      x.denominator,
      x.value,
      x.source_system,
      EXTRACT(MONTH FROM x.period_start)::integer AS calendar_month
    FROM reporting.thip_external_facts x
    WHERE x.period_start >= :start_date
      AND x.period_start < :end_date
  )`.trim();

/**
 * Extended base chain (no leading `WITH`, no trailing comma). Callers append
 * `,\n<more CTEs>` after `ipdBaseCte(...)`. External facts are only included
 * for reporting-layer execution where `reporting.thip_external_facts` exists.
 */
export function extendedBaseCte(includeExternal: boolean): string {
  return includeExternal
    ? `${EXTENDED_BASE_CTE},\n  ${EXTERNAL_FACTS_CTE}`
    : EXTENDED_BASE_CTE;
}
