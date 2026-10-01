-- ==============================================================================
-- THIP KPI SI0201 - อัตราการติดเชื้อในกระแสเลือดจากการคาสายสวนหลอดเลือดส่วนกลาง (ภาพรวม)
-- BSI: Rate of CABSI (All)
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: การติดเชื้อในโรงพยาบาล (HAI)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกเดือน (รายเดือน) - งวดที่คาดหวังในปีงบ: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (12 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 214 - ความถี่ตามเอกสาร: ทุกเดือน หรือ เดือนละครั้ง (ตัวชี้วัดรายเดือน)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 1,000
--   n. a
--     a = จำนวนครั้งของการติดเชื้อในกระแสเลือดในผู้ป่วยใส่สาย central line ทั้งหมด
--   d. b
--     b = จำนวนวันรวมที่ผู้ป่วยใส่สาย central line ทั้งหมด
-- นิยาม:
--   เป็นการติดเชื้อในกระแสเลือดหลังจากใส่สายสวนหลอดเลือดส่วนกลางมากกว่า 2 วัน ปฏิทิน
--   (วันแรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และเมื่อถอดสายสวนหลอดเลือดออกภายใน 1 วันปฏิทิน (*in
--   place on the date of event or the day before) ของผู้ป่วยในจาก
--   ทุกหอผู้ป่วยโดยนับรวมผู้ป่วยทั้งที่อยู่ในและนอกห้อง ICU
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   NOT in standard HOSxP: CABSI needs central-line days and NHSN laboratory-confirmed
--   bloodstream infection events. External staging: one monthly row with indicator_code =
--   SI0201, numerator = NHSN-defined CABSI events in all wards, denominator = total
--   central-line days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2),
--   source_system = icu_infection_surveillance. Confirm with the hospital owner: where
--   central-line insertion and removal dates are kept (ipd_nurse_note has no line-day fields)
--   and the laboratory criteria used for the event definition.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0077363, ส่วน #3.2)
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
        'SI0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0201'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SI0201', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)'), ('SI0201', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E43\0E19\0E01\0E23\0E30\0E41\0E2A\0E40\0E25\0E37\0E2D\0E14\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E2B\0E25\0E2D\0E14\0E40\0E25\0E37\0E2D\0E14\0E2A\0E48\0E27\0E19\0E01\0E25\0E32\0E07\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029', 'BSI: Rate of CABSI (All)')
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
