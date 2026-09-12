-- THIP KPI normalized source-view table (read-only reporting layer).
-- Populate per fiscal year with buildSourceViewRefreshSql(); the app reads it
-- through VITE_BMS_KPI_SOURCE_VIEW and never writes to HOSxP.
CREATE TABLE IF NOT EXISTS reporting.thip_kpi_monthly (
  indicator_code   varchar(10)  NOT NULL,
  period_start     date         NOT NULL,
  fiscal_year      integer      NOT NULL,
  fiscal_month     smallint     NOT NULL CHECK (fiscal_month BETWEEN 1 AND 12),
  numerator        numeric(18, 4),
  denominator      numeric(18, 4),
  value            numeric(18, 4),
  target           numeric(18, 4),
  target_scope     varchar(16)  NOT NULL CHECK (target_scope IN ('monthly', 'annual')),
  percentile       numeric(18, 4),
  indicator_group  varchar(1)   NOT NULL CHECK (indicator_group IN ('A', 'C', 'D', 'H', 'S')),
  unit             varchar(16)  NOT NULL CHECK (unit IN ('percent', 'rate', 'ratio', 'count')),
  direction        varchar(32)  NOT NULL CHECK (direction IN ('higher-is-better', 'lower-is-better', 'neutral')),
  category         text         NOT NULL,
  title            text         NOT NULL,
  title_th         text,
  definition       text         NOT NULL,
  formula          text         NOT NULL,
  numerator_label  text         NOT NULL,
  denominator_label text        NOT NULL,
  source_tables    text[]       NOT NULL CHECK (cardinality(source_tables) > 0),
  frequency        text         NOT NULL,
  reference        text         NOT NULL,
  rule_version     varchar(64)  NOT NULL,
  pending_reason   text,
  tier             varchar(32)  NOT NULL CHECK (tier IN ('registered', 'pending-local-source')),
  refreshed_at     timestamptz  NOT NULL,
  CHECK (unit = 'count' OR denominator IS NOT NULL OR value IS NULL),
  CHECK (denominator IS NULL OR denominator <> 0 OR value IS NULL),
  CHECK (percentile IS NULL OR percentile BETWEEN 0 AND 100),
  UNIQUE (indicator_code, period_start, fiscal_year, fiscal_month)
);

-- Refresh one fiscal year of the normalized THIP source view.
-- Bind: :fiscal_year (integer), :start_date = YYYY-10-01, :end_date = next YYYY-10-01 (exclusive).
DELETE FROM reporting.thip_kpi_monthly WHERE fiscal_year = :fiscal_year;

INSERT INTO reporting.thip_kpi_monthly (
  indicator_code, period_start, fiscal_year, fiscal_month,
  numerator, denominator, value, target, target_scope, percentile,
  indicator_group, unit, direction, category, title, title_th,
  definition, formula, numerator_label, denominator_label,
  source_tables, frequency, reference, rule_version, pending_reason, tier, refreshed_at
)
WITH
WITH ipd AS (
    SELECT
      i.an,
      i.hn,
      i.regdate,
      i.regtime,
      i.dchdate,
      COALESCE(i.bw, 0) AS bw,
      s.age_y,
      s.los,
      REPLACE(UPPER(TRIM(s.pdx)), '.', '') AS pdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
      ) AS died,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
      ) AS has_acs_sdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_cause)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_1)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_2)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_3)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_4)), '.', '') IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
          )
      ) AS died_from_acs,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
      ) AS has_stemi_sdx,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I214', 'I219')
      ) AS has_nste_sdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND d.death_date IS NOT NULL
          AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
            (i.regdate + COALESCE(i.regtime, TIME '00:00:00'))
          AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
            (i.regdate + COALESCE(i.regtime, TIME '00:00:00')) + INTERVAL '48 hours'
      ) AS died_within_48h,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_cause)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_1)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_2)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_3)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
            OR REPLACE(UPPER(TRIM(d.death_diag_4)), '.', '') IN ('I210', 'I211', 'I212', 'I213')
          )
      ) AS died_from_stemi,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_cause)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_1)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_2)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_3)), '.', '') IN ('I214', 'I219')
            OR REPLACE(UPPER(TRIM(d.death_diag_4)), '.', '') IN ('I214', 'I219')
          )
      ) AS died_from_nste,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') <> REPLACE(UPPER(TRIM(s.pdx)), '.', '')
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
          )
      ) AS has_pneumonia_sdx,
      EXISTS (
        SELECT 1
        FROM death d
        WHERE d.an = i.an
          AND (
            LEFT(REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_icd10)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_cause)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_cause)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_1)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_1)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_2)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_2)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_3)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_3)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_4)), '.', ''), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
            OR LEFT(REPLACE(UPPER(TRIM(d.death_diag_4)), '.', ''), 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851')
          )
      ) AS died_from_pneumonia,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A400', 'A419', 'R572', 'R651')
      ) AS has_ce0101_sepsis,
      EXISTS (
        SELECT 1
        FROM iptdiag sd
        WHERE sd.an = i.an
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651')
      ) AS has_ci0101_sepsis
    FROM ipt i
    JOIN an_stat s ON s.an = i.an
    WHERE i.dchdate >= :start_date
      AND i.dchdate < :end_date
      AND i.regdate IS NOT NULL
      AND EXTRACT(EPOCH FROM (
        (i.dchdate + COALESCE(i.dchtime, TIME '23:59:59')) -
        (i.regdate + COALESCE(i.regtime, TIME '00:00:00'))
      )) >= 14400
  ),
  periodized AS (
    SELECT
      *,
      DATE_TRUNC('month', dchdate)::date AS period_start,
      EXTRACT(MONTH FROM dchdate)::integer AS calendar_month
    FROM ipd
  ),
facts AS (

      SELECT
        'DH0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND died) OR (has_acs_sdx AND died_from_acs)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND died) OR (has_acs_sdx AND died_from_acs)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') OR has_acs_sdx)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0101.1' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213') AND died) OR (has_stemi_sdx AND died_from_stemi)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213') AND died) OR (has_stemi_sdx AND died_from_stemi)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213') OR has_stemi_sdx)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0101.2' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('I214', 'I219') AND died) OR (has_nste_sdx AND died_from_nste)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('I214', 'I219') AND died) OR (has_nste_sdx AND died_from_nste)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND (pdx IN ('I214', 'I219') OR has_nste_sdx)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.name ILIKE '%aspirin%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 86400)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.name ILIKE '%aspirin%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 86400)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0112' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DN0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DN0107' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DN0109' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DN0302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died_within_48h) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died_within_48h) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18') OR has_pneumonia_sdx
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18') OR has_pneumonia_sdx
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0403' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'J44'
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CE0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.antibiotic = 'Y'
            AND di.drugcategory ILIKE '%broad%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 10800)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.antibiotic = 'Y'
            AND di.drugcategory ILIKE '%broad%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 10800)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('A400', 'A419', 'R572', 'R651') OR has_ce0101_sepsis
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CI0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651') OR has_ci0101_sepsis
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DG0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DG0202' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) = 'K35'
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0401' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C33','C34','C37','C38','C39','C40','C41','C43','C44','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65','C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C77','C78','C79','C80','C81','C82','C83','C84','C85','C86','C87','C88','C89','C90','C91','C92','C93','C94','C95','C96','C97','D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','Z510','Z511')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('A15', 'A16')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DG0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE pdx = 'K352') AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE pdx = 'K352') * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('K35', 'K352', 'K353', 'K358')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0111' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('J45', 'J46')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0401' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'J44'
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DG0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0105' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (
              di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%'
              OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%'
              OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%'
              OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%'
              OR di.name ILIKE '%spironolactone%' OR di.name ILIKE '%eplerenone%'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (
              di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%'
              OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%'
              OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%'
              OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%'
              OR di.name ILIKE '%spironolactone%' OR di.name ILIKE '%eplerenone%'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'I50' AND NOT EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46'))
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE 
      LEFT(pdx, 3) = 'I50'
      AND (
        EXISTS (
          SELECT 1 FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17' OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720')
        )
        OR EXISTS (
          SELECT 1 FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND scr.smoking_type_id IN (2, 3)
        )
      )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0202' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0203' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T814', 'T826', 'T827')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T814', 'T826', 'T827')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DH0204' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died OR EXISTS (
          SELECT 1
          FROM death d
          WHERE (d.an = periodized.an OR d.hn = periodized.hn)
            AND d.death_date IS NOT NULL
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '30 days'
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (
        WHERE died OR EXISTS (
          SELECT 1
          FROM death d
          WHERE (d.an = periodized.an OR d.hn = periodized.hn)
            AND d.death_date IS NOT NULL
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '30 days'
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        )
      ) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DO0202' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DO0204' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T845'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '365 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T845'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T845'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T845'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '365 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T845'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T845'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DO0205' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T845', 'T814')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '90 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T845', 'T814')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T845', 'T814')
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T845', 'T814')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '90 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T845', 'T814')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T845', 'T814')
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DO0302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DO0303' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T845'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '365 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T845'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T845'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T845'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '365 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T845'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T845'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DO0304' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T845', 'T814')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '90 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T845', 'T814')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T845', 'T814')
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T845', 'T814')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '90 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T845', 'T814')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T845', 'T814')
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE 
      LEFT(pdx, 3) IN ('J45', 'J46')
      AND (
        EXISTS (
          SELECT 1 FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17' OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720')
        )
        OR EXISTS (
          SELECT 1 FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND scr.smoking_type_id IN (2, 3)
        )
      )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DR0404' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE 
      age_y >= 18 AND LEFT(pdx, 3) = 'J44'
      AND (
        EXISTS (
          SELECT 1 FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17' OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720')
        )
        OR EXISTS (
          SELECT 1 FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND scr.smoking_type_id IN (2, 3)
        )
      )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) FILTER (WHERE NOT died) AS denominator,
        ROUND((
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        )) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT died), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0107' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'O72'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O72'
           )
           OR EXISTS (
              SELECT 1 FROM labor lb
              WHERE lb.an = periodized.an
                AND COALESCE(lb.placenta_bloodloss, 0) >= 500
            )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE LEFT(pdx, 3) = 'O72' OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O72') OR EXISTS (SELECT 1 FROM labor lb WHERE lb.an = periodized.an AND COALESCE(lb.placenta_bloodloss, 0) >= 500)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) IN ('O80', 'O81', 'O83') OR pdx IN ('O840', 'O841', 'O848', 'O849'))
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0109' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'O15'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O15'
           )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE LEFT(pdx, 3) = 'O15' OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O15')) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 1) = 'O'
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0110' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE pdx = 'O244'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O244'
           )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE pdx = 'O244' OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O244')) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 1) = 'O'
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0116' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0117' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T814'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T814'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T814'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T814'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T814'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T814'
            ))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
    )
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0118' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AND NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) AS numerator,
        COUNT(*) FILTER (WHERE NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AND NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0119' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0204' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'P21'
           OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'P21')
           OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar1 <= 7 OR nb.has_asphyxia = 'Y'))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND(
        COUNT(*) FILTER (
          WHERE LEFT(pdx, 3) = 'P21'
             OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'P21')
             OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar1 <= 7 OR nb.has_asphyxia = 'Y'))
        ) * 1000.0 / NULLIF(COUNT(*), 0),
        2
      ) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0205' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE pdx = 'P210'
           OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'P210')
           OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar2 <= 4 OR nb.apgar1 <= 3))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND(
        COUNT(*) FILTER (
          WHERE pdx = 'P210'
             OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'P210')
             OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar2 <= 4 OR nb.apgar1 <= 3))
        ) * 1000.0 / NULLIF(COUNT(*), 0),
        2
      ) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0206' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 2500)
           OR (periodized.bw > 0 AND periodized.bw < 2500)
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 2500) OR (periodized.bw > 0 AND periodized.bw < 2500)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0207' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000)
          OR (periodized.bw > 0 AND periodized.bw < 1000)
        )
      ) AS numerator,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000)
           OR (periodized.bw > 0 AND periodized.bw < 1000)
      ) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died AND (EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000) OR (periodized.bw > 0 AND periodized.bw < 1000))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000) OR (periodized.bw > 0 AND periodized.bw < 1000)), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0208' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499)
          OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)
        )
      ) AS numerator,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499)
           OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)
      ) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died AND (EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'CM0209' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499)
          OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)
        )
      ) AS numerator,
        COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499)
           OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)
      ) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died AND (EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499) OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) = 'Z38' OR age_y = 0)
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.hn) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('9502', '9503', '9512')
        )
        OR EXISTS (
          SELECT 1 FROM ovstdiag od
          JOIN ovst ov ON ov.vn = od.vn
          WHERE ov.hn = periodized.hn
            AND REPLACE(UPPER(TRIM(od.icd10)), '.', '') IN ('Z010', 'Z135')
            AND ov.vstdate >= :start_date AND ov.vstdate < :end_date
        )
      ) AS numerator,
        COUNT(DISTINCT periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('9502', '9503', '9512')) OR EXISTS (SELECT 1 FROM ovstdiag od JOIN ovst ov ON ov.vn = od.vn WHERE ov.hn = periodized.hn AND REPLACE(UPPER(TRIM(od.icd10)), '.', '') IN ('Z010', 'Z135') AND ov.vstdate >= :start_date AND ov.vstdate < :end_date)) * 100.0) / NULLIF(COUNT(DISTINCT periodized.hn), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0107' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8410', '8411', '8412', '8413', '8414', '8415', '8416', '8417', '8418', '8419')
        )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8410', '8411', '8412', '8413', '8414', '8415', '8416', '8417', '8418', '8419'))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0108' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE ((age_y < 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0))
            OR (age_y >= 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE ((age_y < 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0)) OR (age_y >= 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0108.1' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 60 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0108.2' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND age_y < 60 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE ((age_y < 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80))
            OR (age_y >= 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)))
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE ((age_y < 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80)) OR (age_y >= 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0201.1' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND age_y < 65 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DC0201.2' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 65 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      GROUP BY period_start, calendar_month

  UNION ALL

      SELECT
        'DP0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= :start_date AND lh.order_date < :end_date
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END < 7.5
        )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM lab_order lo JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number JOIN lab_items li ON li.lab_items_code = lo.lab_items_code WHERE lh.hn = periodized.hn AND li.lab_items_name ILIKE '%hba1c%' AND lh.order_date >= :start_date AND lh.order_date < :end_date AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END < 7.5)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y < 18 AND (LEFT(pdx, 3) = 'E10' OR pdx IN ('E891', 'P702'))
      GROUP BY period_start, calendar_month
),
expected(indicator_code, fiscal_month) AS (
  VALUES
    ('AA0101', 1),
    ('AA0102', 1),
    ('AA0103', 1),
    ('AA0104', 1),
    ('AA0105', 1),
    ('CA0101', 1),
    ('CA0101', 2),
    ('CA0101', 3),
    ('CA0101', 4),
    ('CA0101', 5),
    ('CA0101', 6),
    ('CA0101', 7),
    ('CA0101', 8),
    ('CA0101', 9),
    ('CA0101', 10),
    ('CA0101', 11),
    ('CA0101', 12),
    ('CA0102', 1),
    ('CA0102', 2),
    ('CA0102', 3),
    ('CA0102', 4),
    ('CA0102', 5),
    ('CA0102', 6),
    ('CA0102', 7),
    ('CA0102', 8),
    ('CA0102', 9),
    ('CA0102', 10),
    ('CA0102', 11),
    ('CA0102', 12),
    ('CA0103', 1),
    ('CA0103', 2),
    ('CA0103', 3),
    ('CA0103', 4),
    ('CA0103', 5),
    ('CA0103', 6),
    ('CA0103', 7),
    ('CA0103', 8),
    ('CA0103', 9),
    ('CA0103', 10),
    ('CA0103', 11),
    ('CA0103', 12),
    ('CA0104', 1),
    ('CA0104', 2),
    ('CA0104', 3),
    ('CA0104', 4),
    ('CA0104', 5),
    ('CA0104', 6),
    ('CA0104', 7),
    ('CA0104', 8),
    ('CA0104', 9),
    ('CA0104', 10),
    ('CA0104', 11),
    ('CA0104', 12),
    ('CA0105', 1),
    ('CA0105', 2),
    ('CA0105', 3),
    ('CA0105', 4),
    ('CA0105', 5),
    ('CA0105', 6),
    ('CA0105', 7),
    ('CA0105', 8),
    ('CA0105', 9),
    ('CA0105', 10),
    ('CA0105', 11),
    ('CA0105', 12),
    ('CE0101', 1),
    ('CE0101', 2),
    ('CE0101', 3),
    ('CE0101', 4),
    ('CE0101', 5),
    ('CE0101', 6),
    ('CE0101', 7),
    ('CE0101', 8),
    ('CE0101', 9),
    ('CE0101', 10),
    ('CE0101', 11),
    ('CE0101', 12),
    ('CE0102', 1),
    ('CE0102', 2),
    ('CE0102', 3),
    ('CE0102', 4),
    ('CE0102', 5),
    ('CE0102', 6),
    ('CE0102', 7),
    ('CE0102', 8),
    ('CE0102', 9),
    ('CE0102', 10),
    ('CE0102', 11),
    ('CE0102', 12),
    ('CE0103', 1),
    ('CE0103', 2),
    ('CE0103', 3),
    ('CE0103', 4),
    ('CE0103', 5),
    ('CE0103', 6),
    ('CE0103', 7),
    ('CE0103', 8),
    ('CE0103', 9),
    ('CE0103', 10),
    ('CE0103', 11),
    ('CE0103', 12),
    ('CE0104', 1),
    ('CE0104', 2),
    ('CE0104', 3),
    ('CE0104', 4),
    ('CE0104', 5),
    ('CE0104', 6),
    ('CE0104', 7),
    ('CE0104', 8),
    ('CE0104', 9),
    ('CE0104', 10),
    ('CE0104', 11),
    ('CE0104', 12),
    ('CG0101', 1),
    ('CG0101', 2),
    ('CG0101', 3),
    ('CG0101', 4),
    ('CG0101', 5),
    ('CG0101', 6),
    ('CG0101', 7),
    ('CG0101', 8),
    ('CG0101', 9),
    ('CG0101', 10),
    ('CG0101', 11),
    ('CG0101', 12),
    ('CG0102', 1),
    ('CG0102', 2),
    ('CG0102', 3),
    ('CG0102', 4),
    ('CG0102', 5),
    ('CG0102', 6),
    ('CG0102', 7),
    ('CG0102', 8),
    ('CG0102', 9),
    ('CG0102', 10),
    ('CG0102', 11),
    ('CG0102', 12),
    ('CG0103', 1),
    ('CG0103', 4),
    ('CG0103', 7),
    ('CG0103', 10),
    ('CG0104', 1),
    ('CG0104', 4),
    ('CG0104', 7),
    ('CG0104', 10),
    ('CI0101', 1),
    ('CI0101', 2),
    ('CI0101', 3),
    ('CI0101', 4),
    ('CI0101', 5),
    ('CI0101', 6),
    ('CI0101', 7),
    ('CI0101', 8),
    ('CI0101', 9),
    ('CI0101', 10),
    ('CI0101', 11),
    ('CI0101', 12),
    ('CM0101', 1),
    ('CM0104', 1),
    ('CM0104', 2),
    ('CM0104', 3),
    ('CM0104', 4),
    ('CM0104', 5),
    ('CM0104', 6),
    ('CM0104', 7),
    ('CM0104', 8),
    ('CM0104', 9),
    ('CM0104', 10),
    ('CM0104', 11),
    ('CM0104', 12),
    ('CM0105', 1),
    ('CM0105', 2),
    ('CM0105', 3),
    ('CM0105', 4),
    ('CM0105', 5),
    ('CM0105', 6),
    ('CM0105', 7),
    ('CM0105', 8),
    ('CM0105', 9),
    ('CM0105', 10),
    ('CM0105', 11),
    ('CM0105', 12),
    ('CM0107', 1),
    ('CM0107', 2),
    ('CM0107', 3),
    ('CM0107', 4),
    ('CM0107', 5),
    ('CM0107', 6),
    ('CM0107', 7),
    ('CM0107', 8),
    ('CM0107', 9),
    ('CM0107', 10),
    ('CM0107', 11),
    ('CM0107', 12),
    ('CM0109', 1),
    ('CM0109', 2),
    ('CM0109', 3),
    ('CM0109', 4),
    ('CM0109', 5),
    ('CM0109', 6),
    ('CM0109', 7),
    ('CM0109', 8),
    ('CM0109', 9),
    ('CM0109', 10),
    ('CM0109', 11),
    ('CM0109', 12),
    ('CM0110', 1),
    ('CM0110', 2),
    ('CM0110', 3),
    ('CM0110', 4),
    ('CM0110', 5),
    ('CM0110', 6),
    ('CM0110', 7),
    ('CM0110', 8),
    ('CM0110', 9),
    ('CM0110', 10),
    ('CM0110', 11),
    ('CM0110', 12),
    ('CM0116', 1),
    ('CM0116', 2),
    ('CM0116', 3),
    ('CM0116', 4),
    ('CM0116', 5),
    ('CM0116', 6),
    ('CM0116', 7),
    ('CM0116', 8),
    ('CM0116', 9),
    ('CM0116', 10),
    ('CM0116', 11),
    ('CM0116', 12),
    ('CM0117', 1),
    ('CM0117', 2),
    ('CM0117', 3),
    ('CM0117', 4),
    ('CM0117', 5),
    ('CM0117', 6),
    ('CM0117', 7),
    ('CM0117', 8),
    ('CM0117', 9),
    ('CM0117', 10),
    ('CM0117', 11),
    ('CM0117', 12),
    ('CM0118', 1),
    ('CM0118', 2),
    ('CM0118', 3),
    ('CM0118', 4),
    ('CM0118', 5),
    ('CM0118', 6),
    ('CM0118', 7),
    ('CM0118', 8),
    ('CM0118', 9),
    ('CM0118', 10),
    ('CM0118', 11),
    ('CM0118', 12),
    ('CM0119', 1),
    ('CM0119', 2),
    ('CM0119', 3),
    ('CM0119', 4),
    ('CM0119', 5),
    ('CM0119', 6),
    ('CM0119', 7),
    ('CM0119', 8),
    ('CM0119', 9),
    ('CM0119', 10),
    ('CM0119', 11),
    ('CM0119', 12),
    ('CM0201', 1),
    ('CM0201', 2),
    ('CM0201', 3),
    ('CM0201', 4),
    ('CM0201', 5),
    ('CM0201', 6),
    ('CM0201', 7),
    ('CM0201', 8),
    ('CM0201', 9),
    ('CM0201', 10),
    ('CM0201', 11),
    ('CM0201', 12),
    ('CM0202', 1),
    ('CM0202', 2),
    ('CM0202', 3),
    ('CM0202', 4),
    ('CM0202', 5),
    ('CM0202', 6),
    ('CM0202', 7),
    ('CM0202', 8),
    ('CM0202', 9),
    ('CM0202', 10),
    ('CM0202', 11),
    ('CM0202', 12),
    ('CM0203', 1),
    ('CM0203', 2),
    ('CM0203', 3),
    ('CM0203', 4),
    ('CM0203', 5),
    ('CM0203', 6),
    ('CM0203', 7),
    ('CM0203', 8),
    ('CM0203', 9),
    ('CM0203', 10),
    ('CM0203', 11),
    ('CM0203', 12),
    ('CM0204', 1),
    ('CM0204', 2),
    ('CM0204', 3),
    ('CM0204', 4),
    ('CM0204', 5),
    ('CM0204', 6),
    ('CM0204', 7),
    ('CM0204', 8),
    ('CM0204', 9),
    ('CM0204', 10),
    ('CM0204', 11),
    ('CM0204', 12),
    ('CM0205', 1),
    ('CM0205', 2),
    ('CM0205', 3),
    ('CM0205', 4),
    ('CM0205', 5),
    ('CM0205', 6),
    ('CM0205', 7),
    ('CM0205', 8),
    ('CM0205', 9),
    ('CM0205', 10),
    ('CM0205', 11),
    ('CM0205', 12),
    ('CM0206', 1),
    ('CM0206', 2),
    ('CM0206', 3),
    ('CM0206', 4),
    ('CM0206', 5),
    ('CM0206', 6),
    ('CM0206', 7),
    ('CM0206', 8),
    ('CM0206', 9),
    ('CM0206', 10),
    ('CM0206', 11),
    ('CM0206', 12),
    ('CM0207', 1),
    ('CM0207', 2),
    ('CM0207', 3),
    ('CM0207', 4),
    ('CM0207', 5),
    ('CM0207', 6),
    ('CM0207', 7),
    ('CM0207', 8),
    ('CM0207', 9),
    ('CM0207', 10),
    ('CM0207', 11),
    ('CM0207', 12),
    ('CM0208', 1),
    ('CM0208', 2),
    ('CM0208', 3),
    ('CM0208', 4),
    ('CM0208', 5),
    ('CM0208', 6),
    ('CM0208', 7),
    ('CM0208', 8),
    ('CM0208', 9),
    ('CM0208', 10),
    ('CM0208', 11),
    ('CM0208', 12),
    ('CM0209', 1),
    ('CM0209', 2),
    ('CM0209', 3),
    ('CM0209', 4),
    ('CM0209', 5),
    ('CM0209', 6),
    ('CM0209', 7),
    ('CM0209', 8),
    ('CM0209', 9),
    ('CM0209', 10),
    ('CM0209', 11),
    ('CM0209', 12),
    ('CO0101', 1),
    ('CO0101', 2),
    ('CO0101', 3),
    ('CO0101', 4),
    ('CO0101', 5),
    ('CO0101', 6),
    ('CO0101', 7),
    ('CO0101', 8),
    ('CO0101', 9),
    ('CO0101', 10),
    ('CO0101', 11),
    ('CO0101', 12),
    ('CO0105', 1),
    ('CO0105', 2),
    ('CO0105', 3),
    ('CO0105', 4),
    ('CO0105', 5),
    ('CO0105', 6),
    ('CO0105', 7),
    ('CO0105', 8),
    ('CO0105', 9),
    ('CO0105', 10),
    ('CO0105', 11),
    ('CO0105', 12),
    ('CO0107', 1),
    ('CO0107', 2),
    ('CO0107', 3),
    ('CO0107', 4),
    ('CO0107', 5),
    ('CO0107', 6),
    ('CO0107', 7),
    ('CO0107', 8),
    ('CO0107', 9),
    ('CO0107', 10),
    ('CO0107', 11),
    ('CO0107', 12),
    ('CP0101', 1),
    ('CP0101', 7),
    ('CP0201', 1),
    ('CP0201', 4),
    ('CP0201', 7),
    ('CP0201', 10),
    ('DC0103', 1),
    ('DC0107', 1),
    ('DC0107', 2),
    ('DC0107', 3),
    ('DC0107', 4),
    ('DC0107', 5),
    ('DC0107', 6),
    ('DC0107', 7),
    ('DC0107', 8),
    ('DC0107', 9),
    ('DC0107', 10),
    ('DC0107', 11),
    ('DC0107', 12),
    ('DC0108', 1),
    ('DC0108', 7),
    ('DC0108.1', 1),
    ('DC0108.1', 7),
    ('DC0108.2', 1),
    ('DC0108.2', 7),
    ('DC0201', 1),
    ('DC0201', 7),
    ('DC0201.1', 1),
    ('DC0201.1', 7),
    ('DC0201.2', 1),
    ('DC0201.2', 7),
    ('DC0301', 1),
    ('DC0302', 1),
    ('DC0306', 1),
    ('DC0307', 1),
    ('DC0308', 1),
    ('DC0309', 1),
    ('DC0401', 1),
    ('DC0401', 2),
    ('DC0401', 3),
    ('DC0401', 4),
    ('DC0401', 5),
    ('DC0401', 6),
    ('DC0401', 7),
    ('DC0401', 8),
    ('DC0401', 9),
    ('DC0401', 10),
    ('DC0401', 11),
    ('DC0401', 12),
    ('DC0402', 1),
    ('DC0402', 2),
    ('DC0402', 3),
    ('DC0402', 4),
    ('DC0402', 5),
    ('DC0402', 6),
    ('DC0402', 7),
    ('DC0402', 8),
    ('DC0402', 9),
    ('DC0402', 10),
    ('DC0402', 11),
    ('DC0402', 12),
    ('DC0403', 1),
    ('DC0403', 2),
    ('DC0403', 3),
    ('DC0403', 4),
    ('DC0403', 5),
    ('DC0403', 6),
    ('DC0403', 7),
    ('DC0403', 8),
    ('DC0403', 9),
    ('DC0403', 10),
    ('DC0403', 11),
    ('DC0403', 12),
    ('DC0501', 1),
    ('DC0502', 1),
    ('DC0502', 7),
    ('DE0101', 1),
    ('DE0103', 1),
    ('DE0501', 1),
    ('DE0801', 1),
    ('DE0801', 2),
    ('DE0801', 3),
    ('DE0801', 4),
    ('DE0801', 5),
    ('DE0801', 6),
    ('DE0801', 7),
    ('DE0801', 8),
    ('DE0801', 9),
    ('DE0801', 10),
    ('DE0801', 11),
    ('DE0801', 12),
    ('DE1201', 1),
    ('DE1201', 4),
    ('DE1201', 7),
    ('DE1201', 10),
    ('DE1202', 1),
    ('DE1202', 4),
    ('DE1202', 7),
    ('DE1202', 10),
    ('DE1301', 1),
    ('DE1302', 1),
    ('DE1303', 1),
    ('DE1304', 1),
    ('DE1305', 1),
    ('DE1306', 1),
    ('DE1401', 1),
    ('DE1401', 2),
    ('DE1401', 3),
    ('DE1401', 4),
    ('DE1401', 5),
    ('DE1401', 6),
    ('DE1401', 7),
    ('DE1401', 8),
    ('DE1401', 9),
    ('DE1401', 10),
    ('DE1401', 11),
    ('DE1401', 12),
    ('DE1402', 1),
    ('DE1402', 2),
    ('DE1402', 3),
    ('DE1402', 4),
    ('DE1402', 5),
    ('DE1402', 6),
    ('DE1402', 7),
    ('DE1402', 8),
    ('DE1402', 9),
    ('DE1402', 10),
    ('DE1402', 11),
    ('DE1402', 12),
    ('DE1403', 1),
    ('DE1403', 2),
    ('DE1403', 3),
    ('DE1403', 4),
    ('DE1403', 5),
    ('DE1403', 6),
    ('DE1403', 7),
    ('DE1403', 8),
    ('DE1403', 9),
    ('DE1403', 10),
    ('DE1403', 11),
    ('DE1403', 12),
    ('DE1404', 1),
    ('DE1404', 2),
    ('DE1404', 3),
    ('DE1404', 4),
    ('DE1404', 5),
    ('DE1404', 6),
    ('DE1404', 7),
    ('DE1404', 8),
    ('DE1404', 9),
    ('DE1404', 10),
    ('DE1404', 11),
    ('DE1404', 12),
    ('DE1405', 1),
    ('DE1405', 2),
    ('DE1405', 3),
    ('DE1405', 4),
    ('DE1405', 5),
    ('DE1405', 6),
    ('DE1405', 7),
    ('DE1405', 8),
    ('DE1405', 9),
    ('DE1405', 10),
    ('DE1405', 11),
    ('DE1405', 12),
    ('DE1601', 1),
    ('DG0101', 1),
    ('DG0101', 2),
    ('DG0101', 3),
    ('DG0101', 4),
    ('DG0101', 5),
    ('DG0101', 6),
    ('DG0101', 7),
    ('DG0101', 8),
    ('DG0101', 9),
    ('DG0101', 10),
    ('DG0101', 11),
    ('DG0101', 12),
    ('DG0102', 1),
    ('DG0102', 2),
    ('DG0102', 3),
    ('DG0102', 4),
    ('DG0102', 5),
    ('DG0102', 6),
    ('DG0102', 7),
    ('DG0102', 8),
    ('DG0102', 9),
    ('DG0102', 10),
    ('DG0102', 11),
    ('DG0102', 12),
    ('DG0201', 1),
    ('DG0201', 2),
    ('DG0201', 3),
    ('DG0201', 4),
    ('DG0201', 5),
    ('DG0201', 6),
    ('DG0201', 7),
    ('DG0201', 8),
    ('DG0201', 9),
    ('DG0201', 10),
    ('DG0201', 11),
    ('DG0201', 12),
    ('DG0202', 1),
    ('DG0202', 2),
    ('DG0202', 3),
    ('DG0202', 4),
    ('DG0202', 5),
    ('DG0202', 6),
    ('DG0202', 7),
    ('DG0202', 8),
    ('DG0202', 9),
    ('DG0202', 10),
    ('DG0202', 11),
    ('DG0202', 12),
    ('DH0101', 1),
    ('DH0101', 2),
    ('DH0101', 3),
    ('DH0101', 4),
    ('DH0101', 5),
    ('DH0101', 6),
    ('DH0101', 7),
    ('DH0101', 8),
    ('DH0101', 9),
    ('DH0101', 10),
    ('DH0101', 11),
    ('DH0101', 12),
    ('DH0101.1', 1),
    ('DH0101.1', 2),
    ('DH0101.1', 3),
    ('DH0101.1', 4),
    ('DH0101.1', 5),
    ('DH0101.1', 6),
    ('DH0101.1', 7),
    ('DH0101.1', 8),
    ('DH0101.1', 9),
    ('DH0101.1', 10),
    ('DH0101.1', 11),
    ('DH0101.1', 12),
    ('DH0101.2', 1),
    ('DH0101.2', 2),
    ('DH0101.2', 3),
    ('DH0101.2', 4),
    ('DH0101.2', 5),
    ('DH0101.2', 6),
    ('DH0101.2', 7),
    ('DH0101.2', 8),
    ('DH0101.2', 9),
    ('DH0101.2', 10),
    ('DH0101.2', 11),
    ('DH0101.2', 12),
    ('DH0102', 1),
    ('DH0102', 2),
    ('DH0102', 3),
    ('DH0102', 4),
    ('DH0102', 5),
    ('DH0102', 6),
    ('DH0102', 7),
    ('DH0102', 8),
    ('DH0102', 9),
    ('DH0102', 10),
    ('DH0102', 11),
    ('DH0102', 12),
    ('DH0103', 1),
    ('DH0103', 2),
    ('DH0103', 3),
    ('DH0103', 4),
    ('DH0103', 5),
    ('DH0103', 6),
    ('DH0103', 7),
    ('DH0103', 8),
    ('DH0103', 9),
    ('DH0103', 10),
    ('DH0103', 11),
    ('DH0103', 12),
    ('DH0104', 1),
    ('DH0104', 2),
    ('DH0104', 3),
    ('DH0104', 4),
    ('DH0104', 5),
    ('DH0104', 6),
    ('DH0104', 7),
    ('DH0104', 8),
    ('DH0104', 9),
    ('DH0104', 10),
    ('DH0104', 11),
    ('DH0104', 12),
    ('DH0105', 1),
    ('DH0105', 2),
    ('DH0105', 3),
    ('DH0105', 4),
    ('DH0105', 5),
    ('DH0105', 6),
    ('DH0105', 7),
    ('DH0105', 8),
    ('DH0105', 9),
    ('DH0105', 10),
    ('DH0105', 11),
    ('DH0105', 12),
    ('DH0106', 1),
    ('DH0106', 2),
    ('DH0106', 3),
    ('DH0106', 4),
    ('DH0106', 5),
    ('DH0106', 6),
    ('DH0106', 7),
    ('DH0106', 8),
    ('DH0106', 9),
    ('DH0106', 10),
    ('DH0106', 11),
    ('DH0106', 12),
    ('DH0107', 1),
    ('DH0107', 2),
    ('DH0107', 3),
    ('DH0107', 4),
    ('DH0107', 5),
    ('DH0107', 6),
    ('DH0107', 7),
    ('DH0107', 8),
    ('DH0107', 9),
    ('DH0107', 10),
    ('DH0107', 11),
    ('DH0107', 12),
    ('DH0108', 1),
    ('DH0108', 2),
    ('DH0108', 3),
    ('DH0108', 4),
    ('DH0108', 5),
    ('DH0108', 6),
    ('DH0108', 7),
    ('DH0108', 8),
    ('DH0108', 9),
    ('DH0108', 10),
    ('DH0108', 11),
    ('DH0108', 12),
    ('DH0109', 1),
    ('DH0109', 2),
    ('DH0109', 3),
    ('DH0109', 4),
    ('DH0109', 5),
    ('DH0109', 6),
    ('DH0109', 7),
    ('DH0109', 8),
    ('DH0109', 9),
    ('DH0109', 10),
    ('DH0109', 11),
    ('DH0109', 12),
    ('DH0110', 1),
    ('DH0110', 4),
    ('DH0110', 7),
    ('DH0110', 10),
    ('DH0111', 1),
    ('DH0111', 2),
    ('DH0111', 3),
    ('DH0111', 4),
    ('DH0111', 5),
    ('DH0111', 6),
    ('DH0111', 7),
    ('DH0111', 8),
    ('DH0111', 9),
    ('DH0111', 10),
    ('DH0111', 11),
    ('DH0111', 12),
    ('DH0112', 1),
    ('DH0112', 2),
    ('DH0112', 3),
    ('DH0112', 4),
    ('DH0112', 5),
    ('DH0112', 6),
    ('DH0112', 7),
    ('DH0112', 8),
    ('DH0112', 9),
    ('DH0112', 10),
    ('DH0112', 11),
    ('DH0112', 12),
    ('DH0113', 1),
    ('DH0113', 2),
    ('DH0113', 3),
    ('DH0113', 4),
    ('DH0113', 5),
    ('DH0113', 6),
    ('DH0113', 7),
    ('DH0113', 8),
    ('DH0113', 9),
    ('DH0113', 10),
    ('DH0113', 11),
    ('DH0113', 12),
    ('DH0201', 1),
    ('DH0201', 2),
    ('DH0201', 3),
    ('DH0201', 4),
    ('DH0201', 5),
    ('DH0201', 6),
    ('DH0201', 7),
    ('DH0201', 8),
    ('DH0201', 9),
    ('DH0201', 10),
    ('DH0201', 11),
    ('DH0201', 12),
    ('DH0202', 1),
    ('DH0202', 2),
    ('DH0202', 3),
    ('DH0202', 4),
    ('DH0202', 5),
    ('DH0202', 6),
    ('DH0202', 7),
    ('DH0202', 8),
    ('DH0202', 9),
    ('DH0202', 10),
    ('DH0202', 11),
    ('DH0202', 12),
    ('DH0203', 1),
    ('DH0203', 2),
    ('DH0203', 3),
    ('DH0203', 4),
    ('DH0203', 5),
    ('DH0203', 6),
    ('DH0203', 7),
    ('DH0203', 8),
    ('DH0203', 9),
    ('DH0203', 10),
    ('DH0203', 11),
    ('DH0203', 12),
    ('DH0204', 1),
    ('DH0204', 2),
    ('DH0204', 3),
    ('DH0204', 4),
    ('DH0204', 5),
    ('DH0204', 6),
    ('DH0204', 7),
    ('DH0204', 8),
    ('DH0204', 9),
    ('DH0204', 10),
    ('DH0204', 11),
    ('DH0204', 12),
    ('DH0301', 1),
    ('DH0301', 2),
    ('DH0301', 3),
    ('DH0301', 4),
    ('DH0301', 5),
    ('DH0301', 6),
    ('DH0301', 7),
    ('DH0301', 8),
    ('DH0301', 9),
    ('DH0301', 10),
    ('DH0301', 11),
    ('DH0301', 12),
    ('DH0302', 1),
    ('DH0302', 2),
    ('DH0302', 3),
    ('DH0302', 4),
    ('DH0302', 5),
    ('DH0302', 6),
    ('DH0302', 7),
    ('DH0302', 8),
    ('DH0302', 9),
    ('DH0302', 10),
    ('DH0302', 11),
    ('DH0302', 12),
    ('DH0401', 1),
    ('DH0401', 4),
    ('DH0401', 7),
    ('DH0401', 10),
    ('DH0402', 1),
    ('DH0402', 4),
    ('DH0402', 7),
    ('DH0402', 10),
    ('DM0101', 1),
    ('DM0101', 7),
    ('DM0102', 1),
    ('DM0102', 7),
    ('DM0103', 1),
    ('DM0201', 1),
    ('DM0201', 7),
    ('DM0202', 1),
    ('DM0202', 7),
    ('DM0203', 1),
    ('DM0301', 1),
    ('DM0301', 7),
    ('DM0302', 1),
    ('DM0302', 7),
    ('DM0401', 1),
    ('DM0401', 7),
    ('DM0402', 1),
    ('DM0402', 7),
    ('DN0101', 1),
    ('DN0101', 2),
    ('DN0101', 3),
    ('DN0101', 4),
    ('DN0101', 5),
    ('DN0101', 6),
    ('DN0101', 7),
    ('DN0101', 8),
    ('DN0101', 9),
    ('DN0101', 10),
    ('DN0101', 11),
    ('DN0101', 12),
    ('DN0102', 1),
    ('DN0102', 2),
    ('DN0102', 3),
    ('DN0102', 4),
    ('DN0102', 5),
    ('DN0102', 6),
    ('DN0102', 7),
    ('DN0102', 8),
    ('DN0102', 9),
    ('DN0102', 10),
    ('DN0102', 11),
    ('DN0102', 12),
    ('DN0103', 1),
    ('DN0103', 2),
    ('DN0103', 3),
    ('DN0103', 4),
    ('DN0103', 5),
    ('DN0103', 6),
    ('DN0103', 7),
    ('DN0103', 8),
    ('DN0103', 9),
    ('DN0103', 10),
    ('DN0103', 11),
    ('DN0103', 12),
    ('DN0104', 1),
    ('DN0104', 2),
    ('DN0104', 3),
    ('DN0104', 4),
    ('DN0104', 5),
    ('DN0104', 6),
    ('DN0104', 7),
    ('DN0104', 8),
    ('DN0104', 9),
    ('DN0104', 10),
    ('DN0104', 11),
    ('DN0104', 12),
    ('DN0105', 1),
    ('DN0105', 2),
    ('DN0105', 3),
    ('DN0105', 4),
    ('DN0105', 5),
    ('DN0105', 6),
    ('DN0105', 7),
    ('DN0105', 8),
    ('DN0105', 9),
    ('DN0105', 10),
    ('DN0105', 11),
    ('DN0105', 12),
    ('DN0106', 1),
    ('DN0106', 2),
    ('DN0106', 3),
    ('DN0106', 4),
    ('DN0106', 5),
    ('DN0106', 6),
    ('DN0106', 7),
    ('DN0106', 8),
    ('DN0106', 9),
    ('DN0106', 10),
    ('DN0106', 11),
    ('DN0106', 12),
    ('DN0107', 1),
    ('DN0107', 2),
    ('DN0107', 3),
    ('DN0107', 4),
    ('DN0107', 5),
    ('DN0107', 6),
    ('DN0107', 7),
    ('DN0107', 8),
    ('DN0107', 9),
    ('DN0107', 10),
    ('DN0107', 11),
    ('DN0107', 12),
    ('DN0109', 1),
    ('DN0109', 2),
    ('DN0109', 3),
    ('DN0109', 4),
    ('DN0109', 5),
    ('DN0109', 6),
    ('DN0109', 7),
    ('DN0109', 8),
    ('DN0109', 9),
    ('DN0109', 10),
    ('DN0109', 11),
    ('DN0109', 12),
    ('DN0110', 1),
    ('DN0110', 2),
    ('DN0110', 3),
    ('DN0110', 4),
    ('DN0110', 5),
    ('DN0110', 6),
    ('DN0110', 7),
    ('DN0110', 8),
    ('DN0110', 9),
    ('DN0110', 10),
    ('DN0110', 11),
    ('DN0110', 12),
    ('DN0301', 1),
    ('DN0301', 2),
    ('DN0301', 3),
    ('DN0301', 4),
    ('DN0301', 5),
    ('DN0301', 6),
    ('DN0301', 7),
    ('DN0301', 8),
    ('DN0301', 9),
    ('DN0301', 10),
    ('DN0301', 11),
    ('DN0301', 12),
    ('DN0302', 1),
    ('DN0302', 2),
    ('DN0302', 3),
    ('DN0302', 4),
    ('DN0302', 5),
    ('DN0302', 6),
    ('DN0302', 7),
    ('DN0302', 8),
    ('DN0302', 9),
    ('DN0302', 10),
    ('DN0302', 11),
    ('DN0302', 12),
    ('DN0303', 1),
    ('DN0303', 2),
    ('DN0303', 3),
    ('DN0303', 4),
    ('DN0303', 5),
    ('DN0303', 6),
    ('DN0303', 7),
    ('DN0303', 8),
    ('DN0303', 9),
    ('DN0303', 10),
    ('DN0303', 11),
    ('DN0303', 12),
    ('DO0202', 1),
    ('DO0202', 2),
    ('DO0202', 3),
    ('DO0202', 4),
    ('DO0202', 5),
    ('DO0202', 6),
    ('DO0202', 7),
    ('DO0202', 8),
    ('DO0202', 9),
    ('DO0202', 10),
    ('DO0202', 11),
    ('DO0202', 12),
    ('DO0204', 1),
    ('DO0204', 2),
    ('DO0204', 3),
    ('DO0204', 4),
    ('DO0204', 5),
    ('DO0204', 6),
    ('DO0204', 7),
    ('DO0204', 8),
    ('DO0204', 9),
    ('DO0204', 10),
    ('DO0204', 11),
    ('DO0204', 12),
    ('DO0205', 1),
    ('DO0205', 2),
    ('DO0205', 3),
    ('DO0205', 4),
    ('DO0205', 5),
    ('DO0205', 6),
    ('DO0205', 7),
    ('DO0205', 8),
    ('DO0205', 9),
    ('DO0205', 10),
    ('DO0205', 11),
    ('DO0205', 12),
    ('DO0302', 1),
    ('DO0302', 2),
    ('DO0302', 3),
    ('DO0302', 4),
    ('DO0302', 5),
    ('DO0302', 6),
    ('DO0302', 7),
    ('DO0302', 8),
    ('DO0302', 9),
    ('DO0302', 10),
    ('DO0302', 11),
    ('DO0302', 12),
    ('DO0303', 1),
    ('DO0303', 2),
    ('DO0303', 3),
    ('DO0303', 4),
    ('DO0303', 5),
    ('DO0303', 6),
    ('DO0303', 7),
    ('DO0303', 8),
    ('DO0303', 9),
    ('DO0303', 10),
    ('DO0303', 11),
    ('DO0303', 12),
    ('DO0304', 1),
    ('DO0304', 2),
    ('DO0304', 3),
    ('DO0304', 4),
    ('DO0304', 5),
    ('DO0304', 6),
    ('DO0304', 7),
    ('DO0304', 8),
    ('DO0304', 9),
    ('DO0304', 10),
    ('DO0304', 11),
    ('DO0304', 12),
    ('DP0101', 1),
    ('DR0101', 1),
    ('DR0101', 2),
    ('DR0101', 3),
    ('DR0101', 4),
    ('DR0101', 5),
    ('DR0101', 6),
    ('DR0101', 7),
    ('DR0101', 8),
    ('DR0101', 9),
    ('DR0101', 10),
    ('DR0101', 11),
    ('DR0101', 12),
    ('DR0102', 1),
    ('DR0102', 2),
    ('DR0102', 3),
    ('DR0102', 4),
    ('DR0102', 5),
    ('DR0102', 6),
    ('DR0102', 7),
    ('DR0102', 8),
    ('DR0102', 9),
    ('DR0102', 10),
    ('DR0102', 11),
    ('DR0102', 12),
    ('DR0103', 1),
    ('DR0103', 2),
    ('DR0103', 3),
    ('DR0103', 4),
    ('DR0103', 5),
    ('DR0103', 6),
    ('DR0103', 7),
    ('DR0103', 8),
    ('DR0103', 9),
    ('DR0103', 10),
    ('DR0103', 11),
    ('DR0103', 12),
    ('DR0201', 1),
    ('DR0202', 1),
    ('DR0203', 1),
    ('DR0204', 1),
    ('DR0205', 1),
    ('DR0301', 1),
    ('DR0301', 2),
    ('DR0301', 3),
    ('DR0301', 4),
    ('DR0301', 5),
    ('DR0301', 6),
    ('DR0301', 7),
    ('DR0301', 8),
    ('DR0301', 9),
    ('DR0301', 10),
    ('DR0301', 11),
    ('DR0301', 12),
    ('DR0302', 1),
    ('DR0302', 2),
    ('DR0302', 3),
    ('DR0302', 4),
    ('DR0302', 5),
    ('DR0302', 6),
    ('DR0302', 7),
    ('DR0302', 8),
    ('DR0302', 9),
    ('DR0302', 10),
    ('DR0302', 11),
    ('DR0302', 12),
    ('DR0401', 1),
    ('DR0401', 2),
    ('DR0401', 3),
    ('DR0401', 4),
    ('DR0401', 5),
    ('DR0401', 6),
    ('DR0401', 7),
    ('DR0401', 8),
    ('DR0401', 9),
    ('DR0401', 10),
    ('DR0401', 11),
    ('DR0401', 12),
    ('DR0403', 1),
    ('DR0403', 2),
    ('DR0403', 3),
    ('DR0403', 4),
    ('DR0403', 5),
    ('DR0403', 6),
    ('DR0403', 7),
    ('DR0403', 8),
    ('DR0403', 9),
    ('DR0403', 10),
    ('DR0403', 11),
    ('DR0403', 12),
    ('DR0404', 1),
    ('DR0404', 4),
    ('DR0404', 7),
    ('DR0404', 10),
    ('DS0101', 1),
    ('DS0101', 4),
    ('DS0101', 7),
    ('DS0101', 10),
    ('DS0201', 1),
    ('DS0201', 4),
    ('DS0201', 7),
    ('DS0201', 10),
    ('DS0301', 1),
    ('DS0301', 4),
    ('DS0301', 7),
    ('DS0301', 10),
    ('DS0401', 1),
    ('DS0401', 4),
    ('DS0401', 7),
    ('DS0401', 10),
    ('HC0101', 1),
    ('HC0102', 1),
    ('HE0101', 1),
    ('HE0102', 1),
    ('HE0103', 1),
    ('HE0104', 1),
    ('HE0105', 1),
    ('HE0106', 1),
    ('HH0101.1', 1),
    ('HH0101.1', 4),
    ('HH0101.1', 7),
    ('HH0101.1', 10),
    ('HH0101.2', 1),
    ('HH0101.2', 4),
    ('HH0101.2', 7),
    ('HH0101.2', 10),
    ('HH0102', 1),
    ('HH0102', 7),
    ('HH0103.1', 1),
    ('HH0103.1', 7),
    ('HH0103.2', 1),
    ('HH0103.2', 7),
    ('HH0103.3', 1),
    ('HH0103.3', 7),
    ('HH0103.4', 1),
    ('HH0103.4', 7),
    ('HH0103.5', 1),
    ('HH0103.5', 7),
    ('HH0103.6', 1),
    ('HH0103.6', 7),
    ('HH0104.1', 1),
    ('HH0104.2', 1),
    ('HH0104.3', 1),
    ('HH0104.4', 1),
    ('HH0104.5', 1),
    ('SC0101', 1),
    ('SC0101', 7),
    ('SC0102', 1),
    ('SC0102', 7),
    ('SC0103', 1),
    ('SC0103', 7),
    ('SC0104', 1),
    ('SC0104', 7),
    ('SC0105', 1),
    ('SC0105', 7),
    ('SC0106', 1),
    ('SC0106', 7),
    ('SF0101', 1),
    ('SF0102', 1),
    ('SF0103', 1),
    ('SF0104', 1),
    ('SF0105', 1),
    ('SF0106', 1),
    ('SG0104', 1),
    ('SG0104', 2),
    ('SG0104', 3),
    ('SG0104', 4),
    ('SG0104', 5),
    ('SG0104', 6),
    ('SG0104', 7),
    ('SG0104', 8),
    ('SG0104', 9),
    ('SG0104', 10),
    ('SG0104', 11),
    ('SG0104', 12),
    ('SH0101', 1),
    ('SH0102', 1),
    ('SH0103', 1),
    ('SH0104', 1),
    ('SH0104', 4),
    ('SH0104', 7),
    ('SH0104', 10),
    ('SH0105', 1),
    ('SH0105', 4),
    ('SH0105', 7),
    ('SH0105', 10),
    ('SH0106', 1),
    ('SH0106', 4),
    ('SH0106', 7),
    ('SH0106', 10),
    ('SH0107', 1),
    ('SH0107', 4),
    ('SH0107', 7),
    ('SH0107', 10),
    ('SH0201', 1),
    ('SH0202', 1),
    ('SH0203', 1),
    ('SH0204', 1),
    ('SH0205', 1),
    ('SH0206', 1),
    ('SH0207', 1),
    ('SH0208', 1),
    ('SH0209', 1),
    ('SH0210', 1),
    ('SH0211', 1),
    ('SH0212', 1),
    ('SH0213', 1),
    ('SH0214', 1),
    ('SH0215', 1),
    ('SH0216', 1),
    ('SH0301', 1),
    ('SH0301', 2),
    ('SH0301', 3),
    ('SH0301', 4),
    ('SH0301', 5),
    ('SH0301', 6),
    ('SH0301', 7),
    ('SH0301', 8),
    ('SH0301', 9),
    ('SH0301', 10),
    ('SH0301', 11),
    ('SH0301', 12),
    ('SH0302', 1),
    ('SH0302', 2),
    ('SH0302', 3),
    ('SH0302', 4),
    ('SH0302', 5),
    ('SH0302', 6),
    ('SH0302', 7),
    ('SH0302', 8),
    ('SH0302', 9),
    ('SH0302', 10),
    ('SH0302', 11),
    ('SH0302', 12),
    ('SH0303', 1),
    ('SH0303', 2),
    ('SH0303', 3),
    ('SH0303', 4),
    ('SH0303', 5),
    ('SH0303', 6),
    ('SH0303', 7),
    ('SH0303', 8),
    ('SH0303', 9),
    ('SH0303', 10),
    ('SH0303', 11),
    ('SH0303', 12),
    ('SH0306', 1),
    ('SH0306', 2),
    ('SH0306', 3),
    ('SH0306', 4),
    ('SH0306', 5),
    ('SH0306', 6),
    ('SH0306', 7),
    ('SH0306', 8),
    ('SH0306', 9),
    ('SH0306', 10),
    ('SH0306', 11),
    ('SH0306', 12),
    ('SH0307', 1),
    ('SH0307', 2),
    ('SH0307', 3),
    ('SH0307', 4),
    ('SH0307', 5),
    ('SH0307', 6),
    ('SH0307', 7),
    ('SH0307', 8),
    ('SH0307', 9),
    ('SH0307', 10),
    ('SH0307', 11),
    ('SH0307', 12),
    ('SI0101', 1),
    ('SI0101', 2),
    ('SI0101', 3),
    ('SI0101', 4),
    ('SI0101', 5),
    ('SI0101', 6),
    ('SI0101', 7),
    ('SI0101', 8),
    ('SI0101', 9),
    ('SI0101', 10),
    ('SI0101', 11),
    ('SI0101', 12),
    ('SI0102', 1),
    ('SI0102', 2),
    ('SI0102', 3),
    ('SI0102', 4),
    ('SI0102', 5),
    ('SI0102', 6),
    ('SI0102', 7),
    ('SI0102', 8),
    ('SI0102', 9),
    ('SI0102', 10),
    ('SI0102', 11),
    ('SI0102', 12),
    ('SI0103', 1),
    ('SI0103', 2),
    ('SI0103', 3),
    ('SI0103', 4),
    ('SI0103', 5),
    ('SI0103', 6),
    ('SI0103', 7),
    ('SI0103', 8),
    ('SI0103', 9),
    ('SI0103', 10),
    ('SI0103', 11),
    ('SI0103', 12),
    ('SI0201', 1),
    ('SI0201', 2),
    ('SI0201', 3),
    ('SI0201', 4),
    ('SI0201', 5),
    ('SI0201', 6),
    ('SI0201', 7),
    ('SI0201', 8),
    ('SI0201', 9),
    ('SI0201', 10),
    ('SI0201', 11),
    ('SI0201', 12),
    ('SI0202', 1),
    ('SI0202', 2),
    ('SI0202', 3),
    ('SI0202', 4),
    ('SI0202', 5),
    ('SI0202', 6),
    ('SI0202', 7),
    ('SI0202', 8),
    ('SI0202', 9),
    ('SI0202', 10),
    ('SI0202', 11),
    ('SI0202', 12),
    ('SI0203', 1),
    ('SI0203', 2),
    ('SI0203', 3),
    ('SI0203', 4),
    ('SI0203', 5),
    ('SI0203', 6),
    ('SI0203', 7),
    ('SI0203', 8),
    ('SI0203', 9),
    ('SI0203', 10),
    ('SI0203', 11),
    ('SI0203', 12),
    ('SI0301', 1),
    ('SI0301', 2),
    ('SI0301', 3),
    ('SI0301', 4),
    ('SI0301', 5),
    ('SI0301', 6),
    ('SI0301', 7),
    ('SI0301', 8),
    ('SI0301', 9),
    ('SI0301', 10),
    ('SI0301', 11),
    ('SI0301', 12),
    ('SI0302', 1),
    ('SI0302', 2),
    ('SI0302', 3),
    ('SI0302', 4),
    ('SI0302', 5),
    ('SI0302', 6),
    ('SI0302', 7),
    ('SI0302', 8),
    ('SI0302', 9),
    ('SI0302', 10),
    ('SI0302', 11),
    ('SI0302', 12),
    ('SI0303', 1),
    ('SI0303', 2),
    ('SI0303', 3),
    ('SI0303', 4),
    ('SI0303', 5),
    ('SI0303', 6),
    ('SI0303', 7),
    ('SI0303', 8),
    ('SI0303', 9),
    ('SI0303', 10),
    ('SI0303', 11),
    ('SI0303', 12),
    ('SL0101', 1),
    ('SL0101', 2),
    ('SL0101', 3),
    ('SL0101', 4),
    ('SL0101', 5),
    ('SL0101', 6),
    ('SL0101', 7),
    ('SL0101', 8),
    ('SL0101', 9),
    ('SL0101', 10),
    ('SL0101', 11),
    ('SL0101', 12),
    ('SM0102', 1),
    ('SM0102', 7),
    ('SM0103', 1),
    ('SM0103', 7),
    ('SM0201', 1),
    ('SM0201', 2),
    ('SM0201', 3),
    ('SM0201', 4),
    ('SM0201', 5),
    ('SM0201', 6),
    ('SM0201', 7),
    ('SM0201', 8),
    ('SM0201', 9),
    ('SM0201', 10),
    ('SM0201', 11),
    ('SM0201', 12),
    ('SS0101', 1),
    ('SS0101', 2),
    ('SS0101', 3),
    ('SS0101', 4),
    ('SS0101', 5),
    ('SS0101', 6),
    ('SS0101', 7),
    ('SS0101', 8),
    ('SS0101', 9),
    ('SS0101', 10),
    ('SS0101', 11),
    ('SS0101', 12),
    ('SS0102', 1),
    ('SS0102', 2),
    ('SS0102', 3),
    ('SS0102', 4),
    ('SS0102', 5),
    ('SS0102', 6),
    ('SS0102', 7),
    ('SS0102', 8),
    ('SS0102', 9),
    ('SS0102', 10),
    ('SS0102', 11),
    ('SS0102', 12),
    ('SS0103', 1),
    ('SS0103', 2),
    ('SS0103', 3),
    ('SS0103', 4),
    ('SS0103', 5),
    ('SS0103', 6),
    ('SS0103', 7),
    ('SS0103', 8),
    ('SS0103', 9),
    ('SS0103', 10),
    ('SS0103', 11),
    ('SS0103', 12)
),
metadata(
  indicator_code, indicator_group, unit, direction, target_scope,
  category, title, title_th, definition, formula,
  numerator_label, denominator_label, source_tables, frequency, reference,
  rule_version, pending_reason, tier
) AS (
  VALUES
    ('AA0101', 'A', 'rate', 'neutral', 'annual', 'Ambulatory care', 'Epilepsy: Hospitalization rate', 'Epilepsy: Hospitalization rate', 'ตัวชี้วัดกลุ่ม ACSC ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 286', 'pending-local-source-2026.1', 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และเกณฑ์คัดแยก Epilepsy ACSC', 'pending-local-source'),
    ('AA0102', 'A', 'rate', 'neutral', 'annual', 'Ambulatory care', 'COPD: Hospitalization rate', 'COPD: Hospitalization rate', 'ตัวชี้วัดกลุ่ม ACSC ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 287', 'pending-local-source-2026.1', 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และเกณฑ์คัดแยก Asthma ACSC', 'pending-local-source'),
    ('AA0103', 'A', 'rate', 'neutral', 'annual', 'Ambulatory care', 'Asthma: Hospitalization rate', 'Asthma: Hospitalization rate', 'ตัวชี้วัดกลุ่ม ACSC ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 288', 'pending-local-source-2026.1', 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และเกณฑ์คัดแยก COPD ACSC', 'pending-local-source'),
    ('AA0104', 'A', 'rate', 'neutral', 'annual', 'Ambulatory care', 'Diabetes Mellitus (DM): Hospitalization rate', 'Diabetes Mellitus (DM): Hospitalization rate', 'ตัวชี้วัดกลุ่ม ACSC ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 289', 'pending-local-source-2026.1', 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และการคัดแยกภาวะแทรกซ้อน DM ACSC', 'pending-local-source'),
    ('AA0105', 'A', 'rate', 'neutral', 'annual', 'Ambulatory care', 'Hypertension: Hospitalization rate', 'Hypertension: Hospitalization rate', 'ตัวชี้วัดกลุ่ม ACSC ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 290', 'pending-local-source-2026.1', 'ต้องยืนยัน population denominator รายเขตพื้นที่รับผิดชอบ และการคัดแยกภาวะแทรกซ้อน HT ACSC', 'pending-local-source'),
    ('CA0101', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Anesthesia: Intra-operative cardiac arrest ASA physical status I, II', 'Anesthesia: Intra-operative cardiac arrest ASA physical status I, II', 'ตัวชี้วัดกลุ่ม ANESTHESIA ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 10,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 180', 'pending-local-source-2026.1', 'ต้องยืนยัน ASA, pre-anesthetic, recovery, re-intubation และ capnometry event', 'pending-local-source'),
    ('CA0102', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Anesthesia: Percent of pre-anesthetic visit elective in-patient cases', 'Anesthesia: Percent of pre-anesthetic visit elective in-patient cases', 'ตัวชี้วัดกลุ่ม ANESTHESIA ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 181', 'pending-local-source-2026.1', 'ต้องยืนยัน ASA, pre-anesthetic, recovery, re-intubation และ capnometry event', 'pending-local-source'),
    ('CA0103', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Anesthesia: Percent of patients observed in recovery room', 'Anesthesia: Percent of patients observed in recovery room', 'ตัวชี้วัดกลุ่ม ANESTHESIA ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 182', 'pending-local-source-2026.1', 'ต้องยืนยัน ASA, pre-anesthetic, recovery, re-intubation และ capnometry event', 'pending-local-source'),
    ('CA0104', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Anesthesia: Percent of re-intubation within 2 hours after extubation', 'Anesthesia: Percent of re-intubation within 2 hours after extubation', 'ตัวชี้วัดกลุ่ม ANESTHESIA ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 183', 'pending-local-source-2026.1', 'ต้องยืนยัน ASA, pre-anesthetic, recovery, re-intubation และ capnometry event', 'pending-local-source'),
    ('CA0105', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Anesthesia: Percent of using capnometry during general anesthesia', 'Anesthesia: Percent of using capnometry during general anesthesia', 'ตัวชี้วัดกลุ่ม ANESTHESIA ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 184', 'pending-local-source-2026.1', 'ต้องยืนยัน ASA, pre-anesthetic, recovery, re-intubation และ capnometry event', 'pending-local-source'),
    ('CE0101', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Sepsis: Percent of broad-spectrum antibiotic receiving within 3 hours', 'Sepsis: Percent of broad-spectrum antibiotic receiving within 3 hours', 'ตัวชี้วัดกลุ่ม SEPSIS_ER ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 194', 'registered-2026.1', NULL, 'registered'),
    ('CE0102', 'C', 'ratio', 'neutral', 'monthly', 'Care process', 'ER: Average Emergency Department (ED) TIME-IN, TIME-OUT', 'ER: Average Emergency Department (ED) TIME-IN, TIME-OUT', 'ตัวชี้วัดกลุ่ม ED_FLOW ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'er_regist', 'ovstdiag']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 195', 'pending-local-source-2026.1', 'ต้องยืนยันความหมาย ER TIME-IN/TIME-OUT และเกณฑ์ emergency', 'pending-local-source'),
    ('CE0103', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'ER: Percent of Emergency patients recieveing emergency service (ED TIME-IN, TIME-OUT) within 60 minutes', 'ER: Percent of Emergency patients recieveing emergency service (ED TIME-IN, TIME-OUT) within 60 minutes', 'ตัวชี้วัดกลุ่ม ED_FLOW ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'er_regist', 'ovstdiag']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 197', 'pending-local-source-2026.1', 'ต้องยืนยันความหมาย ER TIME-IN/TIME-OUT และเกณฑ์ emergency', 'pending-local-source'),
    ('CE0104', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Sepsis: Percent of broad-spectrum antibiotic received within 1 hour in emergency room', 'Sepsis: Percent of broad-spectrum antibiotic received within 1 hour in emergency room', 'ตัวชี้วัดกลุ่ม SEPSIS_ER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 198', 'pending-local-source-2026.1', 'ต้องยืนยันเวลา triage, ER order time และเวลาบริหารยา broad-spectrum antibiotic ภายใน 1 ชั่วโมง', 'pending-local-source'),
    ('CG0101', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Rate of Pressure ulcer', 'Pressure Ulcer/Injury: Rate of Pressure ulcer', 'ตัวชี้วัดกลุ่ม PRESSURE_ULCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 188', 'pending-local-source-2026.1', 'ต้องยืนยัน stage, present-on-admission, risk population และ patient-days', 'pending-local-source'),
    ('CG0102', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Rate of Pressure ulcer in risk patients', 'Pressure Ulcer/Injury: Rate of Pressure ulcer in risk patients', 'ตัวชี้วัดกลุ่ม PRESSURE_ULCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 190', 'pending-local-source-2026.1', 'ต้องยืนยัน stage, present-on-admission, risk population และ patient-days', 'pending-local-source'),
    ('CG0103', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury', 'Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury', 'ตัวชี้วัดกลุ่ม PRESSURE_ULCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 191', 'pending-local-source-2026.1', 'ต้องยืนยัน stage, present-on-admission, risk population และ patient-days', 'pending-local-source'),
    ('CG0104', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury (HAPI) rate', 'Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury (HAPI) rate', 'ตัวชี้วัดกลุ่ม PRESSURE_ULCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 193', 'pending-local-source-2026.1', 'ต้องยืนยัน stage, present-on-admission, risk population และ patient-days', 'pending-local-source'),
    ('CI0101', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Sepsis: Percent of mortality', 'Sepsis: Percent of mortality', 'ตัวชี้วัดกลุ่ม SEPSIS_ER ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 199', 'registered-2026.1', NULL, 'registered'),
    ('CM0101', 'C', 'rate', 'neutral', 'annual', 'Care process', 'Maternal: Mortality rate of mother from pregnancy and/or labour', 'Maternal: Mortality rate of mother from pregnancy and/or labour', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 161', 'pending-local-source-2026.1', 'ต้องยืนยัน mother-infant linkage และฐานข้อมูลการเกิดมีชีพ (live births) ในพื้นที่รับผิดชอบ', 'pending-local-source'),
    ('CM0104', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Maternal: Percent of unplanned re-admission of caesarean section within 28 days', 'Maternal: Percent of unplanned re-admission of caesarean section within 28 days', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 162', 'registered-2026.1', NULL, 'registered'),
    ('CM0105', 'C', 'ratio', 'neutral', 'monthly', 'Care process', 'Maternal: Average length of stay of caesarean section', 'Maternal: Average length of stay of caesarean section', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 163', 'registered-2026.1', NULL, 'registered'),
    ('CM0107', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Maternal: Percent of immediate postpartum hemorrhage (Vaginal delivery)', 'Maternal: Percent of immediate postpartum hemorrhage (Vaginal delivery)', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 164', 'registered-2026.1', NULL, 'registered'),
    ('CM0109', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Maternal: Percent of eclampsia in pregnancy induce Hypertension', 'Maternal: Percent of eclampsia in pregnancy induce Hypertension', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 165', 'registered-2026.1', NULL, 'registered'),
    ('CM0110', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Maternal: Percent of gestational DM', 'Maternal: Percent of gestational DM', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 166', 'registered-2026.1', NULL, 'registered'),
    ('CM0116', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'hysterectomy Maternal: Percent of patients who received antibiotic prophylaxis in abdominal hysterectomy', 'hysterectomy Maternal: Percent of patients who received antibiotic prophylaxis in abdominal hysterectomy', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 167', 'registered-2026.1', NULL, 'registered'),
    ('CM0117', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Maternal: Percent of abdominal hysterectomy associated infection', 'Maternal: Percent of abdominal hysterectomy associated infection', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 168', 'registered-2026.1', NULL, 'registered'),
    ('CM0118', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Maternal: Percent of primary cesarean section', 'Maternal: Percent of primary cesarean section', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 169', 'registered-2026.1', NULL, 'registered'),
    ('CM0119', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Maternal: Percent of cesarean section with Pdx = O80-O84 and Sdx = O80-O84 (NHSO health service indicator)', 'Maternal: Percent of cesarean section with Pdx = O80-O84 and Sdx = O80-O84 (NHSO health service indicator)', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 170', 'registered-2026.1', NULL, 'registered'),
    ('CM0201', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Child: Perinatal mortality rate (24 weeks)', 'Child: Perinatal mortality rate (24 weeks)', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 171', 'pending-local-source-2026.1', 'ต้องยืนยันการบันทึกอายุครรภ์ >= 24 สัปดาห์ และการจำแนกทารกตายคลอด (stillbirth)', 'pending-local-source'),
    ('CM0202', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Child: Perinatal mortality rate (28 weeks)', 'Child: Perinatal mortality rate (28 weeks)', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 172', 'pending-local-source-2026.1', 'ต้องยืนยันการบันทึกอายุครรภ์ >= 28 สัปดาห์ และการเสียชีวิตของทารกภายใน 7 วันหลังคลอด', 'pending-local-source'),
    ('CM0203', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Child: Neonatal mortality rate', 'Child: Neonatal mortality rate', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 173', 'pending-local-source-2026.1', 'ต้องยืนยันฐานข้อมูลการเกิดมีชีพ (live births) และการเสียชีวิตของทารกภายใน 28 วันหลังคลอด', 'pending-local-source'),
    ('CM0204', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Child: Birth asphyxia rate', 'Child: Birth asphyxia rate', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 174', 'registered-2026.1', NULL, 'registered'),
    ('CM0205', 'C', 'rate', 'neutral', 'monthly', 'Care process', 'Child: Severe birth asphyxia rate', 'Child: Severe birth asphyxia rate', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 175', 'registered-2026.1', NULL, 'registered'),
    ('CM0206', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Child: Percent of low birth weight < 2500 grams', 'Child: Percent of low birth weight < 2500 grams', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 176', 'registered-2026.1', NULL, 'registered'),
    ('CM0207', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 177', 'registered-2026.1', NULL, 'registered'),
    ('CM0208', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 178', 'registered-2026.1', NULL, 'registered'),
    ('CM0209', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days', 'ตัวชี้วัดกลุ่ม MATERNAL_CHILD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 179', 'registered-2026.1', NULL, 'registered'),
    ('CO0101', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Operation: Percent of using surgical safety check list', 'Operation: Percent of using surgical safety check list', 'ตัวชี้วัดกลุ่ม SURGERY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'operation_item', 'iptoprt', 'ipt', 'an_stat']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 185', 'pending-local-source-2026.1', 'ต้องยืนยัน surgical safety checklist, peri-op window และนิยาม re-operation', 'pending-local-source'),
    ('CO0105', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Operation: Percent of peri-operative mortality within 24 hours', 'Operation: Percent of peri-operative mortality within 24 hours', 'ตัวชี้วัดกลุ่ม SURGERY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'operation_item', 'iptoprt', 'ipt', 'an_stat']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 186', 'pending-local-source-2026.1', 'ต้องยืนยัน surgical safety checklist, peri-op window และนิยาม re-operation', 'pending-local-source'),
    ('CO0107', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Operation: Percent of re-operation', 'Operation: Percent of re-operation', 'ตัวชี้วัดกลุ่ม SURGERY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['operation_list', 'operation_detail', 'operation_item', 'iptoprt', 'ipt', 'an_stat']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 187', 'pending-local-source-2026.1', 'ต้องยืนยัน surgical safety checklist, peri-op window และนิยาม re-operation', 'pending-local-source'),
    ('CP0101', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Percent of carers of children with ADHD/LD/MDD having good compliance to treatment', 'Percent of carers of children with ADHD/LD/MDD having good compliance to treatment', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 200', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('CP0201', 'C', 'percent', 'neutral', 'monthly', 'Care process', 'Percent of children with Neurodevelopmental Disorder being diagnosed within 90 days after registration', 'Percent of children with Neurodevelopmental Disorder being diagnosed within 90 days after registration', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 201', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DC0103', 'D', 'percent', 'neutral', 'annual', 'Disease', 'DM: Percent of diabetic retinopathy screening', 'DM: Percent of diabetic retinopathy screening', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 92', 'registered-2026.1', NULL, 'registered'),
    ('DC0107', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'DM: Percent of lower-extremity amputation among patients with diabetes', 'DM: Percent of lower-extremity amputation among patients with diabetes', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 93', 'registered-2026.1', NULL, 'registered'),
    ('DC0108', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'DM: Percent of good controlled of blood sugar in adult', 'DM: Percent of good controlled of blood sugar in adult', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 94', 'registered-2026.1', NULL, 'registered'),
    ('DC0108.1', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'DM: Percent of good controlled of blood sugar in adult aged ≥ 60 years old', 'DM: Percent of good controlled of blood sugar in adult aged ≥ 60 years old', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 95', 'registered-2026.1', NULL, 'registered'),
    ('DC0108.2', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'DM: Percent of good controlled of blood sugar in adult aged < 60 years old', 'DM: Percent of good controlled of blood sugar in adult aged < 60 years old', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 96', 'registered-2026.1', NULL, 'registered'),
    ('DC0201', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'HT: Percent of good controlled of blood pressure', 'HT: Percent of good controlled of blood pressure', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 97', 'registered-2026.1', NULL, 'registered'),
    ('DC0201.1', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'HT: Percent of good controlled of blood pressure of patient aged < 65 years old', 'HT: Percent of good controlled of blood pressure of patient aged < 65 years old', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 99', 'registered-2026.1', NULL, 'registered'),
    ('DC0201.2', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'HT: Percent of good controlled of blood pressure of patient aged ≥ 65 years old', 'HT: Percent of good controlled of blood pressure of patient aged ≥ 65 years old', 'ตัวชี้วัดกลุ่ม DM_HT ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 100', 'registered-2026.1', NULL, 'registered'),
    ('DC0301', 'D', 'percent', 'neutral', 'annual', 'Disease', 'HIV: Percent of people living with HIV with at least one test viral load (VL) after ARV treatment', 'HIV: Percent of people living with HIV with at least one test viral load (VL) after ARV treatment', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 101', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DC0302', 'D', 'percent', 'neutral', 'annual', 'Disease', 'HIV: Percent of people living with HIV with viral load (VL) < 50 copies/ml after ARV treatment 12 months ago', 'HIV: Percent of people living with HIV with viral load (VL) < 50 copies/ml after ARV treatment 12 months ago', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 102', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DC0306', 'D', 'percent', 'neutral', 'annual', 'Disease', 'HIV: Percent of people living with HIV screening PAP smear', 'HIV: Percent of people living with HIV screening PAP smear', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 103', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DC0307', 'D', 'percent', 'neutral', 'annual', 'Disease', 'HIV: Percent of people living with HIV newly registered who were tested for syphilis', 'HIV: Percent of people living with HIV newly registered who were tested for syphilis', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 104', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DC0308', 'D', 'percent', 'neutral', 'annual', 'Disease', 'HIV: Percent of people living with HIV who were currently receiving antiretroviral therapy', 'HIV: Percent of people living with HIV who were currently receiving antiretroviral therapy', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 105', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DC0309', 'D', 'percent', 'neutral', 'annual', 'Disease', 'HIV: Percent of newly diagnosed people living with HIV were receiving tuberculosis preventive therapy (TPT)', 'HIV: Percent of newly diagnosed people living with HIV were receiving tuberculosis preventive therapy (TPT)', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 106', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DC0401', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Cancer: Percent of mortality', 'Cancer: Percent of mortality', 'ตัวชี้วัดกลุ่ม CANCER ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 107', 'registered-2026.1', NULL, 'registered'),
    ('DC0402', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Cancer: Percent of unplanned re-admission', 'Cancer: Percent of unplanned re-admission', 'ตัวชี้วัดกลุ่ม CANCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 108', 'pending-local-source-2026.1', 'ต้องยืนยัน linkage ของ site/stage กับ mortality/re-admission', 'pending-local-source'),
    ('DC0403', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Liver Cancer: Percent of mortality', 'Liver Cancer: Percent of mortality', 'ตัวชี้วัดกลุ่ม CANCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 109', 'pending-local-source-2026.1', 'ต้องยืนยัน linkage ของ site/stage กับ mortality/re-admission', 'pending-local-source'),
    ('DC0501', 'D', 'percent', 'neutral', 'annual', 'Disease', 'CKD: Percent of patients who achieve the kidney function deterioration delayed target', 'CKD: Percent of patients who achieve the kidney function deterioration delayed target', 'ตัวชี้วัดกลุ่ม CKD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_ckd_member', 'clinic_ckd_member_visit', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 110', 'pending-local-source-2026.1', 'ต้องยืนยันสูตร eGFR, crosswalk ACEI/ARB และ longitudinal target', 'pending-local-source'),
    ('DC0502', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'CKD: Percent of patients who are receiving ACEIs or ARBs', 'CKD: Percent of patients who are receiving ACEIs or ARBs', 'ตัวชี้วัดกลุ่ม CKD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_ckd_member', 'clinic_ckd_member_visit', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 112', 'pending-local-source-2026.1', 'ต้องยืนยันสูตร eGFR, crosswalk ACEI/ARB และ longitudinal target', 'pending-local-source'),
    ('DE0101', 'D', 'ratio', 'neutral', 'annual', 'Disease', 'Breast Cancer: Consultation time in patient with BIRADS 4 or greater mammography result', 'Breast Cancer: Consultation time in patient with BIRADS 4 or greater mammography result', 'ตัวชี้วัดกลุ่ม BREAST_CANCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 130', 'pending-local-source-2026.1', 'ต้องยืนยัน BIRADS, consultation clock และนิยาม stage', 'pending-local-source'),
    ('DE0103', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Breast Cancer: Percent of early diagnosis of stage 1, 2', 'Breast Cancer: Percent of early diagnosis of stage 1, 2', 'ตัวชี้วัดกลุ่ม BREAST_CANCER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 131', 'pending-local-source-2026.1', 'ต้องยืนยัน BIRADS, consultation clock และนิยาม stage', 'pending-local-source'),
    ('DE0501', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Stem Cell Transplantation: Engraftment rate within 45 days', 'Stem Cell Transplantation: Engraftment rate within 45 days', 'ตัวชี้วัดกลุ่ม STEM_CELL ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'lab_head', 'lab_order', 'lab_items', 'operation_list', 'operation_detail']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 132', 'pending-local-source-2026.1', 'ต้องยืนยันวัน engraftment และ denominator', 'pending-local-source'),
    ('DE0801', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'TDT in Pediatrics Patient: Percent of received iron chelator in patient with iron overload (serum ferrous > 1000 ug/L)', 'TDT in Pediatrics Patient: Percent of received iron chelator in patient with iron overload (serum ferrous > 1000 ug/L)', 'ตัวชี้วัดกลุ่ม TDT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 133', 'pending-local-source-2026.1', 'ต้องยืนยัน lab threshold iron overload และ chelator mapping', 'pending-local-source'),
    ('DE1201', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Cleft Lip: Percent of patients who had cleft lip repair with under 6 months of age', 'Cleft Lip: Percent of patients who had cleft lip repair with under 6 months of age', 'ตัวชี้วัดกลุ่ม CLEFT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 134', 'pending-local-source-2026.1', 'ต้องยืนยัน operation master ของ cleft และอายุขณะผ่าตัด', 'pending-local-source'),
    ('DE1202', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Cleft Palate: Percent of patients who had cleft Palate repair with under 18 months of age', 'Cleft Palate: Percent of patients who had cleft Palate repair with under 18 months of age', 'ตัวชี้วัดกลุ่ม CLEFT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 135', 'pending-local-source-2026.1', 'ต้องยืนยัน operation master ของ cleft และอายุขณะผ่าตัด', 'pending-local-source'),
    ('DE1301', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per Embryo Transfer following IVF/ICSI and Fresh embryo transfer (age < 34 years)', 'Infertility: Clinical pregnancy rate per Embryo Transfer following IVF/ICSI and Fresh embryo transfer (age < 34 years)', 'ตัวชี้วัดกลุ่ม INFERTILITY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 136', 'pending-local-source-2026.1', 'ต้องยืนยัน embryo transfer cycle และอายุขณะ transfer', 'pending-local-source'),
    ('DE1302', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age 34 - 39 Years)', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age 34 - 39 Years)', 'ตัวชี้วัดกลุ่ม INFERTILITY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 137', 'pending-local-source-2026.1', 'ต้องยืนยัน embryo transfer cycle และอายุขณะ transfer', 'pending-local-source'),
    ('DE1303', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age > 40 years)', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age > 40 years)', 'ตัวชี้วัดกลุ่ม INFERTILITY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 138', 'pending-local-source-2026.1', 'ต้องยืนยัน embryo transfer cycle และอายุขณะ transfer', 'pending-local-source'),
    ('DE1304', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years)', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years)', 'ตัวชี้วัดกลุ่ม INFERTILITY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 139', 'pending-local-source-2026.1', 'ต้องยืนยัน embryo transfer cycle และอายุขณะ transfer', 'pending-local-source'),
    ('DE1305', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age 34 - 39 years)', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age 34 - 39 years)', 'ตัวชี้วัดกลุ่ม INFERTILITY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 140', 'pending-local-source-2026.1', 'ต้องยืนยัน embryo transfer cycle และอายุขณะ transfer', 'pending-local-source'),
    ('DE1306', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)', 'ตัวชี้วัดกลุ่ม INFERTILITY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 141', 'pending-local-source-2026.1', 'ต้องยืนยัน embryo transfer cycle และอายุขณะ transfer', 'pending-local-source'),
    ('DE1401', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of patients who had underwent EGD within 24 hours', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of patients who had underwent EGD within 24 hours', 'ตัวชี้วัดกลุ่ม UGIH ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 142', 'pending-local-source-2026.1', 'ต้องยืนยัน EGD/hemostasis event และ risk status', 'pending-local-source'),
    ('DE1402', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of high risk patients who had underwent EGD within 24 hours', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of high risk patients who had underwent EGD within 24 hours', 'ตัวชี้วัดกลุ่ม UGIH ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 143', 'pending-local-source-2026.1', 'ต้องยืนยัน EGD/hemostasis event และ risk status', 'pending-local-source'),
    ('DE1403', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Non-variceal Upper Gastrointestinal Hemorrhage (UGIH): Percent of hemostatic success by endoscopic approach', 'Non-variceal Upper Gastrointestinal Hemorrhage (UGIH): Percent of hemostatic success by endoscopic approach', 'ตัวชี้วัดกลุ่ม UGIH ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 145', 'pending-local-source-2026.1', 'ต้องยืนยัน EGD/hemostasis event และ risk status', 'pending-local-source'),
    ('DE1404', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Recurrent rates of UGIH after upper endoscopic treatment', 'Upper Gastrointestinal Hemorrhage (UGIH): Recurrent rates of UGIH after upper endoscopic treatment', 'ตัวชี้วัดกลุ่ม UGIH ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 147', 'pending-local-source-2026.1', 'ต้องยืนยัน EGD/hemostasis event และ risk status', 'pending-local-source'),
    ('DE1405', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Complication rates of upper endoscopic treatment', 'Upper Gastrointestinal Hemorrhage (UGIH): Complication rates of upper endoscopic treatment', 'ตัวชี้วัดกลุ่ม UGIH ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 149', 'pending-local-source-2026.1', 'ต้องยืนยัน EGD/hemostasis event และ risk status', 'pending-local-source'),
    ('DE1601', 'D', 'percent', 'neutral', 'annual', 'Disease', 'New born: Percent of hearing screening within 30 days', 'New born: Percent of hearing screening within 30 days', 'ตัวชี้วัดกลุ่ม NEWBORN ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt_newborn', 'ipt_pregnancy', 'ipt_pregnancy_vital_sign', 'ipt_labour_infant', 'ipt_labour_child', 'labor', 'person_wbc', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 150', 'pending-local-source-2026.1', 'ต้องยืนยันเครื่องมือตรวจคัดกรองการได้ยิน (OAE/AABR) และบันทึกผลภายใน 30 วันหลังเกิด', 'pending-local-source'),
    ('DG0101', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of unplanned re-admission into the hospital within 28 days after last discharge', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of unplanned re-admission into the hospital within 28 days after last discharge', 'ตัวชี้วัดกลุ่ม UGIH ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 120', 'registered-2026.1', NULL, 'registered'),
    ('DG0102', 'D', 'ratio', 'neutral', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Average length of stay', 'Upper Gastrointestinal Hemorrhage (UGIH): Average length of stay', 'ตัวชี้วัดกลุ่ม UGIH ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 121', 'registered-2026.1', NULL, 'registered'),
    ('DG0201', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute Appendicitis: Percent of abruption', 'Acute Appendicitis: Percent of abruption', 'ตัวชี้วัดกลุ่ม APPENDICITIS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 122', 'registered-2026.1', NULL, 'registered'),
    ('DG0202', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute Appendicitis: Percent of mortality', 'Acute Appendicitis: Percent of mortality', 'ตัวชี้วัดกลุ่ม APPENDICITIS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 123', 'registered-2026.1', NULL, 'registered'),
    ('DH0101', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of mortality', 'Acute coronary syndrome: Percent of mortality', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 39', 'registered-2026.1', NULL, 'registered'),
    ('DH0101.1', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome (STEMI): Percent of mortality', 'Acute coronary syndrome (STEMI): Percent of mortality', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 40', 'registered-2026.1', NULL, 'registered'),
    ('DH0101.2', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome (NSTE-ACS): Percent of mortality', 'Acute coronary syndrome (NSTE-ACS): Percent of mortality', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 41', 'registered-2026.1', NULL, 'registered'),
    ('DH0102', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of patient receiving Aspirin within', 'Acute coronary syndrome: Percent of patient receiving Aspirin within', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 42', 'registered-2026.1', NULL, 'registered'),
    ('DH0103', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Aspirin prescribed at discharge', 'Acute coronary syndrome: Percent of Aspirin prescribed at discharge', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 43', 'pending-local-source-2026.1', 'ต้องยืนยันรายการยา Aspirin ที่สั่งจ่าย ณ วันจำหน่าย (discharge prescription)', 'pending-local-source'),
    ('DH0104', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of ACE inhibitors or ARB received for patient who have LVSD', 'Acute coronary syndrome: Percent of ACE inhibitors or ARB received for patient who have LVSD', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 44', 'pending-local-source-2026.1', 'ต้องยืนยันผลตรวจ LVEF < 40% (LVSD) และรายการยา ACEI/ARB ที่ได้รับ', 'pending-local-source'),
    ('DH0105', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of smoking cessation advice given', 'Acute coronary syndrome: Percent of smoking cessation advice given', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 46', 'pending-local-source-2026.1', 'ต้องยืนยันแบบบันทึกคำแนะนำการเลิกบุหรี่ (smoking cessation counseling) ในผู้ป่วย ACS', 'pending-local-source'),
    ('DH0106', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Beta-blocker receiving during hospital admitted', 'Acute coronary syndrome: Percent of Beta-blocker receiving during hospital admitted', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 47', 'pending-local-source-2026.1', 'ต้องยืนยันการบริหารยากลุ่ม Beta-blocker ระหว่างรับไว้รักษาในโรงพยาบาล', 'pending-local-source'),
    ('DH0107', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Beta-blocker prescribed at discharge', 'Acute coronary syndrome: Percent of Beta-blocker prescribed at discharge', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 48', 'pending-local-source-2026.1', 'ต้องยืนยันรายการยา Beta-blocker ที่สั่งจ่าย ณ วันจำหน่าย', 'pending-local-source'),
    ('DH0108', 'D', 'ratio', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Average door to EKG time', 'Acute coronary syndrome: Average door to EKG time', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 49', 'pending-local-source-2026.1', 'ต้องยืนยัน timestamp เวลาถึงโรงพยาบาล (door time) และเวลาทำ EKG 12-lead แผ่นแรก', 'pending-local-source'),
    ('DH0109', 'D', 'ratio', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Average door to refer time', 'Acute coronary syndrome: Average door to refer time', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 50', 'pending-local-source-2026.1', 'ต้องยืนยัน door-to-refer timestamp และเวลาส่งตัวผู้ป่วย ACS', 'pending-local-source'),
    ('DH0110', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Primary Percutaneous Coronary Intervention (PCI) given within 120 minutes or received Fibrinolytic agent within 30 minutes of arrival', 'Acute coronary syndrome: Percent of Primary Percutaneous Coronary Intervention (PCI) given within 120 minutes or received Fibrinolytic agent within 30 minutes of arrival', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 51', 'pending-local-source-2026.1', 'ต้องยืนยัน door-to-balloon time ภายใน 120 นาที หรือ door-to-needle time ภายใน 30 นาที', 'pending-local-source'),
    ('DH0111', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of unplanned re-admission within', 'Acute coronary syndrome: Percent of unplanned re-admission within', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 53', 'registered-2026.1', NULL, 'registered'),
    ('DH0112', 'D', 'ratio', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Average length of stay', 'Acute coronary syndrome: Average length of stay', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 54', 'registered-2026.1', NULL, 'registered'),
    ('DH0113', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of time to Fibrinolytic administration agents within 30 minutes of arrival', 'Acute coronary syndrome: Percent of time to Fibrinolytic administration agents within 30 minutes of arrival', 'ตัวชี้วัดกลุ่ม ACS ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 55', 'pending-local-source-2026.1', 'ต้องยืนยัน door-to-needle timestamp ในการให้ยาละลายลิ่มเลือด (Fibrinolytic) ภายใน 30 นาที', 'pending-local-source'),
    ('DH0201', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): Percent of mortality', 'Coronary Artery Bypass Graft (CABG): Percent of mortality', 'ตัวชี้วัดกลุ่ม CABG ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 57', 'registered-2026.1', NULL, 'registered'),
    ('DH0202', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis', 'ตัวชี้วัดกลุ่ม CABG ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 58', 'registered-2026.1', NULL, 'registered'),
    ('DH0203', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection', 'ตัวชี้วัดกลุ่ม CABG ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 59', 'registered-2026.1', NULL, 'registered'),
    ('DH0204', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): percent of 30-days hospital mortality', 'Coronary Artery Bypass Graft (CABG): percent of 30-days hospital mortality', 'ตัวชี้วัดกลุ่ม CABG ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 60', 'registered-2026.1', NULL, 'registered'),
    ('DH0301', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Fraction (HFREF) received Angiotensin II Converting Enzyme inhibitors (ACEIs) or Angiotensin II Receptor Blockers (ARBs) or Mineralocorticoid Receptor Antagonists (MRA)', 'Fraction (HFREF) received Angiotensin II Converting Enzyme inhibitors (ACEIs) or Angiotensin II Receptor Blockers (ARBs) or Mineralocorticoid Receptor Antagonists (MRA)', 'ตัวชี้วัดกลุ่ม HEART_FAILURE ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 61', 'registered-2026.1', NULL, 'registered'),
    ('DH0302', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Heart failure: Percent of smoking cessation advice given', 'Heart failure: Percent of smoking cessation advice given', 'ตัวชี้วัดกลุ่ม HEART_FAILURE ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 63', 'registered-2026.1', NULL, 'registered'),
    ('DH0401', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Atrial fibrillation: Percent of patient received Warfarin within target', 'Atrial fibrillation: Percent of patient received Warfarin within target', 'ตัวชี้วัดกลุ่ม ATRIAL_FIBRILLATION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 64', 'pending-local-source-2026.1', 'ต้องยืนยัน anticoagulant target และนิยาม intracranial bleed', 'pending-local-source'),
    ('DH0402', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Atrial Fibrillation: Percent of major bleeding (intracranial hemorrhage)', 'Atrial Fibrillation: Percent of major bleeding (intracranial hemorrhage)', 'ตัวชี้วัดกลุ่ม ATRIAL_FIBRILLATION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 66', 'pending-local-source-2026.1', 'ต้องยืนยัน anticoagulant target และนิยาม intracranial bleed', 'pending-local-source'),
    ('DM0101', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'GDD: Percent of children with global development delay that improved after intervented', 'GDD: Percent of children with global development delay that improved after intervented', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 151', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0102', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'GDD: Percent of children with Global development delay that improved after intervented with TEDA4I', 'GDD: Percent of children with Global development delay that improved after intervented with TEDA4I', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 152', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0103', 'D', 'percent', 'neutral', 'annual', 'Disease', 'GDD: Percent of children with global development delay that improved after intervented', 'GDD: Percent of children with global development delay that improved after intervented', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 153', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0201', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement', 'ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 154', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0202', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement with TEDA4I', 'ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement with TEDA4I', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 155', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0203', 'D', 'percent', 'neutral', 'annual', 'Disease', 'ASD: Percent of children with autism spectrum disorder (ASD) that are included in educational system for at least 1 year', 'ASD: Percent of children with autism spectrum disorder (ASD) that are included in educational system for at least 1 year', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 156', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0301', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented', 'Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 157', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0302', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented', 'Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 158', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0401', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Child and adolescent psychiatry: Percent of children with Attention- Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6', 'Child and adolescent psychiatry: Percent of children with Attention- Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 159', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DM0402', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Child and adolescent psychiatry: Percent of children and adolescents with Major Depressive Disorder (MDD) improved after intervented for', 'Child and adolescent psychiatry: Percent of children and adolescents with Major Depressive Disorder (MDD) improved after intervented for', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 160', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DN0101', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Stroke: Percent of mortality', 'Stroke: Percent of mortality', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 67', 'registered-2026.1', NULL, 'registered'),
    ('DN0102', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Ischemic stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission', 'Ischemic stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 68', 'pending-local-source-2026.1', 'ต้องยืนยันการบริหารยา Antiplatelet ภายใน 2 วัน (48 ชั่วโมง) แรกหลังรับไว้รักษา', 'pending-local-source'),
    ('DN0103', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Ischemic stroke: Percent of Antiplatelet or Anticoagulant therapy prescribed at discharge', 'Ischemic stroke: Percent of Antiplatelet or Anticoagulant therapy prescribed at discharge', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 69', 'pending-local-source-2026.1', 'ต้องยืนยันรายการยา Antiplatelet หรือ Anticoagulant ที่สั่งจ่าย ณ วันจำหน่าย', 'pending-local-source'),
    ('DN0104', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Ischemic stroke: Percent of patient with Atrial fibrillation/Flutter receiving Anticoagulation therapy', 'Ischemic stroke: Percent of patient with Atrial fibrillation/Flutter receiving Anticoagulation therapy', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 70', 'pending-local-source-2026.1', 'ต้องยืนยันผล EKG ภาวะ Atrial Fibrillation/Flutter และการสั่งจ่ายยา Anticoagulation', 'pending-local-source'),
    ('DN0105', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Stroke: Percent of patients who were given stroke education during their hospital stay', 'Stroke: Percent of patients who were given stroke education during their hospital stay', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 71', 'pending-local-source-2026.1', 'ต้องยืนยันแบบประเมินและบันทึกการให้สุขศึกษาโรคหลอดเลือดสมอง (Stroke education)', 'pending-local-source'),
    ('DN0106', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Stroke: Percent of treatment, physiotherapy or rehabilitation in stroke or paralytic syndrome within 72 hours', 'Stroke: Percent of treatment, physiotherapy or rehabilitation in stroke or paralytic syndrome within 72 hours', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 72', 'pending-local-source-2026.1', 'ต้องยืนยันบันทึกการเริ่มทำกายภาพบำบัดหรือเวชศาสตร์ฟื้นฟูภายใน 72 ชั่วโมงหลังรับไว้รักษา', 'pending-local-source'),
    ('DN0107', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Stroke: Percent of unplanned re-admission of stroke within 28 days', 'Stroke: Percent of unplanned re-admission of stroke within 28 days', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 73', 'registered-2026.1', NULL, 'registered'),
    ('DN0109', 'D', 'ratio', 'neutral', 'monthly', 'Disease', 'Stroke: Average length of stay', 'Stroke: Average length of stay', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 74', 'registered-2026.1', NULL, 'registered'),
    ('DN0110', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Ischemic Stroke: Percent of time to Thrombolytic administration agents within 60 minutes of arrival', 'Ischemic Stroke: Percent of time to Thrombolytic administration agents within 60 minutes of arrival', 'ตัวชี้วัดกลุ่ม STROKE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 75', 'pending-local-source-2026.1', 'ต้องยืนยัน door-to-needle timestamp ในการให้ยา Thrombolytic (rtPA) ภายใน 60 นาที', 'pending-local-source'),
    ('DN0301', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Head Injury: Percent of unplanned re-admission of Craniotomy within', 'Head Injury: Percent of unplanned re-admission of Craniotomy within', 'ตัวชี้วัดกลุ่ม HEAD_INJURY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 76', 'pending-local-source-2026.1', 'ต้องยืนยัน craniotomy และหน้าต่าง 48 ชั่วโมง', 'pending-local-source'),
    ('DN0302', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Head Injury: Percent of mortality within 48 hours', 'Head Injury: Percent of mortality within 48 hours', 'ตัวชี้วัดกลุ่ม HEAD_INJURY ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 77', 'registered-2026.1', NULL, 'registered'),
    ('DN0303', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Head Injury: Percent of patient underwent craniotomy for Intracranial', 'Head Injury: Percent of patient underwent craniotomy for Intracranial', 'ตัวชี้วัดกลุ่ม HEAD_INJURY ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 78', 'pending-local-source-2026.1', 'ต้องยืนยัน craniotomy และหน้าต่าง 48 ชั่วโมง', 'pending-local-source'),
    ('DO0202', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Hip arthroplasty: Percent of patients who received antibiotic prophylaxis in Hip arthroplasty', 'Hip arthroplasty: Percent of patients who received antibiotic prophylaxis in Hip arthroplasty', 'ตัวชี้วัดกลุ่ม ARTHROPLASTY ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 114', 'registered-2026.1', NULL, 'registered'),
    ('DO0204', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Hip arthroplasty: Percent of hip arthroplasty associated infection within 1 Year', 'Hip arthroplasty: Percent of hip arthroplasty associated infection within 1 Year', 'ตัวชี้วัดกลุ่ม ARTHROPLASTY ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 115', 'registered-2026.1', NULL, 'registered'),
    ('DO0205', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Hip arthroplasty: Percent of hip arthroplasty associated infection within 90 days', 'Hip arthroplasty: Percent of hip arthroplasty associated infection within 90 days', 'ตัวชี้วัดกลุ่ม ARTHROPLASTY ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 116', 'registered-2026.1', NULL, 'registered'),
    ('DO0302', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Knee Arthroplasty: Percent of patients who received antibiotic prophylaxis', 'Knee Arthroplasty: Percent of patients who received antibiotic prophylaxis', 'ตัวชี้วัดกลุ่ม ARTHROPLASTY ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 117', 'registered-2026.1', NULL, 'registered'),
    ('DO0303', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Knee Arthroplasty: Percent of surgical infection within 1 year', 'Knee Arthroplasty: Percent of surgical infection within 1 year', 'ตัวชี้วัดกลุ่ม ARTHROPLASTY ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 118', 'registered-2026.1', NULL, 'registered'),
    ('DO0304', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Knee Arthroplasty: Percent of surgical infection within 90 days', 'Knee Arthroplasty: Percent of surgical infection within 90 days', 'ตัวชี้วัดกลุ่ม ARTHROPLASTY ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 119', 'registered-2026.1', NULL, 'registered'),
    ('DP0101', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Diabetes in child and adolescent: Percent of good controlled of blood sugar (age < 18 years)', 'Diabetes in child and adolescent: Percent of good controlled of blood sugar (age < 18 years)', 'ตัวชี้วัดกลุ่ม PEDIATRIC_DM ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['person', 'clinicmember', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 124', 'registered-2026.1', NULL, 'registered'),
    ('DR0101', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Pneumonia: Percent of mortality after hospital admission', 'Pneumonia: Percent of mortality after hospital admission', 'ตัวชี้วัดกลุ่ม PNEUMONIA ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 79', 'registered-2026.1', NULL, 'registered'),
    ('DR0102', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Pneumonia: Percent of unplanned re-admission within 28 days after last discharge', 'Pneumonia: Percent of unplanned re-admission within 28 days after last discharge', 'ตัวชี้วัดกลุ่ม PNEUMONIA ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 80', 'registered-2026.1', NULL, 'registered'),
    ('DR0103', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Pneumonia: Percent of smoking cessation advice given', 'Pneumonia: Percent of smoking cessation advice given', 'ตัวชี้วัดกลุ่ม PNEUMONIA ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 81', 'pending-local-source-2026.1', 'ต้องยืนยันแบบบันทึกคำแนะนำการเลิกบุหรี่ (smoking cessation counseling) ในผู้ป่วยปอดอักเสบ', 'pending-local-source'),
    ('DR0201', 'D', 'percent', 'neutral', 'annual', 'Disease', 'TB: Percent of mortality during 12 months', 'TB: Percent of mortality during 12 months', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 82', 'registered-2026.1', NULL, 'registered'),
    ('DR0202', 'D', 'percent', 'neutral', 'annual', 'Disease', 'TB: Percentage of people living with HIV having a TB screening', 'TB: Percentage of people living with HIV having a TB screening', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 83', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DR0203', 'D', 'percent', 'neutral', 'annual', 'Disease', 'TB: Percent of treatment success', 'TB: Percent of treatment success', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 84', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DR0204', 'D', 'percent', 'neutral', 'annual', 'Disease', 'TB: Percent of TB having a HIV screening', 'TB: Percent of TB having a HIV screening', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 85', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DR0205', 'D', 'percent', 'neutral', 'annual', 'Disease', 'Antiretroviral therapy (ART) TB: Percent of HIV-positive TB patients started on Antiretroviral therapy (ART)', 'Antiretroviral therapy (ART) TB: Percent of HIV-positive TB patients started on Antiretroviral therapy (ART)', 'ตัวชี้วัดกลุ่ม HIV_TB ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 86', 'pending-local-source-2026.1', 'ต้องยืนยันวันลงทะเบียน cohort, หน้าต่าง 12 เดือน และความหมาย test/result', 'pending-local-source'),
    ('DR0301', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Asthma: Percent of unplanned re-admission within 28 days after last discharge', 'Asthma: Percent of unplanned re-admission within 28 days after last discharge', 'ตัวชี้วัดกลุ่ม ASTHMA_COPD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 87', 'registered-2026.1', NULL, 'registered'),
    ('DR0302', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Asthma: Percent of smoking cessation advice given', 'Asthma: Percent of smoking cessation advice given', 'ตัวชี้วัดกลุ่ม ASTHMA_COPD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 88', 'registered-2026.1', NULL, 'registered'),
    ('DR0401', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'COPD: Percent of unplanned re-admission into the hospital within 28 days after last discharge', 'COPD: Percent of unplanned re-admission into the hospital within 28 days after last discharge', 'ตัวชี้วัดกลุ่ม ASTHMA_COPD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 89', 'registered-2026.1', NULL, 'registered'),
    ('DR0403', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'COPD: Percent of mortality', 'COPD: Percent of mortality', 'ตัวชี้วัดกลุ่ม ASTHMA_COPD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 90', 'registered-2026.1', NULL, 'registered'),
    ('DR0404', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'COPD: Percent of patient with ongoing smoking', 'COPD: Percent of patient with ongoing smoking', 'ตัวชี้วัดกลุ่ม ASTHMA_COPD ตาม THIP KPI Dictionary 2025; มี registered query และต้องยืนยัน local clinical rule', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 91', 'registered-2026.1', NULL, 'registered'),
    ('DS0101', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Methamphetamine Group: 3 months total remission rate', 'Methamphetamine Group: 3 months total remission rate', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 126', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DS0201', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Alcohol Group: 3 months total remission rate', 'Alcohol Group: 3 months total remission rate', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 127', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DS0301', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Tobacco Group: 3 months total remission rate', 'Tobacco Group: 3 months total remission rate', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 128', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('DS0401', 'D', 'percent', 'neutral', 'monthly', 'Disease', 'Opioid Group: 1 year retention rate of opioid in methadone maintenance program', 'Opioid Group: 1 year retention rate of opioid in methadone maintenance program', 'ตัวชี้วัดกลุ่ม MENTAL_DEVELOPMENT ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 129', 'pending-local-source-2026.1', 'ต้องยืนยัน baseline/follow-up score และการติดตาม remission/retention', 'pending-local-source'),
    ('HC0101', 'H', 'ratio', 'neutral', 'annual', 'Health promotion', 'Customer: Asthma patients or their relative(s) who are able to care for the patient''s needs', 'Customer: Asthma patients or their relative(s) who are able to care for the patient''s needs', 'ตัวชี้วัดกลุ่ม CHRONIC_ED ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 270', 'pending-local-source-2026.1', 'ต้องยืนยันระดับความเร่งด่วน triage ของห้องฉุกเฉิน (Non-urgent triage) และเกณฑ์ Asthma/COPD', 'pending-local-source'),
    ('HC0102', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Customer: COPD patients or their relative(s) who are able to care for the patient''s needs', 'Customer: COPD patients or their relative(s) who are able to care for the patient''s needs', 'ตัวชี้วัดกลุ่ม CHRONIC_ED ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 271', 'pending-local-source-2026.1', 'ต้องยืนยันนัดตรวจติดตาม OPD follow-up ภายใน 30 วันหลังจำหน่าย', 'pending-local-source'),
    ('HE0101', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Employee: Percent of employee check-up', 'Employee: Percent of employee check-up', 'ตัวชี้วัดกลุ่ม EMPLOYEE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 264', 'pending-local-source-2026.1', 'ต้องยืนยัน employee denominator, check-up, BMI และ influenza vaccine', 'pending-local-source'),
    ('HE0102', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Employee: Percent of employee have exceeding BMI', 'Employee: Percent of employee have exceeding BMI', 'ตัวชี้วัดกลุ่ม EMPLOYEE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 265', 'pending-local-source-2026.1', 'ต้องยืนยัน employee denominator, check-up, BMI และ influenza vaccine', 'pending-local-source'),
    ('HE0103', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Employee: Percent of employee have behavior-smoky', 'Employee: Percent of employee have behavior-smoky', 'ตัวชี้วัดกลุ่ม EMPLOYEE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 266', 'pending-local-source-2026.1', 'ต้องยืนยัน employee denominator, check-up, BMI และ influenza vaccine', 'pending-local-source'),
    ('HE0104', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Employee: Percent of employee (male) obesity', 'Employee: Percent of employee (male) obesity', 'ตัวชี้วัดกลุ่ม EMPLOYEE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 267', 'pending-local-source-2026.1', 'ต้องยืนยัน employee denominator, check-up, BMI และ influenza vaccine', 'pending-local-source'),
    ('HE0105', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Employee: Percent of employee (female) obesity', 'Employee: Percent of employee (female) obesity', 'ตัวชี้วัดกลุ่ม EMPLOYEE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 268', 'pending-local-source-2026.1', 'ต้องยืนยัน employee denominator, check-up, BMI และ influenza vaccine', 'pending-local-source'),
    ('HE0106', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Employee: Percent of employee received Influenza immunization', 'Employee: Percent of employee received Influenza immunization', 'ตัวชี้วัดกลุ่ม EMPLOYEE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 269', 'pending-local-source-2026.1', 'ต้องยืนยัน employee denominator, check-up, BMI และ influenza vaccine', 'pending-local-source'),
    ('HH0101.1', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percent of smoking tobacco products used by service recipients', 'Tobacco Use: Percent of smoking tobacco products used by service recipients', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 272', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0101.2', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percent of Tobacco Use Screened of Service Recipients aged ≥ 15 years old at the Outpatient Service.', 'Tobacco Use: Percent of Tobacco Use Screened of Service Recipients aged ≥ 15 years old at the Outpatient Service.', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 273', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0102', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence patients receiving nicotine dependence treatment.', 'Tobacco Use: Percentage of nicotine dependence patients receiving nicotine dependence treatment.', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 274', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0103.1', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in DM patients receiving nicotine dependence treatment.', 'Tobacco Use: Percentage of nicotine dependence in DM patients receiving nicotine dependence treatment.', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 275', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0103.2', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Hypertension patients receiving nicotine dependence treatment.', 'Tobacco Use: Percentage of nicotine dependence in Hypertension patients receiving nicotine dependence treatment.', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 276', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0103.3', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment', 'Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 277', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0103.4', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in COPD patients receiving nicotine dependence treatment.', 'Tobacco Use: Percentage of nicotine dependence in COPD patients receiving nicotine dependence treatment.', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 278', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0103.5', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Pregnant patients receiving nicotine dependence treatment.', 'Tobacco Use: Percentage of nicotine dependence in Pregnant patients receiving nicotine dependence treatment.', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 279', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0103.6', 'H', 'percent', 'neutral', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment.', 'Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment.', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 280', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0104.1', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (DM Patients)', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (DM Patients)', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 281', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0104.2', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (Hypertension Patients)', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (Hypertension Patients)', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 282', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0104.3', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (Asthma Patients)', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (Asthma Patients)', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 283', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0104.4', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (COPD Patients)', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (COPD Patients)', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 284', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('HH0104.5', 'H', 'percent', 'neutral', 'annual', 'Health promotion', 'Tobacco use: Tobacco use: continuous abstinence rate (CAR) at 6 months (Pregnant Patients)', 'Tobacco use: Tobacco use: continuous abstinence rate (CAR) at 6 months (Pregnant Patients)', 'ตัวชี้วัดกลุ่ม TOBACCO ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 285', 'pending-local-source-2026.1', 'ต้องยืนยัน screen/treatment/abstinence follow-up และ subgroup', 'pending-local-source'),
    ('SC0101', 'S', 'percent', 'neutral', 'monthly', 'System', 'Customer: Percent of outpatient satisfaction (overall)', 'Customer: Percent of outpatient satisfaction (overall)', 'ตัวชี้วัดกลุ่ม CUSTOMER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 250', 'pending-local-source-2026.1', 'ต้องยืนยัน questionnaire version และ response denominator', 'pending-local-source'),
    ('SC0102', 'S', 'percent', 'neutral', 'monthly', 'System', 'Customer: Percent of inpatient satisfaction (overall)', 'Customer: Percent of inpatient satisfaction (overall)', 'ตัวชี้วัดกลุ่ม CUSTOMER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 251', 'pending-local-source-2026.1', 'ต้องยืนยัน questionnaire version และ response denominator', 'pending-local-source'),
    ('SC0103', 'S', 'percent', 'neutral', 'monthly', 'System', 'Customer: Percent of outpatients who return to receive care', 'Customer: Percent of outpatients who return to receive care', 'ตัวชี้วัดกลุ่ม CUSTOMER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 252', 'pending-local-source-2026.1', 'ต้องยืนยัน questionnaire version และ response denominator', 'pending-local-source'),
    ('SC0104', 'S', 'percent', 'neutral', 'monthly', 'System', 'Customer: Percent of inpatients who return to receive care', 'Customer: Percent of inpatients who return to receive care', 'ตัวชี้วัดกลุ่ม CUSTOMER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 253', 'pending-local-source-2026.1', 'ต้องยืนยัน questionnaire version และ response denominator', 'pending-local-source'),
    ('SC0105', 'S', 'percent', 'neutral', 'monthly', 'System', 'Customer: Percent of outpatients who would recommend friends or family to receive care at this facility', 'Customer: Percent of outpatients who would recommend friends or family to receive care at this facility', 'ตัวชี้วัดกลุ่ม CUSTOMER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 254', 'pending-local-source-2026.1', 'ต้องยืนยัน questionnaire version และ response denominator', 'pending-local-source'),
    ('SC0106', 'S', 'percent', 'neutral', 'monthly', 'System', 'Customer: Percent of inpatients who would recommend friends or family to receive care at this facility', 'Customer: Percent of inpatients who would recommend friends or family to receive care at this facility', 'ตัวชี้วัดกลุ่ม CUSTOMER ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 255', 'pending-local-source-2026.1', 'ต้องยืนยัน questionnaire version และ response denominator', 'pending-local-source'),
    ('SF0101', 'S', 'ratio', 'neutral', 'annual', 'System', 'Financial: Current ratio', 'Financial: Current ratio', 'ตัวชี้วัดกลุ่ม FINANCE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 244', 'pending-local-source-2026.1', 'HOSxP operational fields ไม่เท่ากับงบการเงินที่ตรวจสอบแล้ว', 'pending-local-source'),
    ('SF0102', 'S', 'ratio', 'neutral', 'annual', 'System', 'Financial: Quick ratio', 'Financial: Quick ratio', 'ตัวชี้วัดกลุ่ม FINANCE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 245', 'pending-local-source-2026.1', 'HOSxP operational fields ไม่เท่ากับงบการเงินที่ตรวจสอบแล้ว', 'pending-local-source'),
    ('SF0103', 'S', 'ratio', 'neutral', 'annual', 'System', 'Financial: Fixed asset turnover', 'Financial: Fixed asset turnover', 'ตัวชี้วัดกลุ่ม FINANCE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 246', 'pending-local-source-2026.1', 'HOSxP operational fields ไม่เท่ากับงบการเงินที่ตรวจสอบแล้ว', 'pending-local-source'),
    ('SF0104', 'S', 'ratio', 'neutral', 'annual', 'System', 'Financial: Day in account receivable (average collection period for account receivables)', 'Financial: Day in account receivable (average collection period for account receivables)', 'ตัวชี้วัดกลุ่ม FINANCE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 247', 'pending-local-source-2026.1', 'HOSxP operational fields ไม่เท่ากับงบการเงินที่ตรวจสอบแล้ว', 'pending-local-source'),
    ('SF0105', 'S', 'percent', 'neutral', 'annual', 'System', 'Financial: Net profit margin', 'Financial: Net profit margin', 'ตัวชี้วัดกลุ่ม FINANCE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 248', 'pending-local-source-2026.1', 'HOSxP operational fields ไม่เท่ากับงบการเงินที่ตรวจสอบแล้ว', 'pending-local-source'),
    ('SF0106', 'S', 'percent', 'neutral', 'annual', 'System', 'Financial: Return on asset (ROA)', 'Financial: Return on asset (ROA)', 'ตัวชี้วัดกลุ่ม FINANCE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 249', 'pending-local-source-2026.1', 'HOSxP operational fields ไม่เท่ากับงบการเงินที่ตรวจสอบแล้ว', 'pending-local-source'),
    ('SG0104', 'S', 'ratio', 'neutral', 'monthly', 'System', 'Governance: Percent of recycled waste', 'Governance: Percent of recycled waste', 'ตัวชี้วัดกลุ่ม GOVERNANCE ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'supply_sterile', 'supply_sterile_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 256', 'pending-local-source-2026.1', 'แหล่ง recycled waste อาจเป็น custom/นอก HOSxP มาตรฐาน', 'pending-local-source'),
    ('SH0101', 'S', 'percent', 'neutral', 'annual', 'System', 'HRM: Turnover rate', 'HRM: Turnover rate', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 212', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0102', 'S', 'percent', 'neutral', 'annual', 'System', 'HRM: Percent of employee work-related Injury', 'HRM: Percent of employee work-related Injury', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 213', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0103', 'S', 'percent', 'neutral', 'annual', 'System', 'HRM: Percent of employee work-related Illness', 'HRM: Percent of employee work-related Illness', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 214', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0104', 'S', 'percent', 'neutral', 'monthly', 'System', 'HRM: Turnover rate of physician and dentist', 'HRM: Turnover rate of physician and dentist', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 215', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0105', 'S', 'percent', 'neutral', 'monthly', 'System', 'HRM: Turnover rate of nurses', 'HRM: Turnover rate of nurses', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 216', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0106', 'S', 'percent', 'neutral', 'monthly', 'System', 'HRM: Turnover rate of allied health personnel', 'HRM: Turnover rate of allied health personnel', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 217', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0107', 'S', 'percent', 'neutral', 'monthly', 'System', 'HRM: Turnover rate of back office personnel', 'HRM: Turnover rate of back office personnel', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 218', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0201', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of physician/dentist satisfaction (level 4-5)', 'HRD: Percent of physician/dentist satisfaction (level 4-5)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 219', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0202', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of nurse satisfaction (level 4-5)', 'HRD: Percent of nurse satisfaction (level 4-5)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 220', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0203', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of allied health personel satisfaction (level 4-5)', 'HRD: Percent of allied health personel satisfaction (level 4-5)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 221', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0204', 'S', 'ratio', 'neutral', 'annual', 'System', 'HRD: Training hour per person per year of physician/dentist', 'HRD: Training hour per person per year of physician/dentist', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 222', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0205', 'S', 'ratio', 'neutral', 'annual', 'System', 'HRD: HRD: Training hour per person per Year of nurse', 'HRD: HRD: Training hour per person per Year of nurse', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 223', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0206', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of physician and dentist satisfaction (average)', 'HRD: Percent of physician and dentist satisfaction (average)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 224', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0207', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of physician and dentist satisfaction (level 1-2)', 'HRD: Percent of physician and dentist satisfaction (level 1-2)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 225', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0208', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percentage of nurse satisfaction (average)', 'HRD: Percentage of nurse satisfaction (average)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 226', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0209', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percentage of nurse satisfaction (level 1-2)', 'HRD: Percentage of nurse satisfaction (level 1-2)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 227', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0210', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of allied health personnel satisfaction (average)', 'HRD: Percent of allied health personnel satisfaction (average)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 228', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0211', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of allied health personnel satisfaction (level 1-2)', 'HRD: Percent of allied health personnel satisfaction (level 1-2)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 229', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0212', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percent of back office personnel satisfaction (average)', 'HRD: Percent of back office personnel satisfaction (average)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 230', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0213', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percentage of back office personnel satisfaction (level 4-5)', 'HRD: Percentage of back office personnel satisfaction (level 4-5)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 231', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0214', 'S', 'percent', 'neutral', 'annual', 'System', 'HRD: Percentage of back office personnel satisfaction (level 1-2)', 'HRD: Percentage of back office personnel satisfaction (level 1-2)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 232', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0215', 'S', 'ratio', 'neutral', 'annual', 'System', 'HRD: Training hour per person per year of allied health personnel', 'HRD: Training hour per person per year of allied health personnel', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 233', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0216', 'S', 'ratio', 'neutral', 'annual', 'System', 'HRD: Training hour per person per year of back office personnel', 'HRD: Training hour per person per year of back office personnel', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 234', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0301', 'S', 'rate', 'neutral', 'monthly', 'System', 'HRH: Injury (Illnesses) Frequency Rate (IFR)', 'HRH: Injury (Illnesses) Frequency Rate (IFR)', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 235', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0302', 'S', 'rate', 'neutral', 'monthly', 'System', 'HRH: Injury Severity Rate: ISR of Direct Contact with Patients', 'HRH: Injury Severity Rate: ISR of Direct Contact with Patients', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 236', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0303', 'S', 'rate', 'neutral', 'monthly', 'System', 'HRH: Injury Severity Rate: ISRof non Direct Contact with Patients', 'HRH: Injury Severity Rate: ISRof non Direct Contact with Patients', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 238', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0306', 'S', 'rate', 'neutral', 'monthly', 'System', 'HRH: Injury (illnesses) Frequency Rate: IFR of direct contact with patients', 'HRH: Injury (illnesses) Frequency Rate: IFR of direct contact with patients', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 240', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SH0307', 'S', 'rate', 'neutral', 'monthly', 'System', 'HRH: Injury (Illnesses) Frequency Rate : IFR of Non-direct Contact with Patients', 'HRH: Injury (Illnesses) Frequency Rate : IFR of Non-direct Contact with Patients', 'ตัวชี้วัดกลุ่ม HR ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 242', 'pending-local-source-2026.1', 'ต้องยืนยัน headcount/FTE, category, training และ injury', 'pending-local-source'),
    ('SI0101', 'S', 'rate', 'neutral', 'monthly', 'System', 'VAP: Rate of ventilator-associated pneumonia (All)', 'VAP: Rate of ventilator-associated pneumonia (All)', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 202', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0102', 'S', 'rate', 'neutral', 'monthly', 'System', 'VAP: Rate of ventilator-associated pneumonia in ICU', 'VAP: Rate of ventilator-associated pneumonia in ICU', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 203', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0103', 'S', 'rate', 'neutral', 'monthly', 'System', 'VAP: Rate of ventilator-associated pneumonia outside ICU', 'VAP: Rate of ventilator-associated pneumonia outside ICU', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 204', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0201', 'S', 'rate', 'neutral', 'monthly', 'System', 'BSI: Rate of CABSI (All)', 'BSI: Rate of CABSI (All)', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 205', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0202', 'S', 'rate', 'neutral', 'monthly', 'System', 'BSI: Rate of CABSI in ICU', 'BSI: Rate of CABSI in ICU', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 206', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0203', 'S', 'rate', 'neutral', 'monthly', 'System', 'BSI: Rate of CABSI outside ICU', 'BSI: Rate of CABSI outside ICU', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 207', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0301', 'S', 'rate', 'neutral', 'monthly', 'System', 'CAUTI: Rate of CAUTI (All)', 'CAUTI: Rate of CAUTI (All)', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 208', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0302', 'S', 'rate', 'neutral', 'monthly', 'System', 'CAUTI: Rate of CAUTI in ICU', 'CAUTI: Rate of CAUTI in ICU', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 209', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SI0303', 'S', 'rate', 'neutral', 'monthly', 'System', 'CAUTI: Rate of CAUTI outside ICU', 'CAUTI: Rate of CAUTI outside ICU', 'ตัวชี้วัดกลุ่ม INFECTION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 1,000', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 210', 'pending-local-source-2026.1', 'ต้องยืนยัน device-days และ infection surveillance event (อาจเป็น custom)', 'pending-local-source'),
    ('SL0101', 'S', 'ratio', 'neutral', 'monthly', 'System', 'Crossmatch-to-Transfusion ratios (C:T) in selective surgery cases', 'Crossmatch-to-Transfusion ratios (C:T) in selective surgery cases', 'ตัวชี้วัดกลุ่ม BLOOD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['blood_request', 'ipt', 'an_stat', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 211', 'pending-local-source-2026.1', 'ต้องยืนยัน selective-surgery denominator และ transfusion event', 'pending-local-source'),
    ('SM0102', 'S', 'percent', 'neutral', 'monthly', 'System', 'Medication Use: Percent of Antibiotic prescribing rate on Upper respiratory infection', 'Medication Use: Percent of Antibiotic prescribing rate on Upper respiratory infection', 'ตัวชี้วัดกลุ่ม MEDICATION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'opitemrece', 'drugitems', 'stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'stock_trancation_itemdata']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 260', 'pending-local-source-2026.1', 'ต้องยืนยันนิยาม antibiotic prescribing และสูตร inventory turn', 'pending-local-source'),
    ('SM0103', 'S', 'percent', 'neutral', 'monthly', 'System', 'Medication Use: Percent of Antibiotic prescribing on Acute diarrhea', 'Medication Use: Percent of Antibiotic prescribing on Acute diarrhea', 'ตัวชี้วัดกลุ่ม MEDICATION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'opitemrece', 'drugitems', 'stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'stock_trancation_itemdata']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 261', 'pending-local-source-2026.1', 'ต้องยืนยันนิยาม antibiotic prescribing และสูตร inventory turn', 'pending-local-source'),
    ('SM0201', 'S', 'ratio', 'neutral', 'monthly', 'System', 'Medication management: Inventory turn', 'Medication management: Inventory turn', 'ตัวชี้วัดกลุ่ม MEDICATION ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b (inventory turn; ตรวจสูตรใน PDF)', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ovst', 'ovstdiag', 'opitemrece', 'drugitems', 'stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'stock_trancation_itemdata']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 262', 'pending-local-source-2026.1', 'ต้องยืนยันนิยาม antibiotic prescribing และสูตร inventory turn', 'pending-local-source'),
    ('SS0101', 'S', 'percent', 'neutral', 'monthly', 'System', 'CSSD: Percent of examination of effective sterilization', 'CSSD: Percent of examination of effective sterilization', 'ตัวชี้วัดกลุ่ม CSSD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['supply_sterile', 'supply_sterile_item', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 257', 'pending-local-source-2026.1', 'ต้องยืนยัน sterilization test และ equipment/procedure request', 'pending-local-source'),
    ('SS0102', 'S', 'percent', 'neutral', 'monthly', 'System', 'CSSD: Percent of exact medical equipment prepared for specific procedures', 'CSSD: Percent of exact medical equipment prepared for specific procedures', 'ตัวชี้วัดกลุ่ม CSSD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['supply_sterile', 'supply_sterile_item', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 258', 'pending-local-source-2026.1', 'ต้องยืนยัน sterilization test และ equipment/procedure request', 'pending-local-source'),
    ('SS0103', 'S', 'percent', 'neutral', 'monthly', 'System', 'CSSD: Percent of medical supplies which are accurately provided by the CSSD', 'CSSD: Percent of medical supplies which are accurately provided by the CSSD', 'ตัวชี้วัดกลุ่ม CSSD ตาม THIP KPI Dictionary 2025; ยังต้องทำ local mapping และ source view', 'a/b x 100', 'ต้องยืนยันตามนิยาม PDF และ local rule', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['supply_sterile', 'supply_sterile_item', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 259', 'pending-local-source-2026.1', 'ต้องยืนยัน sterilization test และ equipment/procedure request', 'pending-local-source')
),
fiscal_periods AS (
  SELECT
    generated.period_start::date AS period_start,
    CASE WHEN EXTRACT(MONTH FROM generated.period_start) >= 10 THEN EXTRACT(MONTH FROM generated.period_start)::integer - 9 ELSE EXTRACT(MONTH FROM generated.period_start)::integer + 3 END AS fiscal_month,
    CASE WHEN EXTRACT(MONTH FROM generated.period_start) >= 10 THEN EXTRACT(YEAR FROM generated.period_start)::integer + 1 ELSE EXTRACT(YEAR FROM generated.period_start)::integer END AS fiscal_year
  FROM generate_series(
    CAST(:start_date AS date),
    CAST(:end_date AS date) - INTERVAL '1 month',
    INTERVAL '1 month'
  ) AS generated(period_start)
)
SELECT
  m.indicator_code,
  fp.period_start,
  fp.fiscal_year,
  fp.fiscal_month,
  CASE WHEN m.tier = 'registered' THEN COALESCE(f.numerator, 0) ELSE NULL END AS numerator,
  CASE WHEN m.tier = 'registered' THEN COALESCE(f.denominator, 0) ELSE NULL END AS denominator,
  CASE WHEN m.tier = 'registered' THEN f.value ELSE NULL END AS value,
  NULL::numeric AS target,
  m.target_scope,
  NULL::numeric AS percentile,
  m.indicator_group,
  m.unit,
  m.direction,
  m.category,
  m.title,
  m.title_th,
  m.definition,
  m.formula,
  m.numerator_label,
  m.denominator_label,
  m.source_tables,
  m.frequency,
  m.reference,
  m.rule_version,
  m.pending_reason,
  m.tier,
  NOW() AS refreshed_at
FROM metadata m
JOIN expected e
  ON e.indicator_code = m.indicator_code
JOIN fiscal_periods fp
  ON fp.fiscal_month = e.fiscal_month
LEFT JOIN facts f
  ON f.indicator_code = m.indicator_code
 AND f.period_start = fp.period_start
 AND f.fiscal_month = fp.fiscal_month
 AND f.fiscal_year = fp.fiscal_year
ORDER BY m.indicator_code, fp.period_start;
