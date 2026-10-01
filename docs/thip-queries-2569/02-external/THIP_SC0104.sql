-- ==============================================================================
-- THIP KPI SC0104 - ร้อยละของผู้ป่วยในที่จะกลับมาใช้บริการซ้ำ
-- Customer: Percent of inpatients who return to receive care
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)   |   กลุ่มงาน: ความพึงพอใจลูกค้า (Customer)
-- ตารางที่อ้างอิง: reporting.thip_external_facts (ตาราง staging)
-- รอบรายงาน: ทุก 6 เดือน (รายครึ่งปี) - งวดที่คาดหวังในปีงบ: 1, 7 (2 แถวผลลัพธ์)
-- THIP KPI Dictionary 2025 หน้า 262 - ความถี่ตามเอกสาร: ทุก 6 เดือน (ตัวชี้วัดรายครึ่งปี)
-- ระดับการขึ้นทะเบียน: registered - ทิศทาง: higher-is-better - ค่าเป้าหมาย: เอกสารไม่ระบุ
-- สูตร (ตามเอกสาร): (a/b) x 100
--   n. a
--     a = จำนวนผู้ตอบแบบสอบถามประมาณ 20% ของจำนวนผู้ป่วยที่เข้ารับการตรวจรักษาใน
--     โรงพยาบาลที่ตอบว่าจะกลับมารักษาในครั้งต่อไป
--   d. b
--     b = จำนวนผู้ตอบแบบสอบถามประมาณ 20% ของจำนวนผู้ป่วยที่เข้ารับการตรวจรักษา
--     ในโรงพยาบาลที่ตอบแบบสอบถามทั้งหมด
-- นิยาม:
--   1. เป็นความพึงพอใจต่อโรงพยาบาลของผู้รับบริการ และการกลับมารักษาต่อเนื่อง 2. วิธีการประเมิน
--   โดยใช้แบบสอบถามชุดเดียวกับการประเมินความพึงพอใจของผู้ป่วยใน ซึ่งมีข้อคำถาม
--   "ถ้าท่านสามารถเลือกโรงพยาบาลได้ท่านจะเลือกกลับมาใช้บริการที่ รพ. นี้อีกหรือไม่"
--   และมีคำตอบให้เลือก 2 ข้อ คือมา/ไม่มา 3. การวัดผลการประเมิน
--   โดยคำนวณหาค่าของผู้รับบริการที่จะกลับมารับบริการซ้ำ
-- หมายเหตุการประมาณ (ต้องยืนยันกฎ local):
--   Measures: Percent of inpatients who return to receive care: share of IPD questionnaire
--   respondents answering yes (come) to the question asking whether they would choose this
--   hospital again (THIP page 262). The branch is branchExternal over
--   reporting.thip_external_facts. PDF beyond the branch: the binary return-intention item of
--   the printed IPD questionnaire (answers come or not come), answered by roughly 20 percent of
--   the inpatient volume of the period. Confirm with the hospital owner: which installed
--   question of the IPD instrument is the printed return-intention item, that its positive
--   answer is the come option, and that the sample is roughly 20 percent of inpatient
--   admissions in the period. Staging rows for reporting.thip_external_facts (columns
--   indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows:
--   one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal
--   months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April). numerator
--   (a) = count of sampled IPD respondents answering they would come back. denominator (b) =
--   count of all sampled IPD respondents answering the questionnaire in the period. value =
--   ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100.
--   source_system = 'thip-survey-ipd'. Source check: the HOSxP survey tables were verified
--   column by column and cannot confirm the printed instrument or score scale.
--   survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age,
--   survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5,
--   hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD
--   respondents cannot be separated from IPD respondents and the unconfirmed semantics of
--   survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale.
--   survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id,
--   survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu
--   (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no,
--   survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per
--   question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name,
--   survey_satisfy_part), whose installed wording version is unverifiable local data.
--   dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id,
--   dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the
--   drug information service instrument, not to the printed patient satisfaction questionnaire.
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   ไม่ต้องแก้ :start_date / :end_date (แปลงเป็น thip_params ให้แล้ว); ผลลัพธ์ aggregate เท่านั้น
--   ต้องมีแถวของรหัสนี้ใน reporting.thip_external_facts ก่อน (ดู 03-shared/)
-- ไฟล์รวมทุกคำสั่ง: docs/THIP-ALL-QUERIES-2569.sql (รหัสนี้ที่บรรทัด L0075014, ส่วน #3.2)
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
        'SC0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0104'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES
          ('SC0104', 1, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E17\0E35\0E48\0E08\0E30\0E01\0E25\0E31\0E1A\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23\0E0B\0E49\0E33', 'Customer: Percent of inpatients who return to receive care'), ('SC0104', 7, U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E43\0E19\0E17\0E35\0E48\0E08\0E30\0E01\0E25\0E31\0E1A\0E21\0E32\0E43\0E0A\0E49\0E1A\0E23\0E34\0E01\0E32\0E23\0E0B\0E49\0E33', 'Customer: Percent of inpatients who return to receive care')
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
