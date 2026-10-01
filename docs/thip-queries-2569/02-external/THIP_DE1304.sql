-- ==============================================================================
-- THIP KPI DE1304 - อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุน้อยกว่า 34 ปี)
-- Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo
-- transfer (age < 34 years)
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: ทารกแรกเกิด/เด็ก (Newborn & child)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกปี (รายปี) - งวดที่คาดหวังในปีงบ: 1 (1 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 148 - ความถี่ตามเอกสาร: ทุก 1 ปี (ตัวชี้วัดรายปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: ร้อยละ 30, สมาคมนักวิทยาศาสตร์เพาะเลี้ยงตัวอ่อนแห่งประเทศไทย สน.พท.
-- สูตร (ตามเอกสาร): (a/b) ข 100
--   n. a
--     a = จำนวนสตรีผู้รับบริการที่ได้รับการยืนยันการตั้งครรภ์ (กลุ่มอายุน้อยกว่า 34 ปี) ที่มี
--     การเต้นของหัวใจทารก จากการตรวจด้วยเครื่องความถี่สูง จากการใส่ตัวอ่อนรอบแช่แข็ง
--     ในช่วงระยะเวลาหนึ่งปี
--   d. b
--     b = จำนวนครั้งของการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน
--     รอบแช่แข็งทั้งหมด (กลุ่มอายุน้อยกว่า 34 ปี) ในช่วงเวลาเดียวกัน
-- นิยาม:
--   1. การทำเด็กหลอดแก้ว หมายถึง การใช้เทคโนโลยีช่วยการเจริญพันธุ์ ด้วยการปฏิสนธินอก ร่างกาย
--   อันได้แก่ การผสมนอกร่างกายในจานเพาะเลี้ยง (standard in vitro fertilisation)
--   และการฉีดตัวอสุจิเข้าเซลล์ไข่โดยตรง (ICSI-intracytoplasmic sperm injection) โดยทำ
--   การย้ายตัวอ่อนที่ผ่านการแช่แข็ง ละลาย และ/หรือเพาะเลี้ยงต่อหลังละลายตัวอ่อน
--   เข้าในโพรงมดลูกของสตรีผู้รับบริการ 2. Clinical pregnancy หมายถึง
--   การตรวจด้วยเครื่องความถี่สูง ยืนยันการตั้งครรภ์ของตัว อ่อนมีชีพ (มีการเต้นของหัวใจ)
--   ในโพรงมดลูกที่อายุครรภ์ 6-8 สัปดาห์ หรือ 3-5 สัปดาห์ หลังการใส่ตัวอ่อน
-- เป้าหมาย/เกณฑ์ตัดสิน:
--   ร้อยละ 30, สมาคมนักวิทยาศาสตร์เพาะเลี้ยงตัวอ่อนแห่งประเทศไทย สน.พท.
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   External branch: frozen thawed embryo transfer cycles (age under 34) are not in HOSxP.
--   Staging requirement: one reporting.thip_external_facts row per fiscal year anchor
--   (period_start equal to the first day of October of the fiscal year) with indicator_code
--   DE1304, numerator equal to women under 34 with clinical pregnancy after a frozen embryo
--   transfer, denominator equal to frozen transfer cycles in the same band, value equal to
--   numerator times 100 over denominator, and source_system naming the IVF system. Confirm that
--   thawed and cultured after thaw transfers both count as frozen cycles.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0073880, ส่วน #3.2)
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
        'DE1304' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1304'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DE1304', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0E19\0E49\0E2D\0E22\0E01\0E27\0E48\0E32\0020\0033\0034\0020\0E1B\0E35\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years)')
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
