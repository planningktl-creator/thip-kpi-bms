-- ==============================================================================
-- #5.16 กลุ่มงาน DM_HT - ชุดย่อยของ #1
-- ผลลัพธ์จริงรายงวดสำหรับตัวชี้วัด THIP กลุ่ม DM_HT จาก HOSxP
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
        'DC0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.hn) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('9502', '9503', '9512')
        )
        OR EXISTS (
          SELECT 1 FROM ovstdiag od
          JOIN ovst ov ON ov.vn = od.vn
          WHERE ov.hn = periodized.hn
            AND REPLACE(UPPER(TRIM(od.icd10)), '.', '') IN ('Z010', 'Z135')
            AND ov.vstdate >= (SELECT fy_start FROM thip_params) AND ov.vstdate < (SELECT fy_end FROM thip_params)
        )
      ) AS numerator,
        COUNT(DISTINCT periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('9502', '9503', '9512')) OR EXISTS (SELECT 1 FROM ovstdiag od JOIN ovst ov ON ov.vn = od.vn WHERE ov.hn = periodized.hn AND REPLACE(UPPER(TRIM(od.icd10)), '.', '') IN ('Z010', 'Z135') AND ov.vstdate >= (SELECT fy_start FROM thip_params) AND ov.vstdate < (SELECT fy_end FROM thip_params))) * 100.0) / NULLIF(COUNT(DISTINCT periodized.hn), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DC0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8410', '8411', '8412', '8413', '8414', '8415', '8416', '8417', '8418', '8419')
        )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8410', '8411', '8412', '8413', '8414', '8415', '8416', '8417', '8418', '8419'))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DC0108' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE ((age_y < 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0))
            OR (age_y >= 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE ((age_y < 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0)) OR (age_y >= 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DC0108.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 60 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DC0108.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND age_y < 60 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DC0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE ((age_y < 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80))
            OR (age_y >= 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE ((age_y < 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80)) OR (age_y >= 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DC0201.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND age_y < 65 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DC0201.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 65 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DP0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= (SELECT fy_start FROM thip_params) AND lh.order_date < (SELECT fy_end FROM thip_params)
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END < 7.5
        )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM lab_order lo JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number JOIN lab_items li ON li.lab_items_code = lo.lab_items_code WHERE lh.hn = periodized.hn AND li.lab_items_name ILIKE '%hba1c%' AND lh.order_date >= (SELECT fy_start FROM thip_params) AND lh.order_date < (SELECT fy_end FROM thip_params) AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END < 7.5)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y < 18 AND (LEFT(pdx, 3) = 'E10' OR pdx IN ('E891', 'P702'))
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'AA0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) AS numerator,
        NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0) AS denominator,
        ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('E100', 'E101', 'E106', 'E109', 'E110', 'E111', 'E116', 'E119', 'E130', 'E131', 'E136', 'E139', 'E140', 'E141', 'E146', 'E149')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'AA0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) AS numerator,
        NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0) AS denominator,
        ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('I10', 'I110', 'I119')
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DC0103', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E04\0E31\0E14\0E01\0E23\0E2D\0E07\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E40\0E02\0E49\0E32\0E08\0E2D\0E1B\0E23\0E30\0E2A\0E32\0E17\0E15\0E32', 'DM: Percent of diabetic retinopathy screening'), ('DC0107', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0107', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E31\0E14\0E02\0E32\0E08\0E32\0E01\0E20\0E32\0E27\0E30\0E41\0E17\0E23\0E01\0E0B\0E49\0E2D\0E19\0E02\0E2D\0E07\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'DM: Percent of lower-extremity amputation among patients with diabetes'), ('DC0108', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E1C\0E39\0E49\0E43\0E2B\0E0D\0E48\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E23\0E30\0E14\0E31\0E1A\0E19\0E49\0E33\0E15\0E32\0E25\0E43\0E19\0E40\0E25\0E37\0E2D\0E14\0E44\0E14\0E49\0E14\0E35', 'DM: Percent of good controlled of blood sugar in adult'), ('DC0108', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E1C\0E39\0E49\0E43\0E2B\0E0D\0E48\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E23\0E30\0E14\0E31\0E1A\0E19\0E49\0E33\0E15\0E32\0E25\0E43\0E19\0E40\0E25\0E37\0E2D\0E14\0E44\0E14\0E49\0E14\0E35', 'DM: Percent of good controlled of blood sugar in adult'), ('DC0108.1', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E1C\0E39\0E49\0E43\0E2B\0E0D\0E48\0E2D\0E32\0E22\0E38\0E40\0E01\0E34\0E19\0E01\0E27\0E48\0E32\0020\0036\0030\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E23\0E30\0E14\0E31\0E1A\0E19\0E49\0E33\0E15\0E32\0E25\0E43\0E19\0E40\0E25\0E37\0E2D\0E14\0E44\0E14\0E49\0E14\0E35', U&'\0044\004D\003A\0020\0050\0065\0072\0063\0065\006E\0074\0020\006F\0066\0020\0067\006F\006F\0064\0020\0063\006F\006E\0074\0072\006F\006C\006C\0065\0064\0020\006F\0066\0020\0062\006C\006F\006F\0064\0020\0073\0075\0067\0061\0072\0020\0069\006E\0020\0061\0064\0075\006C\0074\0020\0061\0067\0065\0064\0020>=\0020\0036\0030\0020\0079\0065\0061\0072\0073\0020\006F\006C\0064'), ('DC0108.1', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E1C\0E39\0E49\0E43\0E2B\0E0D\0E48\0E2D\0E32\0E22\0E38\0E40\0E01\0E34\0E19\0E01\0E27\0E48\0E32\0020\0036\0030\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E23\0E30\0E14\0E31\0E1A\0E19\0E49\0E33\0E15\0E32\0E25\0E43\0E19\0E40\0E25\0E37\0E2D\0E14\0E44\0E14\0E49\0E14\0E35', U&'\0044\004D\003A\0020\0050\0065\0072\0063\0065\006E\0074\0020\006F\0066\0020\0067\006F\006F\0064\0020\0063\006F\006E\0074\0072\006F\006C\006C\0065\0064\0020\006F\0066\0020\0062\006C\006F\006F\0064\0020\0073\0075\0067\0061\0072\0020\0069\006E\0020\0061\0064\0075\006C\0074\0020\0061\0067\0065\0064\0020>=\0020\0036\0030\0020\0079\0065\0061\0072\0073\0020\006F\006C\0064'), ('DC0108.2', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E1C\0E39\0E49\0E43\0E2B\0E0D\0E48\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0036\0030\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E23\0E30\0E14\0E31\0E1A\0E19\0E49\0E33\0E15\0E32\0E25\0E43\0E19\0E40\0E25\0E37\0E2D\0E14\0E44\0E14\0E49\0E14\0E35', 'DM: Percent of good controlled of blood sugar in adult aged < 60 years old'), ('DC0108.2', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E1C\0E39\0E49\0E43\0E2B\0E0D\0E48\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0036\0030\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E23\0E30\0E14\0E31\0E1A\0E19\0E49\0E33\0E15\0E32\0E25\0E43\0E19\0E40\0E25\0E37\0E2D\0E14\0E44\0E14\0E49\0E14\0E35', 'DM: Percent of good controlled of blood sugar in adult aged < 60 years old'), ('DC0201', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E2A\0E39\0E07\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E44\0E14\0E49\0E14\0E35', 'HT: Percent of good controlled of blood pressure'), ('DC0201', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E2A\0E39\0E07\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E44\0E14\0E49\0E14\0E35', 'HT: Percent of good controlled of blood pressure'), ('DC0201.1', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E2A\0E39\0E07\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0036\0035\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E44\0E14\0E49\0E14\0E35', 'HT: Percent of good controlled of blood pressure of patient aged < 65 years old'), ('DC0201.1', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E2A\0E39\0E07\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0036\0035\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E44\0E14\0E49\0E14\0E35', 'HT: Percent of good controlled of blood pressure of patient aged < 65 years old'), ('DC0201.2', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E2A\0E39\0E07\0E2D\0E32\0E22\0E38\0E40\0E01\0E34\0E19\0E01\0E27\0E48\0E32\0020\0036\0035\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E44\0E14\0E49\0E14\0E35', U&'\0048\0054\003A\0020\0050\0065\0072\0063\0065\006E\0074\0020\006F\0066\0020\0067\006F\006F\0064\0020\0063\006F\006E\0074\0072\006F\006C\006C\0065\0064\0020\006F\0066\0020\0062\006C\006F\006F\0064\0020\0070\0072\0065\0073\0073\0075\0072\0065\0020\006F\0066\0020\0070\0061\0074\0069\0065\006E\0074\0020\0061\0067\0065\0064\0020>=\0020\0036\0035\0020\0079\0065\0061\0072\0073\0020\006F\006C\0064'), ('DC0201.2', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E2A\0E39\0E07\0E2D\0E32\0E22\0E38\0E40\0E01\0E34\0E19\0E01\0E27\0E48\0E32\0020\0036\0035\0020\0E1B\0E35\0020\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0E42\0E25\0E2B\0E34\0E15\0E44\0E14\0E49\0E14\0E35', U&'\0048\0054\003A\0020\0050\0065\0072\0063\0065\006E\0074\0020\006F\0066\0020\0067\006F\006F\0064\0020\0063\006F\006E\0074\0072\006F\006C\006C\0065\0064\0020\006F\0066\0020\0062\006C\006F\006F\0064\0020\0070\0072\0065\0073\0073\0075\0072\0065\0020\006F\0066\0020\0070\0061\0074\0069\0065\006E\0074\0020\0061\0067\0065\0064\0020>=\0020\0036\0035\0020\0079\0065\0061\0072\0073\0020\006F\006C\0064'), ('DP0101', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0E0A\0E19\0E34\0E14\0E17\0E35\0E48\0020\0031\0020\0E43\0E19\0E40\0E14\0E47\0E01\0E41\0E25\0E30\0E27\0E31\0E22\0E23\0E38\0E48\0E19\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0031\0038\0020\0E1B\0E35\0E17\0E35\0E48\0E04\0E27\0E1A\0E04\0E38\0E21\0E23\0E30\0E14\0E31\0E1A\0020\0E19\0E49\0E33\0E15\0E32\0E25\0E44\0E14\0E49\0E14\0E35', 'Diabetes in child and adolescent: Percent of good controlled of blood sugar (age < 18 years)'), ('AA0104', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E19\0E2D\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E14\0E49\0E27\0E22\0E20\0E32\0E27\0E30\0E17\0E35\0E48\0E04\0E27\0E23\0E04\0E27\0E1A\0E04\0E38\0E21\0E14\0E49\0E27\0E22\0E1A\0E23\0E34\0E01\0E32\0E23\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0020\0028\0E42\0E23\0E04\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19\0029', 'Diabetes Mellitus (DM): Hospitalization rate'), ('AA0105', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E19\0E2D\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E14\0E49\0E27\0E22\0E20\0E32\0E27\0E30\0E17\0E35\0E48\0E04\0E27\0E23\0E04\0E27\0E1A\0E04\0E38\0E21\0E14\0E49\0E27\0E22\0E1A\0E23\0E34\0E01\0E32\0E23\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0020\0028\0E42\0E23\0E04\0E04\0E27\0E32\0E21\0E14\0E31\0E19\0020\0E42\0E25\0E2B\0E34\0E15\0E2A\0E39\0E07\0029', 'Hypertension: Hospitalization rate')
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
