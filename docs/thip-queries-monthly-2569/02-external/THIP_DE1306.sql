-- ==============================================================================
-- THIP KPI DE1306 - อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุ 40 ปีขึ้นไป)  [ผลรายเดือน]
-- Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)
-- รอบรายงานตามเอกสาร: ทุกปี (รายปี) - ไฟล์นี้แสดงผลรายเดือน 12 งวด
-- เป้าหมาย: อ่านจากตาราง kpi_moph ของ HIS (ตามปีงบใน thip_params)
-- THIP KPI Dictionary 2025 หน้า 150 - ทิศทาง: higher-is-better
-- สูตร (ตามเอกสาร): (a/b) ข 100
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year,
--   numerator (จำนวนผลงานเดือน), denominator, value (ร้อยละของเดือน),
--   cum_numerator (จำนวนสะสมปีงบ), cum_denominator, cum_value (ร้อยละสะสมปีงบ),
--   target (เป้าปีงบจาก kpi_moph), vs_target_pct / cum_vs_target_pct (ร้อยละเทียบเป้า), status
-- วิธีรัน: แก้ปีงบประมาณที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   ไฟล์นี้กำหนดปีงบให้แล้ว 2569 = 2025-10-01 ถึงวันสุดท้าย 2026-09-30
--   เป้าถูกอ่านสดจาก kpi_moph ของ HIS - โรงพยาบาลที่ยังไม่บันทึกเป้าจะได้ NULL
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
        'DE1306' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1306'
      ), expected_codes(indicator_code, fiscal_month, indicator_name_th, indicator_name_en) AS (
        VALUES

          ('DE1306', 1, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 2, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 3, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 4, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 5, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 6, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 7, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 8, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 9, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 10, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 11, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)'),
          ('DE1306', 12, U&'\0E2D\0E31\0E15\0E23\0E32\0E01\0E32\0E23\0E15\0E31\0E49\0E07\0E04\0E23\0E23\0E20\0E4C\0E15\0E48\0E2D\0E23\0E2D\0E1A\0E01\0E32\0E23\0E43\0E2A\0E48\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0E02\0E2D\0E07\0E1C\0E39\0E49\0E23\0E31\0E1A\0E1A\0E23\0E34\0E01\0E32\0E23\0E17\0E33\0E40\0E14\0E47\0E01\0E2B\0E25\0E2D\0E14\0E41\0E01\0E49\0E27\0E41\0E25\0E30\0E22\0E49\0E32\0E22\0E15\0E31\0E27\0E2D\0E48\0E2D\0E19\0020\0E23\0E2D\0E1A\0E41\0E0A\0E48\0E41\0E02\0E47\0E07\0020\0028\0E01\0E25\0E38\0E48\0E21\0E2D\0E32\0E22\0E38\0020\0034\0030\0020\0E1B\0E35\0E02\0E36\0E49\0E19\0E44\0E1B\0029', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)')
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
      ),
targets AS (
        SELECT v.indicator_code,
               MAX(COALESCE(m.kpi_moph_number_result, m.kpi_moph_number_mean,
                            m.kpi_moph_number_c, m.kpi_moph_number_b,
                            m.kpi_moph_number_a)) AS target_value
        FROM (VALUES
          ('DE1306')
        ) AS v(indicator_code)
        LEFT JOIN kpi_moph_guideline g
          ON UPPER(COALESCE(g.kpi_moph_guideline_name, '')) ~
             ('(^|[^0-9A-Z])' || REGEXP_REPLACE(v.indicator_code, '\.', '\.?', 'g') || '($|[^0-9])')
        LEFT JOIN kpi_moph m
          ON m.kpi_moph_guideline_id = g.kpi_moph_guideline_id
         AND m.kpi_moph_year IN ((SELECT fiscal_year FROM thip_params),
                                 (SELECT fiscal_year FROM thip_params) - 543,
                                 (SELECT fiscal_year FROM thip_params) - 544)
        GROUP BY v.indicator_code
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
        facts.value,
        SUM(COALESCE(facts.numerator, 0)) OVER w AS cum_numerator,
        SUM(COALESCE(facts.denominator, 0)) OVER w AS cum_denominator,
        CASE WHEN SUM(COALESCE(facts.denominator, 0)) OVER w > 0
             THEN ROUND(SUM(COALESCE(facts.numerator, 0)) OVER w * 100.0
                        / SUM(COALESCE(facts.denominator, 0)) OVER w, 2)
             ELSE SUM(facts.value) OVER w END AS cum_value,
        t.target_value AS target,
        CASE WHEN facts.value IS NULL OR t.target_value IS NULL OR t.target_value = 0
             THEN NULL
             ELSE ROUND(facts.value * 100.0 / t.target_value, 2) END AS vs_target_pct,
        CASE WHEN t.target_value IS NULL OR t.target_value = 0
             THEN NULL
             ELSE ROUND((CASE WHEN SUM(COALESCE(facts.denominator, 0)) OVER w > 0
             THEN ROUND(SUM(COALESCE(facts.numerator, 0)) OVER w * 100.0
                        / SUM(COALESCE(facts.denominator, 0)) OVER w, 2)
             ELSE SUM(facts.value) OVER w END) * 100.0 / t.target_value, 2) END AS cum_vs_target_pct,
        CASE WHEN facts.value IS NULL THEN 'no-data'
             WHEN t.target_value IS NULL OR 'higher-is-better' = 'neutral' THEN 'unbenchmarked'
             WHEN 'higher-is-better' = 'higher-is-better' AND facts.value >= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'higher-is-better'
                  AND facts.value >= t.target_value - GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             WHEN 'higher-is-better' = 'lower-is-better' AND facts.value <= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'lower-is-better'
                  AND facts.value <= t.target_value + GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             ELSE 'action' END AS status
      FROM expected_codes
      JOIN fiscal_periods
        ON fiscal_periods.fiscal_month = expected_codes.fiscal_month
      LEFT JOIN facts
        ON facts.indicator_code = expected_codes.indicator_code
       AND facts.period_start = fiscal_periods.period_start
       AND facts.fiscal_month = fiscal_periods.fiscal_month
       AND facts.fiscal_year = fiscal_periods.fiscal_year
      LEFT JOIN targets t ON t.indicator_code = expected_codes.indicator_code
      WINDOW w AS (ORDER BY fiscal_periods.period_start)
      ORDER BY expected_codes.indicator_code, fiscal_periods.period_start
