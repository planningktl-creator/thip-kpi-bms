-- ==============================================================================
-- THIP KPI DS0101 - ร้อยละของผู้ติดยาเสพติดกลุ่ม Methamphetamine โดยรวมที่หยุดเสพต่อเนื่อง 3 เดือน
-- Methamphetamine group: 3 months total remission rate
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: ยาเสพติด/สุรา/ยาสูบ (Substance)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุก 3 เดือน (รายไตรมาส) - งวดที่คาดหวังในปีงบ: 1, 4, 7, 10 (4 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 135 - ความถี่ตามเอกสาร: ทุก 3 เดือน หรือ ทุกไตรมาส (ตัวชี้วัดรายไตรมาส)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: ฐานข้อมูลการบำบัดรักษายาเสพติดของประเทศ (กระทรวงสาธารณสุข)
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a = จำนวนผู้ติดยาเสพติดกลุ่ม Methamphetamine ที่หยุดเสพต่อเนื่อง 3 เดือนหลัง
--     จำหน่ายจากการบำบัดรักษา
--   d. b
--     b = จำนวนผู้ติดยาเสพติดกลุ่ม Methamphetamine ที่เข้ารับการบำบัดรักษาในระบบ สมัครใจ
--     แบบผู้ป่วยนอก ที่จำหน่ายจากการบำบัดรักษาทั้งหมดในไตรมาสก่อนหน้า
-- นิยาม:
--   ผู้ติดยาเสพติดกลุ่ม Methamphetamine หมายถึง ผู้ติดยาเสพติดกลุ่ม Methamphetamine เช่น ยาบ้า
--   ยาไอซ์ ยาอี และยาเลิฟ เป็นต้น หยุดเสพต่อเนื่อง 3 เดือน หมายถึง ผู้ติดยาเสพติดกลุ่ม
--   Methamphetamine ที่เข้ารับการ บำบัดรักษาในระบบสมัครใจ
--   แบบผู้ป่วยนอกและไม่ครบเกณฑ์ในการวินิจฉัย ผู้ติด (dependence) ต่อเนื่อง 3
--   เดือนหลังจำหน่ายจากการบำบัดรักษา ทั้งนี้ไม่รวมผู้ป่วยถูก จับเสียชีวิต หรือส่งต่อ
--   หลังจำหน่ายจากการบำบัดรักษา
-- เป้าหมาย/เกณฑ์ตัดสิน:
--   ฐานข้อมูลการบำบัดรักษายาเสพติดของประเทศ (กระทรวงสาธารณสุข)
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Methamphetamine three-month abstinence after discharge is a verdict from the national
--   addiction programme follow-up forms, not a structured HOSxP fact (psych_screen_addict holds
--   screening, not the follow-up abstinence verdict). Branch is branchExternal: the hospital
--   must load one row per reporting-period anchor into reporting.thip_external_facts with
--   numerator, denominator, value and source_system, from the addiction treatment database
--   follow-up outcomes.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0074528, ส่วน #3.2)
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
        'DS0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DS0101'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DS0101', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate'), ('DS0101', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate'), ('DS0101', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate'), ('DS0101', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E15\0E34\0E14\0E22\0E32\0E40\0E2A\0E1E\0E15\0E34\0E14\0E01\0E25\0E38\0E48\0E21\0020\004D\0065\0074\0068\0061\006D\0070\0068\0065\0074\0061\006D\0069\006E\0065\0020\0E42\0E14\0E22\0E23\0E27\0E21\0E17\0E35\0E48\0E2B\0E22\0E38\0E14\0E40\0E2A\0E1E\0E15\0E48\0E2D\0E40\0E19\0E37\0E48\0E2D\0E07\0020\0033\0020\0E40\0E14\0E37\0E2D\0E19', 'Methamphetamine group: 3 months total remission rate')
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
