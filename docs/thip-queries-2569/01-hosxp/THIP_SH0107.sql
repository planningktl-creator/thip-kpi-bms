-- ==============================================================================
-- THIP KPI SH0107 - อัตราการลาออก ของบุคลากรสายสนับสนุน
-- HRM : Turnover rate of back office personnel
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: HOSxP   |   กลุ่มงาน: บุคลากร (Human resources)
-- ตารางที่อ้างอิง (15): ตัวชี้วัดนี้: emp, emp_position_main, emp_resign, emp_resign_type
--              ฐานข้อมูลร่วม (ฝังในไฟล์): clinicmember, ipt_newborn, ipt, an_stat, er_regist, labor, ovst, patient, death, iptdiag, ovstdiag
-- รอบรายงาน: ทุก 3 เดือน (รายไตรมาส) - งวดที่คาดหวังในปีงบ: 1, 4, 7, 10 (4 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 227 - ความถี่ตามเอกสาร: ทุก 3 เดือน (ตัวชี้วัดรายไตรมาส)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a = จำนวนบุคลากรสายสนับสนุนที่ลาออกในแต่ละไตรมาส
--   d. b
--     b = จำนวนบุคลากรสายสนับสนุนทั้งหมด ณ วันสุดท้ายของไตรมาสนั้น
-- นิยาม:
--   1. บุคลากรสายสนับสนุน (back office) หมายถึง บุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรง ได้แก่
--   นักบริหารด้านบริการสุขภาพ, นักวิทยาศาสตร์สิ่งมีชีวิต, นักสังคมสงเคราะห์ ผู้ให้คำปรึกษา,
--   เจ้าหน้าที่ด้านบริหาร ธุรการ คลัง บุคคล ตลาด พัสดุ กฎหมาย ประกัน คุณภาพ,
--   เจ้าหน้าที่สารสนเทศ, เจ้าหน้าที่วิเทศสัมพันธ์ ประชาสัมพันธ์ ผู้รับบริการสัมพันธ์,
--   เจ้าหน้าที่งานสวนและสนาม, เจ้าหน้าที่ดูแลความสะอาดอาคารและห้องสุขา, ผู้ช่วยงานใน โรงครัว,
--   ช่างไม้, ช่างประปา, ช่างระบบปรับอากาศและความเย็น, ช่างทาสี, ช่างเชื่อม,
--   ช่างกลและเครื่องจักร, ช่างไฟฟ้าและอิเล็กทรอนิกส์, เจ้าหน้าที่งานตัด-เย็บ 2.
--   คำนวณในกลุ่มที่ลาออกโดยสมัครใจ ไม่นับกลุ่มที่ให้ออก ไล่ออก ปลดออก เกษียณอายุ
--   เข้าโครงการเกษียณก่อนอายุ ถึงแก่กรรม และโอน ย้าย โดยแยกเป็นกลุ่มวิชาชีพและไม่ใช่ วิชาชีพ
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Measures: Quarterly voluntary turnover rate of back office personnel (quarterly anchor).
--   numerator (a) = voluntary resignation events of back office personnel during the quarter
--   denominator (b) = back office personnel employed on the last day of the quarter
--   (active_at_period_end against the quarter boundary of the row month) value = ROUND(a times
--   100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Voluntary resignation
--   is emp_resign rows whose emp_resign_type_name does not mark given-out, dismissed,
--   discharged, retired, early-retired, deceased or transferred staff (name keywords). Confirm
--   the installed emp_resign_type dictionary so only the voluntary group is counted. The
--   job-group split (physician and dentist, professional nurse, allied health, back office) is
--   a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist =
--   name contains the physician token minus technician, assistant and Thai-traditional-medicine
--   names; professional nurse = name contains the professional-nurse token minus assistant and
--   employee-nurse names; allied health = the remaining direct-contact occupations named in the
--   printed definition (midwifery, pharmacy, physician assistant, occupational health and
--   environment, physical therapy, nutrition, communication sciences, optometry, occupational
--   therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and
--   orthotic, nursing employee, dental assistant and dental therapist, health records,
--   community health, optical dispensing, physical therapy assistant, occupational health
--   inspector, ambulance worker, central supply and central pharmacy); back office = every
--   remaining position. Confirm the exact installed position names so the mapping reproduces
--   the printed professional and non-professional groups. PDF beyond the branch: the printed
--   definition needs the exact a and b counts certified by the human resources office for the
--   reporting period. Confirm with the hospital owner: the resignation-type and position-name
--   mapping for the back office group.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0069151, ส่วน #2)
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
        'SH0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.voluntary_resign_cnt) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end) AS denominator,
        ROUND((SUM(hr.voluntary_resign_cnt)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY[U&'%\0E43\0E2B\0E49\0E2D\0E2D\0E01%', U&'%\0E44\0E25\0E48\0E2D\0E2D\0E01%', U&'%\0E1B\0E25\0E14%', U&'%\0E40\0E01\0E29\0E35\0E22\0E13%', U&'%\0E40\0E2A\0E35\0E22\0E0A\0E35\0E27\0E34\0E15%', U&'%\0E16\0E36\0E07\0E41\0E01\0E48\0E01\0E23\0E23\0E21%', U&'%\0E42\0E2D\0E19%', U&'%\0E22\0E49\0E32\0E22%', U&'%\0E15\0E32\0E22%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE U&'%\0E41\0E1E\0E17\0E22\0E4C%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE U&'%\0E40\0E17\0E04\0E19\0E34\0E04\0E01\0E32\0E23\0E41\0E1E\0E17\0E22\0E4C%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE U&'%\0E1C\0E39\0E49\0E0A\0E48\0E27\0E22\0E41\0E1E\0E17\0E22\0E4C%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE U&'%\0E41\0E1E\0E17\0E22\0E4C\0E41\0E1C\0E19%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE U&'%\0E1E\0E22\0E32\0E1A\0E32\0E25\0E27\0E34\0E0A\0E32\0E0A\0E35\0E1E%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE U&'%\0E1E\0E22\0E32\0E1A\0E32\0E25%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE U&'%\0E1C\0E39\0E49\0E0A\0E48\0E27\0E22%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE U&'%\0E1E\0E19\0E31\0E01\0E07\0E32\0E19%'))) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY[U&'%\0E1C\0E14\0E38\0E07\0E04\0E23\0E23\0E20\0E4C%', U&'%\0E40\0E20\0E2A\0E31\0E0A%', U&'%\0E1C\0E39\0E49\0E0A\0E48\0E27\0E22\0E41\0E1E\0E17\0E22\0E4C%', U&'%\0E2D\0E32\0E0A\0E35\0E27\0E2D\0E19\0E32\0E21\0E31\0E22%', U&'%\0E2A\0E34\0E48\0E07\0E41\0E27\0E14\0E25\0E49\0E2D\0E21%', U&'%\0E01\0E32\0E22\0E20\0E32\0E1E%', U&'%\0E42\0E20\0E0A\0E19\0E32%', U&'%\0E2A\0E37\0E48\0E2D\0E04\0E27\0E32\0E21\0E2B\0E21\0E32\0E22%', U&'%\0E17\0E31\0E28\0E19\0E21\0E32\0E15\0E23%', U&'%\0E2D\0E32\0E0A\0E35\0E27\0E1A\0E33\0E1A\0E31\0E14%', U&'%\0E01\0E34\0E08\0E01\0E23\0E23\0E21\0E1A\0E33\0E1A\0E31\0E14%', U&'%\0E40\0E17\0E04\0E19\0E34\0E04\0E01\0E32\0E23\0E41\0E1E\0E17\0E22\0E4C%', U&'%\0E40\0E17\0E04\0E19\0E34\0E04\0E1E\0E22\0E32\0E18\0E34%', U&'%\0E1E\0E22\0E32\0E18\0E34%', U&'%\0E1C\0E39\0E49\0E0A\0E48\0E27\0E22\0E40\0E20\0E2A\0E31\0E0A%', U&'%\0E2D\0E38\0E1B\0E01\0E23\0E13\0E4C\0E01\0E32\0E23\0E41\0E1E\0E17\0E22\0E4C\0E40\0E17\0E35\0E22\0E21%', U&'%\0E1E\0E19\0E31\0E01\0E07\0E32\0E19\0E01\0E32\0E23\0E1E\0E22\0E32\0E1A\0E32\0E25%', U&'%\0E1C\0E39\0E49\0E0A\0E48\0E27\0E22\0E17\0E31\0E19\0E15%', U&'%\0E17\0E31\0E19\0E15\0E20\0E34\0E1A\0E32\0E25%', U&'%\0E40\0E27\0E0A\0E23\0E30\0E40\0E1A\0E35\0E22\0E19%', U&'%\0E2A\0E38\0E02\0E20\0E32\0E1E\0E0A\0E38\0E21\0E0A\0E19%', U&'%\0E1B\0E23\0E30\0E01\0E2D\0E1A\0E41\0E27\0E48\0E19%', U&'%\0E1C\0E39\0E49\0E0A\0E48\0E27\0E22\0E19\0E31\0E01\0E01\0E32\0E22\0E20\0E32\0E1E%', U&'%\0E1C\0E39\0E49\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A%', U&'%\0E23\0E16\0E1E\0E22\0E32\0E1A\0E32\0E25%', U&'%\0E08\0E48\0E32\0E22\0E01\0E25\0E32\0E07%', U&'%\0E40\0E27\0E0A\0E20\0E31\0E13\0E11\0E4C\0E01\0E25\0E32\0E07%', U&'%\0E41\0E1E\0E17\0E22\0E4C\0E41\0E1C\0E19%']))))) AS is_back_office
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, (SELECT fy_start FROM thip_params)), (SELECT fy_start FROM thip_params))),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, (SELECT fy_end FROM thip_params)), (SELECT fy_end FROM thip_params)) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_back_office
      GROUP BY 2, 3, 4
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SH0107', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E25\0E32\0E2D\0E2D\0E01\0020\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19', 'HRM : Turnover rate of back office personnel'), ('SH0107', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E25\0E32\0E2D\0E2D\0E01\0020\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19', 'HRM : Turnover rate of back office personnel'), ('SH0107', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E25\0E32\0E2D\0E2D\0E01\0020\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19', 'HRM : Turnover rate of back office personnel'), ('SH0107', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E25\0E32\0E2D\0E2D\0E01\0020\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0E2A\0E19\0E31\0E1A\0E2A\0E19\0E38\0E19', 'HRM : Turnover rate of back office personnel')
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
