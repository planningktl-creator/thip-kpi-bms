-- ==============================================================================
-- THIP KPI CE0102 - ค่าเฉลี่ยระยะเวลาการเข้ารับ-ออกจากบริการของผู้ป่วยที่มารับบริการที่ห้องฉุกเฉิน
-- ER: Average dmergency department (ED) TIME-IN, TIME-OUT
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: HOSxP   |   กลุ่มงาน: ห้องฉุกเฉิน (ER)
-- ตารางที่อ้างอิง (12): ตัวชี้วัดนี้: (กรองจากคอลัมน์ของฐานข้อมูลร่วม - ไม่ดึงตารางเพิ่ม)
--              ฐานข้อมูลร่วม (ฝังในไฟล์): clinicmember, ipt_newborn, emp, ipt, an_stat, er_regist, labor, ovst, patient, death, iptdiag, ovstdiag
-- รอบรายงาน: ทุกเดือน (รายเดือน) - งวดที่คาดหวังในปีงบ: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (12 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 204 - ความถี่ตามเอกสาร: ทุกเดือน หรือ เดือนละครั้ง (ตัวชี้วัดรายเดือน)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: อาจเลือกจาก MBNQA award recipient
-- สูตร (ตามเอกสาร): a/b
--   n. a
--     a = ระยะเวลา (นาที) รวมทั้งหมดของผู้ป่วยฉุกเฉินมาก ที่มารับบริการในห้องฉุกเฉินใน
--     ช่วงเวลาที่กําหนด
--   d. b
--     b = จำนวนผู้ป่วยฉุกเฉินมาก (คน) ทั้งหมดที่มารับบริการในห้องฉุกเฉินในช่วงเวลาเดียวกัน
-- นิยาม:
--   1. ผู้ป่วยฉุกเฉิน (triage as emergency patients) หมายถึง ผู้ป่วยฉุกเฉินตามประเภท ของ triage
--   ระดับ 1 ฉุกเฉินมาก emergency condition ภาวะที่มีอันตราย 1A ความเสี่ยง สูงต่อชีวิต immediate
--   life threatening ต้องการตรวจรักษาทันทีไม่เกิน 4 นาที ซึ่งเป็น
--   ผู้ป่วยฉุกเฉินที่มารับบริการที่ห้องฉุกเฉิน (ไม่รวมกรณีเสียชีวิตผู้ป่วยคลินิกนอกเวลา
--   ผู้ป่วยที่ จําเป็นต้องนอนรักษาที่ ED หรือรอ admit) 2. ระยะเวลา นับเริ่มตั้งแต่เข้ารับบริการ
--   (time-in) จนถึงออกจากห้องฉุกเฉิน (time-out) ซึ่งอาจเป็นการออกโดยจําหน่าย, admit, หรือ refer
--   3. กำหนดช่วงเวลาของการเก็บข้อมูล ทุกวันที่ 5, 15, 25 ช่วงเวลา 00.00-23.59 น. (24 ชั่วโมง)
--   โดยเก็บข้อมูลทุก 1 เดือนๆ ละ 3 ครั้ง
-- เป้าหมาย/เกณฑ์ตัดสิน:
--   อาจเลือกจาก MBNQA award recipient
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Mean minutes from ER time-in (er_regist.enter_er_time) to time-out (finish_time) for ER
--   visits flagged er_emergency_level_id = 1 (triage level 1 / 1A emergency). The printed
--   definition samples only days 5, 15, 25 of each month and excludes deaths, off-hour clinic
--   patients and admissions held in the ED; the branch measures all level-1 visits with both
--   clocks stamped. The hospital owner must confirm the er_emergency_level_id value that maps
--   to triage 1A and whether the 3-day sampling window must be enforced.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0013266, ส่วน #2)
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
        'CE0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) / NULLIF(60, 0)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((SUM(EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) / NULLIF(60, 0)) * 1.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.enter_er_time IS NOT NULL AND opd_periodized.finish_time IS NOT NULL AND opd_periodized.finish_time > opd_periodized.enter_er_time AND opd_periodized.er_emergency_level_id = 1
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('CE0102', 1, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 2, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 3, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 4, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 5, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 6, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 7, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 8, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 9, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 10, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 11, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT'), ('CE0102', 12, U&'\0E04\0E48\0E32\0E40\0E09\0E25\0E35\0E48\0E22\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E01\0E32\0E23\0E40\0E02\0E49\0E32\0E23\0E31\0E1A\002D\0E2D\0E2D\0E01\0E08\0E32\0E01\0E1A\0E23\0E34\0E01\0E32\0E23\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E21\0E32\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E35\0E48\0E2B\0E49\0E2D\0E07\0E09\0E38\0E01\0E40\0E09\0E34\0E19', 'ER: Average dmergency department (ED) TIME-IN, TIME-OUT')
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
