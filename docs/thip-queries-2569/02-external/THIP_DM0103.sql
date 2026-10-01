-- ==============================================================================
-- THIP KPI DM0103 - ร้อยละเด็กพัฒนาการล่าช้ารอบด้าน (Global development delay: GDD) คงอยู่ใน ระบบการศึกษาได้อย่างน้อย 1 ปี
-- GDD: Percent of children with Global development delay that are included in educational
-- system for at least 1 year
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: พัฒนาการเด็ก/จิตเวชเด็ก (Development)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุกปี (รายปี) - งวดที่คาดหวังในปีงบ: 1 (1 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 162 - ความถี่ตามเอกสาร: ทุก 1 ปี (ตัวชี้วัดรายปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: ร้อยละ 70 (ค่าเฉลี่ยจากการทดลองใช้ตัวชี้วัดเปรียบเทียบ ของกรมสุขภาพจิต กระทรวง สาธารณสุข ระดับเดือนพฤษภาคม 2561 ร้อยละ 75.21 ต่ำสุดร้อยละ 33.33 สูงสุดร้อยละ 100)
-- สูตร (ตามเอกสาร): (a/b) ข 100
--   n. a
--     a = จำนวนเด็กพัฒนาการล่าช้ารอบด้าน (GDD) คงอยู่ในระบบการศึกษาได้ อย่างน้อย 1 ปี (คน)
--   d. b
--     b = จํานวนเด็กพัฒนาการล่าช้ารอบด้าน (GDD) ที่ส่งเข้าระบบการศึกษา (คน)
-- นิยาม:
--   1. เด็กพัฒนาการล่าช้ารอบด้าน หมายถึง เด็กที่ได้รับการวินิจฉัยจากแพทย์ Global developmental
--   delay (F83) หรือ R62 อาจมีหรือไม่มีโรคร่วม ที่มีอายุอยู่ระหว่าง 3 ถึง 5 ปี 11 เดือน 29 วัน
--   2. คงอยู่ในระบบการศึกษาได้อย่างน้อย 1 ปี หมายถึง หลังจากได้เข้าสู่ระบบการศึกษา เช่น
--   การเข้าเรียนในโรงเรียนปกติ โรงเรียนเรียนร่วมหรือโรงเรียนการศึกษาพิเศษ หรือศูนย์
--   พัฒนาเด็กเล็ก ได้อย่างน้อย 1 ปี โดยไม่ถูกส่งกลับหรือถูกปฏิเสธด้วยปัญหาพัฒนาการหรือ พฤติกรรม
-- เป้าหมาย/เกณฑ์ตัดสิน:
--   ร้อยละ 70 (ค่าเฉลี่ยจากการทดลองใช้ตัวชี้วัดเปรียบเทียบ ของกรมสุขภาพจิต กระทรวง สาธารณสุข
--   ระดับเดือนพฤษภาคม 2561 ร้อยละ 75.21 ต่ำสุดร้อยละ 33.33 สูงสุดร้อยละ 100)
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   GDD school retention for at least one year is school-system data, absent from HOSxP. Branch
--   is branchExternal: the hospital must load one row per reporting-period anchor into
--   reporting.thip_external_facts with numerator, denominator, value and source_system, for
--   example sourced from the education referral follow-up register.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0074204, ส่วน #3.2)
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
        'DM0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0103'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('DM0103', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E40\0E14\0E47\0E01\0E1E\0E31\0E12\0E19\0E32\0E01\0E32\0E23\0E25\0E48\0E32\0E0A\0E49\0E32\0E23\0E2D\0E1A\0E14\0E49\0E32\0E19\0020\0028\0047\006C\006F\0062\0061\006C\0020\0064\0065\0076\0065\006C\006F\0070\006D\0065\006E\0074\0020\0064\0065\006C\0061\0079\003A\0020\0047\0044\0044\0029\0020\0E04\0E07\0E2D\0E22\0E39\0E48\0E43\0E19\0020\0E23\0E30\0E1A\0E1A\0E01\0E32\0E23\0E28\0E36\0E01\0E29\0E32\0E44\0E14\0E49\0E2D\0E22\0E48\0E32\0E07\0E19\0E49\0E2D\0E22\0020\0031\0020\0E1B\0E35', 'GDD: Percent of children with Global development delay that are included in educational system for at least 1 year')
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
