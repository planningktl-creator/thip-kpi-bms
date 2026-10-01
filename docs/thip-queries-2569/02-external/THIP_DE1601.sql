-- ==============================================================================
-- THIP KPI DE1601 - ร้อยละของทารกแรกเกิดที่ได้รับการตรวจคัดกรองการได้ยิน ภายใน 30 วัน
-- Newborn: Percent of hearing screening within 30 days
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: ทารกแรกเกิด/เด็ก (Newborn & child)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกปี (รายปี) - งวดที่คาดหวังในปีงบ: 1 (1 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 159 - ความถี่ตามเอกสาร: ทุก 1 ปี (ตัวชี้วัดรายปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: มากกว่าร้อยละ 95
-- สูตร (ตามเอกสาร): (a/b) ข 100
--   n. a
--     a = จำนวนทารกแรกเกิดมีชีพทั้งหมดที่ได้รับการตรวจการได้ยิน ภายใน 30 วัน
--   d. b
--     b = จำนวนทารกแรกเกิดมีชีพทั้งหมด (ในปีเดียวกัน)
-- นิยาม:
--   1.ทารกแรกเกิด หมายถึง ทารกแรกเกิดมีชีพทุกรายที่คลอดในโรงพยาบาลจากหญิง
--   ตั้งครรภ์โดยมีอายุครรภ์ตั้งแต่ 28 สัปดาห์ขึ้นไป ยกเว้นย้ายไปโรงพยาบาลอื่นก่อน 2.
--   การตรวจคัดกรองการได้ยิน หมายถึง การตรวจเพื่อประเมินความผิดปกติของการได้ยิน
--   โดยวัดเสียงสะท้อนจากหูชั้นใน (Otoacoustic emissions: OAE) หรือ การตรวจความ
--   ผิดปกติการได้ยินระดับก้านสมอง (Automated Auditory Brainstem Response: AABR)
-- เป้าหมาย/เกณฑ์ตัดสิน:
--   มากกว่าร้อยละ 95
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   External branch: HOSxP has no OAE or AABR newborn hearing screening table (ckup_ear_* holds
--   school audiometry only). Staging requirement: one reporting.thip_external_facts row per
--   fiscal year anchor (period_start equal to the first day of October of the fiscal year) with
--   indicator_code DE1601, numerator equal to live newborns of gestational age 28 weeks or more
--   screened by OAE or AABR within 30 days of birth, denominator equal to all live newborns in
--   that fiscal year, value equal to numerator times 100 over denominator, and source_system
--   naming the hearing screening system. Confirm the screening register, the 30 day window rule
--   and the exclusion of infants transferred out before screening.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0074123, ส่วน #3.2)
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
        'DE1601' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1601'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DE1601', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E17\0E32\0E23\0E01\0E41\0E23\0E01\0E40\0E01\0E34\0E14\0E17\0E35\0E48\0E44\0E14\0E49\0E23\0E31\0E1A\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E04\0E31\0E14\0E01\0E23\0E2D\0E07\0E01\0E32\0E23\0E44\0E14\0E49\0E22\0E34\0E19\0020\0E20\0E32\0E22\0E43\0E19\0020\0033\0030\0020\0E27\0E31\0E19', 'Newborn: Percent of hearing screening within 30 days')
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
