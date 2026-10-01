-- ==============================================================================
-- #5.12 กลุ่มงาน CABG - ชุดย่อยของ #1
-- ผลลัพธ์จริงรายงวดสำหรับตัวชี้วัด THIP กลุ่ม CABG จาก HOSxP
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
        'DH0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DH0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
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
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DH0203' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
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
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T814', 'T826', 'T827')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
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
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T814', 'T826', 'T827')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY 2, 3, 4

      UNION ALL

      SELECT
        'DH0204' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died OR EXISTS (
          SELECT 1
          FROM death d
          WHERE (d.an = periodized.an OR d.hn = periodized.hn)
            AND d.death_date IS NOT NULL
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '30 days'
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (
        WHERE died OR EXISTS (
          SELECT 1
          FROM death d
          WHERE (d.an = periodized.an OR d.hn = periodized.hn)
            AND d.death_date IS NOT NULL
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '30 days'
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        )
      ) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DH0201', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0201', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of mortality'), ('DH0202', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0202', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E1B\0E0F\0E34\0E0A\0E35\0E27\0E19\0E30\0E41\0E1A\0E1A\0E1B\0E49\0E2D\0E07\0E01\0E31\0E19\0E43\0E19\0E01\0E32\0E23\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis'), ('DH0203', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0203', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E41\0E1C\0E25\0E1C\0E48\0E32\0E15\0E31\0E14\0020\0043\006F\0072\006F\006E\0061\0072\0079\0020\0041\0072\0074\0065\0072\0079\0020\0042\0079\0070\0061\0073\0073\0020\0047\0072\0061\0066\0074\0020\0028\0043\0041\0042\0047\0029', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection'), ('DH0204', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality'), ('DH0204', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E17\0E33\0043\0041\0042\0047\0020\0E20\0E32\0E22\0E43\0E19\0033\0030\0020\0E27\0E31\0E19\0E2B\0E25\0E31\0E07\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E41\0E1A\0E1A\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E27\0E31\0E19\0E41\0E23\0E01', 'Coronary Artery Bypass Graft (CABG): percent of 30 - day hospital mortality')
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
