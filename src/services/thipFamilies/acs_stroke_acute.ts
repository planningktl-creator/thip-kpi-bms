/**
 * THIP family batch `acs_stroke_acute` — 26 fact branches for acute coronary
 * syndrome, atrial fibrillation, stroke, head injury, pneumonia smoking
 * advice, ER sepsis timing and upper gastrointestinal hemorrhage (UGIH).
 *
 * Every branch follows the thipFamilyBatch contract: one row per episode (or
 * per visit for the OPD based AF and ER sepsis codes) per reporting period
 * anchor, dotless ICD literals, NULLIF-guarded divisions only, aggregate-only
 * outer projection. All event-timing and documentation semantics that HOSxP
 * stores only approximately are recorded in ACS_STROKE_ACUTE_APPROXIMATIONS.
 *
 * Verified HOSxP relations used here (HOSxP Structure workbook):
 * ipt, an_stat, iptdiag, iptoprt (an, icd9, opdate, optime, oper_note_text),
 * opitemrece (an, vn, icode, rxdate, rxtime), drugitems (icode, name),
 * opdscreen (vn, smoking_type_id, advice1..advice8, advice7_note, inr),
 * opdscreen_advice, opdscreen_advice_item, ovstdiag, ovst, er_regist,
 * er_regist_oper, er_oper_code, referout (vn, refer_begin_time),
 * ovst_rehab (an, service_date), lab_order, lab_head, lab_items.
 */

import { branchFact, branchIpd } from '@/services/thipFamilyBase';

function ratio100Value(numerator: string, denominator: string): string {
  return `ROUND((${numerator}) * 100 / NULLIF((${denominator}), 0), 2)`;
}

function ratio1Value(numerator: string, denominator: string): string {
  return `ROUND((${numerator}) * 1 / NULLIF((${denominator}), 0), 2)`;
}

// --- Cohort predicates (dotless ICD literals only) ---

const acsWhere = "age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')";
const stemiWhere = "age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213')";
const ischemicStrokeWhere = "age_y >= 18 AND LEFT(pdx, 3) = 'I63'";
const strokeWhere = "age_y >= 18 AND LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64')";
const pneumoniaWhere =
  "LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')";
const headInjuryWhere = "age_y >= 18 AND LEFT(pdx, 3) IN ('S02', 'S06')";
const intracranialInjuryWhere = "age_y >= 18 AND LEFT(pdx, 3) = 'S06'";
const ugihWhere =
  "age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')";
const nonVaricealUgihWhere =
  "age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290')";

// --- Drug name predicates over drugitems.name ---

const ASPIRIN = "di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%'";
const ANTIPLATELET = `${ASPIRIN} OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%'`;
const ANTICOAGULANT = "di.name ILIKE '%warfarin%' OR di.name ILIKE '%heparin%' OR di.name ILIKE '%enoxaparin%' OR di.name ILIKE '%dalteparin%' OR di.name ILIKE '%fondaparinux%' OR di.name ILIKE '%dabigatran%' OR di.name ILIKE '%rivaroxaban%' OR di.name ILIKE '%apixaban%' OR di.name ILIKE '%edoxaban%'";
const ANTITHROMBOTIC = `${ANTIPLATELET} OR ${ANTICOAGULANT}`;
const BETA_BLOCKER = "di.name ILIKE '%metoprolol%' OR di.name ILIKE '%atenolol%' OR di.name ILIKE '%bisoprolol%' OR di.name ILIKE '%carvedilol%' OR di.name ILIKE '%propranolol%' OR di.name ILIKE '%labetalol%' OR di.name ILIKE '%nebivolol%' OR di.name ILIKE '%sotalol%'";
const ACEI_ARB = "di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%' OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%' OR di.name ILIKE '%benazepril%' OR di.name ILIKE '%quinapril%' OR di.name ILIKE '%trandolapril%' OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%' OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%' OR di.name ILIKE '%azilsartan%'";
const THROMBOLYTIC = "di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%'";
const WARFARIN = "di.name ILIKE '%warfarin%'";
const RED_CELL = "di.name ILIKE '%packed red%' OR di.name ILIKE '%red cell%' OR di.name ILIKE '%prbc%'";

const DISCHARGE_WINDOW = "oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate";
const FIRST_48H_WINDOW = "oi.rxdate >= periodized.regdate AND oi.rxdate <= periodized.regdate + INTERVAL '2 days'";

function ipdDrugSubquery(names: string, dateCondition: string): string {
  const cond = dateCondition ? `\n            AND ${dateCondition}` : '';
  return `
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (${names})${cond}`;
}

function visitDrugSubquery(key: string, names: string): string {
  return `
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.vn = ${key}.vn
            AND (${names})`;
}

// --- ER clock subqueries (correlated on the admission) ---

const ekgMinutesSubquery = `
          SELECT EXTRACT(EPOCH FROM ((er.vstdate + ero.begin_time) - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN er_regist_oper ero ON ero.vn = v.vn
          JOIN er_oper_code eoc ON eoc.er_oper_code = ero.er_oper_code
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ero.begin_time IS NOT NULL
            AND (er.vstdate + ero.begin_time) >= er.enter_er_time
            AND (
              eoc.name ILIKE '%ekg%'
              OR eoc.name ILIKE '%ecg%'
              OR REPLACE(UPPER(TRIM(eoc.icd9cm)), '.', '') = '8952'
            )
          ORDER BY ero.begin_time
          LIMIT 1`;

const doorToReferMinutesSubquery = `
          SELECT EXTRACT(EPOCH FROM (ro.refer_begin_time - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN referout ro ON ro.vn = v.vn
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ro.refer_begin_time IS NOT NULL
            AND ro.refer_begin_time >= er.enter_er_time
          ORDER BY ro.refer_begin_time
          LIMIT 1`;

function thrombolyticWithinSubquery(minutes: number): string {
  return `
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (${THROMBOLYTIC})
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '${minutes} minutes'
            )`;
}

const stemiBalloon120Subquery = `
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stemi_balloon = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stemi_balloon_datetime IS NOT NULL
            AND er.stemi_balloon_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stemi_balloon_datetime - er.enter_er_time)) <= 7200`;

const strokeNeedle60Subquery = `
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stroke_needle_datetime IS NOT NULL
            AND er.stroke_needle_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stroke_needle_datetime - er.enter_er_time)) <= 3600`;

const strokeNeedleAnySubquery = `
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y'`;

// --- Documentation and cohort flags ---

const smokerPred = `(
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND (
                LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
                OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND scr.smoking_type_id IN (2, 3)
          )
        )`;

const smokingAdvicePred = `(
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
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
            FROM opdscreen_advice adv
            JOIN opdscreen_advice_item itm ON itm.opdscreen_advice_item_id = adv.opdscreen_advice_item_id
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
              AND (
                itm.opdscreen_advice_item_name ILIKE '%smoke%'
                OR itm.opdscreen_advice_item_name ILIKE '%บุหรี่%'
              )
          )
        )`;

const healthEducationPred = `(
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('Z716', 'Z719', 'V6541', 'V6549')
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
          )
        )`;

const lvsdPred = `EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I502', 'I504')
        )`;

const afSdxPred = `EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
        )`;

const betaContraindicationPred = `NOT EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
              OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('R000', 'R001', 'I440', 'I441', 'I442', 'I495', 'I951')
            )
        )`;

const rehab72hPred = `EXISTS (
          SELECT 1
          FROM ovst_rehab rb
          WHERE rb.an = periodized.an
            AND rb.service_date >= periodized.regdate
            AND rb.service_date::timestamp <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00') + INTERVAL '72 hours')
        )`;

const craniotomyPred = `EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(o.icd9)), '.', ''), 3) IN ('012', '013', '014', '015', '016')
        )`;

const readmit28Numerator = `COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))`;

const readmit28Denominator = 'COUNT(*) FILTER (WHERE NOT died)';

// --- UGIH endoscopy subqueries ---

const EGD_ICD9 = "'4513', '4514', '4515', '4516'";

function egdSubquery(within24h: boolean): string {
  const timing = within24h
    ? `
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) >= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '24 hours'`
    : '';
  return `
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN (${EGD_ICD9})${timing}`;
}

const hemostasisPred = `(
          EXISTS (${egdSubquery(false)})
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN (${EGD_ICD9})
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        )`;

const rebleedingPred = `(
          EXISTS (
            SELECT 1
            FROM iptoprt o3
            WHERE o3.an = periodized.an
              AND REPLACE(UPPER(TRIM(o3.icd9)), '.', '') IN (${EGD_ICD9})
              AND o3.opdate >= periodized.regdate + INTERVAL '2 days'
          )
          OR EXISTS (
            SELECT 1
            FROM opitemrece oi
            JOIN drugitems di ON di.icode = oi.icode
            WHERE oi.an = periodized.an
              AND oi.rxdate > periodized.regdate
              AND (${RED_CELL})
          )
        )`;

const endoscopyComplicationPred = `EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T810', 'T811', 'T812', 'T813', 'T814', 'T815', 'T816', 'T818', 'T819', 'K631', 'J690')
        )`;

const labNumericResult = `CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END`;

const ugihHighRiskPred = `(
          age_y >= 60
          OR EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('N18', 'K74', 'I50', 'I25', 'J43', 'J44')
          )
          OR EXISTS (
            SELECT 1
            FROM lab_order lo
            JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
            JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
            WHERE lh.hn = periodized.hn
              AND lh.order_date >= periodized.regdate
              AND lh.order_date <= periodized.dchdate
              AND (
                li.lab_items_name ILIKE '%hemoglobin%'
                OR li.lab_items_name ILIKE '%hb%'
              )
              AND li.lab_items_name NOT ILIKE '%hba1c%'
              AND ${labNumericResult} <= 8
          )
        )`;

// --- OPD visit based predicates (AF warfarin follow-up and ER sepsis) ---

const afVisitPred = `(
          LEFT(pdx, 3) = 'I48'
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
          )
        )`;

const warfarinVisitPred = `EXISTS (${visitDrugSubquery('opd_periodized', WARFARIN)})`;

const inrRecordedPred = "EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL)";

const inrAtTargetPred = "EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL AND sc.inr >= 2.0 AND sc.inr <= 3.0)";

const majorBleedingPred = `EXISTS (
          SELECT 1
          FROM ipt i2
          JOIN an_stat s2 ON s2.an = i2.an
          WHERE i2.hn = opd_periodized.hn
            AND LEFT(REPLACE(UPPER(TRIM(s2.pdx)), '.', ''), 3) IN ('I60', 'I61', 'I62')
            AND i2.regdate <= opd_periodized.event_date
            AND i2.regdate >= opd_periodized.event_date - INTERVAL '90 days'
        )`;

const erSepsisPred = `(
          pdx IN ('A400', 'A419', 'R572', 'R651')
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651')
          )
        )`;

const abxWithin1hPred =
  "antibiotics_datetime IS NOT NULL AND doctor_tx_time IS NOT NULL AND antibiotics_datetime >= doctor_tx_time AND antibiotics_datetime <= doctor_tx_time + INTERVAL '1 hour'";

// --- Branch assembly ---

function ipdRatioBranch(
  code: string,
  numerator: string,
  denominator: string,
  where: string,
): string {
  return branchIpd(code, numerator, denominator, ratio100Value(numerator, denominator), where);
}

const aspirinDischarge = ipdDrugSubquery(ASPIRIN, DISCHARGE_WINDOW);
const aceiArbInStay = ipdDrugSubquery(ACEI_ARB, '');
const betaBlockerInStay = ipdDrugSubquery(BETA_BLOCKER, '');
const betaBlockerDischarge = ipdDrugSubquery(BETA_BLOCKER, DISCHARGE_WINDOW);
const antiplatelet48h = ipdDrugSubquery(ANTIPLATELET, FIRST_48H_WINDOW);
const antithromboticDischarge = ipdDrugSubquery(ANTITHROMBOTIC, DISCHARGE_WINDOW);
const anticoagulantInStay = ipdDrugSubquery(ANTICOAGULANT, '');

const DH0103_NUM = `COUNT(*) FILTER (WHERE EXISTS (${aspirinDischarge}))`;
const DH0104_NUM = `COUNT(*) FILTER (WHERE EXISTS (${aceiArbInStay}))`;
const DH0104_DEN = 'COUNT(*)';
const DH0105_NUM = `COUNT(*) FILTER (WHERE ${smokingAdvicePred})`;
const DH0106_NUM = `COUNT(*) FILTER (WHERE EXISTS (${betaBlockerInStay}))`;
const DH0107_NUM = `COUNT(*) FILTER (WHERE EXISTS (${betaBlockerDischarge}))`;
const DH0108_NUM = `SUM((${ekgMinutesSubquery}))`;
const DH0108_DEN = 'COUNT(*)';
const DH0109_NUM = `SUM((${doorToReferMinutesSubquery}))`;
const DH0109_DEN = 'COUNT(*)';
const DH0110_NUM = `COUNT(*) FILTER (WHERE EXISTS (${stemiBalloon120Subquery}) OR EXISTS (${thrombolyticWithinSubquery(30)}))`;
const DH0113_NUM = `COUNT(*) FILTER (WHERE EXISTS (${thrombolyticWithinSubquery(30)}))`;
const DN0102_NUM = `COUNT(*) FILTER (WHERE EXISTS (${antiplatelet48h}))`;
const DN0103_NUM = `COUNT(*) FILTER (WHERE EXISTS (${antithromboticDischarge}))`;
const DN0104_NUM = `COUNT(*) FILTER (WHERE EXISTS (${anticoagulantInStay}))`;
const DN0105_NUM = `COUNT(*) FILTER (WHERE ${healthEducationPred})`;
const DN0106_NUM = `COUNT(*) FILTER (WHERE ${rehab72hPred})`;
const DN0110_NUM = `COUNT(*) FILTER (WHERE EXISTS (${strokeNeedle60Subquery}) OR EXISTS (${thrombolyticWithinSubquery(60)}))`;
const DN0110_DEN = `COUNT(*) FILTER (WHERE EXISTS (${strokeNeedleAnySubquery}) OR EXISTS (${ipdDrugSubquery(THROMBOLYTIC, '')}))`;
const DN0303_NUM = `COUNT(*) FILTER (WHERE ${craniotomyPred})`;
const DR0103_NUM = `COUNT(*) FILTER (WHERE ${smokingAdvicePred})`;

export const ACS_STROKE_ACUTE_BRANCHES: readonly string[] = [
  ipdRatioBranch('DH0103', DH0103_NUM, 'COUNT(*)', `${acsWhere} AND NOT died`),
  ipdRatioBranch('DH0104', DH0104_NUM, DH0104_DEN, `${acsWhere} AND ${lvsdPred}`),
  ipdRatioBranch('DH0105', DH0105_NUM, 'COUNT(*)', `${acsWhere} AND ${smokerPred}`),
  ipdRatioBranch('DH0106', DH0106_NUM, 'COUNT(*)', `${acsWhere} AND ${betaContraindicationPred}`),
  ipdRatioBranch('DH0107', DH0107_NUM, 'COUNT(*)', `${acsWhere} AND ${betaContraindicationPred} AND NOT died`),
  branchIpd('DH0108', DH0108_NUM, DH0108_DEN, ratio1Value(DH0108_NUM, DH0108_DEN), `${acsWhere} AND ((${ekgMinutesSubquery})) IS NOT NULL`),
  branchIpd('DH0109', DH0109_NUM, DH0109_DEN, ratio1Value(DH0109_NUM, DH0109_DEN), `${acsWhere} AND ((${doorToReferMinutesSubquery})) IS NOT NULL`),
  ipdRatioBranch('DH0110', DH0110_NUM, 'COUNT(*)', stemiWhere),
  ipdRatioBranch('DH0113', DH0113_NUM, 'COUNT(*)', stemiWhere),
  branchFact(
    'DH0401',
    `COUNT(*) FILTER (WHERE ${inrAtTargetPred})`,
    `COUNT(*) FILTER (WHERE ${inrRecordedPred})`,
    ratio100Value(`COUNT(*) FILTER (WHERE ${inrAtTargetPred})`, `COUNT(*) FILTER (WHERE ${inrRecordedPred})`),
    `age_y >= 18 AND ${afVisitPred} AND ${warfarinVisitPred}`,
    { source: 'opd_periodized' },
  ),
  branchFact(
    'DH0402',
    `COUNT(*) FILTER (WHERE ${majorBleedingPred})`,
    'COUNT(*)',
    ratio100Value(`COUNT(*) FILTER (WHERE ${majorBleedingPred})`, 'COUNT(*)'),
    `age_y >= 18 AND ${afVisitPred} AND ${warfarinVisitPred}`,
    { source: 'opd_periodized' },
  ),
  ipdRatioBranch('DN0102', DN0102_NUM, 'COUNT(*)', ischemicStrokeWhere),
  ipdRatioBranch('DN0103', DN0103_NUM, 'COUNT(*)', `${ischemicStrokeWhere} AND NOT died`),
  ipdRatioBranch('DN0104', DN0104_NUM, 'COUNT(*)', `${strokeWhere} AND ${afSdxPred} AND NOT died`),
  ipdRatioBranch('DN0105', DN0105_NUM, 'COUNT(*)', `${strokeWhere} AND NOT died`),
  ipdRatioBranch('DN0106', DN0106_NUM, 'COUNT(*)', `${strokeWhere} AND NOT died`),
  ipdRatioBranch('DN0110', DN0110_NUM, DN0110_DEN, ischemicStrokeWhere),
  ipdRatioBranch('DN0301', readmit28Numerator, readmit28Denominator, `${headInjuryWhere} AND ${craniotomyPred}`),
  ipdRatioBranch('DN0303', DN0303_NUM, 'COUNT(*)', intracranialInjuryWhere),
  ipdRatioBranch('DR0103', DR0103_NUM, 'COUNT(*)', `(${pneumoniaWhere}) AND ${smokerPred}`),
  branchFact(
    'CE0104',
    `COUNT(*) FILTER (WHERE ${abxWithin1hPred})`,
    'COUNT(*)',
    ratio100Value(`COUNT(*) FILTER (WHERE ${abxWithin1hPred})`, 'COUNT(*)'),
    `age_y >= 18 AND ${erSepsisPred} AND enter_er_time IS NOT NULL`,
    { source: 'opd_periodized' },
  ),
  ipdRatioBranch('DE1401', `COUNT(*) FILTER (WHERE EXISTS (${egdSubquery(true)}))`, 'COUNT(*)', ugihWhere),
  ipdRatioBranch('DE1402', `COUNT(*) FILTER (WHERE EXISTS (${egdSubquery(true)}))`, 'COUNT(*)', `${ugihWhere} AND ${ugihHighRiskPred} AND NOT died`),
  ipdRatioBranch(
    'DE1403',
    `COUNT(*) FILTER (WHERE ${hemostasisPred} AND NOT ${rebleedingPred})`,
    `COUNT(*) FILTER (WHERE ${hemostasisPred})`,
    nonVaricealUgihWhere,
  ),
  ipdRatioBranch(
    'DE1404',
    `COUNT(*) FILTER (WHERE ${hemostasisPred} AND ${rebleedingPred})`,
    `COUNT(*) FILTER (WHERE ${hemostasisPred})`,
    nonVaricealUgihWhere,
  ),
  ipdRatioBranch(
    'DE1405',
    `COUNT(*) FILTER (WHERE EXISTS (${egdSubquery(false)}) AND ${endoscopyComplicationPred})`,
    `COUNT(*) FILTER (WHERE EXISTS (${egdSubquery(false)}))`,
    ugihWhere,
  ),
];

export const ACS_STROKE_ACUTE_APPROXIMATIONS: Readonly<Record<string, string>> = {
  DH0103:
    'Counts ACS admissions (Pdx I210-I219, age 18 or over) discharged alive whose opitemrece holds an aspirin item on the discharge day or the day before (drugitems.name like aspirin). The PDF asks for aspirin prescribed at discharge with a live home discharge status and an absent contraindication (aspirin allergy, active bleeding); HOSxP does not code the contraindication and dchstts home status is approximated as alive discharge (no death record). Owner must confirm the local aspirin item names and the discharge prescription window.',
  DH0104:
    'Counts ACS admissions with an LVSD proxy (secondary diagnosis I502 or I504, systolic or combined heart failure) that received an ACE inhibitor or ARB during the stay (drugitems.name match). The PDF needs echocardiographic ejection fraction 40 percent or lower to define LVSD; ejection fraction is not stored in HOSxP structured tables. Owner must confirm the heart failure code proxy or load the echo-confirmed cohort aggregates into reporting.thip_external_facts.',
  DH0105:
    'Counts ACS admissions of smokers (secondary diagnosis F17 or Z720, or opdscreen smoking_type_id 2 or 3 on a linked visit) whose chart shows cessation advice (secondary diagnosis Z716, opdscreen advice flags, advice7_note text, or an opdscreen_advice item naming tobacco). The PDF needs documented advice given during the admission for every smoker with no contraindication exclusion; documentation completeness depends on local nursing entry habits. Owner must confirm the smoking status and advice item mappings.',
  DH0106:
    'Counts ACS admissions without coded beta blocker contraindications (no asthma J45 or J46 and no bradycardia or block codes R000, R001, I440, I441, I442, I495, I951 as secondary diagnoses) that received a beta blocker drug during the stay. The PDF excludes clinical contraindications (hypotension, decompensated heart failure, severe asthma) that are not coded in HOSxP, so the denominator is broader than the printed one. Owner must confirm the contraindication list and local beta blocker item names.',
  DH0107:
    'Same cohort as DH0106, restricted to live discharges, with a beta blocker drug item ordered on the discharge day or the day before (take home prescription). The PDF asks for beta blocker prescribed at discharge for patients without contraindications and discharged alive with home status; home discharge status is approximated as alive discharge and contraindications are approximated by the coded list. Owner must confirm the discharge prescription window.',
  DH0108:
    'Average door to EKG minutes for ACS admissions with an ER arrival timestamp and an EKG event: the EKG time is the earliest er_regist_oper begin_time for an ER operation whose er_oper_code name matches EKG or ECG, or whose icd9cm normalizes to 8952, measured from er_regist enter_er_time. The PDF wants the average time from arrival to first EKG over all ACS arrivals; HOSxP stores no dedicated EKG event, so the event source and code naming must be confirmed by the owner (or the average loaded into reporting.thip_external_facts).',
  DH0109:
    'Average door to referral minutes for ACS admissions referred out: from er_regist enter_er_time to referout refer_begin_time for the earliest referral of the linked visit. The PDF wants the average arrival-to-referral time over all referred ACS patients; cases without ER clock or refer timestamps are dropped. Owner must confirm refer_begin_time is maintained at referral decision time.',
  DH0110:
    'Counts STEMI admissions (Pdx I210-I213) whose reperfusion clock meets the target: primary PCI proxy is er_regist do_stemi_balloon with stemi_balloon_datetime within 7200 seconds of enter_er_time, or a fibrinolytic drug (drugitems name match) given within 30 minutes of ER arrival (opitemrece rxdate and rxtime). The PDF denominator excludes patients with PPCI limitations or thrombolytic contraindications and its PPCI clock is puncture or device time, not balloon time; both exclusions and the event choice need owner confirmation.',
  DH0113:
    'Counts STEMI admissions receiving a fibrinolytic agent (streptokinase, alteplase, tenecteplase, reteplase, urokinase by drugitems name) within 30 minutes of ER arrival over all STEMI admissions. The PDF denominator excludes thrombolytic contraindications (recent stroke or bleeding) and counts time from first medical contact; HOSxP codes neither, so the denominator is broader and the clock starts at hospital arrival. Owner must confirm the fibrinolytic item names.',
  DH0401:
    'Visit-grain branch over OPD follow-up visits: atrial fibrillation or flutter (Pdx or secondary I48) with a warfarin item on the visit and an INR recorded in opdscreen; numerator is visits with INR between 2.0 and 3.0. The PDF wants AF patients on warfarin whose INR was at target at every visit of the quarter; per patient all-visit compliance and quarterly windowing are not computable in one pass over visits. Owner must confirm the target range for their warfarin clinic (for example 2.0 to 3.0) or load quarterly patient aggregates into reporting.thip_external_facts.',
  DH0402:
    'Visit-grain branch over AF warfarin follow-up visits (same cohort as DH0401 without the INR requirement); numerator is visits of patients with a non-traumatic intracranial hemorrhage admission (an_stat Pdx I60, I61 or I62) within the 90 days before the visit. The PDF wants quarterly major bleeding (intracranial hemorrhage) incidence among warfarin treated AF patients, including GI bleeding events; the lookback window and visit grain are approximations. Owner must confirm the incidence window or load quarterly aggregates into reporting.thip_external_facts.',
  DN0102:
    'Counts ischemic stroke admissions (Pdx I63, age 18 or over) with an antiplatelet drug item (aspirin, clopidogrel, ticagrelor, prasugrel, dipyridamole, cilostazol) ordered between admission day and admission day plus 2 days. The PDF times the dose from symptom onset within 48 hours; symptom onset time is not stored, so admission time is the clock start. Owner must confirm the antiplatelet item names.',
  DN0103:
    'Counts ischemic stroke admissions discharged alive whose discharge day or day before prescription contains an antiplatelet or anticoagulant item (drugitems name match over both drug groups). The PDF asks for antithrombotic therapy at discharge after live home discharge; home status is approximated as alive discharge. Owner must confirm the antithrombotic item names and discharge window.',
  DN0104:
    'Counts stroke admissions (Pdx I60 to I64) with atrial fibrillation or flutter (secondary diagnosis I48) discharged alive that received an anticoagulant (warfarin, heparins, fondaparinux, or a direct oral anticoagulant) at any point in the stay. The PDF restricts to stays of 120 days or less, excludes palliative care and contraindicated patients, and prefers discharge therapy; those flags are not coded. Owner must confirm the anticoagulant item names and whether discharge-only therapy is required.',
  DN0105:
    'Counts stroke admissions discharged alive with a health education proxy: counseling secondary diagnosis (Z716, Z719, V6541, V6549), opdscreen advice flags set on a linked visit, or any opdscreen_advice record. The PDF needs stroke-specific education (emergency activation, follow-up, risk factor and medication counselling) documented for the patient or caregiver; HOSxP has no stroke education checklist, so documentation proxies may over or under count. Owner must confirm which local documentation of stroke education to treat as evidence.',
  DN0106:
    'Counts stroke admissions discharged alive with a rehabilitation record (ovst_rehab on the admission) whose service_date falls within 72 hours of the admit timestamp. The PDF wants physiotherapy or rehabilitation assessment and treatment started within 72 hours once the patient is stable; stability and the assessment text are not structured and ovst_rehab keeps date granularity only. Owner must confirm ovst_rehab is the inpatient rehab register and the local timing convention.',
  DN0110:
    'Counts ischemic stroke admissions receiving thrombolysis within 60 minutes of arrival (er_regist do_stroke_needle with stroke_needle_datetime within 3600 seconds of enter_er_time, or a fibrinolytic drug item given within 60 minutes of arrival) over admissions that received thrombolysis at all (do_stroke_needle or a fibrinolytic item). The PDF excludes thrombolytic contraindications and counts from arrival to needle for every treated patient; the contraindication exclusion is not coded. Owner must confirm which clock field (door_to_needle_second or the timestamps) is maintained.',
  DN0301:
    'Counts head injury admissions (Pdx S02 or S06, age 18 or over) with a craniotomy procedure (iptoprt icd9 in the 012 to 016 families) discharged alive and not readmitted within 28 days of discharge (any later ipt admission of the same hn) as the denominator; the numerator is those with such a readmission. The PDF denominator is the previous month discharge cohort and counts unplanned readmissions only (elective and planned returns excluded); HOSxP has no planned readmission flag and this branch buckets both counts by the discharge month of the craniotomy episode. Owner must confirm the craniotomy icd9 list and the unplanned convention.',
  DN0303:
    'Counts intracranial injury admissions (Pdx S06, age 18 or over) that had at least one craniotomy (iptoprt icd9 012 to 016) over all such admissions. The PDF numerator is the number of craniotomy operations (multiple operations per patient each count) while one episode is counted once here, per the one row per episode grain. Owner must confirm the craniotomy icd9 list and whether operation counts are needed (they can be staged into reporting.thip_external_facts).',
  DR0103:
    'Counts pneumonia admissions of smokers (secondary diagnosis F17 or Z720, or opdscreen smoking_type_id 2 or 3) with documented cessation advice (Z716 secondary diagnosis, opdscreen advice flags or advice note text, or an opdscreen_advice item naming tobacco) over all smoking pneumonia admissions. The PDF needs advice documented for every smoker with pneumonia and lists no age limit; documentation evidence quality is local. Owner must confirm the smoking and advice mappings.',
  CE0104:
    'Visit-grain branch over adult ER visits (opd_periodized with enter_er_time present) diagnosed with severe sepsis or septic shock (Pdx or secondary diagnosis A400, A409, A410, A419, R572, R651); numerator is visits whose er_regist antibiotics_datetime lies between doctor_tx_time and one hour after it. The PDF times antibiotics from the sepsis diagnosis moment; doctor_tx_time (first doctor contact) is the closest stored proxy and the sepsis criteria (SIRS plus organ dysfunction) are approximated by the diagnosis codes. Owner must confirm the diagnosis time convention and the antibiotic timestamp semantics.',
  DE1401:
    'Counts UGIH admissions (Pdx K250 to K286, K290, K920, K921, K922 families) with an upper endoscopy (iptoprt icd9 4513 to 4516) performed within 24 hours of the admit timestamp (opdate and optime). The PDF times from admission or symptom onset to esophagogastroduodenoscopy; the local EGD icd9 coding and whether optime is maintained need owner confirmation.',
  DE1402:
    'High risk UGIH branch: same cohort plus a high risk flag (age 60 or over, or comorbidity secondary diagnosis N18, K74, I50, I25, J43, J44, or a hemoglobin lab result of 8 or lower from lab_order, lab_head and lab_items with a safe numeric cast of lab_order_result), denominator restricted to live discharges, numerator with EGD within 24 hours as in DE1401. The PDF high risk list also includes fresh blood from a nasogastric tube, shock signs and a 2 g per dl hemoglobin drop, which are not structured, and the hemoglobin threshold assumes the site stores grams per dl. Owner must confirm the high risk definition mapping and the lab unit.',
  DE1403:
    'Non-variceal UGIH (Pdx K250 to K286 and K290 families) with endoscopic hemostasis (EGD plus a hemostasis adjunct: hemoclip, heater probe, bipolar or argon coagulation, band ligation or histoacryl evidenced by iptoprt oper_note_text, or an adrenaline, epinephrine, histoacryl or thrombin item in opitemrece) as the denominator; numerator excludes cases with early rebleeding evidence (repeat upper endoscopy from admission day 2 onward or a red cell transfusion after admission). The PDF success judgement comes from the endoscopy report (Forrest class, visible vessel, successful hemostasis), which HOSxP does not store. Owner must confirm how hemostasis modalities are charted or load the endoscopy registry aggregates into reporting.thip_external_facts.',
  DE1404:
    'Rebleeding rate after endoscopic hemostasis: non-variceal UGIH with endoscopic hemostasis (as in DE1403) as the denominator and rebleeding evidence (repeat upper endoscopy from admission day 2 onward or red cell transfusion after admission) as the numerator. The PDF defines rebleeding by hematemesis or melena with shock or a hemoglobin drop after initial hemostasis success; those events are not structured so the proxy may over count (transfusions given for initial resuscitation) or under count (rebleeding managed without repeat endoscopy). Owner must confirm the rebleeding evidence convention.',
  DE1405:
    'Complication rate of upper endoscopy for UGIH: UGIH admissions with an EGD as the denominator and a procedural complication secondary diagnosis (T810 to T819 family, K631 perforation of intestine, or J690 aspiration pneumonitis) during the stay as the numerator. The PDF lists perforation, bleeding, sedation complications and aspiration within the endoscopy episode; HOSxP relies on the coder adding the complication diagnosis. Owner must confirm the complication code list and the observation window.',
};
