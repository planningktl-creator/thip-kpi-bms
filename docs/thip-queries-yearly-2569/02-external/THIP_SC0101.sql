-- ==============================================================================
-- THIP KPI SC0101 - ร้อยละความพึงพอใจของผู้ป่วยนอก (ภาพรวม)  [ผลรายปี - เทียบเป้าทุกปีใน HIS]
-- Customer: Percent of outpatient satisfaction (overall)
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)
-- รอบรายงานตามเอกสาร: ทุก 6 เดือน (รายครึ่งปี) - ไฟล์นี้แสดงผลเป็นรายปีงบประมาณ
-- เป้าหมาย: อ่านจากตาราง kpi_moph ของ HIS ต่อปีงบ (result -> mean -> c -> b -> a)
--   ปีที่แสดง = ทุกปีที่มีการบันทึกตัวเลขเป้าใน kpi_moph (พ.ศ./ค.ศ. normalise อัตโนมัติ)
--   บวกปีงบตั้งต้นของไฟล์ (thip_params) เป็น fallback เมื่อ kpi_moph ยังว่าง
-- ผลการดําเนินงาน: คํานวณเฉพาะข้อมูลของปีงบนั้น ๆ (ไม่สะสมข้ามปี)
-- THIP KPI Dictionary 2025 หน้า 259 - ทิศทาง: higher-is-better
-- สูตร (ตามเอกสาร): (a/b) x 100
-- ----------------------------------------------------------------------------
-- คอลัมน์ผลลัพธ์: indicator_code, indicator_name_th, indicator_name_en,
--   period_start (1 ต.ค. ของปีงบ), fiscal_year (พ.ศ.), numerator, denominator, value,
--   target (เป้าปีงบจาก kpi_moph), vs_target_pct (ร้อยละเทียบเป้า), status
-- วิธีรัน: แก้ปีงบตั้งต้นที่ FROM (VALUES (2569)) AS v(fiscal_year) ใน CTE thip_params
--   (ใช้เป็น fallback เมื่อ kpi_moph ว่าง; ปีที่แสดงจริงมาจาก kpi_moph)
-- ==============================================================================

-- ==============================================================================
-- THIP KPI SC0101 - ร้อยละความพึงพอใจของผู้ป่วยนอก (ภาพรวม)  [ผลรายเดือน]
-- Customer: Percent of outpatient satisfaction (overall)
-- ----------------------------------------------------------------------------
-- แหล่งข้อมูล: reporting.thip_external_facts (โหลดจากภายนอก)
-- รอบรายงานตามเอกสาร: ทุก 6 เดือน (รายครึ่งปี) - ไฟล์นี้แสดงผลรายเดือน 12 งวด
-- เป้าหมาย: อ่านจากตาราง kpi_moph ของ HIS (ตามปีงบใน thip_params)
-- THIP KPI Dictionary 2025 หน้า 259 - ทิศทาง: higher-is-better
-- สูตร (ตามเอกสาร): (a/b) x 100
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
      years_raw AS (
        SELECT DISTINCT CASE WHEN m.kpi_moph_year >= 2400 THEN m.kpi_moph_year
                             WHEN m.kpi_moph_year BETWEEN 2000 AND 2399 THEN m.kpi_moph_year + 543
                        END AS fiscal_year
        FROM kpi_moph_guideline g
        JOIN kpi_moph m ON m.kpi_moph_guideline_id = g.kpi_moph_guideline_id
        WHERE UPPER(COALESCE(g.kpi_moph_guideline_name, '')) ~
              ('(^|[^0-9A-Z])' || REGEXP_REPLACE('SC0101', '\.', '\.?', 'g') || '($|[^0-9])')
          AND COALESCE(m.kpi_moph_number_result, m.kpi_moph_number_mean,
                       m.kpi_moph_number_c, m.kpi_moph_number_b,
                       m.kpi_moph_number_a) IS NOT NULL
        UNION
        SELECT (SELECT fiscal_year FROM thip_params)
      ),
      years AS (
        SELECT fiscal_year FROM years_raw WHERE fiscal_year IS NOT NULL
      ),
      yspan AS (
        SELECT MIN(make_date(fiscal_year - 544, 10, 1)) AS fy_start,
               MAX(make_date(fiscal_year - 543, 10, 1)) AS fy_end
        FROM years
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
    WHERE x.period_start >= (SELECT fy_start FROM yspan)
      AND x.period_start < (SELECT fy_end FROM yspan)
  ),
      facts AS (
      
      SELECT
        'SC0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0101'
      ),
      agg AS (
        SELECT
          facts.fiscal_year + 543 AS fiscal_year_be,
          SUM(COALESCE(facts.numerator, 0)) AS num_sum,
          SUM(COALESCE(facts.denominator, 0)) AS den_sum,
          SUM(facts.value) AS val_sum
        FROM facts
        GROUP BY 1
      ),
      targets AS (
        SELECT y.fiscal_year,
               MAX(COALESCE(m.kpi_moph_number_result, m.kpi_moph_number_mean,
                            m.kpi_moph_number_c, m.kpi_moph_number_b,
                            m.kpi_moph_number_a)) AS target_value
        FROM years y
        LEFT JOIN kpi_moph_guideline g
          ON UPPER(COALESCE(g.kpi_moph_guideline_name, '')) ~
             ('(^|[^0-9A-Z])' || REGEXP_REPLACE('SC0101', '\.', '\.?', 'g') || '($|[^0-9])')
        LEFT JOIN kpi_moph m
          ON m.kpi_moph_guideline_id = g.kpi_moph_guideline_id
         AND (CASE WHEN m.kpi_moph_year >= 2400 THEN m.kpi_moph_year
                   WHEN m.kpi_moph_year BETWEEN 2000 AND 2399 THEN m.kpi_moph_year + 543 END) = y.fiscal_year
        GROUP BY y.fiscal_year
      ),
      per_year AS (
        SELECT y.fiscal_year,
               COALESCE(a.num_sum, 0) AS numerator,
               COALESCE(a.den_sum, 0) AS denominator,
               CASE WHEN a.num_sum IS NOT NULL AND a.den_sum > 0
                    THEN ROUND(a.num_sum * 100.0 / a.den_sum, 2)
                    ELSE a.val_sum END AS value
        FROM years y
        LEFT JOIN agg a ON a.fiscal_year_be = y.fiscal_year
      )
      SELECT
        'SC0101' AS indicator_code,
        U&'\0E23\0E49\0E2D\0E22\0E25\0E30\0E04\0E27\0E32\0E21\0E1E\0E36\0E07\0E1E\0E2D\0E43\0E08\0E02\0E2D\0E07\0E1C\0E39\0E49\0E1B\0E48\0E27\0E22\0E19\0E2D\0E01\0020\0028\0E20\0E32\0E1E\0E23\0E27\0E21\0029' AS indicator_name_th,
        'Customer: Percent of outpatient satisfaction (overall)' AS indicator_name_en,
        make_date(p.fiscal_year - 544, 10, 1) AS period_start,
        p.fiscal_year AS fiscal_year,
        p.numerator,
        p.denominator,
        p.value,
        t.target_value AS target,
        CASE WHEN p.value IS NULL OR t.target_value IS NULL OR t.target_value = 0
             THEN NULL
             ELSE ROUND(p.value * 100.0 / t.target_value, 2) END AS vs_target_pct,
        CASE WHEN p.value IS NULL THEN 'no-data'
             WHEN t.target_value IS NULL OR 'higher-is-better' = 'neutral' THEN 'unbenchmarked'
             WHEN 'higher-is-better' = 'higher-is-better' AND p.value >= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'higher-is-better' AND p.value >= t.target_value - GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             WHEN 'higher-is-better' = 'lower-is-better' AND p.value <= t.target_value THEN 'on-track'
             WHEN 'higher-is-better' = 'lower-is-better' AND p.value <= t.target_value + GREATEST(ABS(t.target_value) * 0.08, 0.02) THEN 'watch'
             ELSE 'action' END AS status
      FROM per_year p
      LEFT JOIN targets t ON t.fiscal_year = p.fiscal_year
      ORDER BY p.fiscal_year
