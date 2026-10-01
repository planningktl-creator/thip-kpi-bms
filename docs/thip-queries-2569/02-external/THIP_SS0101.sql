-- ==============================================================================
-- THIP KPI SS0101 - ร้อยละการตรวจสอบประสิทธิภาพการทำปราศจากเชื้อผ่านเกณฑ์
-- CSSD: Percent of examination of effective sterilization
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: งานปราศจากเชื้อ/จ่ายกลาง (CSSD)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกเดือน (รายเดือน) - งวดที่คาดหวังในปีงบ: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (12 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 266 - ความถี่ตามเอกสาร: ทุกเดือน หรือเดือนละครั้ง (ตัวชี้วัดรายเดือน)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a = จำนวนครั้งการตรวจสอบประสิทธิภาพการทำปราศจากเชื้อผ่านเกณฑ์ใน 1 เดือน
--   d. b
--     b = จำนวนครั้งการตรวจสอบประสิทธิภาพการทำปราศจากเชื้อทั้งหมด ในเดือนเดียวกัน
-- นิยาม:
--   1. วิธีการตรวจสอบการทำปราศจากเชื้อ (ทั้งการนึ่งฆ่าเชื้อด้วยไอน้ำ และการอบฆ่าเชื้อด้วย ก๊าซ)
--   ประกอบด้วยกรรมวิธี 3 ด้าน คือ 1.1 ตัวบ่งชี้ทางเชิงกล (mechanical indicator)
--   เพื่อบ่งบอกสภาวะของเครื่องที่ทำให้ ปราศจากเชื้อ โดยดูจากมาตรวัดอุณหภูมิ มาตรวัดความดัน
--   สัญญาณไฟต่างๆ และแผ่น บันทึกการทำงานของเครื่อง 1.2 ตัวบ่งชี้ทางเคมี (chemical indicator)
--   โดยดูจากการเปลี่ยนสีของตัวบ่งชี้ทางเคมี ภายนอก และการเปลี่ยนสีของตัวบ่งชี้ทางเคมีภายใน 1.3
--   ตัวบ่งชี้ทางชีวภาพ (biological indicator) โดยดูจากผลการตรวจ spore test negative 2.
--   อุณหภูมิและความดันที่ปรากฏที่มาตรวัดตลอดจนตัวบ่งชี้ทางเคมีและชีวภาพ ที่ทำให้ ปราศจากเชื้อ
--   ต้องสอดคล้องเป็นไปตามข้อกำหนดและคู่มือการใช้งานของบริษัทผู้ผลิต
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   NOT in HOSxP: sterilization effectiveness checks (mechanical, chemical and biological
--   spore-test indicators) are CSSD logbook events. External staging: one monthly row per
--   anchor in reporting.thip_external_facts with indicator_code = SS0101, numerator =
--   sterilization effectiveness checks passing all applicable indicators, denominator = all
--   sterilization effectiveness checks in the month (steam and gas), value = ROUND(numerator *
--   100 / NULLIF(denominator, 0), 2), source_system = cssd_log. Confirm with the hospital
--   owner: the check frequency policy (each load, weekly spore test) and who keeps the log.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0077849, ส่วน #3.2)
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
        'SS0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SS0101'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SS0101', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 2, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 3, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 4, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 5, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 6, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 8, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 9, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 10, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 11, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization'), ('SS0101', 12, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E01\0E32\0E23\0E15\0E23\0E27\0E08\0E2A\0E2D\0E1A\0E1B\0E23\0E30\0E2A\0E34\0E17\0E18\0E34\0E20\0E32\0E1E\0E01\0E32\0E23\0E17\0E33\0E1B\0E23\0E32\0E28\0E08\0E32\0E01\0E40\0E0A\0E37\0E49\0E2D\0E1C\0E48\0E32\0E19\0E40\0E01\0E13\0E11\0E4C', 'CSSD: Percent of examination of effective sterilization')
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
