-- ==============================================================================
-- #5.02 กลุ่มงาน STROKE - ชุดย่อยของ #1
-- ผลลัพธ์จริงรายงวดสำหรับตัวชี้วัด THIP กลุ่ม STROKE จาก HOSxP
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
      facts AS (
      
      SELECT
        'DN0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DN0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DN0109' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DN0101', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0101', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Percent of mortality'), ('DN0107', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0107', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065\0020\0E14\0E49\0E27\0E22\0E42\0E23\0E04\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E21\0E2D\0E07\0E40\0E14\0E34\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Stroke: Percent of unplanned re-admission of stroke within 28 days'), ('DN0109', 1, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 2, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 3, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 4, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 5, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 6, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 7, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 8, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 9, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 10, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 11, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay'), ('DN0109', 12, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0020\0053\0074\0072\006F\006B\0065', 'Stroke: Average length of stay')
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
        COALESCE(facts.numerator, 0) AS numerator,
        COALESCE(facts.denominator, 0) AS denominator,
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
