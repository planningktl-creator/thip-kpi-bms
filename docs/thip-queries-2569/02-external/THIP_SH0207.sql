-- ==============================================================================
-- THIP KPI SH0207 - ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของแพทย์/ทันตแพทย์(ระดับ 1-2)
-- HRD: Percent of physician/dentist satisfaction (level 1-2)
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: บุคลากร (Human resources)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกปี (รายปี) - งวดที่คาดหวังในปีงบ: 1 (1 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 234 - ความถี่ตามเอกสาร: ทุกปี หรือ ปีละครั้ง (ตัวชี้วัดรายปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a = จำนวนแพทย์/ทันตแพทย์ที่ตอบแบบสอบถามมีระดับความพึงพอใจในระดับ 1-2
--   d. b
--     b = จำนวนแพทย์/ทันตแพทย์ที่ตอบแบบสอบถามทั้งหมด
-- นิยาม:
--   1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม
--   "ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด" 2. ระดับความพึงพอใจ หมายถึง
--   ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5
--   ระดับจากน้อยที่สุดไปถึงมากที่สุด
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Measures: the level 1 to 2 share of overall organizational satisfaction among physicians
--   and dentists, from the single five-level questionnaire item. The branch is branchExternal
--   over reporting.thip_external_facts. PDF beyond the branch: the the level 1 to 2 share
--   response counts of physicians and dentists from the employee satisfaction survey of the
--   fiscal year. Confirm with the hospital owner: that the installed instrument is the printed
--   single item with the five-level scale, and the response counts per job group. Staging rows
--   for reporting.thip_external_facts (columns indicator_code, period_start, numerator,
--   denominator, value, source_system): one row per annual reporting anchor with period_start =
--   1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value =
--   ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100,
--   source_system = the employee satisfaction survey system. No HOSxP table holds the printed
--   questionnaire: the item is the single question on overall organizational satisfaction
--   answered on a five-level scale, and neither the instrument version nor the level semantics
--   can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu,
--   survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other,
--   unversioned instruments). The survey result must therefore be aggregated by the hospital
--   and loaded into reporting.thip_external_facts.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0076310, ส่วน #3.2)
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
        'SH0207' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0207'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SH0207', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1A\0E38\0E04\0E25\0E32\0E01\0E23\0E43\0E19\0E2D\0E07\0E04\0E4C\0E01\0E23\0E43\0E19\0E20\0E32\0E1E\0E23\0E27\0E21\0E02\0E2D\0E07\0E41\0E1E\0E17\0E22\0E4C\002F\0E17\0E31\0E19\0E15\0E41\0E1E\0E17\0E22\0E4C\0028\0E23\0E30\0E14\0E31\0E1A\0020\0031\002D\0032\0029', 'HRD: Percent of physician/dentist satisfaction (level 1-2)')
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
