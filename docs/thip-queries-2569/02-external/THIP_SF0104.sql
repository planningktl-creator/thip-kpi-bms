-- ==============================================================================
-- THIP KPI SF0104 - ระยะเวลาถัวเฉลี่ยในการเรียกเก็บลูกหนี้ค่ารักษาสุทธิ
-- Financial: Day in account receivable (average collection period for account receivables)
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: การเงิน (Finance)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกปี (รายปี) - งวดที่คาดหวังในปีงบ: 1 (1 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 256 - ความถี่ตามเอกสาร: ทุกปี หรือ ปีละครั้ง (ตัวชี้วัดรายปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): a/b
--   n. a
--     a = ยอดลูกหนี้สุทธิ ณ วันสิ้นปี
--   d. b
--     b = ยอดขายเชื่อเฉลี่ยต่อวัน
-- นิยาม:
--   ระยะเวลาถัวเฉลี่ยในการเรียกเก็บลูกหนี้ค่ารักษาสุทธิ เป็นการหาค่าระยะเวลาถัวเฉลี่ยใน
--   การเรียกเก็บหนี้ ที่แสดงให้เห็นถึงระยะเวลาในการเรียกเก็บหนี้ว่าสั้นหรือยาว (จำนวนวันที่
--   ต้องรอเพื่อเก็บเงินจากลูกหนี้ค่ารักษาพยาบาล) เพื่อให้ทราบถึงคุณภาพของลูกหนี้ค่า รักษาพยาบาล
--   ประสิทธิภาพในการเรียกเก็บหนี้ และนโยบายในการให้สินเชื่อ
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Measures: Average collection period of net medical receivables, in days (THIP page 256;
--   lower is better). The branch is branchExternal over reporting.thip_external_facts because
--   the audited financial statements of the hospital are outside HOSxP (the stock_item and
--   stock_trancation candidates only hold consumable stock card quantities and money flows,
--   never balance sheet or income statement items). PDF beyond the branch: the a and b amounts
--   of the printed definition taken from the audited financial statements of the fiscal year.
--   Confirm with the hospital owner: the finance office computation of average credit sales per
--   day and that the receivable balance is the year-end net figure; the resulting value is a
--   day count, not a percent. Staging rows for reporting.thip_external_facts (columns
--   indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows:
--   one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal
--   year 2026; the anchor is always 1 October). numerator (a) = net accounts receivable in THB
--   at the end of the fiscal year. denominator (b) = average credit sales per day in THB (net
--   credit sales of the fiscal year prorated to one day by the finance office before loading).
--   value = ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b (unit: days).
--   source_system = 'thip-finance-audited'.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0075500, ส่วน #3.2)
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
        'SF0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0104'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SF0104', 1, U&'\0E23\0E30\0E22\0E30\0E40\0E27\0E25\0E32\0E16\0E31\0E27\0E40\0E09\0E25\0E35\0E48\0E22\0E43\0E19\0E01\0E32\0E23\0E40\0E23\0E35\0E22\0E01\0E40\0E01\0E47\0E1A\0E25\0E39\0E01\0E2B\0E19\0E35\0E49\0E04\0E48\0E32\0E23\0E31\0E01\0E29\0E32\0E2A\0E38\0E17\0E18\0E34', 'Financial: Day in account receivable (average collection period for account receivables)')
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
