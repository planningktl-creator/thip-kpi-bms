-- ==============================================================================
-- THIP KPI CA0105 - ร้อยละของผู้ป่วยที่ดมยาสลบได้รับการเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ ในลมหายใจออก
-- Anesthesia: Percent of using capnometry during general anesthesia
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: HOSxP   |   กลุ่มงาน: วิสัญญี/การผ่าตัด (Anesthesia)
-- ตารางที่อ้างอิง (16): ตัวชี้วัดนี้: operation_list, operation_anes, operation_anes_detail, ipd_nurse_note
--              ฐานข้อมูลร่วม (ฝังในไฟล์): clinicmember, ipt_newborn, emp, ipt, an_stat, er_regist, labor, ovst, patient, death, iptdiag, ovstdiag
-- รอบรายงาน: ทุกเดือน (รายเดือน) - งวดที่คาดหวังในปีงบ: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (12 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 193 - ความถี่ตามเอกสาร: ทุกเดือน หรือ เดือนละครั้ง (ตัวชี้วัดรายเดือน)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a = จำนวนผู้ป่วยที่ได้รับการเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ในลมหายใจออก ใน 1 เดือน
--   d. b
--     b = จำนวนผู้ป่วยที่ได้รับการให้ยาระงับความรู้สึกแบบทั้งตัวที่ใส่ท่อช่วยหายใจทั้งหมด (ใน
--     เดือนเดียวกัน)
-- นิยาม:
--   1. การเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ในลมหายใจออก หมายถึง การเฝ้าระวังการ
--   หายใจโดยการใช้เครื่องวัดระดับคาร์บอนไดออกไซด์ในลมหายใจออก ด้วยเครื่อง Capnometry
--   ในผู้ป่วยผ่าตัดที่ได้รับยาระงับความรู้สึกแบบทั้งตัวและใส่ท่อช่วยหายใจ
--   ระหว่างการได้รับยาระงับความรู้สึก 2. การผ่าตัด หมายถึง
--   การผ่าตัดทุกชนิดที่มีการให้ยาระงับความรู้สึกโดยวิสัญญี
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Measures the share of intubated general-anesthesia IPD cases with exhaled-CO2 (capnometry)
--   monitoring, evidenced by the operation_anes_detail.monitor text (capno, etco, คาพโน) or a
--   recorded ipd_nurse_note.etco2 value. PDF needs: capnometry use for the whole intubated
--   general-anesthesia period. Confirm with the hospital owner: the monitor naming convention
--   in operation_anes_detail, and whether capnometry is charted elsewhere (for example an
--   anesthesia record sheet outside HOSxP).
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0012556, ส่วน #2)
-- ถอดจากซอร์สเรพโอ commit 19306cd - สร้างใหม่ได้ตาม README.md ในโฟลเดอร์นี้
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
        'CA0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.ga_capno, FALSE)) AS numerator,
        COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.ga, FALSE)) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.ga_capno, FALSE)) * 100 / NULLIF(COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.ga, FALSE)), 0), 2) AS value
      FROM periodized
      LEFT JOIN LATERAL (
          SELECT
            BOOL_OR(EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )) AS ga,
            BOOL_OR(EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          ) AND (
            EXISTS (
              SELECT 1
              FROM operation_anes_detail ad
              WHERE ad.operation_id = ol.operation_id
                AND (
                  LOWER(ad.monitor) LIKE '%capno%'
                  OR LOWER(ad.monitor) LIKE '%etco%'
                  OR ad.monitor ILIKE U&'%\0E04\0E32\0E1E\0E42\0E19%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.etco2 IS NOT NULL
            )
          )) AS ga_capno
          FROM operation_list ol
          WHERE ol.an = periodized.an
        ) operation_flags ON TRUE
      WHERE TRUE
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('CA0105', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia'), ('CA0105', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E14\0E21\0E22\0E32\0E2A\0E25\0E1A\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E40\0E1D\0E49\0E32\0E23\0E30\0E27\0E31\0E07\0E23\0E30\0E14\0E31\0E1A\0E01\0E4A\0E32\0E0B\0E04\0E32\0E23\0E4C\0E1A\0E2D\0E19\0E44\0E14\0E2D\0E2D\0E01\0E44\0E0B\0E14\0E4C\0020\0E43\0E19\0E25\0E21\0E2B\0E32\0E22\0E43\0E08\0E2D\0E2D\0E01', 'Anesthesia: Percent of using capnometry during general anesthesia')
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
