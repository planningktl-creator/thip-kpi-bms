-- ==============================================================================
-- THIP KPI CG0103 - อัตราความชุกของแผลกดทับ
-- Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: ความปลอดภัยผู้ป่วย (Patient safety)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุก 3 เดือน (รายไตรมาส) - งวดที่คาดหวังในปีงบ: 1, 4, 7, 10 (4 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 200 - ความถี่ตามเอกสาร: ทุก 3 เดือน (ตัวชี้วัดรายไตรมาส)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: น้อยกว่าร้อยละ 10 (คณะกรรมการตัวชี้วัดแผลกดทับ ชมรมเครือข่ายพัฒนาคุณภาพการ พยาบาล UHNDC)
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a= จำนวนผู้ป่วยที่มีแผลกดทับที่พบทั้งหมดในโรงพยาบาล แบ่งเป็นเกิดก่อนมาโรงพยาบาล
--     และเกิดในโรงพยาบาล ที่มีความรุนแรงตั้งแต่ระดับ 1 ขึ้นไป ในช่วงเวลาที่สำรวจ
--   d. b
--     b= จำนวนผู้ป่วยทั้งหมดที่มีอยู่ในโรงพยาบาลในช่วงเวลาเดียวกัน
-- นิยาม:
--   1. อัตราความชุกของแผลกดทับ หมายถึง ตัวเลขที่แสดงจำนวนผู้ป่วยที่มีแผลกดทับทั้งหมด
--   ในโรงพยาบาล ในช่วงเวลาที่สำรวจ 2. การนับจำนวนผู้ป่วยที่มีแผลกดทับในประชากรที่สำรวจ ณ
--   เวลาใดเวลาหนึ่งเท่านั้น เป็น การวัดจำนวนผู้ป่วยที่เกิดแผลกดทับในโรงพยาบาล ณ
--   วันที่มีการสำรวจ การนับจำนวนให้ รวมผู้ป่วยที่เกิดแผลกดทับก่อนรับเข้าโรงพยาบาล
--   และผู้ป่วยที่เกิดแผลกดทับภายหลัง รับเข้ารักษาในโรงพยาบาล 3. แผลกดทับ
--   แบ่งตามระดับความรุนแรงเป็น 4 ระดับและ 2 ลักษณะ (ระดับความรุนแรง 1-4,
--   ไม่สามารถระบุระดับความลึกของเนื้อเยื่อที่โดนทำลายได้และการบาดเจ็บเนื้อเยื่อชั้น ลึก)
--   คณะทำงานตัวชี้วัดแผลกดทับ ชมรมพยาบาลแผล ออสโตมี และควบคุมการขับถ่าย
--   และชมรมเครือข่ายพัฒนาคุณภาพการพยาบาล (University Hospital Nursing Director Consortium;
--   UHNDC) ตามเอกสารภาคผนวก 4. การคำนวณตัวชี้วัดนี้
--   ต้องการเอกสารผู้ป่วยทุกคนในหน่วยการรายงานในวันที่สำรวจ
-- เป้าหมาย/เกณฑ์ตัดสิน:
--   น้อยกว่าร้อยละ 10 (คณะกรรมการตัวชี้วัดแผลกดทับ ชมรมเครือข่ายพัฒนาคุณภาพการ พยาบาล UHNDC)
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   NOT computable from HOSxP: the PDF defines a point-prevalence survey (all pressure-ulcer
--   patients present in the hospital at the survey moment, including pre-admission-onset, over
--   the surveyed population). External staging: load one row per quarterly anchor (period_start
--   = first day of Jan, Apr, Jul or Oct) into reporting.thip_external_facts with indicator_code
--   = CG0103, numerator = surveyed patients with any pressure ulcer stage 1 or worse
--   (present-on-admission plus hospital-acquired), denominator = all surveyed inpatients at
--   that moment, value = ROUND(numerator * 100 / NULLIF(denominator, 0), 2), source_system =
--   nursing_pui_survey. Confirm with the hospital owner: survey dates and the survey roster
--   used.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0073475, ส่วน #3.2)
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
        'CG0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'CG0103'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('CG0103', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury'), ('CG0103', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury'), ('CG0103', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury'), ('CG0103', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A', 'Pressure ulcer/injury: Hospital-acquired pressure ulcer/injury')
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
