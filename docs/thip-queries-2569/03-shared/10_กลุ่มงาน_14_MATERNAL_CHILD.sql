-- ==============================================================================
-- #5.14 กลุ่มงาน MATERNAL_CHILD - ชุดย่อยของ #1
-- ผลลัพธ์จริงรายงวดสำหรับตัวชี้วัด THIP กลุ่ม MATERNAL_CHILD จาก HOSxP
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
        'CM0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died AND (
          LEFT(pdx, 3) BETWEEN 'O00' AND 'O95'
          OR LEFT(pdx, 3) IN ('O98', 'O99')
        )
      ) AS numerator,
        NULLIF((
        SELECT COUNT(*)
        FROM ipt nb
        JOIN an_stat nbs ON nbs.an = nb.an
        WHERE nb.dchdate >= (SELECT fy_start FROM thip_params)
          AND nb.dchdate < (SELECT fy_end FROM thip_params)
          AND (LEFT(REPLACE(UPPER(TRIM(nbs.pdx)), '.', ''), 3) = 'Z38' OR nbs.age_y = 0)
      ), 0) AS denominator,
        ROUND(
        (COUNT(*) FILTER (WHERE died AND (LEFT(pdx, 3) BETWEEN 'O00' AND 'O95' OR LEFT(pdx, 3) IN ('O98', 'O99')))) * 100000.0 /
        NULLIF((SELECT COUNT(*) FROM ipt nb JOIN an_stat nbs ON nbs.an = nb.an WHERE nb.dchdate >= (SELECT fy_start FROM thip_params) AND nb.dchdate < (SELECT fy_end FROM thip_params) AND (LEFT(REPLACE(UPPER(TRIM(nbs.pdx)), '.', ''), 3) = 'Z38' OR nbs.age_y = 0)), 0),
        2
      ) AS value
      FROM periodized
      WHERE LEFT(pdx, 1) = 'O'
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0104' AS indicator_code,
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
      WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'O72'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O72'
           )
           OR EXISTS (
              SELECT 1 FROM labor lb
              WHERE lb.an = periodized.an
                AND COALESCE(lb.placenta_bloodloss, 0) >= 500
            )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE LEFT(pdx, 3) = 'O72' OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O72') OR EXISTS (SELECT 1 FROM labor lb WHERE lb.an = periodized.an AND COALESCE(lb.placenta_bloodloss, 0) >= 500)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) IN ('O80', 'O81', 'O83') OR pdx IN ('O840', 'O841', 'O848', 'O849'))
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0109' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'O15'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O15'
           )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE LEFT(pdx, 3) = 'O15' OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O15')) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 1) = 'O'
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0110' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE pdx = 'O244'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O244'
           )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE pdx = 'O244' OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O244')) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 1) = 'O'
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0116' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
    )
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0117' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T814'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T814'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T814'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T814'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T814'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T814'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
    )
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0118' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AND NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) AS numerator,
        COUNT(*) FILTER (WHERE NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AND NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0119' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE died) * 1000.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE died) * 1000.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0203' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE died) * 1000.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0204' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'P21'
           OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'P21')
           OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar1 <= 7 OR nb.has_asphyxia = 'Y'))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND(
        COUNT(*) FILTER (
          WHERE LEFT(pdx, 3) = 'P21'
             OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'P21')
             OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar1 <= 7 OR nb.has_asphyxia = 'Y'))
        ) * 1000.0 / NULLIF(COUNT(*), 0),
        2
      ) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0205' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE pdx = 'P210'
           OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'P210')
           OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar2 <= 4 OR nb.apgar1 <= 3))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND(
        COUNT(*) FILTER (
          WHERE pdx = 'P210'
             OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'P210')
             OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar2 <= 4 OR nb.apgar1 <= 3))
        ) * 1000.0 / NULLIF(COUNT(*), 0),
        2
      ) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0206' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 2500)
           OR (periodized.bw > 0 AND periodized.bw < 2500)
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 2500) OR (periodized.bw > 0 AND periodized.bw < 2500)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0207' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000)
          OR (periodized.bw > 0 AND periodized.bw < 1000)
        )
      ) AS numerator,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000)
           OR (periodized.bw > 0 AND periodized.bw < 1000)
      ) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died AND (EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000) OR (periodized.bw > 0 AND periodized.bw < 1000))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000) OR (periodized.bw > 0 AND periodized.bw < 1000)), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0208' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499)
          OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)
        )
      ) AS numerator,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499)
           OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)
      ) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died AND (EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'CM0209' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499)
          OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)
        )
      ) AS numerator,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499)
           OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)
      ) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died AND (EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DE1601' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') = '9541'
        )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') = '9541')) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('CM0101', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E21\0E32\0E23\0E14\0E32\0E08\0E32\0E01\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E41\0E25\0E30\002F\0E2B\0E23\0E37\0E2D\0E01\0E32\0E23\0E04\0E25\0E2D\0E14\0020\0028\0E15\0E48\0E2D\0E41\0E2A\0E19\0E17\0E32\0E23\0E01\0E40\0E01\0E34\0E14\0E21\0E35\0E0A\0E35\0E1E\0029', 'Maternal: Mortality rate of mother from pregnancy and/or labour (1:100,000)'), ('CM0104', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0104', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E23\0E31\0E1A\0E01\0E25\0E31\0E1A\0E40\0E02\0E49\0E32\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0020\0043\0061\0065\0073\0061\0072\0065\0061\006E\0020\0073\0065\0063\0074\0069\006F\006E\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19\0020\0E42\0E14\0E22\0020\0E44\0E21\0E48\0E44\0E14\0E49\0E27\0E32\0E07\0E41\0E1C\0E19', 'Maternal: Percent of unplanned re-admission of Caesarean section within 28 days'), ('CM0105', 1, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 2, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 3, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 4, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 5, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 6, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 7, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 8, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 9, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 10, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 11, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0105', 12, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E27\0E31\0E19\0E19\0E2D\0E19\0E40\0E09\0E25\0E35\0E48\0E22\0E02\0E2D\0E07\0E1C\0E39\0E49\0E04\0E25\0E2D\0E14\0E42\0E14\0E22\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E2B\0E19\0E49\0E32\0E17\0E49\0E2D\0E07', 'Maternal: Average length of stay of Caesarean section'), ('CM0107', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0107', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E01\0E40\0E25\0E37\0E2D\0E14\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0E01\0E23\0E13\0E35\0E04\0E25\0E2D\0E14\0E17\0E32\0E07\0E0A\0E48\0E2D\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of Immediate postpartum hemorrhage (vaginal delivery)'), ('CM0109', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0109', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E0A\0E31\0E01\0E02\0E13\0E30\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0020\0E04\0E25\0E2D\0E14\0E2B\0E23\0E37\0E2D\0E2B\0E25\0E31\0E07\0E04\0E25\0E2D\0E14', 'Maternal: Percent of eclampsia in pregnancy induce hypertension'), ('CM0110', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0110', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E2B\0E0D\0E34\0E07\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E17\0E35\0E48\0E21\0E35\0E20\0E32\0E27\0E30\0E40\0E1A\0E32\0E2B\0E27\0E32\0E19', 'Maternal: Percent of gestational DM'), ('CM0116', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0116', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0070\0072\006F\0070\0068\0079\006C\0061\0063\0074\0069\0063\0020\0061\006E\0074\0069\0062\0069\006F\0074\0069\0063\0020\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0061\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of receiving antibiotic prophylaxis in abdominal hysterectomy'), ('CM0117', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0117', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0041\0062\0064\006F\006D\0069\006E\0061\006C\0020\0068\0079\0073\0074\0065\0072\0065\0063\0074\006F\006D\0079', 'Maternal: Percent of abdominal hysterectomy associated infection'), ('CM0118', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0118', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E1B\0E10\0E21\0E20\0E39\0E21\0E34\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of primary cesarean section'), ('CM0119', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0119', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0E04\0E25\0E2D\0E14\0E1A\0E38\0E15\0E23\0E17\0E31\0E49\0E07\0E2B\0E21\0E14\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Maternal: Percent of overall cesarean section'), ('CM0201', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0201', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0034\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (24 weeks)'), ('CM0202', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0202', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E1B\0E23\0E34\0E01\0E33\0E40\0E19\0E34\0E14\0020\0028\0E2D\0E32\0E22\0E38\0E04\0E23\0E23\0E20\0E4C\0E15\0E31\0E49\0E07\0E41\0E15\0E48\0020\0032\0038\0020\0E2A\0E31\0E1B\0E14\0E32\0E2B\0E4C\0029', 'Child: Perinatal mortality rate (28 weeks)'), ('CM0203', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0203', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E32\0E22\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Neonatal mortality rate'), ('CM0204', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0204', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Birth asphyxia rate'), ('CM0205', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0205', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E02\0E32\0E14\0E2D\0E2D\0E01\0E0B\0E34\0E40\0E08\0E19\0E23\0E38\0E19\0E41\0E23\0E07\0E43\0E19\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14', 'Child: Severe birth asphyxia rate'), ('CM0206', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0206', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0032\002C\0035\0030\0030\0020\0E01\0E23\0E31\0E21', 'Child: Percent of low birth weight < 2500 grams'), ('CM0207', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0207', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0E15\0E48\0E33\0E01\0E27\0E48\0E32\0020\0031\002C\0030\0030\0030\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days'), ('CM0208', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0208', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0030\0030\0030\002D\0031\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days'), ('CM0209', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('CM0209', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E19\0E49\0E33\0E2B\0E19\0E31\0E01\0020\0031\002C\0035\0030\0030\0020\002D\0020\0032\002C\0034\0039\0039\0020\0E01\0E23\0E31\0E21\0E20\0E32\0E22\0E43\0E19\0020\0032\0038\0020\0E27\0E31\0E19', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days'), ('DE1601', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E04\0E31\0E14\0E01\0E23\0E2D\0E07\0E01\0E32\0E23\0E44\0E14\0E49\0E22\0E34\0E19\0020\0E20\0E32\0E22\0E43\0E19\0020\0033\0030\0020\0E27\0E31\0E19', 'Newborn: Percent of hearing screening within 30 days')
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
