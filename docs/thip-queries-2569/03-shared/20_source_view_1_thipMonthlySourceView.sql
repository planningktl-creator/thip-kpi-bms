-- ==============================================================================
-- #6.1 อ่านผลลัพธ์จาก source view
-- ต้องมีตาราง reporting.thip_kpi_monthly (ดู 21_...) และ bind :fiscal_year เพิ่ม
-- ==============================================================================

SELECT
        indicator_code,
        period_start,
        fiscal_year,
        fiscal_month,
        numerator,
        denominator,
        value,
        target,
        target_scope,
        percentile,
        indicator_group,
        unit,
        direction,
        category,
        title,
        title_th,
        definition,
        formula,
        numerator_label,
        denominator_label,
        source_tables,
        frequency,
        reference,
        rule_version,
        pending_reason,
        refreshed_at
      FROM "reporting"."thip_kpi_monthly"
      WHERE period_start >= DATE '2025-10-01'
        AND period_start < DATE '2026-10-01'
        AND fiscal_year = 2569
      ORDER BY indicator_code, fiscal_month
