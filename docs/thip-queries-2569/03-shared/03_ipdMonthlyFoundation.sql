-- ==============================================================================
-- #4.2 ipdMonthlyFoundation - โครงข้อมูล IPD รายเดือน
-- ตรวจภาพรวม IPD รายเดือน (จำนวน discharge, ยังไม่ใส่ DRG, adjRW เฉลี่ย)
-- ==============================================================================

SELECT
        DATE_TRUNC('month', ipt.dchdate)::date AS month_start,
        COUNT(DISTINCT ipt.an)::integer AS discharges,
        COUNT(DISTINCT CASE WHEN NULLIF(TRIM(ipt.drg), '') IS NULL THEN ipt.an END)::integer AS uncoded_cases,
        AVG(ipt.adjrw)::numeric AS mean_adjrw
      FROM ipt
      WHERE ipt.dchdate >= DATE '2025-10-01'
        AND ipt.dchdate < DATE '2026-10-01'
      GROUP BY DATE_TRUNC('month', ipt.dchdate)
      ORDER BY month_start
