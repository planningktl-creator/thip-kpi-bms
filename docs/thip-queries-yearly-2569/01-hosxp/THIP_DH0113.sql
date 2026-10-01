-- ==============================================================================
-- THIP KPI DH0113 - ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น (STEMI) ที่ได้รับ Fibrinolytic agent ภายใน 30 นาทีเมื่อมาถึงโรงพยาบาล  [ผลรายปี - เทียบเป้าทุกปีใน HIS]
-- Acute coronary syndrome (STEMI) : Percent of time to Fibrinolytic administration agents within 30 minutes of arrival
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: HOSxP
-- รอบรายงานตามเอกสาร: ทุกเดือน (รายเดือน) - ไฟล์นี้แสดงผลเป็นรายปีงบประมาณ
-- เป้าหมาย: อ่านจากตาราง kpi_moph ของ HIS ต่อปีงบ (result -> mean -> c -> b -> a)
--   ปีที่แสดง = ทุกปีที่มีการบันทึกตัวเลขเป้าใน kpi_moph (พ.ศ./ค.ศ. normalise อัตโนมัติ)
--   บวกปีงบตั้งต้นของไฟล์ (thip_params) เป็น fallback เมื่อ kpi_moph ยังว่าง
-- ผลการดําเนินงาน: คํานวณเฉพาะข้อมูลของปีงบนั้น ๆ (ไม่สะสมข้ามปี)
-- THIP KPI Dictionary 2025 หน้า 64 - ทิศทาง: higher-is-better
-- สูตร (ตามเอกสาร): (a/b) x100
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en,
--   period_start (1 ต.ค. ของปีงบ), fiscal_year (พ.ศ.), numerator, denominator, value,
--   target (เป้าปีงบจาก kpi_moph), vs_target_pct (ร้อยละเทียบเป้า), status
-- วิธีรัน: แก้ปีงบตั้งต้นที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   (ใช้เป็น fallback เมื่อ kpi_moph ว่าง; ปีที่แสดงจริงมาจาก kpi_moph)
-- ==============================================================================

-- ==============================================================================
-- THIP KPI DH0113 - ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น (STEMI) ที่ได้รับ Fibrinolytic agent ภายใน 30 นาทีเมื่อมาถึงโรงพยาบาล  [ผลรายเดือน]
-- Acute coronary syndrome (STEMI) : Percent of time to Fibrinolytic administration agents within 30 minutes of arrival
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: HOSxP
-- รอบรายงานตามเอกสาร: ทุกเดือน (รายเดือน) - ไฟล์นี้แสดงผลรายเดือน 12 งวด
-- เป้าหมาย: อ่านจากตาราง kpi_moph ของ HIS (ตามปีงบใน thip_params)
-- THIP KPI Dictionary 2025 หน้า 64 - ทิศทาง: higher-is-better
-- สูตร (ตามเอกสาร): (a/b) x100
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year,
--   numerator (จำนวนผลงานเดือน), denominator, value (ร้อยละของเดือน),
--   cum_numerator (จำนวนสะสมปีงบ), cum_denominator, cum_value (ร้อยละสะสมปีงบ),
--   target (เป้าปีงบจาก kpi_moph), vs_target_pct / cum_vs_target_pct (ร้อยละเทียบเป้า), status
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   เป้าถูกอ่านสดจาก kpi_moph ของ HIS - โรงพยาบาลที่ยังไม่บันทึกเป้าจะได้ NULL
-- ==============================================================================

WITH
      thip_params AS (
        SELECT
          v.fiscal_year,
          -- ปีงบประมาณไทยเริ่ม 1 ต.ค.:  พ.ศ. Y -> 1 ต.ค. ค.ศ. (Y-544)
          make_date(v.fiscal_year - 544, 10, 1) AS fy_start,
          -- 1 ต.ค. ของปีถัดไป = ขอบเขตบนแบบไม่รวม (exclusive) คือวันสุดท้าย 30 ก.ย. (Y-543)
          make_date(v.fiscal_year - 543, 10, 1) AS fy_end
        FROM (VALUES (2569)) AS v(fiscal_year)
      ),
      years_raw AS (
        SELECT DISTINCT CASE WHEN m.kpi_moph_year >= 2400 THEN m.kpi_moph_year
                             WHEN m.kpi_moph_year BETWEEN 2000 AND 2399 THEN m.kpi_moph_year + 543
                        END AS fiscal_year
        FROM kpi_moph_guideline g
        JOIN kpi_moph m ON m.kpi_moph_guideline_id = g.kpi_moph_guideline_id
        WHERE UPPER(COALESCE(g.kpi_moph_guideline_name, '')) ~
              ('(^|[^0-9A-Z])' || REGEXP_REPLACE('DH0113', '\.', '\.?', 'g') || '($|[^0-9])')
          AND COALESCE(m.kpi_moph_number_result, m.kpi_moph_number_mean,
                       m.kpi_moph_number_c, m.kpi_moph_number_b,
                       m.kpi_moph_number_a) IS NOT NULL
        UNION
        SELECT (SELECT fiscal_year FROM thip_params)
      ),
      years AS (
        SELECT fiscal_year FROM years_raw WHERE fiscal_year IS NOT NULL
      ),
      yspan AS (
        SELECT MIN(make_date(fiscal_year - 544, 10, 1)) AS fy_start,
               MAX(make_date(fiscal_year - 543, 10, 1)) AS fy_end
        FROM years
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
    WHERE i.dchdate >= (SELECT fy_start FROM yspan)
      AND i.dchdate < (SELECT fy_end FROM yspan)
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
    WHERE v.vstdate >= (SELECT fy_start FROM yspan)
      AND v.vstdate < (SELECT fy_end FROM yspan)
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
    WHERE cm.regdate >= (SELECT fy_start FROM yspan)
      AND cm.regdate < (SELECT fy_end FROM yspan)
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
    WHERE COALESCE(l.labour_startdate, i.regdate) >= (SELECT fy_start FROM yspan)
      AND COALESCE(l.labour_startdate, i.regdate) < (SELECT fy_end FROM yspan)
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
    WHERE nb.born_date >= (SELECT fy_start FROM yspan)
      AND nb.born_date < (SELECT fy_end FROM yspan)
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
    WHERE e.emp_work_begindate >= (SELECT fy_start FROM yspan)
      AND e.emp_work_begindate < (SELECT fy_end FROM yspan)
  ),
      facts AS (
      
      SELECT
        'DH0113' AS indicator_code,
        DATE_TRUNC('month', period_start)::date AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            )))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213')
      GROUP BY 2, 3, 4
      ),
      agg AS (
        SELECT
          facts.fiscal_year + 543 AS fiscal_year_be,
          SUM(COALESCE(facts.numerator, 0)) AS num_sum,
          SUM(COALESCE(facts.denominator, 0)) AS den_sum,
          SUM(facts.value) AS val_sum
        FROM facts
        GROUP BY 1
      ),
      targets AS (
        SELECT y.fiscal_year,
               MAX(COALESCE(m.kpi_moph_number_result, m.kpi_moph_number_mean,
                            m.kpi_moph_number_c, m.kpi_moph_number_b,
                            m.kpi_moph_number_a)) AS target_value
        FROM years y
        LEFT JOIN kpi_moph_guideline g
          ON UPPER(COALESCE(g.kpi_moph_guideline_name, '')) ~
             ('(^|[^0-9A-Z])' || REGEXP_REPLACE('DH0113', '\.', '\.?', 'g') || '($|[^0-9])')
        LEFT JOIN kpi_moph m
          ON m.kpi_moph_guideline_id = g.kpi_moph_guideline_id
         AND (CASE WHEN m.kpi_moph_year >= 2400 THEN m.kpi_moph_year
                   WHEN m.kpi_moph_year BETWEEN 2000 AND 2399 THEN m.kpi_moph_year + 543 END) = y.fiscal_year
        GROUP BY y.fiscal_year
      ),
      per_year AS (
        SELECT y.fiscal_year,
               COALESCE(a.num_sum, 0) AS numerator,
               COALESCE(a.den_sum, 0) AS denominator,
               CASE WHEN a.num_sum IS NOT NULL AND a.den_sum > 0
                    THEN ROUND(a.num_sum * 100.0 / a.den_sum, 2)
                    ELSE a.val_sum END AS value
        FROM years y
        LEFT JOIN agg a ON a.fiscal_year_be = y.fiscal_year
      )
      SELECT
        'DH0113' AS indicator_code,
        U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E20\0E32\0E27\0E30\0E2B\0E31\0E27\0E43\0E08\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E40\0E09\0E35\0E22\0E1A\0E1E\0E25\0E31\0E19\0020\0E0A\0E19\0E34\0E14\0020\0053\0054\0020\0073\0065\0067\006D\0065\006E\0074\0020\0E22\0E01\0E02\0E36\0E49\0E19\0020\0028\0053\0054\0045\004D\0049\0029\0020\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0020\0046\0069\0062\0072\0069\006E\006F\006C\0079\0074\0069\0063\0020\0061\0067\0065\006E\0074\0020\0E20\0E32\0E22\0E43\0E19\0020\0033\0030\0020\0E19\0E32\0E17\0E35\0E40\0E21\0E37\0E48\0E2D\0E21\0E32\0E16\0E36\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25' AS indicator_name_th,
        'Acute coronary syndrome (STEMI) : Percent of time to Fibrinolytic administration agents within 30 minutes of arrival' AS indicator_name_en,
        make_date(p.fiscal_year - 544, 10, 1) AS period_start,
        p.fiscal_year AS fiscal_year,
        p.numerator,
        p.denominator,
        p.value,
        t.target_value AS target,
        CASE WHEN p.value IS NULL OR t.target_value IS NULL OR t.target_value = 0
             THEN NULL
             ELSE ROUND(p.value * 100.0 / t.target_value, 2) END AS vs_target_pct,
        CASE WHEN p.value IS NULL THEN 'no-data'
             WHEN t.target_value IS NULL OR 'higher-is-better' = 'neutral' THEN 'unbenchmarked'
             WHEN 'higher-is-better' = 'higher-is-better' AND p.value >= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'higher-is-better' AND p.value >= t.target_value - GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             WHEN 'higher-is-better' = 'lower-is-better' AND p.value <= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'lower-is-better' AND p.value <= t.target_value + GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             ELSE 'action' END AS status
      FROM per_year p
      LEFT JOIN targets t ON t.fiscal_year = p.fiscal_year
      ORDER BY p.fiscal_year
