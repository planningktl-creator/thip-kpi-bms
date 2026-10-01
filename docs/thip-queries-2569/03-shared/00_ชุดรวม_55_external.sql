-- ==============================================================================
-- #3.3 ชุดรวม 55 รหัสภายนอก (อ่าน reporting.thip_external_facts)
-- ที่มา: queryRegistry.thipExternalFoundation - ต้องโหลดข้อมูลเข้า staging ก่อน
-- ==============================================================================

WITH thip_params AS (
        SELECT
          v.fiscal_year,
          -- ปีงบประมาณไทยเริ่ม 1 ต.ค.:  พ.ศ. Y -> 1 ต.ค. ค.ศ. (Y-544)
          make_date(v.fiscal_year - 544, 10, 1) AS fy_start,
          -- 1 ต.ค. ของปีถัดไป = ขอบเขตบนแบบไม่รวม (exclusive) คือวันสุดท้าย 30 ก.ย. (Y-543)
          make_date(v.fiscal_year - 543, 10, 1) AS fy_end
        FROM (VALUES (2569)) AS v(fiscal_year)
      ),
      ipd AS (
    SELECT
      i.an,
      i.hn,
      i.regdate,
      i.regtime,
      i.dchdate,
      COALESCE(i.bw, 0) AS bw,
      s.age_y,
      s.los,
      REPLACE(UPPER(TRIM(s.pdx)), '.', '') AS pdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
      ) AS died,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
      ) AS has_acs_sdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_cause)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_1)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_2)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_3)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_4)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
          )
      ) AS died_from_acs,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
      ) AS has_stemi_sdx,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I214', 'I219')
      ) AS has_nste_sdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND d.death_date IS NOT NULL
          AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
            (i.regdate + COALESCE(i.regtime, TIME '00:00:00'))
          AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
            (i.regdate + COALESCE(i.regtime, TIME '00:00:00')) + INTERVAL '48 hours'
      ) AS died_within_48h,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_cause)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_1)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_2)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_3)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_4)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
          )
      ) AS died_from_stemi,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_cause)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_1)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_2)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_3)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_4)), '.', '') IN ('I214', 'I219')
          )
      ) AS died_from_nste,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
          )
      ) AS has_pneumonia_sdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            LEFT(REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_cause)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_cause)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_1)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_1)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_2)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_2)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_3)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_3)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_4)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_4)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
          )
      ) AS died_from_pneumonia,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A400', 'A419', 'R572', 'R651')
      ) AS has_ce0101_sepsis,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651')
      ) AS has_ci0101_sepsis
    FROM ipt i
    JOIN an_stat s ON s.an = i.an
    WHERE i.dchdate >= (SELECT fy_start FROM thip_params)
      AND i.dchdate < (SELECT fy_end FROM thip_params)
      AND i.regdate IS NOT NULL
      AND EXTRACT(EPOCH FROM (
        (i.dchdate + COALESCE(i.dchtime, TIME '23:59:59')) -
        (i.regdate + COALESCE(i.regtime, TIME '00:00:00'))
      )) >= 14400
  ),
  periodized AS (
    SELECT
      *,
      DATE_TRUNC('month', dchdate)::date AS period_start,
      EXTRACT(MONTH FROM dchdate)::integer AS calendar_month
    FROM ipd
  ),
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
    WHERE v.vstdate >= (SELECT fy_start FROM thip_params)
      AND v.vstdate < (SELECT fy_end FROM thip_params)
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
    WHERE cm.regdate >= (SELECT fy_start FROM thip_params)
      AND cm.regdate < (SELECT fy_end FROM thip_params)
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
    WHERE COALESCE(l.labour_startdate, i.regdate) >= (SELECT fy_start FROM thip_params)
      AND COALESCE(l.labour_startdate, i.regdate) < (SELECT fy_end FROM thip_params)
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
    WHERE nb.born_date >= (SELECT fy_start FROM thip_params)
      AND nb.born_date < (SELECT fy_end FROM thip_params)
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
    WHERE e.emp_work_begindate >= (SELECT fy_start FROM thip_params)
      AND e.emp_work_begindate < (SELECT fy_end FROM thip_params)
  ),
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
    WHERE x.period_start >= (SELECT fy_start FROM thip_params)
      AND x.period_start < (SELECT fy_end FROM thip_params)
  ),
      facts AS (
      
      SELECT
        'CG0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'CG0103'

      UNION ALL

      SELECT
        'CG0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'CG0104'

      UNION ALL

      SELECT
        'DE1301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1301'

      UNION ALL

      SELECT
        'DE1302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1302'

      UNION ALL

      SELECT
        'DE1303' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1303'

      UNION ALL

      SELECT
        'DE1304' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1304'

      UNION ALL

      SELECT
        'DE1305' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1305'

      UNION ALL

      SELECT
        'DE1306' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1306'

      UNION ALL

      SELECT
        'DE1601' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1601'

      UNION ALL

      SELECT
        'DM0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0103'

      UNION ALL

      SELECT
        'DM0203' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0203'

      UNION ALL

      SELECT
        'DM0401' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0401'

      UNION ALL

      SELECT
        'DM0402' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0402'

      UNION ALL

      SELECT
        'DS0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DS0101'

      UNION ALL

      SELECT
        'DS0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DS0201'

      UNION ALL

      SELECT
        'DS0301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DS0301'

      UNION ALL

      SELECT
        'SC0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0101'

      UNION ALL

      SELECT
        'SC0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0102'

      UNION ALL

      SELECT
        'SC0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0103'

      UNION ALL

      SELECT
        'SC0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0104'

      UNION ALL

      SELECT
        'SC0105' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0105'

      UNION ALL

      SELECT
        'SC0106' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0106'

      UNION ALL

      SELECT
        'SF0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0101'

      UNION ALL

      SELECT
        'SF0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0102'

      UNION ALL

      SELECT
        'SF0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0103'

      UNION ALL

      SELECT
        'SF0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0104'

      UNION ALL

      SELECT
        'SF0105' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0105'

      UNION ALL

      SELECT
        'SF0106' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0106'

      UNION ALL

      SELECT
        'SG0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SG0104'

      UNION ALL

      SELECT
        'SH0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0201'

      UNION ALL

      SELECT
        'SH0202' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0202'

      UNION ALL

      SELECT
        'SH0203' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0203'

      UNION ALL

      SELECT
        'SH0204' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0204'

      UNION ALL

      SELECT
        'SH0205' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0205'

      UNION ALL

      SELECT
        'SH0206' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0206'

      UNION ALL

      SELECT
        'SH0207' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0207'

      UNION ALL

      SELECT
        'SH0208' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0208'

      UNION ALL

      SELECT
        'SH0209' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0209'

      UNION ALL

      SELECT
        'SH0210' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0210'

      UNION ALL

      SELECT
        'SH0211' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0211'

      UNION ALL

      SELECT
        'SH0212' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0212'

      UNION ALL

      SELECT
        'SH0213' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0213'

      UNION ALL

      SELECT
        'SH0214' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0214'

      UNION ALL

      SELECT
        'SH0215' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0215'

      UNION ALL

      SELECT
        'SH0216' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0216'

      UNION ALL

      SELECT
        'SI0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0101'

      UNION ALL

      SELECT
        'SI0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0102'

      UNION ALL

      SELECT
        'SI0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0103'

      UNION ALL

      SELECT
        'SI0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0201'

      UNION ALL

      SELECT
        'SI0202' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0202'

      UNION ALL

      SELECT
        'SI0203' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0203'

      UNION ALL

      SELECT
        'SI0301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0301'

      UNION ALL

      SELECT
        'SI0302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0302'

      UNION ALL

      SELECT
        'SI0303' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0303'

      UNION ALL

      SELECT
        'SS0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SS0101'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('CG0103', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury'), ('CG0103', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury'), ('CG0103', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury'), ('CG0103', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury'), ('CG0104', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate'), ('CG0104', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate'), ('CG0104', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate'), ('CG0104', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate'), ('DE1301', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E2A\0E14\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0033\0034\0020\0E1B\0E35\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age < 34 years)'), ('DE1302', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E2A\0E14\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0033\0034\0020\002D\0020\0033\0039\0020\0E1B\0E35\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age 34 - 39 Years)'), ('DE1303', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E2A\0E14\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age > 40 years)'), ('DE1304', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0033\0034\0020\0E1B\0E35\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years)'), ('DE1305', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0033\0034\0020\002D\0020\0033\0039\0020\0E1B\0E35\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age 34 - 39 years)'), ('DE1306', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'), ('DE1601', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E04\0E31\0E14\0E01\0E23\0E2D\0E07\0E01\0E32\0E23\0E44\0E14\0E49\0E22\0E34\0E19\0020\0E20\0E32\0E22\0E43\0E19\0020\0033\0030\0020\0E27\0E31\0E19', 'Newborn: Percent of hearing screening within 30 days'), ('DM0103', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E40\0E14\0E47\0E01\0E1E\0E31\0E12\0E19\0E32\0E01\0E32\0E23\0E25\0E48\0E32\0E0A\0E49\0E32\0E23\0E2D\0E1A\0E14\0E49\0E32\0E19\0020\0028\0047\006C\006F\0062\0061\006C\0020\0064\0065\0076\0065\006C\006F\0070\006D\0065\006E\0074\0020\0064\0065\006C\0061\0079\003A\0020\0047\0044\0044\0029\0020\0E04\0E07\0E2D\0E22\0E39\0E48\0E43\0E19\0020\0E23\0E30\0E1A\0E1A\0E01\0E32\0E23\0E28\0E36\0E01\0E29\0E32\0E44\0E14\0E49\0E2D\0E22\0E48\0E32\0E07\0E19\0E49\0E2D\0E22\0020\0031\0020\0E1B\0E35', 'GDD: Percent of children with Global development delay that are included in educational system for at least 1 year'), ('DM0203', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E40\0E14\0E47\0E01\0E2D\0E2D\0E17\0E34\0E2A\0E15\0E34\0E01\0E04\0E07\0E2D\0E22\0E39\0E48\0E43\0E19\0E23\0E30\0E1A\0E1A\0E01\0E32\0E23\0E28\0E36\0E01\0E29\0E32\0E44\0E14\0E49\0E2D\0E22\0E48\0E32\0E07\0E19\0E49\0E2D\0E22\0020\0031\0020\0E1B\0E35', 'ASD: Percent of children with Autism spectrum disorder (ASD) that are included in educational system for at least 1 year'), ('DM0401', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E14\0E47\0E01\0E2A\0E21\0E32\0E18\0E34\0E2A\0E31\0E49\0E19\0E23\0E32\0E22\0E43\0E2B\0E21\0E48\0E2D\0E32\0E01\0E32\0E23\0E14\0E35\0E02\0E36\0E49\0E19\0E20\0E32\0E22\0E43\0E19\0020\0036\0020\0E40\0E14\0E37\0E2D\0E19', 'Child and adolescent psychiatry: Percent of children with Attention-Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6 months'), ('DM0401', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E14\0E47\0E01\0E2A\0E21\0E32\0E18\0E34\0E2A\0E31\0E49\0E19\0E23\0E32\0E22\0E43\0E2B\0E21\0E48\0E2D\0E32\0E01\0E32\0E23\0E14\0E35\0E02\0E36\0E49\0E19\0E20\0E32\0E22\0E43\0E19\0020\0036\0020\0E40\0E14\0E37\0E2D\0E19', 'Child and adolescent psychiatry: Percent of children with Attention-Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6 months'), ('DM0402', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E14\0E47\0E01\0E0B\0E36\0E21\0E40\0E28\0E23\0E49\0E32\0E2D\0E32\0E01\0E32\0E23\0E14\0E35\0E02\0E36\0E49\0E19\0E20\0E32\0E22\0E43\0E19\0020\0036\0020\0E40\0E14\0E37\0E2D\0E19', 'Child and adolescent psychiatry: Percent of children and adolescents with Major depressive disorder (MDD) improved after intervented for 6 months'), ('DM0402', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E14\0E47\0E01\0E0B\0E36\0E21\0E40\0E28\0E23\0E49\0E32\0E2D\0E32\0E01\0E32\0E23\0E14\0E35\0E02\0E36\0E49\0E19\0E20\0E32\0E22\0E43\0E19\0020\0036\0020\0E40\0E14\0E37\0E2D\0E19', 'Child and adolescent psychiatry: Percent of children and adolescents with Major depressive disorder (MDD) improved after intervented for 6 months'), ('DS0101', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate'), ('DS0101', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate'), ('DS0101', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate'), ('DS0101', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate'), ('DS0201', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E2A\0E38\0E23\0E32\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Alcohol group: 3 months total remission rate'), ('DS0201', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E2A\0E38\0E23\0E32\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Alcohol group: 3 months total remission rate'), ('DS0201', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E2A\0E38\0E23\0E32\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Alcohol group: 3 months total remission rate'), ('DS0201', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E2A\0E38\0E23\0E32\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Alcohol group: 3 months total remission rate'), ('DS0301', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E2A\0E39\0E1A\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Tobacco group: 3 months total remission rate'), ('DS0301', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E2A\0E39\0E1A\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Tobacco group: 3 months total remission rate'), ('DS0301', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E2A\0E39\0E1A\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Tobacco group: 3 months total remission rate'), ('DS0301', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E2A\0E39\0E1A\0E42\0E14\0E22\0E23\0E27\0E21\0020\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Tobacco group: 3 months total remission rate'), ('SC0101', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'Customer: Percent of outpatient satisfaction (overall)'), ('SC0101', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'Customer: Percent of outpatient satisfaction (overall)'), ('SC0102', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'Customer: Percent of inpatient satisfaction (overall)'), ('SC0102', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'Customer: Percent of inpatient satisfaction (overall)'), ('SC0103', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0E17\0E35\0E48\0E08\0E30\0E01\0E25\0E31\0E1A\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23\0E0B\0E49\0E33', 'Customer: Percent of outpatients who return to receive care'), ('SC0103', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0E17\0E35\0E48\0E08\0E30\0E01\0E25\0E31\0E1A\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23\0E0B\0E49\0E33', 'Customer: Percent of outpatients who return to receive care'), ('SC0104', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E17\0E35\0E48\0E08\0E30\0E01\0E25\0E31\0E1A\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23\0E0B\0E49\0E33', 'Customer: Percent of inpatients who return to receive care'), ('SC0104', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E17\0E35\0E48\0E08\0E30\0E01\0E25\0E31\0E1A\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23\0E0B\0E49\0E33', 'Customer: Percent of inpatients who return to receive care'), ('SC0105', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0E17\0E35\0E48\0E08\0E30\0E41\0E19\0E30\0E19\0E33\0E0D\0E32\0E15\0E34\0E2B\0E23\0E37\0E2D\0E04\0E19\0E23\0E39\0E49\0E08\0E31\0E01\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23', 'Customer: Percent of outpatients who would recommend friends or family to receive care at this facility'), ('SC0105', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0E17\0E35\0E48\0E08\0E30\0E41\0E19\0E30\0E19\0E33\0E0D\0E32\0E15\0E34\0E2B\0E23\0E37\0E2D\0E04\0E19\0E23\0E39\0E49\0E08\0E31\0E01\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23', 'Customer: Percent of outpatients who would recommend friends or family to receive care at this facility'), ('SC0106', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E17\0E35\0E48\0E08\0E30\0E41\0E19\0E30\0E19\0E33\0E0D\0E32\0E15\0E34\0E2B\0E23\0E37\0E2D\0E04\0E19\0E23\0E39\0E49\0E08\0E31\0E01\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23', 'Customer: Percent of inpatients who would recommend friends or family to receive care at this facility'), ('SC0106', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E17\0E35\0E48\0E08\0E30\0E41\0E19\0E30\0E19\0E33\0E0D\0E32\0E15\0E34\0E2B\0E23\0E37\0E2D\0E04\0E19\0E23\0E39\0E49\0E08\0E31\0E01\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23', 'Customer: Percent of inpatients who would recommend friends or family to receive care at this facility'), ('SF0101', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E2A\0E48\0E27\0E19\0E17\0E38\0E19\0E2B\0E21\0E38\0E19\0E40\0E27\0E35\0E22\0E19', 'Financial: Current ratio'), ('SF0102', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E2A\0E48\0E27\0E19\0E17\0E38\0E19\0E2B\0E21\0E38\0E19\0E40\0E27\0E35\0E22\0E19\0E40\0E23\0E47\0E27\0020\0028\0E2D\0E31\0E15\0E23\0E32\0E2A\0E48\0E27\0E19\0E2A\0E34\0E19\0E17\0E23\0E31\0E1E\0E22\0E4C\0E2A\0E20\0E32\0E1E\0E04\0E25\0E48\0E2D\0E07\0029', 'Financial: Quick ratio'), ('SF0103', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E21\0E38\0E19\0E40\0E27\0E35\0E22\0E19\0E02\0E2D\0E07\0E2A\0E34\0E19\0E17\0E23\0E31\0E1E\0E22\0E4C\0E16\0E32\0E27\0E23', 'Financial: Fixed asset turnover'), ('SF0104', 1, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E16\0E31\0E27\0E40\0E09\0E25\0E35\0E48\0E22\0E43\0E19\0E01\0E32\0E23\0E40\0E23\0E35\0E22\0E01\0E40\0E01\0E47\0E1A\0E25\0E39\0E01\0E2B\0E19\0E35\0E49\0E04\0E48\0E32\0E23\0E31\0E01\0E29\0E32\0E2A\0E38\0E17\0E18\0E34', 'Financial: Day in account receivable (average collection period for account receivables)'), ('SF0105', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E2A\0E48\0E27\0E19\0E23\0E30\0E2B\0E27\0E48\0E32\0E07\0E01\0E33\0E44\0E23\0E2A\0E38\0E17\0E18\0E34\0020\0E01\0E31\0E1A\0E22\0E2D\0E14\0E02\0E32\0E22\0E2A\0E38\0E17\0E18\0E34', 'Financial: Net profit margin'), ('SF0106', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E1C\0E25\0E15\0E2D\0E1A\0E41\0E17\0E19\0E08\0E32\0E01\0E2A\0E34\0E19\0E17\0E23\0E31\0E1E\0E22\0E4C\0E23\0E27\0E21', 'Financial: Return on asset (ROA)'), ('SG0104', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 2, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 3, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 4, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 5, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 6, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 7, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 8, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 9, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 10, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 11, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 12, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SH0201', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E41\0E1E\0E17\0E22\0E4C\002F\0E17\0E31\0E19\0E15\0E41\0E1E\0E17\0E22\0E4C\0020\0028\0E23\0E30\0E14\0E31\0E1A\0020\0034\002D\0035\0029', 'HRD: Percent of physician/dentist satisfaction (level 4-5)'), ('SH0202', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0020\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E27\0E34\0E0A\0E32\0E0A\0E35\0E1E\0020\0028\0E23\0E30\0E14\0E31\0E1A\0020\0034\002D\0035\0029', 'HRD: Percent of nurse satisfaction (level 4-5)'), ('SH0203', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0020\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0020\0041\006C\006C\0069\0065\0064\0020\0048\0065\0061\006C\0074\0068\0020\0028\0E23\0E30\0E14\0E31\0E1A\0020\0034\002D\0035\0029', 'HRD: Percent of allied health personel satisfaction (level 4-5)'), ('SH0204', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E0A\0E31\0E48\0E27\0E42\0E21\0E07\0E01\0E32\0E23\0E1D\0E36\0E01\0E2D\0E1A\0E23\0E21\0E15\0E48\0E2D\0E04\0E19\0E15\0E48\0E2D\0E1B\0E35\0E02\0E2D\0E07\0E41\0E1E\0E17\0E22\0E4C\002F\0020\0E17\0E31\0E19\0E15\0E41\0E1E\0E17\0E22\0E4C', 'HRD: Training hour per person per year of physician/dentist'), ('SH0205', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E0A\0E31\0E48\0E27\0E42\0E21\0E07\0E01\0E32\0E23\0E1D\0E36\0E01\0E2D\0E1A\0E23\0E21\0E15\0E48\0E2D\0E04\0E19\0E15\0E48\0E2D\0E1B\0E35\0E02\0E2D\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E27\0E34\0E0A\0E32\0E0A\0E35\0E1E', 'HRD: Training hour per person per year of nurse'), ('SH0206', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E41\0E1E\0E17\0E22\0E4C\002F\0E17\0E31\0E19\0E15\0E41\0E1E\0E17\0E22\0E4C\0020\0028\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0029', 'HRD: Percent of physician/dentist satisfaction (average)'), ('SH0207', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E41\0E1E\0E17\0E22\0E4C\002F\0E17\0E31\0E19\0E15\0E41\0E1E\0E17\0E22\0E4C\0028\0E23\0E30\0E14\0E31\0E1A\0020\0031\002D\0032\0029', 'HRD: Percent of physician/dentist satisfaction (level 1-2)'), ('SH0208', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E27\0E34\0E0A\0E32\0E0A\0E35\0E1E\0020\0028\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0029', 'HRD: Percentage of nurse satisfaction (average)'), ('SH0209', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E27\0E34\0E0A\0E32\0E0A\0E35\0E1E\0020\0028\0E23\0E30\0E14\0E31\0E1A\0020\0031\002D\0032\0029', 'HRD: Percentage of nurse satisfaction (level 1-2)'), ('SH0210', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0020\0061\006C\006C\0069\0065\0064\0020\0068\0065\0061\006C\0074\0068\0020\0028\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0029', 'HRD: Percentage of allied health personel satisfaction (average)'), ('SH0211', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0020\0061\006C\006C\0069\0065\0064\0020\0068\0065\0061\006C\0074\0068\0020\0028\0E23\0E30\0E14\0E31\0E1A\0020\0031\002D\0032\0029', 'HRD: Percentage of allied health personel satisfaction (level 1-2)'), ('SH0212', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19\0028\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0029', 'HRD: Percentage of back office personel satisfaction (average)'), ('SH0213', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19\0020\0028\0E23\0E30\0E14\0E31\0E1A\0020\0034\002D\0035\0029', 'HRD: Percentage of back office personel satisfaction (level 4-5)'), ('SH0214', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19\0020\0028\0E23\0E30\0E14\0E31\0E1A\0020\0031\002D\0032\0029', 'HRD: Percentage of back office personel satisfaction (level 1-2)'), ('SH0215', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E0A\0E31\0E48\0E27\0E42\0E21\0E07\0E01\0E32\0E23\0E1D\0E36\0E01\0E2D\0E1A\0E23\0E21\0E15\0E48\0E2D\0E04\0E19\0E15\0E48\0E2D\0E1B\0E35\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0020\0061\006C\006C\0069\0065\0064\0020\0068\0065\0061\006C\0074\0068', 'HRD: Training hour per person per year of allied health personel'), ('SH0216', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E0A\0E31\0E48\0E27\0E42\0E21\0E07\0E01\0E32\0E23\0E1D\0E36\0E01\0E2D\0E1A\0E23\0E21\0E15\0E48\0E2D\0E04\0E19\0E15\0E48\0E2D\0E1B\0E35\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19', 'HRD: Training hour per person per year of back office personel'), ('SI0101', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0101', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'VAP: Rate of ventilator-associated pneumonia (All)'), ('SI0102', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0102', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'VAP: Rate of ventilator-associated pneumonia in ICU'), ('SI0103', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0103', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E1B\0E2D\0E14\0E2D\0E31\0E01\0E40\0E2A\0E1A\0E08\0E32\0E01\0E01\0E32\0E23\0E43\0E0A\0E49\0E40\0E04\0E23\0E37\0E48\0E2D\0E07\0E0A\0E48\0E27\0E22\0E2B\0E32\0E22\0E43\0E08\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'VAP: Rate of Ventilator-associated pneumonia outside ICU'), ('SI0201', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0202', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0202', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0020\0049\0043\0055', 'BSI: Rate of CABSI in ICU'), ('SI0203', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0203', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0020\0E23\0E31\0E01\0E29\0E32\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'BSI: Rate of CABSI outside ICU'), ('SI0301', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0301', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'CAUTI: Rate of CAUTI (All)'), ('SI0302', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0302', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E43\0E19\0020\0049\0043\0055', 'CAUTI: Rate of CAUTI in ICU'), ('SI0303', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SS0101', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization')
      ), fiscal_periods AS (
        SELECT
          generated.period_start::date AS period_start,
          CASE
            WHEN EXTRACT(MONTH FROM generated.period_start) >= 10
              THEN EXTRACT(MONTH FROM generated.period_start)::integer - 9
            ELSE EXTRACT(MONTH FROM generated.period_start)::integer + 3
          END AS fiscal_month,
          CASE
            WHEN EXTRACT(MONTH FROM generated.period_start) >= 10
              THEN EXTRACT(YEAR FROM generated.period_start)::integer + 1
            ELSE EXTRACT(YEAR FROM generated.period_start)::integer
          END AS fiscal_year
        FROM generate_series(
          CAST((SELECT fy_start FROM thip_params) AS date),
          CAST((SELECT fy_end FROM thip_params) AS date) - INTERVAL '1 month',
          INTERVAL '1 month'
        ) AS generated(period_start)
      )
      SELECT
        expected_codes.indicator_code,
        expected_codes.indicator_name_th AS indicator_name_th,
        expected_codes.indicator_name_en AS indicator_name_en,
        fiscal_periods.period_start,
        fiscal_periods.fiscal_month,
        fiscal_periods.fiscal_year,
        facts.numerator,
        facts.denominator,
        facts.value
      FROM expected_codes
      JOIN fiscal_periods
        ON fiscal_periods.fiscal_month = expected_codes.fiscal_month
      LEFT JOIN facts
        ON facts.indicator_code = expected_codes.indicator_code
       AND facts.period_start = fiscal_periods.period_start
       AND facts.fiscal_month = fiscal_periods.fiscal_month
       AND facts.fiscal_year = fiscal_periods.fiscal_year
      ORDER BY expected_codes.indicator_code, fiscal_periods.period_start
