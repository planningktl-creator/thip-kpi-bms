-- ==============================================================================
-- THIP KPI SH0215 - สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของบุคลากรสาย allied health
-- HRD: Training hour per person per year of allied health personel
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: บุคลากร (Human resources)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกปี (รายปี) - งวดที่คาดหวังในปีงบ: 1 (1 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 242 - ความถี่ตามเอกสาร: ทุกปี หรือ ปีละครั้ง (ตัวชี้วัดรายปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): a/b
--   n. a
--     a = จำนวนชั่วโมงของบุคลากรสาย allied health ที่ได้ฝึกอบรมเพื่อพัฒนาทักษะตามสาย
--     วิชาชีพของตน
--   d. b
--     b = จำนวนบุคลากรสาย allied health ทั้งหมด
-- นิยาม:
--   1. การฝึกอบรมที่นับจำนวนชั่วโมง ได้แก่ ศึกษา, ฝึกอบรม, ปฏิบัติงานวิจัย (ที่ระยะเวลาไม่ เกิน
--   3 เดือน), ดูงาน, การให้บริการทางวิชาการ, ประชุม, ประชุมและเป็นวิทยากร, ประชุม และเสนอผลงาน,
--   อบรม, สัมมนา ที่มีกำหนดการประชุมและ/หรือช่วงเวลาเริ่มต้น-สิ้นสุดที่ ชัดเจน 1.1
--   กรณีไปเป็นวิทยากรโดยไม่เข้าร่วมประชุม จะนับชั่วโมงจริงเฉพาะช่วงเวลาที่เป็น วิทยากรเท่านั้น
--   1.2 กรณีไปเป็นวิทยากรและเข้าร่วมประชุม, กรณีประชุมและเสนอผลงาน จะนับชั่วโมง รวมเป็นประชุม
--   2. การฝึกอบรมที่ไม่นับจำนวนชั่วโมง ได้แก่ การไปปฏิบัติงานตามภาระงานบริหารหรือที่
--   ได้รับมอบหมายด้านการบริหาร (ไปราชการ) 3. จำนวนชั่วโมงอบรม 1 วัน =6 ชั่วโมง
--   (ไม่คิดช่วงเวลาพักทานอาหารกลางวัน) 1 เดือน =23 วันทำการ
--   (กรณีไม่มีกำหนดการอบรมจะไม่คิดวันเสาร์/อาทิตย์-ตาม มาตรฐานการคิดเวลาทำงาน)
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Measures: training hours per person per year of allied health personnel (counted events:
--   study, training, short research, observation visits, academic services, meetings, seminars
--   with explicit schedules; one training day is six hours). The branch is branchExternal over
--   reporting.thip_external_facts. PDF beyond the branch: total counted training hours and the
--   staff count of allied health personnel for the fiscal year. Confirm with the hospital
--   owner: the counted-hour rules and the job-group roster used for the denominator. Staging
--   rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator,
--   denominator, value, source_system): one row per annual reporting anchor with period_start =
--   1 October of the fiscal year (fiscal month 1), numerator = a (training hours), denominator
--   = b (staff count of the group), value = ROUND(a times 1 divided by NULLIF(b, 0), 2) per
--   formulaScale a over b, source_system = the human resources training register. No HOSxP
--   table holds the staff training-hour register (the emp_work_study and emp_education tables
--   hold leave-for-study records and education-level lookups, and emp_educate_child and
--   emp_wf_edu_regis cover children and welfare education, not staff training events with
--   hours). Training hours must be aggregated by the human resources office and loaded into
--   reporting.thip_external_facts.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0076958, ส่วน #3.2)
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
        'SH0215' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0215'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SH0215', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E0A\0E31\0E48\0E27\0E42\0E21\0E07\0E01\0E32\0E23\0E1D\0E36\0E01\0E2D\0E1A\0E23\0E21\0E15\0E48\0E2D\0E04\0E19\0E15\0E48\0E2D\0E1B\0E35\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E2A\0E32\0E22\0020\0061\006C\006C\0069\0065\0064\0020\0068\0065\0061\006C\0074\0068', 'HRD: Training hour per person per year of allied health personel')
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
