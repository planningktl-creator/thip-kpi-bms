-- ==============================================================================
-- THIP KPI CG0104 - อัตราความชุกของแผลกดทับที่เกิดในโรงพยาบาล
-- Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: ความปลอดภัยผู้ป่วย (Patient safety)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุก 3 เดือน (รายไตรมาส) - งวดที่คาดหวังในปีงบ: 1, 4, 7, 10 (4 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 202 - ความถี่ตามเอกสาร: ทุก 3 เดือน (ตัวชี้วัดรายไตรมาส)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: lower-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a= จำนวนผู้ป่วยที่มีแผลกดทับที่เกิดในโรงพยาบาล ที่มีความรุนแรงตั้งแต่ระดับ 1 ขึ้น ไป
--     ในช่วงเวลาที่สำรวจ
--   d. b
--     b = จำนวนประชากรผู้ป่วยทั้งหมดในเวลาที่สำรวจ
-- นิยาม:
--   1. อัตราความชุกของแผลกดทับที่เกิดในโรงพยาบาล หมายถึง ตัวเลขที่แสดงจำนวน
--   ผู้ป่วยที่มีแผลกดทับที่เกิดขึ้นในโรงพยาบาล ในช่วงเวลาที่สำรวจ 2.
--   การนับจำนวนผู้ป่วยที่มีแผลกดทับที่เกิดภายหลัง admit ในประชากรที่สำรวจ ณ
--   เวลาใดเวลาหนึ่งที่สำรวจ เป็นการวัดจำนวนผู้ป่วยที่เกิดแผลกดทับในโรงพยาบาล ณ วันที่มีการสำรวจ
--   การนับจำนวนให้นับเฉพาะผู้ป่วยที่เกิดแผลกดทับใหม่หลังรับเข้า โรงพยาบาล 3. การคำนวณ HAPI rate
--   จำเป็นต้องมีการทบทวนบันทีกผู้ป่วยที่มีแผลกดทับ ณ วันที่ admit ถ้าพบว่าบันทึกตอน admit
--   ผู้ป่วยไม่มีแผลกดทับ แสดงว่าแผลที่พบเป็นแผลกด ทับที่เกิดในโรงพยาบาล 4. แผลกดทับ
--   แบ่งตามระดับความรุนแรงเป็น 4 ระดับและ 2 ลักษณะ (ระดับความ รุนแรง 1-4,
--   ไม่สามารถระบุระดับความลึกของเนื้อเยื่อที่โดนทำลายได้และการบาดเจ็บ เนื้อเยื่อชั้นลึก)
--   คณะทำงานตัวชี้วัดแผลกดทับ ชมรมพยาบาลแผล ออสโตมี และควบคุม การขับถ่าย
--   และชมรมเครือข่ายพัฒนาคุณภาพการพยาบาล (University Hospital Nursing Director Consortium;
--   UHNDC) ตามเอกสารภาคผนวก 5. การคำนวณตัวชี้วัดนี้
--   ต้องการเอกสารผู้ป่วยทุกคนในหน่วยการรายงานในวันที่สำรวจ
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   NOT computable from HOSxP: the PDF defines a point-prevalence survey counting only ulcers
--   that developed after admission (chart review of the admission note required). External
--   staging: load one row per quarterly anchor (period_start = first day of Jan, Apr, Jul or
--   Oct) into reporting.thip_external_facts with indicator_code = CG0104, numerator = surveyed
--   patients with a hospital-acquired pressure ulcer stage 1 or worse, denominator = the whole
--   surveyed population at that moment, value = ROUND(numerator * 100 / NULLIF(denominator, 0),
--   2), source_system = nursing_pui_survey. Confirm with the hospital owner: the admission-note
--   review process that separates hospital-acquired from present-on-admission ulcers.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0073556, ส่วน #3.2)
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
        'CG0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'CG0104'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('CG0104', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate'), ('CG0104', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate'), ('CG0104', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate'), ('CG0104', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E04\0E27\0E32\0E21\0E0A\0E38\0E01\0E02\0E2D\0E07\0E41\0E1C\0E25\0E01\0E14\0E17\0E31\0E1A\0E17\0E35\0E48\0E40\0E01\0E34\0E14\0E43\0E19\0E42\0E23\0E07\0E1E\0E22\0E32\0E1A\0E32\0E25', 'Pressure ulcer/injury: Hospital acquired pressure ulcer/Injury (HAPI) rate')
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
