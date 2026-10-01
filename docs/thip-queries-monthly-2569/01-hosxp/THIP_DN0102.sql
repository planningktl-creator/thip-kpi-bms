-- ==============================================================================
-- THIP KPI DN0102 - ร้อยละผู้ป่วยโรคสมองขาดเลือดที่ได้รับยาต้านเกล็ดเลือด (Antiplatelet) ภายใน 2 วัน หลังเข้ารับการรักษาในโรงพยาบาล  [ผลรายเดือน]
-- Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: HOSxP
-- รอบรายงานตามเอกสาร: ทุกเดือน (รายเดือน) - ไฟล์นี้แสดงผลรายเดือน 12 งวด
-- เป้าหมาย: อ่านจากตาราง kpi_moph ของ HIS (ตามปีงบใน thip_params)
-- THIP KPI Dictionary 2025 หน้า 77 - ทิศทาง: higher-is-better
-- สูตร (ตามเอกสาร): (a/b) x 100
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
        'DN0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%')
            AND oi.rxdate >= periodized.regdate AND oi.rxdate <= periodized.regdate + INTERVAL '2 days')) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%')
            AND oi.rxdate >= periodized.regdate AND oi.rxdate <= periodized.regdate + INTERVAL '2 days'))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'I63'
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES

          ('DN0102', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission'),
          ('DN0102', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E42\0E23\0E04\0E2A\0E21\0E2D\0E07\0E02\0E32\0E14\0E40\0E25\0E37\0E2D\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E22\0E32\0E15\0E49\0E32\0E19\0E40\0E01\0E25\0E47\0E14\0E40\0E25\0E37\0E2D\0E14\0020\0028\0041\006E\0074\0069\0070\006C\0061\0074\0065\006C\0065\0074\0029\0020\0E20\0E32\0E22\0E43\0E19\0020\0032\0020\0E27\0E31\0E19\0020\0E2B\0E25\0E31\0E07\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\0E01\0E32\0E23\0E23\0E31\0E01\0E29\0E32\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Ischemic Stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission')
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
      ),
targets AS (
        SELECT v.indicator_code,
               MAX(COALESCE(m.kpi_moph_number_result, m.kpi_moph_number_mean,
                            m.kpi_moph_number_c, m.kpi_moph_number_b,
                            m.kpi_moph_number_a)) AS target_value
        FROM (VALUES
          ('DN0102')
        ) AS v(indicator_code)
        LEFT JOIN kpi_moph_guideline g
          ON UPPER(COALESCE(g.kpi_moph_guideline_name, '')) ~
             ('(^|[^0-9A-Z])' || REGEXP_REPLACE(v.indicator_code, '\.', '\.?', 'g') || '($|[^0-9])')
        LEFT JOIN kpi_moph m
          ON m.kpi_moph_guideline_id = g.kpi_moph_guideline_id
         AND m.kpi_moph_year IN ((SELECT fiscal_year FROM thip_params),
                                 (SELECT fiscal_year FROM thip_params) - 543,
                                 (SELECT fiscal_year FROM thip_params) - 544)
        GROUP BY v.indicator_code
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
        facts.value,
        SUM(COALESCE(facts.numerator, 0)) OVER w AS cum_numerator,
        SUM(COALESCE(facts.denominator, 0)) OVER w AS cum_denominator,
        CASE WHEN SUM(COALESCE(facts.denominator, 0)) OVER w > 0
             THEN ROUND(SUM(COALESCE(facts.numerator, 0)) OVER w * 100.0
                        / SUM(COALESCE(facts.denominator, 0)) OVER w, 2)
             ELSE SUM(facts.value) OVER w END AS cum_value,
        t.target_value AS target,
        CASE WHEN facts.value IS NULL OR t.target_value IS NULL OR t.target_value = 0
             THEN NULL
             ELSE ROUND(facts.value * 100.0 / t.target_value, 2) END AS vs_target_pct,
        CASE WHEN t.target_value IS NULL OR t.target_value = 0
             THEN NULL
             ELSE ROUND((CASE WHEN SUM(COALESCE(facts.denominator, 0)) OVER w > 0
             THEN ROUND(SUM(COALESCE(facts.numerator, 0)) OVER w * 100.0
                        / SUM(COALESCE(facts.denominator, 0)) OVER w, 2)
             ELSE SUM(facts.value) OVER w END) * 100.0 / t.target_value, 2) END AS cum_vs_target_pct,
        CASE WHEN facts.value IS NULL THEN 'no-data'
             WHEN t.target_value IS NULL OR 'higher-is-better' = 'neutral' THEN 'unbenchmarked'
             WHEN 'higher-is-better' = 'higher-is-better' AND facts.value >= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'higher-is-better'
                  AND facts.value >= t.target_value - GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             WHEN 'higher-is-better' = 'lower-is-better' AND facts.value <= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'lower-is-better'
                  AND facts.value <= t.target_value + GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             ELSE 'action' END AS status
      FROM expected_codes
      JOIN fiscal_periods
        ON fiscal_periods.fiscal_month = expected_codes.fiscal_month
      LEFT JOIN facts
        ON facts.indicator_code = expected_codes.indicator_code
       AND facts.period_start = fiscal_periods.period_start
       AND facts.fiscal_month = fiscal_periods.fiscal_month
       AND facts.fiscal_year = fiscal_periods.fiscal_year
      LEFT JOIN targets t ON t.indicator_code = expected_codes.indicator_code
      WINDOW w AS (ORDER BY fiscal_periods.period_start)
      ORDER BY expected_codes.indicator_code, fiscal_periods.period_start
