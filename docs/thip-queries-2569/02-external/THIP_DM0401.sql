-- ==============================================================================
-- THIP KPI DM0401 - ร้อยละผู้ป่วยเด็กสมาธิสั้นรายใหม่อาการดีขึ้นภายใน 6 เดือน
-- Child and adolescent psychiatry: Percent of children with Attention-Deficit Hyperactivity
-- Disorder (ADHD) improved after intervented for 6 months
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: พัฒนาการเด็ก/จิตเวชเด็ก (Development)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุก 6 เดือน (รายครึ่งปี) - งวดที่คาดหวังในปีงบ: 1, 7 (2 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 168 - ความถี่ตามเอกสาร: ทุก 6 เดือน (ตัวชี้วัดรายครึ่งปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: ร้อยละ 80 (ค่าเฉลี่ยจากการทดลองใช้ตัวชี้วัดเปรียบเทียบ ของกรมสุขภาพจิต กระทรวง สาธารณสุข เดือนพฤษภาคม 2561 ร้อยละ 69.16 ต่ำสุดร้อยละ 8.04 สูงสุดร้อยละ 100)
-- สูตร (ตามเอกสาร): (a/b) ข 100
--   n. a
--     a = จํานวนผู้ป่วยเด็กสมาธิสั้น อายุ 6-14 ปี 11 เดือน 29 วัน ที่มารับการรักษาทั้งหมด
--     ในช่วง 6 เดือนและมีคะแนน SNAP-IV ลดลงจากการประเมินโดยผู้ปกครอง (คน)
--   d. b
--     b = จํานวนผู้ป่วยเด็กสมาธิสั้น อายุ 6-14 ปี 11 เดือน 29 วัน ที่มารับการรักษาทั้งหมด
--     ในช่วง 6 เดือน (คน)
-- นิยาม:
--   ผู้ป่วยสมาธิสั้น หมายถึง ผู้ป่วยที่ได้รับการวินิจฉัยเป็นโรคสมาธิสั้น (F90) อาการดีขึ้น
--   หมายถึง คะแนนจากแบบวัด SNAP-IV ฉบับผู้ปกครองลดลงด้านใดด้านหนึ่ง หลังรับการรักษา 6 เดือน
-- เป้าหมาย/เกณฑ์ตัดสิน:
--   ร้อยละ 80 (ค่าเฉลี่ยจากการทดลองใช้ตัวชี้วัดเปรียบเทียบ ของกรมสุขภาพจิต กระทรวง สาธารณสุข
--   เดือนพฤษภาคม 2561 ร้อยละ 69.16 ต่ำสุดร้อยละ 8.04 สูงสุดร้อยละ 100)
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   ADHD improvement needs a parent SNAP-IV score pair; HOSxP psych_assess stores only question
--   and answer references with no verified SNAP-IV binding
--   (psych_assess_list.psych_assess_evalueate is ambiguous). Branch is branchExternal: the
--   hospital must load one row per reporting-period anchor into reporting.thip_external_facts
--   with numerator, denominator, value and source_system, computed from the SNAP-IV parent
--   questionnaires.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0074366, ส่วน #3.2)
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
        'DM0401' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0401'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DM0401', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E14\0E47\0E01\0E2A\0E21\0E32\0E18\0E34\0E2A\0E31\0E49\0E19\0E23\0E32\0E22\0E43\0E2B\0E21\0E48\0E2D\0E32\0E01\0E32\0E23\0E14\0E35\0E02\0E36\0E49\0E19\0E20\0E32\0E22\0E43\0E19\0020\0036\0020\0E40\0E14\0E37\0E2D\0E19', 'Child and adolescent psychiatry: Percent of children with Attention-Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6 months'), ('DM0401', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E40\0E14\0E47\0E01\0E2A\0E21\0E32\0E18\0E34\0E2A\0E31\0E49\0E19\0E23\0E32\0E22\0E43\0E2B\0E21\0E48\0E2D\0E32\0E01\0E32\0E23\0E14\0E35\0E02\0E36\0E49\0E19\0E20\0E32\0E22\0E43\0E19\0020\0036\0020\0E40\0E14\0E37\0E2D\0E19', 'Child and adolescent psychiatry: Percent of children with Attention-Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6 months')
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
