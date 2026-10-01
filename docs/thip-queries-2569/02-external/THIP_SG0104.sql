-- ==============================================================================
-- THIP KPI SG0104 - สัดส่วนของขยะรีไซเคิล
-- Governance: Percent of recycled waste
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: สิ่งแวดล้อม/ขยะ (Green)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกเดือน (รายเดือน) - งวดที่คาดหวังในปีงบ: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (12 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 265 - ความถี่ตามเอกสาร: ทุกเดือน หรือเดือนละครั้ง (ตัวชี้วัดรายเดือน)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): a/b
--   n. a
--     a = น้ำหนักของขยะรีไซเคิลของเดือนนี้ (กิโลกรัม)
--   d. b
--     b = น้ำหนักของขยะรีไซเคิลในเดือนที่ผ่านมา (กิโลกรัม)
-- นิยาม:
--   1. ขยะรีไซเคิล หมายถึง ขยะที่สามารถนำกลับมาใช้ใหม่ได้ โดยนำไปผ่านกระบวนการแปร
--   รูปในระบบอุตสาหกรรม 2. ระบบการดำเนินการเกี่ยวกับขยะรีไซเคิล
--   เป็นการประเมินว่าองค์กรมีระบบและ แผนปฏิบัติการกำจัดขยะรีไซเคิล ที่มีประสิทธิภาพ
--   บุคลากรทุกระดับสามารถปฏิบัติตาม แนวทางได้
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Measures: Percent of recycled waste: month-over-month ratio of recycled-waste weight (THIP
--   page 265), a = weight of recycled waste of the month in kilograms, b = weight of recycled
--   waste of the previous month in kilograms. The branch is branchExternal over
--   reporting.thip_external_facts because no HOSxP table records waste weights. PDF beyond the
--   branch: the monthly kilogram weights of waste classified as recyclable (waste that can be
--   reprocessed in the industrial system), including the previous month weight that the printed
--   b definition needs. Confirm with the hospital owner: that the hospital environment office
--   waste log measures kilograms, which waste streams count as recycled waste, and that
--   month-over-month comparison against the previous month weight is the intended denominator.
--   Staging rows for reporting.thip_external_facts (columns indicator_code, period_start,
--   numerator, denominator, value, source_system): Anchor rows: one row per monthly reporting
--   anchor with period_start = first day of each calendar month (for example 2025-10-01,
--   2025-11-01). numerator (a) = weight of recycled waste of that month in kilograms.
--   denominator (b) = weight of recycled waste of the immediately previous month in kilograms
--   (the first loaded month needs its predecessor weight from the waste log). value = ROUND(a *
--   1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b. source_system =
--   'thip-environment-waste-log'. Source check: stock_item and stock_trancation track
--   consumable stock cards (item_id, transaction_date, in_qty, out_qty, unit quantities and
--   money columns) with no waste weights or waste-type registry; supply_sterile and
--   supply_sterile_item track sterile supply processing counts (supply_sterile_item_qty);
--   house_survey_garbage, provis_garbage, village_garbage_place and village_recycle_tank are
--   village health survey lookup lists without weights or dates.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0075743, ส่วน #3.2)
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
        'SG0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SG0104'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SG0104', 1, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 2, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 3, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 4, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 5, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 6, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 7, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 8, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 9, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 10, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 11, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste'), ('SG0104', 12, U&'\0E2A\0E31\0E14\0E2A\0E48\0E27\0E19\0E02\0E2D\0E07\0E02\0E22\0E30\0E23\0E35\0E44\0E0B\0E40\0E04\0E34\0E25', 'Governance: Percent of recycled waste')
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
