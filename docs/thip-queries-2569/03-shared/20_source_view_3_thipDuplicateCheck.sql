-- ==============================================================================
-- #6.3 ตรวจ duplicate
-- ต้องมีตาราง reporting.thip_kpi_monthly (ดู 21_...) และ bind :fiscal_year เพิ่ม
-- ==============================================================================

SELECT
        indicator_code,
        period_start,
        fiscal_year,
        fiscal_month,
        COUNT(*) AS row_count
      FROM "reporting"."thip_kpi_monthly"
      WHERE period_start >= DATE '2025-10-01'
        AND period_start < DATE '2026-10-01'
        AND fiscal_year = 2569
      GROUP BY indicator_code, period_start, fiscal_year, fiscal_month
      HAVING COUNT(*) <> 1
      ORDER BY indicator_code, period_start
