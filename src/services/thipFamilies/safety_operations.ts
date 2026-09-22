/**
 * Safety & operations family batch: 25 THIP KPI fact branches covering
 * anesthesia (CA*), pressure ulcer (CG*), surgical safety and peri-operative
 * outcomes (CO*), infection / device-associated surveillance (SI*), blood use
 * (SL0101) and CSSD (SS*).
 *
 * Every HOSxP table.column referenced here was verified against the
 * `HOSxP Structure` sheet of `HOSxP Structure.xlsx`. The branches follow the
 * read-only contract of `thipFamilyBase`: aggregate-only outer projection,
 * dotless ICD literals compared via REPLACE(UPPER(TRIM(col)), '.', ''),
 * `X / NULLIF(Y, 0)` divisions only, one row per reporting period anchor, and
 * episode grain kept with COUNT(DISTINCT key) / EXISTS subqueries instead of
 * one-to-many joins with COUNT(*).
 *
 * Event semantics that HOSxP cannot express exactly (NHSN device-day
 * surveillance, UHNDC point-prevalence surveys, CSSD biological indicator
 * tests, true transfused units) are either approximated from the closest
 * verified column or delegated to `branchExternal`; every gap is recorded in
 * SAFETY_OPERATIONS_APPROXIMATIONS with the staging rows the hospital owner
 * must load into `reporting.thip_external_facts`.
 */

import { branchExternal, branchFact, branchIpd } from '@/services/thipFamilyBase';

/** ROUND(<num> * <multiplier> / NULLIF(<den>, 0), 2) per the formulaScale contract. */
function ratioValue(numerator: string, denominator: string, multiplier: number): string {
  return `ROUND(${numerator} * ${multiplier} / NULLIF(${denominator}, 0), 2)`;
}

/**
 * `branchExternal` projection with explicit `AS` column aliases so every batch
 * branch satisfies the per-code `AS numerator, AS denominator, AS value` test
 * contract. Branch shape, bucketing behavior and `isExternalBranch` detection
 * are exactly what `branchExternal` produces.
 */
function externalFactBranch(code: string): string {
  return branchExternal(code).replace(
    /\bnumerator,(\s+)denominator,(\s+)value\b/,
    'numerator AS numerator,$1denominator AS denominator,$2value AS value',
  );
}

// ---------------------------------------------------------------------------
// Shared predicates. `ol` is an `operation_list` row in scope (joined or inside
// an EXISTS subquery correlated on `ol.an = periodized.an`).
// ---------------------------------------------------------------------------

/** An anesthetized operating-room case (anesthesia type / completion recorded). */
const anesCaseOl = `(
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )`;

/** Elective (non-emergency) case per the operation_emergency lookup names. */
const notEmergencyOl = `NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )`;

/** Pre-anesthetic visit documented (visit record or pre-anesthetic note). */
const preAnesVisitOl = `(
          ol.pre_anes_operation_note IS NOT NULL
          OR EXISTS (
            SELECT 1
            FROM operation_visit_list ov
            WHERE ov.operation_id = ol.operation_id
              AND (
                ov.pre_anes_note IS NOT NULL
                OR ov.operation_visit_anes_type_id IS NOT NULL
              )
          )
        )`;

/** Post-anesthesia recovery-room care documented. */
const recoveryRoomOl = `EXISTS (
            SELECT 1
            FROM operation_recovery_room rr
            WHERE rr.operation_id = ol.operation_id
          )`;

/** General anesthesia with intubation (tube type or intubation time recorded). */
const gaIntubatedOl = `EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )`;

/** Airway (re-)intubation event within 2 hours after the recorded extubation. */
const reIntubationOl = `EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
              AND EXISTS (
                SELECT 1
                FROM operation_anes_problem ap
                WHERE ap.operation_id = ol.operation_id
                  AND (
                    ap.comment ILIKE '%ใส่ท่อ%'
                    OR LOWER(ap.comment) LIKE '%intubat%'
                    OR ap.airway_solution_id IN (
                      SELECT asl.airway_solution_id
                      FROM operation_airway_solution asl
                      WHERE asl.airway_solution_name ILIKE '%ใส่ท่อ%'
                         OR LOWER(asl.airway_solution_name) LIKE '%intubat%'
                    )
                  )
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) >=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59')))
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) <=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59'))) + INTERVAL '2 hours'
              )
          )`;

/** Capnometry (exhaled CO2) monitoring documented during anesthesia. */
const capnometryOl = `(
            EXISTS (
              SELECT 1
              FROM operation_anes_detail ad
              WHERE ad.operation_id = ol.operation_id
                AND (
                  LOWER(ad.monitor) LIKE '%capno%'
                  OR LOWER(ad.monitor) LIKE '%etco%'
                  OR ad.monitor ILIKE '%คาพโน%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.etco2 IS NOT NULL
            )
          )`;

/** Surgical safety checklist documented in all three parts (sign in, time out, sign out). */
const checklistCompleteOl = `(
          ol.operation_check_date IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM operation_detail od
            WHERE od.operation_id = ol.operation_id
              AND od.time_out_datetime IS NOT NULL
          )
          AND EXISTS (
            SELECT 1
            FROM operation_screen_in osi
            WHERE osi.operation_id = ol.operation_id
              AND osi.preoperative_nursing_record IS NOT NULL
              AND osi.perioperative_record IS NOT NULL
              AND osi.postoperative_record IS NOT NULL
          )
        )`;

// ---------------------------------------------------------------------------
// Pressure ulcer (CG*) episode predicates over `periodized`.
// ---------------------------------------------------------------------------

/** Pressure-ulcer evidence first documented after the admission day (stage >= 1 proxy). */
const hapiEvidence = `(
          LEFT(periodized.pdx, 3) <> 'L89'
          AND (
            EXISTS (
              SELECT 1
              FROM iptdiag sd
              WHERE sd.an = periodized.an
                AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'L89'
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.note_date > periodized.regdate
                AND (
                  nn.note ILIKE '%แผลกดทับ%'
                  OR LOWER(nn.note) LIKE '%pressure ulcer%'
                )
            )
          )
        )`;

/** Pressure-ulcer risk assessment documented in the nursing notes (Braden proxy). */
const riskAssessed = `EXISTS (
            SELECT 1
            FROM ipd_nurse_note rn
            WHERE rn.an = periodized.an
              AND (
                LOWER(rn.note) LIKE '%braden%'
                OR rn.note ILIKE '%เสี่ยงต่อการเกิดแผลกดทับ%'
                OR (rn.note ILIKE '%เสี่ยง%' AND rn.note ILIKE '%กดทับ%')
              )
          )`;

// ---------------------------------------------------------------------------
// Blood (SL0101) and CSSD (SS0102, SS0103) sources: self-contained derived
// tables exposing period_start + calendar_month so the cadence-aware bucketing
// of branchFact applies without touching the shared base CTEs.
// ---------------------------------------------------------------------------

const bloodRequestSource = `(
      SELECT
        br.blood_request_id,
        br.vn,
        br.hn,
        br.request_date,
        DATE_TRUNC('month', br.request_date)::date AS period_start,
        EXTRACT(MONTH FROM br.request_date)::integer AS calendar_month
      FROM blood_request br
      WHERE br.request_date >= :start_date
        AND br.request_date < :end_date
    ) blood_requests`;

const surgicalBloodRequestWhere = `EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.vn = blood_requests.vn
         OR (
              ol.hn = blood_requests.hn
              AND ol.operation_date >= blood_requests.request_date - INTERVAL '7 days'
              AND ol.operation_date <= blood_requests.request_date + INTERVAL '7 days'
            )
    )`;

const sterileBatchSource = `(
      SELECT
        st.supply_sterile_id,
        st.supply_sterile_date,
        st.supply_sterile_confirm,
        st.supply_sterile_complete,
        DATE_TRUNC('month', st.supply_sterile_date)::date AS period_start,
        EXTRACT(MONTH FROM st.supply_sterile_date)::integer AS calendar_month
      FROM supply_sterile st
      WHERE st.supply_sterile_date >= :start_date
        AND st.supply_sterile_date < :end_date
    ) sterile_batches`;

const sterileReceiptSource = `(
      SELECT
        sr.supply_sterile_receive_id,
        sr.supply_sterile_id,
        sr.supply_sterile_receive_date,
        sr.supply_sterile_receive_status,
        DATE_TRUNC('month', sr.supply_sterile_receive_date)::date AS period_start,
        EXTRACT(MONTH FROM sr.supply_sterile_receive_date)::integer AS calendar_month
      FROM supply_sterile_receive sr
      WHERE sr.supply_sterile_receive_date >= :start_date
        AND sr.supply_sterile_receive_date < :end_date
    ) sterile_receipts`;

// ---------------------------------------------------------------------------
// Branches (one per assigned code, in code order).
// ---------------------------------------------------------------------------

const ca0101Den = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
    ))`;

const ca0101Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
        AND (
          EXISTS (
            SELECT 1
            FROM operation_cpr cpr
            WHERE cpr.operation_id = ol.operation_id
          )
          OR ol.intra_anes_operation_note ILIKE '%หัวใจหยุดเต้น%'
          OR LOWER(ol.intra_anes_operation_note) LIKE '%cardiac arrest%'
        )
    ))`;

const ca0102Den = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${anesCaseOl}
        AND ${notEmergencyOl}
    ))`;

const ca0102Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${anesCaseOl}
        AND ${notEmergencyOl}
        AND ${preAnesVisitOl}
    ))`;

const ca0103Den = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${anesCaseOl}
    ))`;

const ca0103Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${anesCaseOl}
        AND ${recoveryRoomOl}
    ))`;

const ca0104Den = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${gaIntubatedOl}
    ))`;

const ca0104Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${gaIntubatedOl}
        AND ${reIntubationOl}
    ))`;

const ca0105Den = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${gaIntubatedOl}
    ))`;

const ca0105Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${gaIntubatedOl}
        AND ${capnometryOl}
    ))`;

const cg0101Den = 'SUM(COALESCE(periodized.los, 0))';
const cg0101Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE ${hapiEvidence})`;

const cg0102Den = `SUM(COALESCE(periodized.los, 0)) FILTER (WHERE ${riskAssessed})`;
const cg0102Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE ${riskAssessed} AND ${hapiEvidence})`;

const co0105Den = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${anesCaseOl}
        AND ${notEmergencyOl}
    ))`;

const co0105Num = `COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND ${anesCaseOl}
        AND ${notEmergencyOl}
        AND EXISTS (
          SELECT 1
          FROM operation_detail od
          WHERE od.operation_id = ol.operation_id
            AND EXISTS (
              SELECT 1
              FROM death d
              WHERE d.an = periodized.an
                AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
                  COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00'))
                AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
                  COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00')) + INTERVAL '24 hours'
            )
        )
    ))`;

const sl0101Num = 'SUM(brd.request_qty)';
const sl0101Den = 'SUM(brd.response_qty)';

const ss0102Num = `COUNT(*) FILTER (
        WHERE sterile_batches.supply_sterile_complete = 'Y'
          AND sterile_batches.supply_sterile_confirm = 'Y'
          AND NOT EXISTS (
            SELECT 1
            FROM supply_sterile_list sl
            WHERE sl.supply_sterile_id = sterile_batches.supply_sterile_id
              AND COALESCE(sl.supply_sterile_list_complete, 'N') <> 'Y'
          )
      )`;
const ss0102Den = 'COUNT(*)';

const ss0103Num = `COUNT(*) FILTER (
        WHERE sterile_receipts.supply_sterile_receive_status = 'Y'
          AND EXISTS (
            SELECT 1
            FROM supply_sterile st
            WHERE st.supply_sterile_id = sterile_receipts.supply_sterile_id
              AND st.supply_sterile_confirm = 'Y'
          )
      )`;
const ss0103Den = 'COUNT(*)';

export const SAFETY_OPERATIONS_BRANCHES: readonly string[] = [
  branchIpd('CA0101', ca0101Num, ca0101Den, ratioValue(ca0101Num, ca0101Den, 10000), 'TRUE'),
  branchIpd('CA0102', ca0102Num, ca0102Den, ratioValue(ca0102Num, ca0102Den, 100), 'TRUE'),
  branchIpd('CA0103', ca0103Num, ca0103Den, ratioValue(ca0103Num, ca0103Den, 100), 'TRUE'),
  branchIpd('CA0104', ca0104Num, ca0104Den, ratioValue(ca0104Num, ca0104Den, 100), 'TRUE'),
  branchIpd('CA0105', ca0105Num, ca0105Den, ratioValue(ca0105Num, ca0105Den, 100), 'TRUE'),
  branchIpd('CG0101', cg0101Num, cg0101Den, ratioValue(cg0101Num, cg0101Den, 1000), 'TRUE'),
  branchIpd('CG0102', cg0102Num, cg0102Den, ratioValue(cg0102Num, cg0102Den, 1000), 'TRUE'),
  externalFactBranch('CG0103'),
  externalFactBranch('CG0104'),
  branchIpd(
    'CO0101',
    `COUNT(DISTINCT ol.operation_id) FILTER (WHERE ${checklistCompleteOl})`,
    'COUNT(DISTINCT ol.operation_id)',
    ratioValue(`COUNT(DISTINCT ol.operation_id) FILTER (WHERE ${checklistCompleteOl})`, 'COUNT(DISTINCT ol.operation_id)', 100),
    'TRUE',
    { join: 'JOIN operation_list ol ON ol.an = periodized.an' },
  ),
  branchIpd('CO0105', co0105Num, co0105Den, ratioValue(co0105Num, co0105Den, 100), 'TRUE'),
  branchIpd(
    'CO0107',
    "COUNT(DISTINCT ol.operation_id) FILTER (WHERE ol.re_operation = 'Y')",
    'COUNT(DISTINCT ol.operation_id)',
    ratioValue("COUNT(DISTINCT ol.operation_id) FILTER (WHERE ol.re_operation = 'Y')", 'COUNT(DISTINCT ol.operation_id)', 100),
    'TRUE',
    { join: 'JOIN operation_list ol ON ol.an = periodized.an' },
  ),
  externalFactBranch('SI0101'),
  externalFactBranch('SI0102'),
  externalFactBranch('SI0103'),
  externalFactBranch('SI0201'),
  externalFactBranch('SI0202'),
  externalFactBranch('SI0203'),
  externalFactBranch('SI0301'),
  externalFactBranch('SI0302'),
  externalFactBranch('SI0303'),
  branchFact(
    'SL0101',
    sl0101Num,
    sl0101Den,
    ratioValue(sl0101Num, sl0101Den, 1),
    surgicalBloodRequestWhere,
    {
      source: bloodRequestSource,
      join: 'JOIN blood_request_detail brd ON brd.blood_request_id = blood_requests.blood_request_id',
    },
  ),
  externalFactBranch('SS0101'),
  branchFact('SS0102', ss0102Num, ss0102Den, ratioValue(ss0102Num, ss0102Den, 100), 'TRUE', {
    source: sterileBatchSource,
  }),
  branchFact('SS0103', ss0103Num, ss0103Den, ratioValue(ss0103Num, ss0103Den, 100), 'TRUE', {
    source: sterileReceiptSource,
  }),
];

export const SAFETY_OPERATIONS_APPROXIMATIONS: Readonly<Record<string, string>> = {
  CA0101:
    'Measures IPD admissions with an operation_list case carrying ASA physical status I or II ' +
    '(operation_anes_physical_status_id IN (1,2) or operation_anes_detail.asa_id IN (1,2)) whose ' +
    'intra-operative cardiac arrest is evidenced by an operation_cpr record or a cardiac-arrest note in ' +
    'operation_list.intra_anes_operation_note. PDF needs: arrests among ASA I or II patients only, counted ' +
    'per anesthetized patient, with event time strictly inside the operation. Confirm with the hospital ' +
    'owner: the id-to-ASA mapping of operation_anes_physical_status (assumed 1 = ASA I, 2 = ASA II), that ' +
    'operation_cpr is filled for every intra-operative arrest, and that arrests documented only in ' +
    'anesthesia free text are captured by the note keywords. OPD-only operations are out of scope of the ' +
    'IPD discharge base.',
  CA0102:
    'Measures the share of elective anesthetized IPD operation cases with a documented pre-anesthetic ' +
    'visit (operation_list.pre_anes_operation_note or operation_visit_list rows with pre_anes_note or ' +
    'operation_visit_anes_type_id). PDF needs: major elective operations only and a true pre-anesthetic ' +
    'visit within the recommended pre-operative window. Confirm with the hospital owner: the ' +
    'operation_emergency name convention used to flag emergency cases (matched on "ฉุกเฉิน" or ' +
    '"emergen"), how major operations are marked (oper_type lookup), and that pre-anesthetic visits are ' +
    'recorded in operation_visit_list rather than paper forms.',
  CA0103:
    'Measures the share of anesthetized IPD operation cases with a recovery-room record ' +
    '(operation_recovery_room rows for the operation). PDF needs: care in the recovery room for the ' +
    'clinically appropriate duration per anesthesia type. Confirm with the hospital owner: that every ' +
    'post-anesthesia recovery stay is charted in operation_recovery_room (enter/leave times present) and ' +
    'whether direct-to-ICU transfers should be excluded.',
  CA0104:
    'Measures re-intubation within 2 hours after extubation among intubated general-anesthesia IPD cases ' +
    '(operation_anes with tube type or intubation time), detecting the event from operation_anes_problem ' +
    'rows whose comment or operation_airway_solution lookup name mentions intubation, timestamped within ' +
    '2 hours after the recorded anesthesia end. PDF needs: true extubation time and any re-intubation for ' +
    'any reason. Confirm with the hospital owner: that extubation is recorded (operation_anes.end), that ' +
    'airway problems and their solutions are charted in operation_anes_problem, and the lookup wording in ' +
    'operation_airway_solution used for re-intubation.',
  CA0105:
    'Measures the share of intubated general-anesthesia IPD cases with exhaled-CO2 (capnometry) ' +
    'monitoring, evidenced by the operation_anes_detail.monitor text (capno, etco, คาพโน) or a recorded ' +
    'ipd_nurse_note.etco2 value. PDF needs: capnometry use for the whole intubated general-anesthesia ' +
    'period. Confirm with the hospital owner: the monitor naming convention in operation_anes_detail, and ' +
    'whether capnometry is charted elsewhere (for example an anesthesia record sheet outside HOSxP).',
  CG0101:
    'Measures new hospital-acquired pressure ulcers stage 1 or worse per 1000 patient-days: numerator is ' +
    'IPD admissions whose secondary diagnosis carries dotless L89 codes or whose nursing notes mention a ' +
    'pressure ulcer strictly after the admission date (with principal diagnosis outside L89), ' +
    'denominator is SUM(an_stat.los) over the same discharge cohort. PDF needs: true present-on-admission ' +
    'status, UHNDC staging (1-4, unstageable, deep tissue injury) and onset date. Confirm with the ' +
    'hospital owner: the L89 staging convention, that patient-days should be census days rather than ' +
    'discharged-cohort length of stay, and whether ulcers present on admission are distinguishable in ' +
    'ipd_nurse_note. Staging and POA precision likely require the UHNDC survey forms loaded via ' +
    'branchExternal.',
  CG0102:
    'Same rate restricted to risk-assessed patients: a risk assessment is approximated by nursing notes ' +
    'mentioning Braden or pressure-ulcer risk, the denominator being their total length of stay and the ' +
    'numerator the CG0101 evidence within that group. PDF needs: the documented Braden (or local) risk ' +
    'assessment population and their patient-days. Confirm with the hospital owner: where the risk ' +
    'assessment is recorded (structured Braden scores are not standard HOSxP columns) and the accepted ' +
    'wording; otherwise stage the risk-patient counts via branchExternal.',
  CG0103:
    'NOT computable from HOSxP: the PDF defines a point-prevalence survey (all pressure-ulcer patients ' +
    'present in the hospital at the survey moment, including pre-admission-onset, over the surveyed ' +
    'population). External staging: load one row per quarterly anchor (period_start = first day of Jan, ' +
    'Apr, Jul or Oct) into reporting.thip_external_facts with indicator_code = CG0103, numerator = ' +
    'surveyed patients with any pressure ulcer stage 1 or worse (present-on-admission plus ' +
    'hospital-acquired), denominator = all surveyed inpatients at that moment, value = ROUND(numerator * ' +
    '100 / NULLIF(denominator, 0), 2), source_system = nursing_pui_survey. Confirm with the hospital ' +
    'owner: survey dates and the survey roster used.',
  CG0104:
    'NOT computable from HOSxP: the PDF defines a point-prevalence survey counting only ulcers that ' +
    'developed after admission (chart review of the admission note required). External staging: load one ' +
    'row per quarterly anchor (period_start = first day of Jan, Apr, Jul or Oct) into ' +
    'reporting.thip_external_facts with indicator_code = CG0104, numerator = surveyed patients with a ' +
    'hospital-acquired pressure ulcer stage 1 or worse, denominator = the whole surveyed population at ' +
    'that moment, value = ROUND(numerator * 100 / NULLIF(denominator, 0), 2), source_system = ' +
    'nursing_pui_survey. Confirm with the hospital owner: the admission-note review process that ' +
    'separates hospital-acquired from present-on-admission ulcers.',
  CO0101:
    'Measures the share of operating-room occasions with a complete surgical safety checklist: ' +
    'operation_list.operation_check_date set, an operation_detail row with time_out_datetime (time-out), ' +
    'and operation_screen_in rows with preoperative, perioperative and postoperative nursing records ' +
    '(sign in, time out, sign out). Denominator counts operation_list.operation_id occasions of IPD ' +
    'cases discharged in the period. PDF needs: every procedure in every OR, with each of the three parts ' +
    'completed correctly. Confirm with the hospital owner: the confirm_receive and confirm_complete flag ' +
    'semantics on operation_list, whether checklist completion is verified against paper checklists, and ' +
    'that OPD-only procedures (no admission) are out of scope here.',
  CO0105:
    'Measures peri-operative mortality within 24 hours for elective anesthetized IPD operation cases: ' +
    'death (death table) timestamped between the first operation_detail begin time (falling back to ' +
    'operation_list operation_date + operation_time) and that anchor plus 24 hours. PDF needs: major ' +
    'elective operations only, with the window covering anesthesia induction through 24 hours after ' +
    'surgery. Confirm with the hospital owner: the operation_emergency name convention for emergency ' +
    'cases, the major-operation marker (oper_type lookup), and whether deaths between induction and ' +
    'incision would be missed by the incision-time anchor.',
  CO0107:
    'Measures the share of operating-room occasions flagged as re-operation ' +
    '(operation_list.re_operation = Y) among all operation occasions of IPD cases discharged in the ' +
    'period. PDF needs: unplanned re-operations for the same disease within one admission plus ' +
    'outpatient operations that force an immediate unplanned admission, excluding planned staged ' +
    'procedures. Confirm with the hospital owner: that re_operation is actively maintained (it is a ' +
    'char(1) flag whose Y convention must be verified), how planned staged operations are marked, and ' +
    'how the OPD-to-admission cases are recorded.',
  SI0101:
    'NOT in standard HOSxP: VAP needs NHSN device-days and surveillance-defined events. External ' +
    'staging: one monthly row per anchor (period_start = first day of the month) in ' +
    'reporting.thip_external_facts with indicator_code = SI0101, numerator = NHSN-defined VAP events in ' +
    'all wards (ICU plus non-ICU), denominator = total ventilator-days in all wards, value = ' +
    'ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. ' +
    'Confirm with the hospital owner: the infection-control registry that keeps ventilator-days and the ' +
    'NHSN case definition version in use.',
  SI0102:
    'As SI0101 restricted to ICU patients. External staging: one monthly row with indicator_code = ' +
    'SI0102, numerator = NHSN-defined VAP events of ICU patients (all ICUs combined), denominator = ' +
    'ICU ventilator-days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = ' +
    'icu_infection_surveillance. Confirm with the hospital owner: the list of wards counted as ICUs and ' +
    'that device-days are collected per ICU.',
  SI0103:
    'As SI0101 restricted to non-ICU wards. External staging: one monthly row with indicator_code = ' +
    'SI0103, numerator = NHSN-defined VAP events outside the ICUs, denominator = non-ICU ' +
    'ventilator-days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = ' +
    'icu_infection_surveillance. Confirm with the hospital owner: ward classification of the ICU list.',
  SI0201:
    'NOT in standard HOSxP: CABSI needs central-line days and NHSN laboratory-confirmed bloodstream ' +
    'infection events. External staging: one monthly row with indicator_code = SI0201, numerator = ' +
    'NHSN-defined CABSI events in all wards, denominator = total central-line days, value = ' +
    'ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. ' +
    'Confirm with the hospital owner: where central-line insertion and removal dates are kept (ipd_nurse_note ' +
    'has no line-day fields) and the laboratory criteria used for the event definition.',
  SI0202:
    'As SI0201 restricted to ICU patients. External staging: one monthly row with indicator_code = ' +
    'SI0202, numerator = NHSN-defined CABSI events of ICU patients (all ICUs combined), denominator = ' +
    'ICU central-line days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = ' +
    'icu_infection_surveillance. Confirm with the hospital owner: the ICU ward list and per-ICU line-day ' +
    'collection.',
  SI0203:
    'As SI0201 restricted to non-ICU wards. External staging: one monthly row with indicator_code = ' +
    'SI0203, numerator = NHSN-defined CABSI events outside the ICUs, denominator = non-ICU ' +
    'central-line days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = ' +
    'icu_infection_surveillance. Confirm with the hospital owner: ward classification of the ICU list.',
  SI0301:
    'NOT in standard HOSxP: CAUTI needs urinary-catheter days and NHSN symptomatic urinary-tract ' +
    'infection events. External staging: one monthly row with indicator_code = SI0301, numerator = ' +
    'NHSN-defined CAUTI events in all wards, denominator = total urinary-catheter days, value = ' +
    'ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. ' +
    'Confirm with the hospital owner: where catheter insertion and removal dates are recorded and that ' +
    'asymptomatic bacteriuria cases are excluded per the definition.',
  SI0302:
    'As SI0301 restricted to ICU patients. External staging: one monthly row with indicator_code = ' +
    'SI0302, numerator = NHSN-defined CAUTI events of ICU patients (all ICUs combined), denominator = ' +
    'ICU urinary-catheter days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), ' +
    'source_system = icu_infection_surveillance. Confirm with the hospital owner: the ICU ward list.',
  SI0303:
    'As SI0301 restricted to non-ICU wards. External staging: one monthly row with indicator_code = ' +
    'SI0303, numerator = NHSN-defined CAUTI events outside the ICUs, denominator = non-ICU ' +
    'urinary-catheter days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = ' +
    'icu_infection_surveillance. Confirm with the hospital owner: ward classification of the ICU list.',
  SL0101:
    'Measures the C:T ratio for surgical cases from blood_request plus blood_request_detail: numerator ' +
    'is SUM(request_qty) (units crossmatch-requested) and denominator SUM(response_qty) (units issued) ' +
    'of blood requests tied to a surgical case (operation_list matched on vn, or on hn with an operation ' +
    'date within 7 days of the request). PDF needs: crossmatched units versus truly transfused units per ' +
    'month for elective surgery groups. Confirm with the hospital owner: whether response_qty equals ' +
    'transfused units, the correct patient-to-operation matching key (blood_request carries vn and hn ' +
    'but no an), and whether the blood-bank module (bb_ or blb_ tables) holds the authoritative ' +
    'crossmatch and transfusion unit counts that should be staged via branchExternal instead.',
  SS0101:
    'NOT in HOSxP: sterilization effectiveness checks (mechanical, chemical and biological spore-test ' +
    'indicators) are CSSD logbook events. External staging: one monthly row per anchor in ' +
    'reporting.thip_external_facts with indicator_code = SS0101, numerator = sterilization effectiveness ' +
    'checks passing all applicable indicators, denominator = all sterilization effectiveness checks in ' +
    'the month (steam and gas), value = ROUND(numerator * 100 / NULLIF(denominator, 0), 2), ' +
    'source_system = cssd_log. Confirm with the hospital owner: the check frequency policy (each load, ' +
    'weekly spore test) and who keeps the log.',
  SS0102:
    'Measures the share of CSSD sterilization batches prepared correctly and completely: ' +
    'supply_sterile batches with supply_sterile_complete = Y and supply_sterile_confirm = Y and no ' +
    'supply_sterile_list line left incomplete. PDF needs: instrument sets assembled correctly for the ' +
    'specific procedure per the hospital committee agreement. Confirm with the hospital owner: that ' +
    'set-content correctness is verified against operation_set (operation_list.operation_set_id) or a ' +
    'paper checklist, and the Y convention of the supply_sterile flags; otherwise stage the audit counts ' +
    'via branchExternal.',
  SS0103:
    'Measures the share of CSSD distributions acknowledged as accurately provided: ' +
    'supply_sterile_receive rows with supply_sterile_receive_status = Y whose parent ' +
    'supply_sterile batch is confirmed. PDF needs: correct, complete and on-time provision of supplies ' +
    'to the requesting units as verified by the receiving unit. Confirm with the hospital owner: that ' +
    'supply_sterile_receive records the unit acknowledgement of an accurate delivery (including ' +
    'timeliness) and the status flag convention.',
};
