-- ==============================================================================
-- THIP KPI SI0303 - อัตราการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะ ของผู้ป่วยที่นอนรักษา นอก ICU ของโรงพยาบาล
-- CAUTI: Rate of CAUTI outside ICU
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: การติดเชื้อในโรงพยาบาล (HAI)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกเดือน (รายเดือน) - งวดที่คาดหวังในปีงบ: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (12 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 219 - ความถี่ตามเอกสาร: ทุกเดือน หรือ เดือนละครั้ง (ตัวชี้วัดรายเดือน)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 1,000
--   n. a
--     a = จำนวนครั้งของการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะของ
--     ผู้ป่วยที่นอนนอกห้อง ICU
--   d. b
--     b = จำนวนวันรวมที่ผู้ป่วยนอกห้อง ICU ที่คาสายสวนปัสสาวะทั้งหมด
-- นิยาม:
--   1. การติดเชื้อของผู้ป่วยในระบบทางเดินปัสสาวะ(นับเฉพาะชนิดที่มีอาการ ไม่นับการติด
--   เชื้อที่ไม่มีอาการ (asymptomatic bacteriuria) แต่มีการติดเชื้อในเลือดโดยเชื้อในเลือด
--   เป็นชนิดเดียวกับที่พบในปัสสาวะ) อันเป็นผลมาจากการคาสายสวนปัสสาวะเกิน 2 วัน ปฏิทิน
--   (วันแรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และหลังเอาสายสวนปัสสาวะออกภายใน 2 วันปฏิทิน (*in
--   place on the date of event or the day before) เฉพาะผู้ป่วยที่รักษา นอกห้อง ICU 2. ไอ ซี ยู
--   คือ หอผู้ป่วยจำเพาะที่ให้การดูแลรักษาผู้ป่วยวิกฤตที่มีโรคหรือการบาดเจ็บ
--   รุนแรงจนอาจเสียชีวิต โดยการรักษาเหตุของโรคและการรักษาประคับประคองเพื่อรอให้
--   อวัยวะที่เสื่อมสภาพกลับฟื้นมาทำงาน ร่วมกับการติดตามเฝ้าระวังโดยบุคลากรและการใช้
--   เครื่องมือต่างๆ อย่างใกล้ชิด
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   As SI0301 restricted to non-ICU wards. External staging: one monthly row with
--   indicator_code = SI0303, numerator = NHSN-defined CAUTI events outside the ICUs,
--   denominator = non-ICU urinary-catheter days, value = ROUND(numerator * 1000 /
--   NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the
--   hospital owner: ward classification of the ICU list.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0077768, ส่วน #3.2)
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
        'SI0303' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0303'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SI0303', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU'), ('SI0303', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E34\0E14\0E40\0E0A\0E37\0E49\0E2D\0E23\0E30\0E1A\0E1A\0E17\0E32\0E07\0E40\0E14\0E34\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0E08\0E32\0E01\0E01\0E32\0E23\0E04\0E32\0E2A\0E32\0E22\0E2A\0E27\0E19\0E1B\0E31\0E2A\0E2A\0E32\0E27\0E30\0020\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E17\0E35\0E48\0E19\0E2D\0E19\0E23\0E31\0E01\0E29\0E32\0020\0E19\0E2D\0E01\0020\0049\0043\0055\0020\0E02\0E2D\0E07\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'CAUTI: Rate of CAUTI outside ICU')
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
