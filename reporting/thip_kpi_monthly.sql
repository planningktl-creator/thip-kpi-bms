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

-- Hospital-loaded aggregate staging for KPIs whose denominator or source lives
-- outside HOSxP (population registers, finance, surveys, custom registries).
-- Load exactly one row per indicator code x reporting-period anchor; rows read
-- by the thipExternalFoundation query and the refresh above through the
-- external_facts CTE. Aggregate values only — never patient rows.
CREATE TABLE IF NOT EXISTS reporting.thip_external_facts (
  indicator_code varchar(10)  NOT NULL,
  period_start   date         NOT NULL,
  numerator      numeric(18, 4),
  denominator    numeric(18, 4),
  value          numeric(18, 4),
  source_system  text         NOT NULL,
  loaded_at      timestamptz  NOT NULL DEFAULT NOW(),
  CHECK (numerator IS NULL OR numerator >= 0),
  CHECK (denominator IS NULL OR denominator >= 0),
  UNIQUE (indicator_code, period_start)
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
opd_periodized AS (
    SELECT
      v.vn,
      v.hn,
      v.an,
      EXTRACT(YEAR FROM AGE(v.vstdate, pd.birthday))::integer AS age_y,
      pd.sex,
      (SELECT REPLACE(UPPER(TRIM(sd.icd10)), '.', '')
         FROM ovstdiag sd
        WHERE sd.vn = v.vn AND sd.diagtype = '1'
        ORDER BY sd.ovst_diag_id
        LIMIT 1) AS pdx,
      v.vstdate AS event_date,
      er.enter_er_time,
      er.triage_datetime,
      er.doctor_tx_time,
      er.finish_time,
      er.antibiotics_datetime,
      er.stroke_needle_datetime,
      er.stemi_balloon_datetime,
      er.er_emergency_level_id,
      er.unplanned_return,
      er.news2_score,
      DATE_TRUNC('month', v.vstdate)::date AS period_start,
      EXTRACT(MONTH FROM v.vstdate)::integer AS calendar_month
    FROM ovst v
    LEFT JOIN patient pd ON pd.hn = v.hn
    LEFT JOIN er_regist er ON er.vn = v.vn
    WHERE v.vstdate >= :start_date
      AND v.vstdate < :end_date
  ),
  chronic_periodized AS (
    SELECT
      cm.clinicmember_id,
      cm.clinic,
      cm.hn,
      cm.regdate,
      cm.lastvisit,
      cm.dchdate,
      cm.current_status,
      cm.clinic_member_status_id,
      cm.age_y,
      cm.sex,
      cm.chronic_type,
      cm.begin_year,
      cm.last_hba1c_value,
      cm.last_hba1c_date,
      cm.last_bp_bps_value,
      cm.last_bp_bpd_value,
      cm.last_bp_date,
      DATE_TRUNC('month', cm.regdate)::date AS period_start,
      EXTRACT(MONTH FROM cm.regdate)::integer AS calendar_month
    FROM clinicmember cm
    WHERE cm.regdate >= :start_date
      AND cm.regdate < :end_date
  ),
  delivery_periodized AS (
    SELECT
      l.laborid,
      l.an,
      l.hage AS mother_age_y,
      l.labor_type,
      l.mother_method,
      l.infant_sex,
      l.infant_weight,
      l.infant_apgarscore1,
      l.infant_apgarscore5,
      l.infant_apgarscore10,
      l.placenta_bloodloss,
      l.labour_startdate,
      l.labour_finishdate,
      DATE_TRUNC('month', COALESCE(l.labour_startdate, i.regdate))::date AS period_start,
      EXTRACT(MONTH FROM COALESCE(l.labour_startdate, i.regdate))::integer AS calendar_month
    FROM labor l
    LEFT JOIN ipt i ON i.an = l.an
    WHERE COALESCE(l.labour_startdate, i.regdate) >= :start_date
      AND COALESCE(l.labour_startdate, i.regdate) < :end_date
  ),
  newborn_periodized AS (
    SELECT
      nb.an,
      nb.mother_an,
      nb.born_date,
      nb.birth_weight,
      nb.apgar1,
      nb.apgar2,
      nb.dead,
      nb.has_asphyxia,
      nb.birthcondition1,
      nb.birthcondition2,
      nb.anc_complete,
      DATE_TRUNC('month', nb.born_date)::date AS period_start,
      EXTRACT(MONTH FROM nb.born_date)::integer AS calendar_month
    FROM ipt_newborn nb
    WHERE nb.born_date >= :start_date
      AND nb.born_date < :end_date
  ),
  emp_periodized AS (
    SELECT
      e.emp_id,
      e.emp_sex_id,
      e.emp_birthdate,
      e.emp_status_id,
      e.emp_type_id,
      e.emp_dep_id,
      e.emp_position_main_id,
      e.emp_work_begindate,
      e.emp_resign_enddate,
      e.emp_resign_type_id,
      DATE_TRUNC('month', e.emp_work_begindate)::date AS period_start,
      EXTRACT(MONTH FROM e.emp_work_begindate)::integer AS calendar_month
    FROM emp e
    WHERE e.emp_work_begindate >= :start_date
      AND e.emp_work_begindate < :end_date
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
    WHERE x.period_start >= :start_date
      AND x.period_start < :end_date
  ),
fact_events AS (

      SELECT
        'AA0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) AS numerator,
        NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0) AS denominator,
        ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('G40', 'G41')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'AA0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) AS numerator,
        NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0) AS denominator,
        ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2) AS value
      FROM periodized
      WHERE (
      LEFT(pdx, 3) IN ('J40', 'J41', 'J42', 'J43', 'J44', 'J47')
      OR (
        (pdx = 'J100' OR pdx = 'J110' OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18', 'J20', 'J21', 'J22'))
        AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'J44'
        )
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'AA0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) AS numerator,
        NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0) AS denominator,
        ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('J45', 'J46')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'AA0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) AS numerator,
        NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0) AS denominator,
        ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('E100', 'E101', 'E106', 'E109', 'E110', 'E111', 'E116', 'E119', 'E130', 'E131', 'E136', 'E139', 'E140', 'E141', 'E146', 'E149')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'AA0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) AS numerator,
        NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0) AS denominator,
        ROUND(COUNT(*) * 100000.0 / NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('I10', 'I110', 'I119')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CA0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
        AND (
          EXISTS (
            SELECT 1
            FROM operation_cpr cpr
            WHERE cpr.operation_id = ol.operation_id
          )
          OR ol.intra_anes_operation_note ILIKE '%หัวใจหยุดเต้น%'
          OR LOWER(ol.intra_anes_operation_note) LIKE '%cardiac arrest%'
        )
    )) AS numerator,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
    )) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
        AND (
          EXISTS (
            SELECT 1
            FROM operation_cpr cpr
            WHERE cpr.operation_id = ol.operation_id
          )
          OR ol.intra_anes_operation_note ILIKE '%หัวใจหยุดเต้น%'
          OR LOWER(ol.intra_anes_operation_note) LIKE '%cardiac arrest%'
        )
    )) * 10000 / NULLIF(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
    )), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CA0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
        AND (
          ol.pre_anes_operation_note IS NOT NULL
          OR EXISTS (
            SELECT 1
            FROM operation_visit_list ov
            WHERE ov.operation_id = ol.operation_id
              AND (
                ov.pre_anes_note IS NOT NULL
                OR ov.operation_visit_anes_type_id IS NOT NULL
              )
          )
        )
    )) AS numerator,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
    )) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
        AND (
          ol.pre_anes_operation_note IS NOT NULL
          OR EXISTS (
            SELECT 1
            FROM operation_visit_list ov
            WHERE ov.operation_id = ol.operation_id
              AND (
                ov.pre_anes_note IS NOT NULL
                OR ov.operation_visit_anes_type_id IS NOT NULL
              )
          )
        )
    )) * 100 / NULLIF(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
    )), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CA0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND EXISTS (
            SELECT 1
            FROM operation_recovery_room rr
            WHERE rr.operation_id = ol.operation_id
          )
    )) AS numerator,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
    )) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND EXISTS (
            SELECT 1
            FROM operation_recovery_room rr
            WHERE rr.operation_id = ol.operation_id
          )
    )) * 100 / NULLIF(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
    )), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CA0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
              AND EXISTS (
                SELECT 1
                FROM operation_anes_problem ap
                WHERE ap.operation_id = ol.operation_id
                  AND (
                    ap.comment ILIKE '%ใส่ท่อ%'
                    OR LOWER(ap.comment) LIKE '%intubat%'
                    OR ap.airway_solution_id IN (
                      SELECT asl.airway_solution_id
                      FROM operation_airway_solution asl
                      WHERE asl.airway_solution_name ILIKE '%ใส่ท่อ%'
                         OR LOWER(asl.airway_solution_name) LIKE '%intubat%'
                    )
                  )
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) >=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59')))
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) <=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59'))) + INTERVAL '2 hours'
              )
          )
    )) AS numerator,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
    )) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
              AND EXISTS (
                SELECT 1
                FROM operation_anes_problem ap
                WHERE ap.operation_id = ol.operation_id
                  AND (
                    ap.comment ILIKE '%ใส่ท่อ%'
                    OR LOWER(ap.comment) LIKE '%intubat%'
                    OR ap.airway_solution_id IN (
                      SELECT asl.airway_solution_id
                      FROM operation_airway_solution asl
                      WHERE asl.airway_solution_name ILIKE '%ใส่ท่อ%'
                         OR LOWER(asl.airway_solution_name) LIKE '%intubat%'
                    )
                  )
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) >=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59')))
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) <=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59'))) + INTERVAL '2 hours'
              )
          )
    )) * 100 / NULLIF(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
    )), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CA0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
        AND (
            EXISTS (
              SELECT 1
              FROM operation_anes_detail ad
              WHERE ad.operation_id = ol.operation_id
                AND (
                  LOWER(ad.monitor) LIKE '%capno%'
                  OR LOWER(ad.monitor) LIKE '%etco%'
                  OR ad.monitor ILIKE '%คาพโน%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.etco2 IS NOT NULL
            )
          )
    )) AS numerator,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
    )) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
        AND (
            EXISTS (
              SELECT 1
              FROM operation_anes_detail ad
              WHERE ad.operation_id = ol.operation_id
                AND (
                  LOWER(ad.monitor) LIKE '%capno%'
                  OR LOWER(ad.monitor) LIKE '%etco%'
                  OR ad.monitor ILIKE '%คาพโน%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.etco2 IS NOT NULL
            )
          )
    )) * 100 / NULLIF(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
    )), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CE0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CE0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) / NULLIF(60, 0)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((SUM(EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) / NULLIF(60, 0)) * 1.0) / NULLIF(COUNT(*), 0), 2)} AS value
      FROM opd_periodized
      WHERE opd_periodized.enter_er_time IS NOT NULL AND opd_periodized.finish_time IS NOT NULL AND opd_periodized.finish_time > opd_periodized.enter_er_time AND opd_periodized.er_emergency_level_id = 1
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CE0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) <= 3600) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) <= 3600) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.enter_er_time IS NOT NULL AND opd_periodized.finish_time IS NOT NULL AND opd_periodized.finish_time > opd_periodized.enter_er_time AND opd_periodized.er_emergency_level_id = 1
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CE0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE antibiotics_datetime IS NOT NULL AND doctor_tx_time IS NOT NULL AND antibiotics_datetime >= doctor_tx_time AND antibiotics_datetime <= doctor_tx_time + INTERVAL '1 hour') AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE antibiotics_datetime IS NOT NULL AND doctor_tx_time IS NOT NULL AND antibiotics_datetime >= doctor_tx_time AND antibiotics_datetime <= doctor_tx_time + INTERVAL '1 hour')) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM opd_periodized
      WHERE age_y >= 18 AND (
          pdx IN ('A400', 'A419', 'R572', 'R651')
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651')
          )
        ) AND enter_er_time IS NOT NULL
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CG0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE (
          LEFT(periodized.pdx, 3) <> 'L89'
          AND (
            EXISTS (
              SELECT 1
              FROM iptdiag sd
              WHERE sd.an = periodized.an
                AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'L89'
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.note_date > periodized.regdate
                AND (
                  nn.note ILIKE '%แผลกดทับ%'
                  OR LOWER(nn.note) LIKE '%pressure ulcer%'
                )
            )
          )
        )) AS numerator,
        SUM(COALESCE(periodized.los, 0)) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE (
          LEFT(periodized.pdx, 3) <> 'L89'
          AND (
            EXISTS (
              SELECT 1
              FROM iptdiag sd
              WHERE sd.an = periodized.an
                AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'L89'
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.note_date > periodized.regdate
                AND (
                  nn.note ILIKE '%แผลกดทับ%'
                  OR LOWER(nn.note) LIKE '%pressure ulcer%'
                )
            )
          )
        )) * 1000 / NULLIF(SUM(COALESCE(periodized.los, 0)), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CG0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
            SELECT 1
            FROM ipd_nurse_note rn
            WHERE rn.an = periodized.an
              AND (
                LOWER(rn.note) LIKE '%braden%'
                OR rn.note ILIKE '%เสี่ยงต่อการเกิดแผลกดทับ%'
                OR (rn.note ILIKE '%เสี่ยง%' AND rn.note ILIKE '%กดทับ%')
              )
          ) AND (
          LEFT(periodized.pdx, 3) <> 'L89'
          AND (
            EXISTS (
              SELECT 1
              FROM iptdiag sd
              WHERE sd.an = periodized.an
                AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'L89'
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.note_date > periodized.regdate
                AND (
                  nn.note ILIKE '%แผลกดทับ%'
                  OR LOWER(nn.note) LIKE '%pressure ulcer%'
                )
            )
          )
        )) AS numerator,
        SUM(COALESCE(periodized.los, 0)) FILTER (WHERE EXISTS (
            SELECT 1
            FROM ipd_nurse_note rn
            WHERE rn.an = periodized.an
              AND (
                LOWER(rn.note) LIKE '%braden%'
                OR rn.note ILIKE '%เสี่ยงต่อการเกิดแผลกดทับ%'
                OR (rn.note ILIKE '%เสี่ยง%' AND rn.note ILIKE '%กดทับ%')
              )
          )) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
            SELECT 1
            FROM ipd_nurse_note rn
            WHERE rn.an = periodized.an
              AND (
                LOWER(rn.note) LIKE '%braden%'
                OR rn.note ILIKE '%เสี่ยงต่อการเกิดแผลกดทับ%'
                OR (rn.note ILIKE '%เสี่ยง%' AND rn.note ILIKE '%กดทับ%')
              )
          ) AND (
          LEFT(periodized.pdx, 3) <> 'L89'
          AND (
            EXISTS (
              SELECT 1
              FROM iptdiag sd
              WHERE sd.an = periodized.an
                AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'L89'
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.note_date > periodized.regdate
                AND (
                  nn.note ILIKE '%แผลกดทับ%'
                  OR LOWER(nn.note) LIKE '%pressure ulcer%'
                )
            )
          )
        )) * 1000 / NULLIF(SUM(COALESCE(periodized.los, 0)) FILTER (WHERE EXISTS (
            SELECT 1
            FROM ipd_nurse_note rn
            WHERE rn.an = periodized.an
              AND (
                LOWER(rn.note) LIKE '%braden%'
                OR rn.note ILIKE '%เสี่ยงต่อการเกิดแผลกดทับ%'
                OR (rn.note ILIKE '%เสี่ยง%' AND rn.note ILIKE '%กดทับ%')
              )
          )), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CG0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'CG0103'

  UNION ALL

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

  UNION ALL

      SELECT
        'CI0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651') OR has_ci0101_sepsis
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt m
          JOIN death d ON (d.an = m.an OR d.hn = m.hn)
          WHERE m.an = delivery_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= COALESCE(delivery_periodized.labour_startdate, d.death_date)
            AND d.death_date <= COALESCE(delivery_periodized.labour_finishdate, delivery_periodized.labour_startdate, d.death_date) + INTERVAL '42 days'
            AND (
              d.death_preg_42_day = 'Y'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_1, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_2, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_3, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_4, ''))), '.', ''), 1) = 'O'
            )
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_1, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_2, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_3, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_4, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        )) AS numerator,
        SUM((
          SELECT COUNT(*)
          FROM ipt_newborn nb
          WHERE nb.mother_an = delivery_periodized.an
            AND COALESCE(nb.dead, 'N') <> 'Y'
        )) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt m
          JOIN death d ON (d.an = m.an OR d.hn = m.hn)
          WHERE m.an = delivery_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= COALESCE(delivery_periodized.labour_startdate, d.death_date)
            AND d.death_date <= COALESCE(delivery_periodized.labour_finishdate, delivery_periodized.labour_startdate, d.death_date) + INTERVAL '42 days'
            AND (
              d.death_preg_42_day = 'Y'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_1, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_2, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_3, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_4, ''))), '.', ''), 1) = 'O'
            )
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_1, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_2, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_3, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_4, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        )) * 100000.0 / NULLIF(SUM((
          SELECT COUNT(*)
          FROM ipt_newborn nb
          WHERE nb.mother_an = delivery_periodized.an
            AND COALESCE(nb.dead, 'N') <> 'Y'
        )), 0), 2) AS value
      FROM delivery_periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0109' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0110' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0116' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0117' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0118' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AND NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) AS numerator,
        COUNT(*) FILTER (WHERE NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AND NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))) * 100.0) / NULLIF(COUNT(*) FILTER (WHERE NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342'))), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0119' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (COALESCE(newborn_periodized.dead, 'N') = 'Y' OR EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '7 days'
        )) AND (COALESCE(newborn_periodized.birth_weight, 0) >= 500 OR (newborn_periodized.birth_weight IS NULL AND EXISTS (
          SELECT 1
          FROM ipt_pregnancy pg
          WHERE pg.an = newborn_periodized.mother_an
            AND COALESCE(pg.ga, 0) >= 24
        )))) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE (COALESCE(newborn_periodized.dead, 'N') = 'Y' OR EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '7 days'
        )) AND (COALESCE(newborn_periodized.birth_weight, 0) >= 500 OR (newborn_periodized.birth_weight IS NULL AND EXISTS (
          SELECT 1
          FROM ipt_pregnancy pg
          WHERE pg.an = newborn_periodized.mother_an
            AND COALESCE(pg.ga, 0) >= 24
        )))) * 1000.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM newborn_periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (COALESCE(newborn_periodized.dead, 'N') = 'Y' OR EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '7 days'
        )) AND (COALESCE(newborn_periodized.birth_weight, 0) >= 1000 OR (newborn_periodized.birth_weight IS NULL AND EXISTS (
          SELECT 1
          FROM ipt_pregnancy pg
          WHERE pg.an = newborn_periodized.mother_an
            AND COALESCE(pg.ga, 0) >= 28
        )))) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE (COALESCE(newborn_periodized.dead, 'N') = 'Y' OR EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '7 days'
        )) AND (COALESCE(newborn_periodized.birth_weight, 0) >= 1000 OR (newborn_periodized.birth_weight IS NULL AND EXISTS (
          SELECT 1
          FROM ipt_pregnancy pg
          WHERE pg.an = newborn_periodized.mother_an
            AND COALESCE(pg.ga, 0) >= 28
        )))) * 1000.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM newborn_periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0203' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '28 days'
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '28 days'
        )) * 1000.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM newborn_periodized
      WHERE COALESCE(newborn_periodized.dead, 'N') <> 'Y'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0204' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0205' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0206' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0207' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0208' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CM0209' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CO0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT ol.operation_id) FILTER (WHERE (
          ol.operation_check_date IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM operation_detail od
            WHERE od.operation_id = ol.operation_id
              AND od.time_out_datetime IS NOT NULL
          )
          AND EXISTS (
            SELECT 1
            FROM operation_screen_in osi
            WHERE osi.operation_id = ol.operation_id
              AND osi.preoperative_nursing_record IS NOT NULL
              AND osi.perioperative_record IS NOT NULL
              AND osi.postoperative_record IS NOT NULL
          )
        )) AS numerator,
        COUNT(DISTINCT ol.operation_id) AS denominator,
        ROUND(COUNT(DISTINCT ol.operation_id) FILTER (WHERE (
          ol.operation_check_date IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM operation_detail od
            WHERE od.operation_id = ol.operation_id
              AND od.time_out_datetime IS NOT NULL
          )
          AND EXISTS (
            SELECT 1
            FROM operation_screen_in osi
            WHERE osi.operation_id = ol.operation_id
              AND osi.preoperative_nursing_record IS NOT NULL
              AND osi.perioperative_record IS NOT NULL
              AND osi.postoperative_record IS NOT NULL
          )
        )) * 100 / NULLIF(COUNT(DISTINCT ol.operation_id), 0), 2) AS value
      FROM periodized
      JOIN operation_list ol ON ol.an = periodized.an
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CO0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
        AND EXISTS (
          SELECT 1
          FROM operation_detail od
          WHERE od.operation_id = ol.operation_id
            AND EXISTS (
              SELECT 1
              FROM death d
              WHERE d.an = periodized.an
                AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
                  COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00'))
                AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
                  COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00')) + INTERVAL '24 hours'
            )
        )
    )) AS numerator,
        COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
    )) AS denominator,
        ROUND(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
        AND EXISTS (
          SELECT 1
          FROM operation_detail od
          WHERE od.operation_id = ol.operation_id
            AND EXISTS (
              SELECT 1
              FROM death d
              WHERE d.an = periodized.an
                AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
                  COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00'))
                AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
                  COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00')) + INTERVAL '24 hours'
            )
        )
    )) * 100 / NULLIF(COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
    )), 0), 2) AS value
      FROM periodized
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CO0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT ol.operation_id) FILTER (WHERE ol.re_operation = 'Y') AS numerator,
        COUNT(DISTINCT ol.operation_id) AS denominator,
        ROUND(COUNT(DISTINCT ol.operation_id) FILTER (WHERE ol.re_operation = 'Y') * 100 / NULLIF(COUNT(DISTINCT ol.operation_id), 0), 2) AS value
      FROM periodized
      JOIN operation_list ol ON ol.an = periodized.an
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CP0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE attended.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE attended.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_therapy th
        JOIN ovst tv ON tv.vn = th.vn_an
        WHERE tv.hn = chronic_periodized.hn
          AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
          AND th.psych_therapy_date <= chronic_periodized.regdate
      ) OR EXISTS (
        SELECT 1
        FROM psych_plan pf
        WHERE pf.hn = chronic_periodized.hn
          AND pf.psych_plan_finish_date IS NOT NULL
          AND pf.psych_plan_finish_date >= chronic_periodized.regdate - INTERVAL '6 months'
          AND pf.psych_plan_finish_date <= chronic_periodized.regdate
      ) AS flagged
    ) attended ON TRUE
      WHERE chronic_periodized.age_y <= 18
    AND (EXISTS (
      SELECT 1
      FROM ovstdiag sdc
      WHERE sdc.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdc.icd10)), '.', ''), 3) IN ('F80', 'F81', 'F82', 'F83', 'F90', 'F32', 'F33') OR REPLACE(UPPER(TRIM(sdc.icd10)), '.', '') IN ('F341'))
    ))
    AND EXISTS (
      SELECT 1
      FROM psych_plan pps
      WHERE pps.hn = chronic_periodized.hn
        AND pps.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pps.psych_plan_date <= chronic_periodized.regdate
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'CP0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE dx90.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE dx90.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM ovstdiag sd9
        WHERE sd9.hn = chronic_periodized.hn
          AND LEFT(REPLACE(UPPER(TRIM(sd9.icd10)), '.', ''), 3) IN ('F83', 'R62', 'F84', 'G80')
          AND sd9.vstdate >= chronic_periodized.regdate
          AND sd9.vstdate <= chronic_periodized.regdate + INTERVAL '90 days'
      ) AS flagged
    ) dx90 ON TRUE
      WHERE chronic_periodized.age_y <= 6
    AND EXISTS (
      SELECT 1
      FROM psych_screen_child psc
      WHERE psc.hn = chronic_periodized.hn
        AND psc.psych_screen_child_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND psc.psych_screen_child_date <= chronic_periodized.regdate + INTERVAL '3 months'
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0108' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0108.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0108.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0201.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0201.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0301' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE vl_done.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE vl_done.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%viral%')
          AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND lh.order_date <= chronic_periodized.regdate
      ) AS flagged
    ) vl_done ON TRUE
      WHERE (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND EXISTS (
      SELECT 1
      FROM arv_tx ax
      WHERE ax.hn = chronic_periodized.hn
        AND ax.date_entry <= chronic_periodized.regdate - INTERVAL '6 months'
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0302' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE vl50_done.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE vl50_done.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%viral%')
          AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND lh.order_date <= chronic_periodized.regdate
          AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END IS NOT NULL AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END < 50
      ) AS flagged
    ) vl50_done ON TRUE
      WHERE (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND EXISTS (
      SELECT 1
      FROM arv_tx ax
      WHERE ax.hn = chronic_periodized.hn
        AND ax.date_entry <= chronic_periodized.regdate - INTERVAL '12 months'
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0306' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE pap_done.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE pap_done.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%pap%')
          AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND lh.order_date <= chronic_periodized.regdate
      ) AS flagged
    ) pap_done ON TRUE
      WHERE chronic_periodized.sex = '2'
    AND (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0307' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE syph_done.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE syph_done.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%vdrl%' OR li.lab_items_name ILIKE '%rpr%' OR li.lab_items_name ILIKE '%tpha%' OR li.lab_items_name ILIKE '%tppa%' OR li.lab_items_name ILIKE '%syphilis%' OR li.lab_items_name ILIKE '%ซิฟิลิส%')
          AND lh.order_date >= chronic_periodized.regdate
          AND lh.order_date <= chronic_periodized.regdate + INTERVAL '12 months'
      ) AS flagged
    ) syph_done ON TRUE
      WHERE (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0308' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE arv_pickup.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE arv_pickup.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%tenofovir%' OR di.name ILIKE '%lamivudine%' OR di.name ILIKE '%zidovudine%' OR di.name ILIKE '%emtricitabine%' OR di.name ILIKE '%abacavir%' OR di.name ILIKE '%efavirenz%' OR di.name ILIKE '%nevirapine%' OR di.name ILIKE '%lopinavir%' OR di.name ILIKE '%atazanavir%' OR di.name ILIKE '%darunavir%' OR di.name ILIKE '%dolutegravir%' OR di.name ILIKE '%raltegravir%')
          AND oi.vstdate >= chronic_periodized.regdate - INTERVAL '12 months'
          AND oi.vstdate <= chronic_periodized.regdate
      ) AS flagged
    ) arv_pickup ON TRUE
      WHERE (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0309' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE tpt_done.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE tpt_done.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%isoniazid%' OR di.name ILIKE '%rifapentine%' OR di.name ILIKE '%rifampicin%' OR di.name ILIKE '%inah%')
          AND oi.vstdate >= chronic_periodized.regdate
          AND oi.vstdate <= chronic_periodized.regdate + INTERVAL '6 months'
      ) AS flagged
    ) tpt_done ON TRUE
      WHERE (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND NOT EXISTS (
      SELECT 1
      FROM tb_register tba
      WHERE tba.hn = chronic_periodized.hn
        AND tba.tb_register_date >= chronic_periodized.regdate - INTERVAL '12 months'
        AND tba.tb_register_date <= chronic_periodized.regdate + INTERVAL '6 months'
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0401' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C33','C34','C37','C38','C39','C40','C41','C43','C44','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65','C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C77','C78','C79','C80','C81','C82','C83','C84','C85','C86','C87','C88','C89','C90','C91','C92','C93','C94','C95','C96','C97','D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','Z510','Z511')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0402' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.dchdate IS NOT NULL
            AND periodized.regdate > r.dchdate
            AND periodized.regdate <= r.dchdate + INTERVAL '28 days'
            AND (
              (LEFT(REPLACE(UPPER(TRIM(rs.pdx)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(rs.pdx)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('Z510', 'Z511'))
              OR EXISTS (
                SELECT 1
                FROM iptdiag rd
                WHERE rd.an = r.an
                  AND (LEFT(REPLACE(UPPER(TRIM(rd.icd10)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(rd.icd10)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('Z510', 'Z511'))
              )
            )
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.dchdate IS NOT NULL
            AND periodized.regdate > r.dchdate
            AND periodized.regdate <= r.dchdate + INTERVAL '28 days'
            AND (
              (LEFT(REPLACE(UPPER(TRIM(rs.pdx)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(rs.pdx)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('Z510', 'Z511'))
              OR EXISTS (
                SELECT 1
                FROM iptdiag rd
                WHERE rd.an = r.an
                  AND (LEFT(REPLACE(UPPER(TRIM(rd.icd10)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(rd.icd10)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('Z510', 'Z511'))
              )
            )
        )) * 100.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE ((LEFT(REPLACE(UPPER(TRIM(pdx)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(pdx)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(pdx)), '.', '') IN ('Z510', 'Z511')) OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('Z510', 'Z511'))
        ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0403' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE died) * 100.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE ((LEFT(pdx, 3) IN ('C220', 'C222', 'C223', 'C224', 'C225', 'C226', 'C227', 'C228', 'C229')) OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('C220', 'C222', 'C223', 'C224', 'C225', 'C226', 'C227', 'C228', 'C229')
        ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0501' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE egfr.first_val - egfr.last_val < 4) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE egfr.first_val - egfr.last_val < 4) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        COUNT(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END) AS n,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date))[1] AS first_val,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date DESC))[1] AS last_val
      FROM lab_head lh
      JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
      JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
      WHERE lh.hn = chronic_periodized.hn
        AND (li.lab_items_name ILIKE '%egfr%' OR li.lab_items_name ILIKE '%gfr%')
        AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
        AND lh.order_date <= chronic_periodized.regdate
    ) egfr ON TRUE
      WHERE EXISTS (
      SELECT 1
      FROM clinic_ckd_member ck
      WHERE ck.clinicmember_id = chronic_periodized.clinicmember_id
    )
    AND egfr.n >= 2
    AND egfr.first_val IS NOT NULL
    AND egfr.last_val IS NOT NULL
    AND egfr.first_val >= 15
    AND egfr.first_val < 60
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DC0502' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE ace_arb.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE ace_arb.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        COUNT(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END) AS n,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date))[1] AS first_val,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date DESC))[1] AS last_val
      FROM lab_head lh
      JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
      JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
      WHERE lh.hn = chronic_periodized.hn
        AND (li.lab_items_name ILIKE '%egfr%' OR li.lab_items_name ILIKE '%gfr%')
        AND lh.order_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND lh.order_date <= chronic_periodized.regdate
    ) egfr ON TRUE
    LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%' OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%' OR di.name ILIKE '%benazepril%' OR di.name ILIKE '%imidapril%' OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%' OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%')
          AND oi.vstdate >= chronic_periodized.regdate - INTERVAL '6 months'
          AND oi.vstdate <= chronic_periodized.regdate
      ) AS flagged
    ) ace_arb ON TRUE
      WHERE EXISTS (
      SELECT 1
      FROM clinic_ckd_member ck
      WHERE ck.clinicmember_id = chronic_periodized.clinicmember_id
    )
    AND egfr.n >= 1
    AND egfr.last_val IS NOT NULL
    AND egfr.last_val >= 15
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM((
          SELECT MIN(pcr.patient_cancer_first_meet_doctor_date - bc.screen_date)
          FROM person pp
          JOIN person_bc_screen bc ON bc.person_id = pp.person_id
          JOIN patient_cancer_registeration pcr ON pcr.hn = pp.patient_hn
          WHERE pp.patient_hn = opd_periodized.hn
            AND bc.screen_date = opd_periodized.event_date
            AND COALESCE(bc.mamogram_birads_result_integer, 0) >= 4
            AND pcr.patient_cancer_first_meet_doctor_date IS NOT NULL
            AND pcr.patient_cancer_first_meet_doctor_date >= bc.screen_date
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND(SUM((
          SELECT MIN(pcr.patient_cancer_first_meet_doctor_date - bc.screen_date)
          FROM person pp
          JOIN person_bc_screen bc ON bc.person_id = pp.person_id
          JOIN patient_cancer_registeration pcr ON pcr.hn = pp.patient_hn
          WHERE pp.patient_hn = opd_periodized.hn
            AND bc.screen_date = opd_periodized.event_date
            AND COALESCE(bc.mamogram_birads_result_integer, 0) >= 4
            AND pcr.patient_cancer_first_meet_doctor_date IS NOT NULL
            AND pcr.patient_cancer_first_meet_doctor_date >= bc.screen_date
        )) * 1.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM opd_periodized
      WHERE (
          SELECT MIN(pcr.patient_cancer_first_meet_doctor_date - bc.screen_date)
          FROM person pp
          JOIN person_bc_screen bc ON bc.person_id = pp.person_id
          JOIN patient_cancer_registeration pcr ON pcr.hn = pp.patient_hn
          WHERE pp.patient_hn = opd_periodized.hn
            AND bc.screen_date = opd_periodized.event_date
            AND COALESCE(bc.mamogram_birads_result_integer, 0) >= 4
            AND pcr.patient_cancer_first_meet_doctor_date IS NOT NULL
            AND pcr.patient_cancer_first_meet_doctor_date >= bc.screen_date
        ) IS NOT NULL
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM patient_cancer_registeration pcr
          WHERE pcr.clinicmember_id = chronic_periodized.clinicmember_id
            AND COALESCE(pcr.m_value, 0) = 0
            AND COALESCE(pcr.n_value, 99) <= 1
            AND COALESCE(pcr.t_value, 99) <= 2
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM patient_cancer_registeration pcr
          WHERE pcr.clinicmember_id = chronic_periodized.clinicmember_id
            AND COALESCE(pcr.m_value, 0) = 0
            AND COALESCE(pcr.n_value, 99) <= 1
            AND COALESCE(pcr.t_value, 99) <= 2
        )) * 100.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM chronic_periodized
      WHERE EXISTS (
          SELECT 1
          FROM clinicmember_cancer cc
          WHERE cc.clinicmember_id = chronic_periodized.clinicmember_id
            AND LEFT(REPLACE(UPPER(TRIM(COALESCE(cc.f53_topography, ''))), '.', ''), 3) = 'C50'
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE0501' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          WHERE ol.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '410'
            AND EXISTS (
              SELECT 1
              FROM lab_head lh
              JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
              JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
              WHERE lh.hn = ol.hn
                AND li.lab_items_name ILIKE '%neutrophil%'
                AND lh.order_date IS NOT NULL
                AND ol.operation_date IS NOT NULL
                AND lh.order_date >= ol.operation_date
                AND lh.order_date <= ol.operation_date + INTERVAL '45 days'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '') ~ '^[0-9]+(\.[0-9]+)?$'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '')::numeric >= 500
            )
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          WHERE ol.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '410'
            AND EXISTS (
              SELECT 1
              FROM lab_head lh
              JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
              JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
              WHERE lh.hn = ol.hn
                AND li.lab_items_name ILIKE '%neutrophil%'
                AND lh.order_date IS NOT NULL
                AND ol.operation_date IS NOT NULL
                AND lh.order_date >= ol.operation_date
                AND lh.order_date <= ol.operation_date + INTERVAL '45 days'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '') ~ '^[0-9]+(\.[0-9]+)?$'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '')::numeric >= 500
            )
        )) * 100.0 / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          WHERE ol.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '410'
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE0801' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v2
          JOIN opitemrece oi ON oi.vn = v2.vn
          JOIN drugitems di ON di.icode = oi.icode
          WHERE v2.hn = opd_periodized.hn
            AND v2.vstdate >= opd_periodized.period_start
            AND v2.vstdate < opd_periodized.period_start + INTERVAL '1 month'
            AND (
              di.name ILIKE '%deferasirox%'
              OR di.name ILIKE '%deferoxamine%'
              OR di.name ILIKE '%deferiprone%'
            )
        )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v2
          JOIN opitemrece oi ON oi.vn = v2.vn
          JOIN drugitems di ON di.icode = oi.icode
          WHERE v2.hn = opd_periodized.hn
            AND v2.vstdate >= opd_periodized.period_start
            AND v2.vstdate < opd_periodized.period_start + INTERVAL '1 month'
            AND (
              di.name ILIKE '%deferasirox%'
              OR di.name ILIKE '%deferoxamine%'
              OR di.name ILIKE '%deferiprone%'
            )
        )) * 100.0 / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE age_y > 2 AND age_y <= 15 AND (LEFT(pdx, 3) = 'D56' OR EXISTS (
          SELECT 1
          FROM ovstdiag sd
          WHERE sd.vn = opd_periodized.vn
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'D56'
        )) AND EXISTS (
          SELECT 1
          FROM lab_head lh
          JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = opd_periodized.hn
            AND lh.order_date >= opd_periodized.period_start
            AND lh.order_date < opd_periodized.period_start + INTERVAL '1 month'
            AND li.lab_items_name ILIKE '%ferritin%'
            AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '') ~ '^[0-9]+(\.[0-9]+)?$'
            AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '')::numeric > 1000
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          JOIN patient pd ON pd.hn = ol.hn
          WHERE ol.an = periodized.an
            AND ((LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '304') OR (oi.name ILIKE '%cleft lip%' OR oi.name ILIKE '%ปากแหว่ง%'))
            AND ol.operation_date IS NOT NULL
            AND pd.birthday IS NOT NULL
            AND ol.operation_date >= pd.birthday
            AND ol.operation_date <= pd.birthday + INTERVAL '6 months'
        )) AS numerator,
        COUNT(DISTINCT periodized.hn) AS denominator,
        ROUND(COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          JOIN patient pd ON pd.hn = ol.hn
          WHERE ol.an = periodized.an
            AND ((LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '304') OR (oi.name ILIKE '%cleft lip%' OR oi.name ILIKE '%ปากแหว่ง%'))
            AND ol.operation_date IS NOT NULL
            AND pd.birthday IS NOT NULL
            AND ol.operation_date >= pd.birthday
            AND ol.operation_date <= pd.birthday + INTERVAL '6 months'
        )) * 100.0 / NULLIF(COUNT(DISTINCT periodized.hn), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) IN ('Q35', 'Q36', 'Q37') OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('Q35', 'Q36', 'Q37')
        )) AND EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          
          WHERE ol.an = periodized.an
            AND ((LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '304') OR (oi.name ILIKE '%cleft lip%' OR oi.name ILIKE '%ปากแหว่ง%'))
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          JOIN patient pd ON pd.hn = ol.hn
          WHERE ol.an = periodized.an
            AND ((REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', '') IN ('2754')) OR (oi.name ILIKE '%cleft palate%' OR oi.name ILIKE '%เพดานโหว่%'))
            AND ol.operation_date IS NOT NULL
            AND pd.birthday IS NOT NULL
            AND ol.operation_date >= pd.birthday
            AND ol.operation_date <= pd.birthday + INTERVAL '18 months'
        )) AS numerator,
        COUNT(DISTINCT periodized.hn) AS denominator,
        ROUND(COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          JOIN patient pd ON pd.hn = ol.hn
          WHERE ol.an = periodized.an
            AND ((REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', '') IN ('2754')) OR (oi.name ILIKE '%cleft palate%' OR oi.name ILIKE '%เพดานโหว่%'))
            AND ol.operation_date IS NOT NULL
            AND pd.birthday IS NOT NULL
            AND ol.operation_date >= pd.birthday
            AND ol.operation_date <= pd.birthday + INTERVAL '18 months'
        )) * 100.0 / NULLIF(COUNT(DISTINCT periodized.hn), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 3) IN ('Q35', 'Q36', 'Q37') OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('Q35', 'Q36', 'Q37')
        )) AND EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          
          WHERE ol.an = periodized.an
            AND ((REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', '') IN ('2754')) OR (oi.name ILIKE '%cleft palate%' OR oi.name ILIKE '%เพดานโหว่%'))
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1301'

  UNION ALL

      SELECT
        'DE1302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1302'

  UNION ALL

      SELECT
        'DE1303' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1303'

  UNION ALL

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

  UNION ALL

      SELECT
        'DE1305' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1305'

  UNION ALL

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

  UNION ALL

      SELECT
        'DE1401' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) >= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '24 hours')) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) >= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '24 hours'))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1402' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) >= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '24 hours')) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) >= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '24 hours'))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922') AND (
          age_y >= 60
          OR EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('N18', 'K74', 'I50', 'I25', 'J43', 'J44')
          )
          OR EXISTS (
            SELECT 1
            FROM lab_order lo
            JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
            JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
            WHERE lh.hn = periodized.hn
              AND lh.order_date >= periodized.regdate
              AND lh.order_date <= periodized.dchdate
              AND (
                li.lab_items_name ILIKE '%hemoglobin%'
                OR li.lab_items_name ILIKE '%hb%'
              )
              AND li.lab_items_name NOT ILIKE '%hba1c%'
              AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8
          )
        ) AND NOT died
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1403' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ) AND NOT (
          EXISTS (
            SELECT 1
            FROM iptoprt o3
            WHERE o3.an = periodized.an
              AND REPLACE(UPPER(TRIM(o3.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
              AND o3.opdate >= periodized.regdate + INTERVAL '2 days'
          )
          OR EXISTS (
            SELECT 1
            FROM opitemrece oi
            JOIN drugitems di ON di.icode = oi.icode
            WHERE oi.an = periodized.an
              AND oi.rxdate > periodized.regdate
              AND (di.name ILIKE '%packed red%' OR di.name ILIKE '%red cell%' OR di.name ILIKE '%prbc%')
          )
        )) AS numerator,
        COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        )) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ) AND NOT (
          EXISTS (
            SELECT 1
            FROM iptoprt o3
            WHERE o3.an = periodized.an
              AND REPLACE(UPPER(TRIM(o3.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
              AND o3.opdate >= periodized.regdate + INTERVAL '2 days'
          )
          OR EXISTS (
            SELECT 1
            FROM opitemrece oi
            JOIN drugitems di ON di.icode = oi.icode
            WHERE oi.an = periodized.an
              AND oi.rxdate > periodized.regdate
              AND (di.name ILIKE '%packed red%' OR di.name ILIKE '%red cell%' OR di.name ILIKE '%prbc%')
          )
        ))) * 100 / NULLIF((COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ))), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1404' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ) AND (
          EXISTS (
            SELECT 1
            FROM iptoprt o3
            WHERE o3.an = periodized.an
              AND REPLACE(UPPER(TRIM(o3.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
              AND o3.opdate >= periodized.regdate + INTERVAL '2 days'
          )
          OR EXISTS (
            SELECT 1
            FROM opitemrece oi
            JOIN drugitems di ON di.icode = oi.icode
            WHERE oi.an = periodized.an
              AND oi.rxdate > periodized.regdate
              AND (di.name ILIKE '%packed red%' OR di.name ILIKE '%red cell%' OR di.name ILIKE '%prbc%')
          )
        )) AS numerator,
        COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        )) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ) AND (
          EXISTS (
            SELECT 1
            FROM iptoprt o3
            WHERE o3.an = periodized.an
              AND REPLACE(UPPER(TRIM(o3.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
              AND o3.opdate >= periodized.regdate + INTERVAL '2 days'
          )
          OR EXISTS (
            SELECT 1
            FROM opitemrece oi
            JOIN drugitems di ON di.icode = oi.icode
            WHERE oi.an = periodized.an
              AND oi.rxdate > periodized.regdate
              AND (di.name ILIKE '%packed red%' OR di.name ILIKE '%red cell%' OR di.name ILIKE '%prbc%')
          )
        ))) * 100 / NULLIF((COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ))), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1405' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')) AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T810', 'T811', 'T812', 'T813', 'T814', 'T815', 'T816', 'T818', 'T819', 'K631', 'J690')
        )) AS numerator,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')) AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T810', 'T811', 'T812', 'T813', 'T814', 'T815', 'T816', 'T818', 'T819', 'K631', 'J690')
        ))) * 100 / NULLIF((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')))), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DE1601' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DE1601'

  UNION ALL

      SELECT
        'DG0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DG0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DG0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE pdx = 'K352') AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE pdx = 'K352') * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('K35', 'K352', 'K353', 'K358')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DG0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) = 'K35'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND died) OR (has_acs_sdx AND died_from_acs)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND died) OR (has_acs_sdx AND died_from_acs)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') OR has_acs_sdx)
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0101.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213') AND died) OR (has_stemi_sdx AND died_from_stemi)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213') AND died) OR (has_stemi_sdx AND died_from_stemi)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213') OR has_stemi_sdx)
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0101.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('I214', 'I219') AND died) OR (has_nste_sdx AND died_from_nste)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('I214', 'I219') AND died) OR (has_nste_sdx AND died_from_nste)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND (pdx IN ('I214', 'I219') OR has_nste_sdx)
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND NOT died
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%' OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%' OR di.name ILIKE '%benazepril%' OR di.name ILIKE '%quinapril%' OR di.name ILIKE '%trandolapril%' OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%' OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%' OR di.name ILIKE '%azilsartan%'))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%' OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%' OR di.name ILIKE '%benazepril%' OR di.name ILIKE '%quinapril%' OR di.name ILIKE '%trandolapril%' OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%' OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%' OR di.name ILIKE '%azilsartan%')))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I502', 'I504')
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
                OR scr.advice7_note ILIKE '%smoke%'
                OR scr.advice7_note ILIKE '%สูบ%'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN opdscreen_advice_item itm ON itm.opdscreen_advice_item_id = adv.opdscreen_advice_item_id
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
              AND (
                itm.opdscreen_advice_item_name ILIKE '%smoke%'
                OR itm.opdscreen_advice_item_name ILIKE '%บุหรี่%'
              )
          )
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
                OR scr.advice7_note ILIKE '%smoke%'
                OR scr.advice7_note ILIKE '%สูบ%'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN opdscreen_advice_item itm ON itm.opdscreen_advice_item_id = adv.opdscreen_advice_item_id
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
              AND (
                itm.opdscreen_advice_item_name ILIKE '%smoke%'
                OR itm.opdscreen_advice_item_name ILIKE '%บุหรี่%'
              )
          )
        ))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND (
                LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
                OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND scr.smoking_type_id IN (2, 3)
          )
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0106' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%metoprolol%' OR di.name ILIKE '%atenolol%' OR di.name ILIKE '%bisoprolol%' OR di.name ILIKE '%carvedilol%' OR di.name ILIKE '%propranolol%' OR di.name ILIKE '%labetalol%' OR di.name ILIKE '%nebivolol%' OR di.name ILIKE '%sotalol%'))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%metoprolol%' OR di.name ILIKE '%atenolol%' OR di.name ILIKE '%bisoprolol%' OR di.name ILIKE '%carvedilol%' OR di.name ILIKE '%propranolol%' OR di.name ILIKE '%labetalol%' OR di.name ILIKE '%nebivolol%' OR di.name ILIKE '%sotalol%')))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND NOT EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
              OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('R000', 'R001', 'I440', 'I441', 'I442', 'I495', 'I951')
            )
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%metoprolol%' OR di.name ILIKE '%atenolol%' OR di.name ILIKE '%bisoprolol%' OR di.name ILIKE '%carvedilol%' OR di.name ILIKE '%propranolol%' OR di.name ILIKE '%labetalol%' OR di.name ILIKE '%nebivolol%' OR di.name ILIKE '%sotalol%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%metoprolol%' OR di.name ILIKE '%atenolol%' OR di.name ILIKE '%bisoprolol%' OR di.name ILIKE '%carvedilol%' OR di.name ILIKE '%propranolol%' OR di.name ILIKE '%labetalol%' OR di.name ILIKE '%nebivolol%' OR di.name ILIKE '%sotalol%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND NOT EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
              OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('R000', 'R001', 'I440', 'I441', 'I442', 'I495', 'I951')
            )
        ) AND NOT died
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0108' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM((
          SELECT EXTRACT(EPOCH FROM ((er.vstdate + ero.begin_time) - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN er_regist_oper ero ON ero.vn = v.vn
          JOIN er_oper_code eoc ON eoc.er_oper_code = ero.er_oper_code
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ero.begin_time IS NOT NULL
            AND (er.vstdate + ero.begin_time) >= er.enter_er_time
            AND (
              eoc.name ILIKE '%ekg%'
              OR eoc.name ILIKE '%ecg%'
              OR REPLACE(UPPER(TRIM(eoc.icd9cm)), '.', '') = '8952'
            )
          ORDER BY ero.begin_time
          LIMIT 1)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((SUM((
          SELECT EXTRACT(EPOCH FROM ((er.vstdate + ero.begin_time) - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN er_regist_oper ero ON ero.vn = v.vn
          JOIN er_oper_code eoc ON eoc.er_oper_code = ero.er_oper_code
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ero.begin_time IS NOT NULL
            AND (er.vstdate + ero.begin_time) >= er.enter_er_time
            AND (
              eoc.name ILIKE '%ekg%'
              OR eoc.name ILIKE '%ecg%'
              OR REPLACE(UPPER(TRIM(eoc.icd9cm)), '.', '') = '8952'
            )
          ORDER BY ero.begin_time
          LIMIT 1))) * 1 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND ((
          SELECT EXTRACT(EPOCH FROM ((er.vstdate + ero.begin_time) - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN er_regist_oper ero ON ero.vn = v.vn
          JOIN er_oper_code eoc ON eoc.er_oper_code = ero.er_oper_code
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ero.begin_time IS NOT NULL
            AND (er.vstdate + ero.begin_time) >= er.enter_er_time
            AND (
              eoc.name ILIKE '%ekg%'
              OR eoc.name ILIKE '%ecg%'
              OR REPLACE(UPPER(TRIM(eoc.icd9cm)), '.', '') = '8952'
            )
          ORDER BY ero.begin_time
          LIMIT 1)) IS NOT NULL
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0109' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM((
          SELECT EXTRACT(EPOCH FROM (ro.refer_begin_time - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN referout ro ON ro.vn = v.vn
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ro.refer_begin_time IS NOT NULL
            AND ro.refer_begin_time >= er.enter_er_time
          ORDER BY ro.refer_begin_time
          LIMIT 1)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((SUM((
          SELECT EXTRACT(EPOCH FROM (ro.refer_begin_time - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN referout ro ON ro.vn = v.vn
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ro.refer_begin_time IS NOT NULL
            AND ro.refer_begin_time >= er.enter_er_time
          ORDER BY ro.refer_begin_time
          LIMIT 1))) * 1 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND ((
          SELECT EXTRACT(EPOCH FROM (ro.refer_begin_time - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN referout ro ON ro.vn = v.vn
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ro.refer_begin_time IS NOT NULL
            AND ro.refer_begin_time >= er.enter_er_time
          ORDER BY ro.refer_begin_time
          LIMIT 1)) IS NOT NULL
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0110' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stemi_balloon = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stemi_balloon_datetime IS NOT NULL
            AND er.stemi_balloon_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stemi_balloon_datetime - er.enter_er_time)) <= 7200) OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stemi_balloon = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stemi_balloon_datetime IS NOT NULL
            AND er.stemi_balloon_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stemi_balloon_datetime - er.enter_er_time)) <= 7200) OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            )))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0111' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0112' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0113' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            ))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            )))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0203' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0204' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0301' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0302' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0401' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL AND sc.inr >= 2.0 AND sc.inr <= 3.0)) AS numerator,
        COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL)) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL AND sc.inr >= 2.0 AND sc.inr <= 3.0))) * 100 / NULLIF((COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL))), 0), 2) AS value
      FROM opd_periodized
      WHERE age_y >= 18 AND (
          LEFT(pdx, 3) = 'I48'
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
          )
        ) AND EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.vn = opd_periodized.vn
            AND (di.name ILIKE '%warfarin%'))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DH0402' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt i2
          JOIN an_stat s2 ON s2.an = i2.an
          WHERE i2.hn = opd_periodized.hn
            AND LEFT(REPLACE(UPPER(TRIM(s2.pdx)), '.', ''), 3) IN ('I60', 'I61', 'I62')
            AND i2.regdate <= opd_periodized.event_date
            AND i2.regdate >= opd_periodized.event_date - INTERVAL '90 days'
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt i2
          JOIN an_stat s2 ON s2.an = i2.an
          WHERE i2.hn = opd_periodized.hn
            AND LEFT(REPLACE(UPPER(TRIM(s2.pdx)), '.', ''), 3) IN ('I60', 'I61', 'I62')
            AND i2.regdate <= opd_periodized.event_date
            AND i2.regdate >= opd_periodized.event_date - INTERVAL '90 days'
        ))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM opd_periodized
      WHERE age_y >= 18 AND (
          LEFT(pdx, 3) = 'I48'
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
          )
        ) AND EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.vn = opd_periodized.vn
            AND (di.name ILIKE '%warfarin%'))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DM0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
      WHERE chronic_periodized.age_y <= 6
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdg
      WHERE sdg.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdg.icd10)), '.', ''), 3) IN ('F83', 'R62'))
    )
    AND EXISTS (
      SELECT 1
      FROM psych_assess_head ha
      JOIN psych_assess_child ca ON ca.psych_assess_head_id = ha.psych_assess_head_id
      WHERE ha.hn = chronic_periodized.hn
        AND ha.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
        AND ha.date_assessment <= chronic_periodized.regdate
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DM0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        JOIN psych_assess_topic tpa ON tpa.psych_assess_topic_id = h1.psych_assess_topic_id AND tpa.psych_assess_topic_name ILIKE '%teda%'
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        JOIN psych_assess_topic tpb ON tpb.psych_assess_topic_id = h2.psych_assess_topic_id AND tpb.psych_assess_topic_name ILIKE '%teda%'
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
      WHERE chronic_periodized.age_y <= 6
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdg
      WHERE sdg.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdg.icd10)), '.', ''), 3) IN ('F83', 'R62'))
    )
    AND EXISTS (
      SELECT 1
      FROM psych_assess_head ha
      JOIN psych_assess_child ca ON ca.psych_assess_head_id = ha.psych_assess_head_id
      WHERE ha.hn = chronic_periodized.hn
        AND ha.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
        AND ha.date_assessment <= chronic_periodized.regdate
        AND ha.psych_assess_topic_id IN (SELECT tpx.psych_assess_topic_id FROM psych_assess_topic tpx WHERE tpx.psych_assess_topic_name ILIKE '%teda%')
    )
      GROUP BY 2, 3, 4

  UNION ALL

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

  UNION ALL

      SELECT
        'DM0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND (((((c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month)) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
      WHERE EXISTS (
      SELECT 1
      FROM ovstdiag sda
      WHERE sda.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sda.icd10)), '.', ''), 3) IN ('F84'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DM0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        JOIN psych_assess_topic tpa ON tpa.psych_assess_topic_id = h1.psych_assess_topic_id AND tpa.psych_assess_topic_name ILIKE '%teda%'
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        JOIN psych_assess_topic tpb ON tpb.psych_assess_topic_id = h2.psych_assess_topic_id AND tpb.psych_assess_topic_name ILIKE '%teda%'
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND (((((c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month)) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
      WHERE EXISTS (
      SELECT 1
      FROM ovstdiag sda
      WHERE sda.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sda.icd10)), '.', ''), 3) IN ('F84'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DM0203' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0203'

  UNION ALL

      SELECT
        'DM0301' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
      WHERE chronic_periodized.age_y <= 18
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdp
      WHERE sdp.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdp.icd10)), '.', ''), 3) IN ('G80'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DM0302' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        JOIN psych_assess_topic tpa ON tpa.psych_assess_topic_id = h1.psych_assess_topic_id AND tpa.psych_assess_topic_name ILIKE '%teda%'
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        JOIN psych_assess_topic tpb ON tpb.psych_assess_topic_id = h2.psych_assess_topic_id AND tpb.psych_assess_topic_name ILIKE '%teda%'
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
      WHERE chronic_periodized.age_y <= 18
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdp
      WHERE sdp.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdp.icd10)), '.', ''), 3) IN ('G80'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DM0401' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0401'

  UNION ALL

      SELECT
        'DM0402' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DM0402'

  UNION ALL

      SELECT
        'DN0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%')
            AND oi.rxdate >= periodized.regdate AND oi.rxdate <= periodized.regdate + INTERVAL '2 days')) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%')
            AND oi.rxdate >= periodized.regdate AND oi.rxdate <= periodized.regdate + INTERVAL '2 days'))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'I63'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%' OR di.name ILIKE '%warfarin%' OR di.name ILIKE '%heparin%' OR di.name ILIKE '%enoxaparin%' OR di.name ILIKE '%dalteparin%' OR di.name ILIKE '%fondaparinux%' OR di.name ILIKE '%dabigatran%' OR di.name ILIKE '%rivaroxaban%' OR di.name ILIKE '%apixaban%' OR di.name ILIKE '%edoxaban%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%' OR di.name ILIKE '%warfarin%' OR di.name ILIKE '%heparin%' OR di.name ILIKE '%enoxaparin%' OR di.name ILIKE '%dalteparin%' OR di.name ILIKE '%fondaparinux%' OR di.name ILIKE '%dabigatran%' OR di.name ILIKE '%rivaroxaban%' OR di.name ILIKE '%apixaban%' OR di.name ILIKE '%edoxaban%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'I63' AND NOT died
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%warfarin%' OR di.name ILIKE '%heparin%' OR di.name ILIKE '%enoxaparin%' OR di.name ILIKE '%dalteparin%' OR di.name ILIKE '%fondaparinux%' OR di.name ILIKE '%dabigatran%' OR di.name ILIKE '%rivaroxaban%' OR di.name ILIKE '%apixaban%' OR di.name ILIKE '%edoxaban%'))) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%warfarin%' OR di.name ILIKE '%heparin%' OR di.name ILIKE '%enoxaparin%' OR di.name ILIKE '%dalteparin%' OR di.name ILIKE '%fondaparinux%' OR di.name ILIKE '%dabigatran%' OR di.name ILIKE '%rivaroxaban%' OR di.name ILIKE '%apixaban%' OR di.name ILIKE '%edoxaban%')))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64') AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
        ) AND NOT died
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('Z716', 'Z719', 'V6541', 'V6549')
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
          )
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('Z716', 'Z719', 'V6541', 'V6549')
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
          )
        ))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64') AND NOT died
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0106' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst_rehab rb
          WHERE rb.an = periodized.an
            AND rb.service_date >= periodized.regdate
            AND rb.service_date::timestamp <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00') + INTERVAL '72 hours')
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst_rehab rb
          WHERE rb.an = periodized.an
            AND rb.service_date >= periodized.regdate
            AND rb.service_date::timestamp <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00') + INTERVAL '72 hours')
        ))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64') AND NOT died
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0109' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        ROUND(SUM(los)::numeric, 2) AS numerator,
        COUNT(*) AS denominator,
        ROUND(AVG(los), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0110' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stroke_needle_datetime IS NOT NULL
            AND er.stroke_needle_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stroke_needle_datetime - er.enter_er_time)) <= 3600) OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '60 minutes'
            ))) AS numerator,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y') OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%'))) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stroke_needle_datetime IS NOT NULL
            AND er.stroke_needle_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stroke_needle_datetime - er.enter_er_time)) <= 3600) OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '60 minutes'
            )))) * 100 / NULLIF((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y') OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')))), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'I63'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0301' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
        ROUND((COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))) * 100 / NULLIF((COUNT(*) FILTER (WHERE NOT died)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) IN ('S02', 'S06') AND EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(o.icd9)), '.', ''), 3) IN ('012', '013', '014', '015', '016')
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0302' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died_within_48h) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died_within_48h) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DN0303' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(o.icd9)), '.', ''), 3) IN ('012', '013', '014', '015', '016')
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(o.icd9)), '.', ''), 3) IN ('012', '013', '014', '015', '016')
        ))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'S06'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DO0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DO0204' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DO0205' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DO0302' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DO0303' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DO0304' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DP0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia)) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18') OR has_pneumonia_sdx
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
                OR scr.advice7_note ILIKE '%smoke%'
                OR scr.advice7_note ILIKE '%สูบ%'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN opdscreen_advice_item itm ON itm.opdscreen_advice_item_id = adv.opdscreen_advice_item_id
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
              AND (
                itm.opdscreen_advice_item_name ILIKE '%smoke%'
                OR itm.opdscreen_advice_item_name ILIKE '%บุหรี่%'
              )
          )
        )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
                OR scr.advice7_note ILIKE '%smoke%'
                OR scr.advice7_note ILIKE '%สูบ%'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN opdscreen_advice_item itm ON itm.opdscreen_advice_item_id = adv.opdscreen_advice_item_id
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
              AND (
                itm.opdscreen_advice_item_name ILIKE '%smoke%'
                OR itm.opdscreen_advice_item_name ILIKE '%บุหรี่%'
              )
          )
        ))) * 100 / NULLIF((COUNT(*)), 0), 2) AS value
      FROM periodized
      WHERE (LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND (
                LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
                OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND scr.smoking_type_id IN (2, 3)
          )
        )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE pdx IN ('A15', 'A16')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0202' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE tb_scr.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE tb_scr.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM tb_lab_examination_sputum ts
        WHERE ts.tb_register_id IN (
            SELECT tbrs.tb_register_id FROM tb_register tbrs WHERE tbrs.hn = chronic_periodized.hn
          )
          AND ts.tb_lab_examination_sputum_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND ts.tb_lab_examination_sputum_date <= chronic_periodized.regdate
      ) OR EXISTS (
        SELECT 1
        FROM clinic_visit cv
        JOIN ovst cvv ON cvv.vn = cv.vn
        WHERE cv.hn = chronic_periodized.hn
          AND cv.afb_check = 'Y'
          AND cvv.vstdate >= chronic_periodized.regdate - INTERVAL '12 months'
          AND cvv.vstdate <= chronic_periodized.regdate
      ) OR EXISTS (
        SELECT 1
        FROM tb_register tbr2
        WHERE tbr2.hn = chronic_periodized.hn
          AND tbr2.tb_register_receive_recomment_tb_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND tbr2.tb_register_receive_recomment_tb_date <= chronic_periodized.regdate
      ) AS flagged
    ) tb_scr ON TRUE
      WHERE (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND NOT EXISTS (
      SELECT 1
      FROM tb_register tba
      WHERE tba.hn = chronic_periodized.hn
        AND tba.tb_register_date >= chronic_periodized.regdate - INTERVAL '12 months'
        AND tba.tb_register_date <= chronic_periodized.regdate + INTERVAL '6 months'
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0203' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE tdt.tb_discharge_type_name ILIKE '%หาย%' OR tdt.tb_discharge_type_name ILIKE '%ครบ%' OR tdt.tb_discharge_type_name ILIKE '%cure%' OR tdt.tb_discharge_type_name ILIKE '%complete%') AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE tdt.tb_discharge_type_name ILIKE '%หาย%' OR tdt.tb_discharge_type_name ILIKE '%ครบ%' OR tdt.tb_discharge_type_name ILIKE '%cure%' OR tdt.tb_discharge_type_name ILIKE '%complete%') * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        tbr.tb_register_id,
        tbr.tb_register_date,
        tbr.tb_register_start_date_treatment,
        tbr.tb_discharge_type_id,
        tbr.clinicmember_tb_patient_type_id,
        tbr.tb_result_sputum_id,
        tbr.tb_register_receive_recomment_hiv_date
      FROM tb_register tbr
      WHERE tbr.hn = chronic_periodized.hn
        AND tbr.tb_register_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND tbr.tb_register_date <= chronic_periodized.regdate + INTERVAL '3 months'
      ORDER BY ABS(tbr.tb_register_date - chronic_periodized.regdate)
      LIMIT 1
    ) tbr ON TRUE
    LEFT JOIN clinicmember_tb_patient_type tpt
      ON tpt.clinicmember_tb_patient_type_id = tbr.clinicmember_tb_patient_type_id
    LEFT JOIN tb_result_sputum trs
      ON trs.tb_result_sputum_id = tbr.tb_result_sputum_id
    LEFT JOIN tb_discharge_type tdt
      ON tdt.tb_discharge_type_id = tbr.tb_discharge_type_id
      WHERE tbr.tb_register_id IS NOT NULL
    AND (tpt.clinicmember_tb_patient_type_name ILIKE '%ใหม่%' OR tpt.clinicmember_tb_patient_type_name ILIKE '%new%')
    AND (trs.tb_result_sputum_name ILIKE '%บวก%' OR trs.tb_result_sputum_name ILIKE '%pos%')
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0204' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE hiv_scr.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE hiv_scr.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        tbr.tb_register_id,
        tbr.tb_register_date,
        tbr.tb_register_start_date_treatment,
        tbr.tb_discharge_type_id,
        tbr.clinicmember_tb_patient_type_id,
        tbr.tb_result_sputum_id,
        tbr.tb_register_receive_recomment_hiv_date
      FROM tb_register tbr
      WHERE tbr.hn = chronic_periodized.hn
        AND tbr.tb_register_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND tbr.tb_register_date <= chronic_periodized.regdate + INTERVAL '3 months'
      ORDER BY ABS(tbr.tb_register_date - chronic_periodized.regdate)
      LIMIT 1
    ) tbr ON TRUE
    LEFT JOIN clinicmember_tb_patient_type tpt
      ON tpt.clinicmember_tb_patient_type_id = tbr.clinicmember_tb_patient_type_id
    LEFT JOIN tb_result_sputum trs
      ON trs.tb_result_sputum_id = tbr.tb_result_sputum_id
    LEFT JOIN tb_discharge_type tdt
      ON tdt.tb_discharge_type_id = tbr.tb_discharge_type_id
    LEFT JOIN LATERAL (
      SELECT
        (tbr.tb_register_receive_recomment_hiv_date IS NOT NULL) OR EXISTS (
          SELECT 1
          FROM lab_head lh
          JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = chronic_periodized.hn
            AND (li.lab_items_name ILIKE '%hiv%' OR li.lab_items_name ILIKE '%เอชไอวี%')
            AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
            AND lh.order_date <= chronic_periodized.regdate
        ) AS flagged
    ) hiv_scr ON TRUE
      WHERE tbr.tb_register_id IS NOT NULL
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0205' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE art_started.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE art_started.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        tbr.tb_register_id,
        tbr.tb_register_date,
        tbr.tb_register_start_date_treatment,
        tbr.tb_discharge_type_id,
        tbr.clinicmember_tb_patient_type_id,
        tbr.tb_result_sputum_id,
        tbr.tb_register_receive_recomment_hiv_date
      FROM tb_register tbr
      WHERE tbr.hn = chronic_periodized.hn
        AND tbr.tb_register_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND tbr.tb_register_date <= chronic_periodized.regdate + INTERVAL '3 months'
      ORDER BY ABS(tbr.tb_register_date - chronic_periodized.regdate)
      LIMIT 1
    ) tbr ON TRUE
    LEFT JOIN clinicmember_tb_patient_type tpt
      ON tpt.clinicmember_tb_patient_type_id = tbr.clinicmember_tb_patient_type_id
    LEFT JOIN tb_result_sputum trs
      ON trs.tb_result_sputum_id = tbr.tb_result_sputum_id
    LEFT JOIN tb_discharge_type tdt
      ON tdt.tb_discharge_type_id = tbr.tb_discharge_type_id
    LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM arv_tx ax
        WHERE ax.hn = chronic_periodized.hn
          AND ax.date_entry <= chronic_periodized.regdate + INTERVAL '6 months'
      ) AS flagged
    ) art_started ON TRUE
      WHERE tbr.tb_register_id IS NOT NULL
    AND (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0301' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0302' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0401' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0403' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18 AND LEFT(pdx, 3) = 'J44'
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DR0404' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
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
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'DS0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DS0101'

  UNION ALL

      SELECT
        'DS0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DS0201'

  UNION ALL

      SELECT
        'DS0301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator,
        denominator,
        value
      FROM external_facts
      WHERE indicator_code = 'DS0301'

  UNION ALL

      SELECT
        'DS0401' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT clinicmember_id) FILTER (WHERE mmt_retained.flagged) AS numerator,
        COUNT(DISTINCT clinicmember_id) AS denominator,
        ROUND((COUNT(DISTINCT clinicmember_id) FILTER (WHERE mmt_retained.flagged) * 100.0) / NULLIF(COUNT(DISTINCT clinicmember_id), 0), 2) AS value
      FROM chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%methadone%')
          AND oi.vstdate >= chronic_periodized.regdate + INTERVAL '11 months'
          AND oi.vstdate <= chronic_periodized.regdate + INTERVAL '15 months'
      ) AS flagged
    ) mmt_retained ON TRUE
      WHERE EXISTS (
      SELECT 1
      FROM opitemrece oi0
      JOIN drugitems di0 ON di0.icode = oi0.icode
      WHERE oi0.hn = chronic_periodized.hn
        AND di0.name ILIKE '%methadone%'
        AND oi0.vstdate >= chronic_periodized.regdate - INTERVAL '3 months'
        AND oi0.vstdate <= chronic_periodized.regdate + INTERVAL '3 months'
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HC0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE opd_periodized.enter_er_time IS NOT NULL) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v2.vn)
      FROM ovst v2
      JOIN ovstdiag sd2 ON sd2.vn = v2.vn
      WHERE v2.hn = opd_periodized.hn
        AND v2.vstdate >= :start_date
        AND v2.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd2.icd10)), '.', ''), 3) IN ('J45', 'J46')
    ) >= 2) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE opd_periodized.enter_er_time IS NOT NULL) * 1.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v2.vn)
      FROM ovst v2
      JOIN ovstdiag sd2 ON sd2.vn = v2.vn
      WHERE v2.hn = opd_periodized.hn
        AND v2.vstdate >= :start_date
        AND v2.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd2.icd10)), '.', ''), 3) IN ('J45', 'J46')
    ) >= 2), 0), 2)} AS value
      FROM opd_periodized
      WHERE (
      LEFT(pdx, 3) IN ('J45', 'J46')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HC0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v3.vn)
      FROM ovst v3
      JOIN er_regist er3 ON er3.vn = v3.vn
      WHERE v3.hn = opd_periodized.hn
        AND v3.vstdate >= :start_date
        AND v3.vstdate < :end_date
    ) >= 3) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v4.vn)
      FROM ovst v4
      JOIN ovstdiag sd4 ON sd4.vn = v4.vn
      WHERE v4.hn = opd_periodized.hn
        AND v4.vstdate >= :start_date
        AND v4.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd4.icd10)), '.', ''), 3) = 'J44'
    ) >= 2) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v3.vn)
      FROM ovst v3
      JOIN er_regist er3 ON er3.vn = v3.vn
      WHERE v3.hn = opd_periodized.hn
        AND v3.vstdate >= :start_date
        AND v3.vstdate < :end_date
    ) >= 3) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v4.vn)
      FROM ovst v4
      JOIN ovstdiag sd4 ON sd4.vn = v4.vn
      WHERE v4.hn = opd_periodized.hn
        AND v4.vstdate >= :start_date
        AND v4.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd4.icd10)), '.', ''), 3) = 'J44'
    ) >= 2), 0), 2) AS value
      FROM opd_periodized
      WHERE (
      LEFT(pdx, 3) IN ('J44')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HE0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.had_checkup) AS numerator,
        COUNT(DISTINCT hr.staff_key) AS denominator,
        ROUND((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.had_checkup)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.checkup = '1'
          )) AS had_checkup
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HE0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.bmi_over) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.bmi_measured) AS denominator,
        ROUND((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.bmi_over)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.bmi_measured), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.bmi IS NOT NULL
          )) AS bmi_measured,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.bmi >= 23
          )) AS bmi_over
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HE0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.smoker) AS numerator,
        COUNT(DISTINCT hr.staff_key) AS denominator,
        ROUND((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.smoker)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.smoking_type_id IN (2, 3)
          )) AS smoker
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HE0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_over_male) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_measured_male) AS denominator,
        ROUND((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_over_male)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_measured_male), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%ชาย%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist IS NOT NULL
          )) AS waist_measured_male,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%ชาย%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist > 90
          )) AS waist_over_male
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        LEFT JOIN emp_sex sx ON sx.emp_sex_id = e.emp_sex_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HE0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_over_female) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_measured_female) AS denominator,
        ROUND((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_over_female)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_measured_female), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%หญิง%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist IS NOT NULL
          )) AS waist_measured_female,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%หญิง%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist > 80
          )) AS waist_over_female
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        LEFT JOIN emp_sex sx ON sx.emp_sex_id = e.emp_sex_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HE0106' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.got_influenza_vaccine) AS numerator,
        COUNT(DISTINCT hr.staff_key) AS denominator,
        ROUND((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.got_influenza_vaccine)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN ovst vv ON vv.hn = pp.hn
            JOIN ovst_vaccine ovv ON ovv.vn = vv.vn
            JOIN person_vaccine pv ON pv.person_vaccine_id = ovv.person_vaccine_id
            WHERE pp.cid = e.emp_cid
              AND vv.vstdate >= months.work_month
              AND vv.vstdate < months.work_month + INTERVAL '1 month'
              AND (pv.vaccine_name ILIKE '%ไข้หวัดใหญ่%' OR pv.vaccine_name ILIKE '%influenza%')
          )) AS got_influenza_vaccine
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0101.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND scr.smoking_type_id IS NOT NULL
      )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND scr.smoking_type_id IS NOT NULL
      )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0101.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
        SELECT 1
        FROM ovst v
        JOIN opdscreen scr ON scr.vn = v.vn
        WHERE v.an = periodized.an
          AND scr.smoking_type_id IS NOT NULL
      )) AS numerator,
        COUNT(DISTINCT periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
        SELECT 1
        FROM ovst v
        JOIN opdscreen scr ON scr.vn = v.vn
        WHERE v.an = periodized.an
          AND scr.smoking_type_id IS NOT NULL
      )) * 100.0) / NULLIF(COUNT(DISTINCT periodized.hn), 0), 2) AS value
      FROM periodized
      WHERE periodized.age_y >= 15
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND 1 = 1
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0103.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0103.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0103.3' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0103.4' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0103.5' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM opdscreen pg
        WHERE pg.vn = opd_periodized.vn
          AND pg.pregnancy = 'Y'
      )
      OR EXISTS (
        SELECT 1
        FROM opdscreen_pregnancy pg2
        WHERE pg2.vn = opd_periodized.vn
      )
      OR EXISTS (
          SELECT 1
          FROM ipt_pregnancy ipg
          WHERE ipg.an = opd_periodized.an
        )
      OR EXISTS (
        SELECT 1
        FROM clinicmember cm
        WHERE cm.hn = opd_periodized.hn
          AND cm.with_pregnancy = 'Y'
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0103.6' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0104.1' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0104.2' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0104.3' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0104.4' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'HH0104.5' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) AS numerator,
        COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )) AS denominator,
        ROUND((COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    )) * 100.0) / NULLIF(COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    )), 0), 2) AS value
      FROM opd_periodized
      WHERE opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM opdscreen pg
        WHERE pg.vn = opd_periodized.vn
          AND pg.pregnancy = 'Y'
      )
      OR EXISTS (
        SELECT 1
        FROM opdscreen_pregnancy pg2
        WHERE pg2.vn = opd_periodized.vn
      )
      OR EXISTS (
          SELECT 1
          FROM ipt_pregnancy ipg
          WHERE ipg.an = opd_periodized.an
        )
      OR EXISTS (
        SELECT 1
        FROM clinicmember cm
        WHERE cm.hn = opd_periodized.hn
          AND cm.with_pregnancy = 'Y'
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

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

  UNION ALL

      SELECT
        'SC0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0102'

  UNION ALL

      SELECT
        'SC0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0103'

  UNION ALL

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

  UNION ALL

      SELECT
        'SC0105' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0105'

  UNION ALL

      SELECT
        'SC0106' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SC0106'

  UNION ALL

      SELECT
        'SF0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0101'

  UNION ALL

      SELECT
        'SF0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0102'

  UNION ALL

      SELECT
        'SF0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0103'

  UNION ALL

      SELECT
        'SF0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0104'

  UNION ALL

      SELECT
        'SF0105' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0105'

  UNION ALL

      SELECT
        'SF0106' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SF0106'

  UNION ALL

      SELECT
        'SG0104' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SG0104'

  UNION ALL

      SELECT
        'SH0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.voluntary_resign_cnt) / NULLIF(12, 0) AS numerator,
        (COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2, 0) AS denominator,
        ROUND((SUM(hr.voluntary_resign_cnt) / NULLIF(12, 0)) * 100 / NULLIF((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2, 0), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END)) AS active_at_fy_start,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day'))) AS active_at_fy_end
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.work_injury_event_cnt) AS numerator,
        (COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2, 0) AS denominator,
        ROUND((SUM(hr.work_injury_event_cnt)) * 100 / NULLIF((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2, 0), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END)) AS active_at_fy_start,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day'))) AS active_at_fy_end
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (1)) AS period_start,
        1 AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.work_illness_event_cnt) AS numerator,
        (COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2, 0) AS denominator,
        ROUND((SUM(hr.work_illness_event_cnt)) * 100 / NULLIF((COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2, 0), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END)) AS active_at_fy_start,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day'))) AS active_at_fy_end
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0104' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.voluntary_resign_cnt) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end) AS denominator,
        ROUND((SUM(hr.voluntary_resign_cnt)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          ((COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AS is_physician
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_physician
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0105' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.voluntary_resign_cnt) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end) AS denominator,
        ROUND((SUM(hr.voluntary_resign_cnt)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          ((COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AS is_nurse
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_nurse
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0106' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.voluntary_resign_cnt) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end) AS denominator,
        ROUND((SUM(hr.voluntary_resign_cnt)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%'])))) AS is_allied_health
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_allied_health
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0107' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 3 THEN 1 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 4 WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 9 THEN 7 ELSE 10 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.voluntary_resign_cnt) AS numerator,
        COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end) AS denominator,
        ROUND((SUM(hr.voluntary_resign_cnt)) * 100 / NULLIF(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_back_office
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_back_office
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0201'

  UNION ALL

      SELECT
        'SH0202' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0202'

  UNION ALL

      SELECT
        'SH0203' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0203'

  UNION ALL

      SELECT
        'SH0204' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0204'

  UNION ALL

      SELECT
        'SH0205' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0205'

  UNION ALL

      SELECT
        'SH0206' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0206'

  UNION ALL

      SELECT
        'SH0207' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0207'

  UNION ALL

      SELECT
        'SH0208' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0208'

  UNION ALL

      SELECT
        'SH0209' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0209'

  UNION ALL

      SELECT
        'SH0210' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0210'

  UNION ALL

      SELECT
        'SH0211' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0211'

  UNION ALL

      SELECT
        'SH0212' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0212'

  UNION ALL

      SELECT
        'SH0213' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0213'

  UNION ALL

      SELECT
        'SH0214' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0214'

  UNION ALL

      SELECT
        'SH0215' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0215'

  UNION ALL

      SELECT
        'SH0216' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SH0216'

  UNION ALL

      SELECT
        'SH0301' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt) AS numerator,
        SUM(hr.work_hours) AS denominator,
        ROUND((SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt)) * 1000000 / NULLIF(SUM(hr.work_hours), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0302' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.injury_lost_days) AS numerator,
        SUM(hr.work_hours) AS denominator,
        ROUND((SUM(hr.injury_lost_days)) * 1000000 / NULLIF(SUM(hr.work_hours), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COALESCE(SUM(es.emp_work_sick_countday), 0)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS injury_lost_days,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%') OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%')) OR ((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_direct_contact
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_direct_contact
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0303' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.injury_lost_days) AS numerator,
        SUM(hr.work_hours) AS denominator,
        ROUND((SUM(hr.injury_lost_days)) * 1000000 / NULLIF(SUM(hr.work_hours), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COALESCE(SUM(es.emp_work_sick_countday), 0)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS injury_lost_days,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_back_office
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_back_office
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0306' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt) AS numerator,
        SUM(hr.work_hours) AS denominator,
        ROUND((SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt)) * 1000000 / NULLIF(SUM(hr.work_hours), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%') OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%')) OR ((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_direct_contact
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_direct_contact
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SH0307' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt) AS numerator,
        SUM(hr.work_hours) AS denominator,
        ROUND((SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt)) * 1000000 / NULLIF(SUM(hr.work_hours), 0), 2) AS value
      FROM (
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_back_office
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
      ) hr
      WHERE hr.is_back_office
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SI0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0101'

  UNION ALL

      SELECT
        'SI0102' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0102'

  UNION ALL

      SELECT
        'SI0103' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0103'

  UNION ALL

      SELECT
        'SI0201' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0201'

  UNION ALL

      SELECT
        'SI0202' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0202'

  UNION ALL

      SELECT
        'SI0203' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0203'

  UNION ALL

      SELECT
        'SI0301' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0301'

  UNION ALL

      SELECT
        'SI0302' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0302'

  UNION ALL

      SELECT
        'SI0303' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SI0303'

  UNION ALL

      SELECT
        'SL0101' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        SUM(brd.request_qty) AS numerator,
        SUM(brd.response_qty) AS denominator,
        ROUND(SUM(brd.request_qty) * 1 / NULLIF(SUM(brd.response_qty), 0), 2) AS value
      FROM (
      SELECT
        br.blood_request_id,
        br.vn,
        br.hn,
        br.request_date,
        DATE_TRUNC('month', br.request_date)::date AS period_start,
        EXTRACT(MONTH FROM br.request_date)::integer AS calendar_month
      FROM blood_request br
      WHERE br.request_date >= :start_date
        AND br.request_date < :end_date
    ) blood_requests
      JOIN blood_request_detail brd ON brd.blood_request_id = blood_requests.blood_request_id
      WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.vn = blood_requests.vn
         OR (
              ol.hn = blood_requests.hn
              AND ol.operation_date >= blood_requests.request_date - INTERVAL '7 days'
              AND ol.operation_date <= blood_requests.request_date + INTERVAL '7 days'
            )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SM0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
      )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
      )) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM opd_periodized
      WHERE (
      LEFT(pdx, 3) = 'J00'
      OR pdx IN ('B053', 'H650', 'H651', 'H659', 'H660', 'H664', 'H669', 'H670', 'H671', 'H678', 'H720', 'H722', 'H728', 'H729', 'J010', 'J014', 'J018', 'J019', 'J020', 'J029', 'J030', 'J038', 'J039', 'J040', 'J042', 'J050', 'J051', 'J060', 'J068', 'J069', 'J101', 'J111', 'J200', 'J209', 'J210', 'J218', 'J219')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'J00'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('B053', 'H650', 'H651', 'H659', 'H660', 'H664', 'H669', 'H670', 'H671', 'H678', 'H720', 'H722', 'H728', 'H729', 'J010', 'J014', 'J018', 'J019', 'J020', 'J029', 'J030', 'J038', 'J039', 'J040', 'J042', 'J050', 'J051', 'J060', 'J068', 'J069', 'J101', 'J111', 'J200', 'J209', 'J210', 'J218', 'J219')
          )
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SM0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END)) AS period_start,
        CASE WHEN (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) <= 6 THEN 1 ELSE 7 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
      )) AS numerator,
        COUNT(*) AS denominator,
        ROUND((COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
      )) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM opd_periodized
      WHERE (
      LEFT(pdx, 3) = 'A09'
      OR pdx IN ('A000', 'A001', 'A009', 'A020', 'A030', 'A033', 'A038', 'A039', 'A040', 'A049', 'A050', 'A053', 'A054', 'A059', 'A080', 'A085', 'K521', 'K528', 'K529')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'A09'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A000', 'A001', 'A009', 'A020', 'A030', 'A033', 'A038', 'A039', 'A040', 'A049', 'A050', 'A053', 'A054', 'A059', 'A080', 'A085', 'K521', 'K528', 'K529')
          )
      )
    )
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SM0201' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        MAX((
        SELECT SUM(bal.left_value)
        FROM (
          SELECT DISTINCT ON (st.item_id) (st.left_qty * st.price) AS left_value
          FROM stock_trancation st
          WHERE st.transaction_date >= opd_periodized.period_start
            AND st.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          ORDER BY st.item_id, st.transaction_date DESC, st.stock_trancation_id DESC
        ) bal
      )) AS numerator,
        MAX((
        SELECT SUM(st2.out_qty * st2.price)
        FROM stock_trancation st2
        WHERE st2.transaction_date >= opd_periodized.period_start
          AND st2.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          AND COALESCE(st2.out_qty, 0) > 0
      )) AS denominator,
        ROUND((MAX((
        SELECT SUM(bal.left_value)
        FROM (
          SELECT DISTINCT ON (st.item_id) (st.left_qty * st.price) AS left_value
          FROM stock_trancation st
          WHERE st.transaction_date >= opd_periodized.period_start
            AND st.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          ORDER BY st.item_id, st.transaction_date DESC, st.stock_trancation_id DESC
        ) bal
      )) * 1.0) / NULLIF(MAX((
        SELECT SUM(st2.out_qty * st2.price)
        FROM stock_trancation st2
        WHERE st2.transaction_date >= opd_periodized.period_start
          AND st2.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          AND COALESCE(st2.out_qty, 0) > 0
      )), 0), 2)} AS value
      FROM opd_periodized
      WHERE opd_periodized.event_date IS NOT NULL
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SS0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        numerator AS numerator,
        denominator AS denominator,
        value AS value
      FROM external_facts
      WHERE indicator_code = 'SS0101'

  UNION ALL

      SELECT
        'SS0102' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE sterile_batches.supply_sterile_complete = 'Y'
          AND sterile_batches.supply_sterile_confirm = 'Y'
          AND NOT EXISTS (
            SELECT 1
            FROM supply_sterile_list sl
            WHERE sl.supply_sterile_id = sterile_batches.supply_sterile_id
              AND COALESCE(sl.supply_sterile_list_complete, 'N') <> 'Y'
          )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (
        WHERE sterile_batches.supply_sterile_complete = 'Y'
          AND sterile_batches.supply_sterile_confirm = 'Y'
          AND NOT EXISTS (
            SELECT 1
            FROM supply_sterile_list sl
            WHERE sl.supply_sterile_id = sterile_batches.supply_sterile_id
              AND COALESCE(sl.supply_sterile_list_complete, 'N') <> 'Y'
          )
      ) * 100 / NULLIF(COUNT(*), 0), 2) AS value
      FROM (
      SELECT
        st.supply_sterile_id,
        st.supply_sterile_date,
        st.supply_sterile_confirm,
        st.supply_sterile_complete,
        DATE_TRUNC('month', st.supply_sterile_date)::date AS period_start,
        EXTRACT(MONTH FROM st.supply_sterile_date)::integer AS calendar_month
      FROM supply_sterile st
      WHERE st.supply_sterile_date >= :start_date
        AND st.supply_sterile_date < :end_date
    ) sterile_batches
      WHERE TRUE
      GROUP BY 2, 3, 4

  UNION ALL

      SELECT
        'SS0103' AS indicator_code,
        DATE_TRUNC('month', period_start)::date - MAKE_INTERVAL(months => (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END) - (CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END)) AS period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (
        WHERE sterile_receipts.supply_sterile_receive_status = 'Y'
          AND EXISTS (
            SELECT 1
            FROM supply_sterile st
            WHERE st.supply_sterile_id = sterile_receipts.supply_sterile_id
              AND st.supply_sterile_confirm = 'Y'
          )
      ) AS numerator,
        COUNT(*) AS denominator,
        ROUND(COUNT(*) FILTER (
        WHERE sterile_receipts.supply_sterile_receive_status = 'Y'
          AND EXISTS (
            SELECT 1
            FROM supply_sterile st
            WHERE st.supply_sterile_id = sterile_receipts.supply_sterile_id
              AND st.supply_sterile_confirm = 'Y'
          )
      ) * 100 / NULLIF(COUNT(*), 0), 2) AS value
      FROM (
      SELECT
        sr.supply_sterile_receive_id,
        sr.supply_sterile_id,
        sr.supply_sterile_receive_date,
        sr.supply_sterile_receive_status,
        DATE_TRUNC('month', sr.supply_sterile_receive_date)::date AS period_start,
        EXTRACT(MONTH FROM sr.supply_sterile_receive_date)::integer AS calendar_month
      FROM supply_sterile_receive sr
      WHERE sr.supply_sterile_receive_date >= :start_date
        AND sr.supply_sterile_receive_date < :end_date
    ) sterile_receipts
      WHERE TRUE
      GROUP BY 2, 3, 4
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
    ('AA0101', 'A', 'rate', 'lower-is-better', 'annual', 'Ambulatory care', 'Epilepsy: Hospitalization rate', 'อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคลมชัก)', 'ภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคลมชัก) (ACSC: Ambulatory Care Sensitive Condition) เป็นการคัดเลือกข้อมูลการนอนโรงพยาบาลของภาวะที่ควรควบคุม ด้วยบริการผู้ป่วยนอก โดยพิจารณาจากการวินิจฉัยหลัก (Pdx) โดยใช้รหัส ICD-10 ของ ผู้ป่วยโรคลมชัก (Epilepsy) ได้แก่ G40 และ G41 *ACSC อ้างอิงจากการศึกษาของสุพล ลิมวัฒนานนท์ ในคู่มือการวิเคราะห์อัตราการนอน โรงพยาบาลของภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก ประกอบด้วยโรคลมชัก, ปอดอุด กั้นเรื้อรัง, หืด, เบาหวาน, และความดันโลหิตสูง โดยบริบทประเทศไทยไม่รวมโรคหัวใจ ล้มเหลวและน้ำท่วมปอด (Heart Failure-HT, Pulmonary Edema-PE) เนื่องจากไม่ สามารถให้การรักษาสองโรคนี้ได้ในหน่วยบริการปฐมภูมิ', '(a/b) x 100,000', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 286', 'registered-2026.1', NULL, 'registered'),
    ('AA0102', 'A', 'rate', 'lower-is-better', 'annual', 'Ambulatory care', 'COPD: Hospitalization rate', 'อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคปอดอุดกั้น เรื้อรัง)', 'ภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคลมชัก) (ACSC: Ambulatory Care Sensitive Condition) เป็นการคัดเลือกข้อมูลการนอนโรงพยาบาลของภาวะที่ควรควบคุม ด้วยบริการผู้ป่วยนอก โดยพิจารณาจากการวินิจฉัยหลัก (Pdx) โดยใช้รหัส ICD-10 ของ ผู้ป่วยโรคปอดอุดกั้นเรื้อรัง (COPD) ได้แก่ J40-J44 และ J47 รวมทั้ง J10.0, J11.0, J12- J16, J18, J20, J21, J22 ที่มีการวินิจฉัยรอง (Sdx) เป็น J44 *ACSC อ้างอิงจากการศึกษาของสุพล ลิมวัฒนานนท์ ในคู่มือการวิเคราะห์อัตราการนอน โรงพยาบาลของภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก ประกอบด้วยโรคลมชัก, ปอดอุด กั้นเรื้อรัง, หืด, เบาหวาน, และความดันโลหิตสูง โดยบริบทประเทศไทยไม่รวมโรคหัวใจ ล้มเหลวและน้ำท่วมปอด (Heart Failure-HT, Pulmonary Edema-PE) เนื่องจากไม่ สามารถให้การรักษาสองโรคนี้ได้ในหน่วยบริการปฐมภูมิ', '(a/b) x 100,000', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 287', 'registered-2026.1', NULL, 'registered'),
    ('AA0103', 'A', 'rate', 'lower-is-better', 'annual', 'Ambulatory care', 'Asthma: Hospitalization rate', 'อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคหืด)', 'ภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคลมชัก) (ACSC: Ambulatory Care Sensitive Condition) เป็นการคัดเลือกข้อมูลการนอนโรงพยาบาลของภาวะที่ควรควบคุม ด้วยบริการผู้ป่วยนอก โดยพิจารณาจากการวินิจฉัยหลัก (Pdx) โดยใช้รหัส ICD-10 ของ ผู้ป่วยโรคหืด (Asthma) ได้แก่ J45 และ J46 *ACSC อ้างอิงจากการศึกษาของสุพล ลิมวัฒนานนท์ ในคู่มือการวิเคราะห์อัตราการนอน โรงพยาบาลของภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก ประกอบด้วยโรคลมชัก, ปอดอุด กั้นเรื้อรัง, หืด, เบาหวาน, และความดันโลหิตสูง โดยบริบทประเทศไทยไม่รวมโรคหัวใจ ล้มเหลวและน้ำท่วมปอด (Heart Failure-HT, Pulmonary Edema-PE) เนื่องจากไม่ สามารถให้การรักษาสองโรคนี้ได้ในหน่วยบริการปฐมภูมิ', '(a/b) x 100,000', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 288', 'registered-2026.1', NULL, 'registered'),
    ('AA0104', 'A', 'rate', 'lower-is-better', 'annual', 'Ambulatory care', 'Diabetes Mellitus (DM): Hospitalization rate', 'อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคเบาหวาน)', 'ภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคลมชัก) (ACSC: Ambulatory Care Sensitive Condition) เป็นการคัดเลือกข้อมูลการนอนโรงพยาบาลของภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก โดยพิจารณาจากการวินิจฉัยหลัก (Pdx) โดยใช้รหัส ICD-10 ของผู้ป่วยโรคเบาหวาน (DM) ได้แก่ E10.0, E10.1, E10.6, E10.9, E11.0, E11.1, E11.6, E11.9, E13.0, E13.1, E13.6, E13.9, E14.0, E14.1, E14.6 และE14.9 *ACSC อ้างอิงจากการศึกษาของสุพล ลิมวัฒนานนท์ ในคู่มือการวิเคราะห์อัตราการนอน โรงพยาบาลของภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก ประกอบด้วยโรคลมชัก, ปอดอุด กั้นเรื้อรัง, หืด, เบาหวาน, และความดันโลหิตสูง โดยบริบทประเทศไทยไม่รวมโรคหัวใจ ล้มเหลวและน้ำท่วมปอด (Heart Failure-HT, Pulmonary Edema-PE) เนื่องจากไม่ สามารถให้การรักษาสองโรคนี้ได้ในหน่วยบริการปฐมภูมิ', '(a/b) x 100,000', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 289', 'registered-2026.1', NULL, 'registered'),
    ('AA0105', 'A', 'rate', 'lower-is-better', 'annual', 'Ambulatory care', 'Hypertension: Hospitalization rate', 'อัตราการนอนโรงพยาบาลด้วยภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคความดัน โลหิตสูง)', 'ภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก (โรคลมชัก) (ACSC: Ambulatory Care Sensitive Condition) เป็นการคัดเลือกข้อมูลการนอนโรงพยาบาลของภาวะที่ควรควบคุมด้วยบริการผู้ป่วย นอก โดยพิจารณาจากการวินิจฉัยหลัก (Pdx) โดยใช้รหัส ICD-10 ของผู้ป่วยโรคความดันโลหิตสูง (HT) ได้แก่ I10 และ I11 โดยไม่มีการให้หัตถการดังต่อไปนี้ 33.6, 35, 36, 37.3, 37.5, 37.7, 37.8, 37.94, และ37.98 *ACSC อ้างอิงจากการศึกษาของสุพล ลิมวัฒนานนท์ ในคู่มือการวิเคราะห์อัตราการนอน โรงพยาบาลของภาวะที่ควรควบคุมด้วยบริการผู้ป่วยนอก ประกอบด้วยโรคลมชัก, ปอดอุด กั้นเรื้อรัง, หืด, เบาหวาน, และความดันโลหิตสูง โดยบริบทประเทศไทยไม่รวมโรคหัวใจ ล้มเหลวและน้ำท่วมปอด (Heart Failure-HT, Pulmonary Edema-PE) เนื่องจากไม่ สามารถให้การรักษาสองโรคนี้ได้ในหน่วยบริการปฐมภูมิ', '(a/b) x 100,000', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'ipt', 'an_stat', 'iptdiag', 'patient', 'person']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 290', 'registered-2026.1', NULL, 'registered'),
    ('CA0101', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Anesthesia: Intra-operative cardiac arrest ASA physical status I, II', 'อัตราการเกิดภาวะหัวใจหยุดเต้นระหว่างผ่าตัดในผู้ป่วยที่มีระดับ ASA physical status I, II ก่อนผ่าตัด', '1. การเกิดภาวะหัวใจหยุดเต้นระหว่างผ่าตัด หมายถึง การเกิดภาวะหัวใจหยุดเต้นของ ผู้ป่วยที่อยู่ระหว่างการผ่าตัด 2. ผู้ป่วยที่มีระดับ ASA physical status I, II ก่อนผ่าตัด หมายถึง ผู้ป่วยที่ได้รับการตรวจ ประเมินก่อนผ่าตัด และพบว่ามีภาวะ ASA physical status I, II 3. การผ่าตัด หมายถึง การผ่าตัดทุกชนิดที่มีการให้ยาระงับความรู้สึกโดยวิสัญญี', '(a/b) x 10,000', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 180', 'registered-2026.1', NULL, 'registered'),
    ('CA0102', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Anesthesia: Percent of pre-anesthetic visit elective in-patient cases', 'ร้อยละของการเยี่ยมผู้ป่วยก่อนการให้ยาระงับความรู้สึกในผู้ป่วยในที่รับการผ่าตัดแบบไม่ ฉุกเฉิน', '1. การเยี่ยมผู้ป่วยก่อนการให้ยาระงับความรู้สึกในการผ่าตัดแบบไม่ฉุกเฉิน หมายถึง การ เยี่ยมเพื่อตรวจประเมินอาการของผู้ป่วยใน ก่อนการให้ยาระงับความรู้สึกในการรับการ ผ่าตัดแบบไม่ฉุกเฉิน 2. ผู้ป่วยใน หมายถึง ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป 3. การผ่าตัด หมายถึง major operation จากคำนิยามสถิติสาธารณสุข นับรวมการผ่าตัด ในห้องผ่าตัด ที่มีการดมยาหรือ block ด้วยวิธี spinal หรือ epidural Block ในที่นี้จะนับ รวม กลุ่มผู้ป่วยที่ brachial plexus block, ฉีดยาชา เจาะคอ under maximum anesthetic care', '(a/b) x 100', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 181', 'registered-2026.1', NULL, 'registered'),
    ('CA0103', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Anesthesia: Percent of patients observed in recovery room', 'ร้อยละของผู้ป่วยที่รับการให้ยาระงับความรู้สึกที่ได้รับการดูแลในห้องพักฟื้น', '1. การให้ยาระงับความรู้สึก หมายถึง การให้ยาระงับความรู้สึกทุกวิธีการในผู้ป่วยผ่าตัด เพื่อให้ผู้ป่วยหมดความรู้สึก ก่อนทำการผ่าตัด 2. ผู้ป่วยที่รับการให้ยาระงับความรู้สึกที่ได้รับการดูแลในห้องพักฟื้น หมายถึง การที่ผู้ป่วย ผ่าตัดที่ได้รับยาระงับความรู้สึก ได้รับการดูแลช่วงหลังการให้ยาระงับความรู้สึกในห้องพัก ฟื้นในระยะเวลาที่เหมาะสมตามประเภทของการให้ยาระงับความรู้สึกและสภาพของผู้ป่วย เพื่อส่งต่อผู้ป่วยกลับหอผู้ป่วยได้อย่างปลอดภัย 3. การผ่าตัด หมายถึง การผ่าตัดทุกชนิดที่มีการให้ยาระงับความรู้สึกโดยวิสัญญี', '(a/b) x 100', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 182', 'registered-2026.1', NULL, 'registered'),
    ('CA0104', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Anesthesia: Percent of re-intubation within 2 hours after extubation', 'ร้อยละของผู้ป่วยได้รับการใส่ท่อหายใจซ้ำภายใน 2 ชั่วโมงหลังการถอดท่อหายใจ', '1. ผู้ป่วยได้รับการใส่ท่อหายใจซ้ำหลังการถอดท่อหายใจ หมายถึง ผู้ป่วยผ่าตัดที่ได้รับการ ให้ยาระงับความรู้สึกแบบทั้งตัว ที่ใส่ท่อหายใจและได้รับการถอดท่อหายใจแล้วต้องกลับมา ใส่ท่อหายใจซ้ำไม่ว่าจากสาเหตุใด ๆ 2. การผ่าตัด หมายถึง การผ่าตัดทุกชนิดที่มีการให้ยาระงับความรู้สึกโดยวิสัญญี', '(a/b) x 100', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 183', 'registered-2026.1', NULL, 'registered'),
    ('CA0105', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Anesthesia: Percent of using capnometry during general anesthesia', 'ร้อยละของผู้ป่วยที่ดมยาสลบได้รับการเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ ในลมหายใจออก', '1. การเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ในลมหายใจออก หมายถึง การเฝ้าระวังการ หายใจโดยการใช้เครื่องวัดระดับคาร์บอนไดออกไซด์ในลมหายใจออก ด้วยเครื่อง Capnometry ในผู้ป่วยผ่าตัดที่ได้รับยาระงับความรู้สึกแบบทั้งตัวและใส่ท่อช่วยหายใจ ระหว่างการได้รับยาระงับความรู้สึก 2. การผ่าตัด หมายถึง การผ่าตัดทุกชนิดที่มีการให้ยาระงับความรู้สึกโดยวิสัญญี', '(a/b) x 100', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'ipt', 'an_stat', 'er_regist']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 184', 'registered-2026.1', NULL, 'registered'),
    ('CE0101', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Sepsis: Percent of broad-spectrum antibiotic receiving within 3 hours', 'ร้อยละผู้ป่วยห้องฉุกเฉินที่มีภาวะติดเชื้อในกระแสโลหิตได้รับยาต้านจุลชีพ ภายใน 3 ชั่วโมง', '1. ภาวะติดเชื้อในกระแสโลหิต หมายถึง ภาวะ Sepsis หรือ การที่ผู้ป่วยมีอาการแสดงของ การอักเสบทั่วตัว (systemic inflammation) ร่วมกับพบเชื้อจากการตรวจเพาะเชื้อจาก เลือด หรือ พบว่ามีการติดเชื้อที่ใดที่หนึ่งในร่างกาย (reference: surviving sepsis campaign 2012) ซึ่งมี Pdx หรือมีอาการแสดงตามรหัสโรค ICD-10 TM ที่กำหนด (ในที่นี้หมายรวมถึงเฉพาะผู้ป่วยผู้ใหญ่ ที่มารับบริการที่ห้องฉุกเฉิน (ER) เท่านั้น) 2. การได้รับยาปฏิชีวนะ หมายถึง การที่ผู้ป่วย Sepsis, Severe sepsis, Septic shock ได้รับยาปฏิชีวนะภายใน 3 ชั่วโมง นับตั้งแต่ระยะเวลาที่ผู้ป่วยมาถึง ER จนถึงเวลาที่ ได้รับยา', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 194', 'registered-2026.1', NULL, 'registered'),
    ('CE0102', 'C', 'ratio', 'lower-is-better', 'monthly', 'Care process', 'ER: Average Emergency Department (ED) TIME-IN, TIME-OUT', 'ค่าเฉลี่ยระยะเวลาการเข้ารับ-ออกจากบริการของผู้ป่วยที่มารับบริการที่ห้องฉุกเฉิน', '1. ผู้ป่วยฉุกเฉิน (triage as emergency patients) หมายถึง ผู้ป่วยฉุกเฉินตามประเภท ของ triage ระดับ 1 ฉุกเฉินมาก emergency condition ภาวะที่มีอันตราย 1A ความเสี่ยง สูงต่อชีวิต immediate life threatening ต้องการตรวจรักษาทันทีไม่เกิน 4 นาที ซึ่งเป็น ผู้ป่วยฉุกเฉินที่มารับบริการที่ห้องฉุกเฉิน (ไม่รวมกรณีเสียชีวิตผู้ป่วยคลินิกนอกเวลา ผู้ป่วยที่ จําเป็นต้องนอนรักษาที่ ED หรือรอ admit) 2. ระยะเวลา นับเริ่มตั้งแต่เข้ารับบริการ (time-in) จนถึงออกจากห้องฉุกเฉิน (time-out) ซึ่งอาจเป็นการออกโดยจําหน่าย, admit, หรือ refer 3. กำหนดช่วงเวลาของการเก็บข้อมูล ทุกวันที่ 5, 15, 25 ช่วงเวลา 00.00-23.59 น. (24 ชั่วโมง) โดยเก็บข้อมูลทุก 1 เดือนๆ ละ 3 ครั้ง', 'a/b', 'a', 'b', ARRAY['ovst', 'er_regist', 'ovstdiag']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 195', 'registered-2026.1', NULL, 'registered'),
    ('CE0103', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'ER: Percent of Emergency patients recieveing emergency service (ED TIME-IN, TIME-OUT) within 60 minutes', 'ร้อยละของผู้ป่วยฉุกเฉินมากที่ได้รับบริการที่ห้องฉุกเฉินระยะเวลาภายใน 60 นาที', '1. ผู้ป่วยฉุกเฉิน (triage as emergency patients) หมายถึง ผู้ป่วยฉุกเฉินตามประเภท ของ Triage ระดับ 1 ฉุกเฉินมาก emergency condition ภาวะที่มีอันตราย 1A ความ เสี่ยงสูงต่อชีวิต immediate life threatening ต้องการตรวจรักษาทันทีไม่เกิน 4 นาที ซึ่ง เป็นผู้ป่วยฉุกเฉินที่มารับบริการที่ห้องฉุกเฉิน(ไม่รวมกรณีเสียชีวิตผู้ป่วยคลินิกนอกเวลา ผู้ป่วยที่จําเป็นต้องนอนรักษาที่ ED หรือรอ admit) 2. ระยะเวลา นับเริ่มตั้งแต่เข้ารับบริการ (time-in) จนถึงออกจากห้องฉุกเฉิน (time-out) ซึ่งอาจเป็นการออกโดยจําหน่าย, admit, หรือ refer 3. กำหนดช่วงเวลาของการเก็บข้อมูล ทุกวันที่ 5, 15, 25 ช่วงเวลา 00.00-23.59 น. (24 ชั่วโมง) โดยเก็บข้อมูลทุก 1 เดือนๆ ละ 3 ครั้ง', '(a/b) x 100', 'a', 'b', ARRAY['ovst', 'er_regist', 'ovstdiag']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 197', 'registered-2026.1', NULL, 'registered'),
    ('CE0104', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Sepsis: Percent of broad-spectrum antibiotic received within 1 hour in emergency room', 'ร้อยละผู้ป่วยห้องฉุกเฉิน ที่มีภาวะติดเชื้อในกระแสโลหิตได้รับยาต้านจุลชีพภายใน 1 ชั่วโมง', '1. ผู้ป่วยห้องฉุกเฉิน ที่มีภาวะติดเชื้อในกระแสโลหิต หมายถึง ผู้ป่วยผู้ใหญ่ที่มีการวินิจฉัย ภาวะ Severe Sepsis /Septic shock เมื่อมารับบริการห้องฉุกเฉินของโรงพยาบาล โดยมี เกณฑ์การวินิจฉัยภาวะ Sepsis/Septic shock (reference Crit Care Med 2007; 35 (4): 1105 – 12) The criteria for Servere sepsis/Septic shock 1. Two or more of the following four Items a. Temperature >38.3oC or <36.0oC b. Heat rate > 90 beats/min c. Respiration > 20 b/min d. Wbc > 12,000 or < 4,000/mm3, or >10% bandemia 2. A suspected infection 3. SBP <90 mmHg. after 20 mL/kg fluid bolus or lactate >4 mmol/L 2. การได้รับยาปฏิชีวนะภายใน1 ชั่วโมงหมายถึงการที่ผู้ป่วยSevere sepsis/ Septic shock ได้รับ ยาปฏิชีวนะภายใน1ชั่วโมง (นับจากเวลาที่ผู้ป่วยได้รับการวินิจฉัยจนถึงเวลาที่ได้รับยา)', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 198', 'registered-2026.1', NULL, 'registered'),
    ('CG0101', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Rate of Pressure ulcer', 'อัตราการเกิดแผลกดทับในโรงพยาบาล', '1. อัตราการเกิดแผลกดทับในโรงพยาบาล หมายถึง จำนวนตัวเลขที่แสดงถึงจำนวนผู้ป่วย ที่เกิดแผลกดทับ ซึ่งเกิดขึ้นในผู้ป่วยที่รับนอนในโรงพยาบาล นาน ≥4 ชั่วโมง ภายใน 1 เดือน และมีความรุนแรงตั้งแต่ระดับ 1 ขึ้นไป เปรียบเทียบกับจำนวน 1000 วันนอนในเดือนนั้น ๆ 2. ความหมายและการแบ่งระดับของแผลกดทับ อ้างอิงตามนิยามที่กำหนดโดยคณะทำงาน ตัวชี้วัดแผลกดทับ ชมรมพยาบาลแผล ออสโตมี และควบคุมการขับถ่าย และชมรม เครือข่ายพัฒนาคุณภาพการพยาบาล (University Hospital Nursing Director Consortium; UHNDC) ตามเอกสารภาคผนวก 3. เครื่องมือในการเก็บข้อมูล ได้แก่ (1) แบบรายงานการเก็บข้อมูลการเกิดแผลกดทับ แบ่ง ความรุนแรงเป็น 4 ระดับและ 2 ลักษณะ (ระดับ 1-4, ไม่สามารถระบุระดับได้และการ บาดเจ็บที่เนื้อเยื่อชั้นลึก), และ (2) แบบรายงานสถิติข้อมูลแผลกดทับ', '(a/b) x 1,000', 'a', 'b', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 188', 'registered-2026.1', NULL, 'registered'),
    ('CG0102', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Rate of Pressure ulcer in risk patients', 'อัตราการเกิดแผลกดทับในโรงพยาบาลในผู้ป่วยกลุ่มเสี่ยง', '1. อัตราการเกิดแผลกดทับในโรงพยาบาล หมายถึง จำนวนตัวเลขที่แสดงถึงจำนวนครั้งของ การเกิดแผลกดทับ ซึ่งเกิดขึ้นในผู้ป่วยที่รับนอนในโรงพยาบาล นาน ≥4 ชั่วโมง ที่ได้รับการ ประเมินว่ามีความเสี่ยงต่อการเกิดแผลกดทับ ภายใน 1 เดือน และมีความรุนแรงตั้งแต่ระดับ 1 ขึ้นไป เปรียบเทียบกับจำนวน 1000 วันนอนในเดือนนั้น ๆ 2. ความหมายและการแบ่งระดับของแผลกดทับ อ้างอิงตามนิยามที่กำหนดโดยคณะทำงาน ตัวชี้วัดแผลกดทับ ชมรมพยาบาลแผล ออสโตมี และควบคุมการขับถ่าย และชมรม เครือข่ายพัฒนาคุณภาพการพยาบาล (University Hospital Nursing Director Consortium; UHNDC) ตามเอกสารภาคผนวก 3. จำนวนวันนอนรวมของผู้ป่วยกลุ่มเสี่ยง หมายถึง ผลรวมของจำนวนวันนอนของผู้ป่วยที่ ได้รับการประเมินว่ามีความเสี่ยงต่อการเกิดแผลกดทับ ในหอผู้ป่วยในทั้งหมด', '(a/b) x 1,000', 'a', 'b', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 190', 'registered-2026.1', NULL, 'registered'),
    ('CG0103', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury', 'อัตราความชุกของแผลกดทับ', '1. อัตราความชุกของแผลกดทับ หมายถึง ตัวเลขที่แสดงจำนวนผู้ป่วยที่มีแผลกดทับทั้งหมด ในโรงพยาบาล ในช่วงเวลาที่สำรวจ 2. การนับจำนวนผู้ป่วยที่มีแผลกดทับในประชากรที่สำรวจ ณ เวลาใดเวลาหนึ่งเท่านั้น เป็น การวัดจำนวนผู้ป่วยที่เกิดแผลกดทับในโรงพยาบาล ณ วันที่มีการสำรวจ การนับจำนวนให้ รวมผู้ป่วยที่เกิดแผลกดทับก่อนรับเข้าโรงพยาบาล และผู้ป่วยที่เกิดแผลกดทับภายหลัง รับเข้ารักษาในโรงพยาบาล 3. แผลกดทับ แบ่งตามระดับความรุนแรงเป็น 4 ระดับและ 2 ลักษณะ (ระดับความรุนแรง 1-4, ไม่สามารถระบุระดับความลึกของเนื้อเยื่อที่โดนทำลายได้และการบาดเจ็บเนื้อเยื่อชั้น ลึก) คณะทำงานตัวชี้วัดแผลกดทับ ชมรมพยาบาลแผล ออสโตมี และควบคุมการขับถ่าย และชมรมเครือข่ายพัฒนาคุณภาพการพยาบาล (University Hospital Nursing Director Consortium; UHNDC) ตามเอกสารภาคผนวก 4. การคำนวณตัวชี้วัดนี้ ต้องการเอกสารผู้ป่วยทุกคนในหน่วยการรายงานในวันที่สำรวจ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 191', 'registered-2026.1', NULL, 'registered'),
    ('CG0104', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury (HAPI) rate', 'อัตราความชุกของแผลกดทับที่เกิดในโรงพยาบาล', '1. อัตราความชุกของแผลกดทับที่เกิดในโรงพยาบาล หมายถึง ตัวเลขที่แสดงจำนวน ผู้ป่วยที่มีแผลกดทับที่เกิดขึ้นในโรงพยาบาล ในช่วงเวลาที่สำรวจ 2. การนับจำนวนผู้ป่วยที่มีแผลกดทับที่เกิดภายหลัง admit ในประชากรที่สำรวจ ณ เวลาใดเวลาหนึ่งที่สำรวจ เป็นการวัดจำนวนผู้ป่วยที่เกิดแผลกดทับในโรงพยาบาล ณ วันที่มีการสำรวจ การนับจำนวนให้นับเฉพาะผู้ป่วยที่เกิดแผลกดทับใหม่หลังรับเข้า โรงพยาบาล 3. การคำนวณ HAPI rate จำเป็นต้องมีการทบทวนบันทีกผู้ป่วยที่มีแผลกดทับ ณ วันที่ admit ถ้าพบว่าบันทึกตอน admit ผู้ป่วยไม่มีแผลกดทับ แสดงว่าแผลที่พบเป็นแผลกด ทับที่เกิดในโรงพยาบาล 4. แผลกดทับ แบ่งตามระดับความรุนแรงเป็น 4 ระดับและ 2 ลักษณะ (ระดับความ รุนแรง 1-4, ไม่สามารถระบุระดับความลึกของเนื้อเยื่อที่โดนทำลายได้และการบาดเจ็บ เนื้อเยื่อชั้นลึก) คณะทำงานตัวชี้วัดแผลกดทับ ชมรมพยาบาลแผล ออสโตมี และควบคุม การขับถ่าย และชมรมเครือข่ายพัฒนาคุณภาพการพยาบาล (University Hospital Nursing Director Consortium; UHNDC) ตามเอกสารภาคผนวก 5. การคำนวณตัวชี้วัดนี้ ต้องการเอกสารผู้ป่วยทุกคนในหน่วยการรายงานในวันที่สำรวจ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'ipd_nurse_note', 'iptbedmove', 'ward']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 193', 'registered-2026.1', NULL, 'registered'),
    ('CI0101', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Sepsis: Percent of mortality', 'ร้อยละการเสียชีวิตของผู้ป่วยในจากภาวะติดเชื้อในกระแสโลหิต', '1. การเสียชีวิตของผู้ป่วยใน หมายถึง การเสียชีวิตของผู้ป่วยขณะที่เข้ารับการรักษาเป็น ผู้ป่วยใน โดยมีระยะเวลาการนอนพักรักษานานตั้งแต่ 4 ชั่วโมงขึ้นไป 2. ภาวะติดเชื้อในกระแสโลหิต หมายถึง ภาวะ Sepsis หรือการที่ผู้ป่วยมีอาการแสดงของ การอักเสบทั่วตัว (systemic inflammation) ร่วมกับพบเชื้อจากการตรวจเพาะเชื้อจาก เลือด หรือพบว่ามีการติดเชื้อที่ใดที่หนึ่งในร่างกาย (reference : surviving sepsis campaign 2012) ซึ่งมี Pdx หรือ Sdx หรือมีอาการแสดงตามรหัสโรค ICD-10 TM ที่ กำหนด', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 199', 'registered-2026.1', NULL, 'registered'),
    ('CM0101', 'C', 'rate', 'lower-is-better', 'annual', 'Care process', 'Maternal: Mortality rate of mother from pregnancy and/or labour', 'สัดส่วนการตายของมารดาจากการตั้งครรภ์ และ/หรือการคลอด (ต่อแสนทารกเกิดมีชีพ)', '1. มารดา หมายถึง หญิงตั้งครรภ์ ซึ่งคลอดทารกมีชีพในโรงพยาบาล ที่มี Principal diagnosis (Pdx) or Secondary diagnosis (sdx) เป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยใน หมายถึง ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป 3. การตายมารดา หมายถึง การตายของมารดาตั้งแต่ขณะตั้งครรภ์ การคลอด และหลัง คลอด (ไม่เกิน 6 สัปดาห์หลังคลอด) ไม่ว่าอายุครรภ์จะเป็นเท่าใด หรือการตั้งครรภ์ที่ ตำแหน่งใด จากสาเหตุที่เกี่ยวข้องหรือก่อให้เกิดความรุนแรงขึ้นจากการตั้งครรภ์ และ/ หรือ การดูแลรักษาขณะตั้งครรภ์ และคลอด แต่ไม่ใช่จากอุบัติเหตุหรือสาเหตุที่ไม่เกี่ยวข้อง', '(a/b) x 100,000', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 161', 'registered-2026.1', NULL, 'registered'),
    ('CM0104', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Percent of unplanned re-admission of caesarean section within 28 days', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้คลอด Caesarean section ภายใน 28 วัน โดย ไม่ได้วางแผน', '1. ผู้คลอด Caesarean section หมายถึง หญิงตั้งครรภ์ที่มี Principal diagnosis (Pdx) or Secondary diagnosis (Sdx) ของการคลอดที่มีเหตุจำเป็นต้องผ่าตัดคลอดทางหน้าท้อง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10และ/หรือ ICD-9 ดังที่ระบุไว้นี้ 2. การรับกลับเข้าโรงพยาบาลของผู้คลอด Caesarean section ภายใน 28 วัน โดยไม่ได้ วางแผนหลังจำหน่ายจากโรงพยาบาล ด้วยสถานะการอนุญาตให้กลับบ้าน (status=improve) (ยกเว้นผู้คลอด C/S ที่ไปรักษาที่โรงพยาบาลอื่น หรือไม่ยินยอมรับการ รักษาตามแผน)', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 162', 'registered-2026.1', NULL, 'registered'),
    ('CM0105', 'C', 'ratio', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Average length of stay of caesarean section', 'ระยะเวลาวันนอนเฉลี่ยของผู้คลอดโดยการผ่าตัดคลอดทางหน้าท้อง', '1. ผู้ป่วยที่ทำ Caesarean section หมายถึง ผู้ป่วยที่มี Principal diagnosis (Pdx) or Secondary diagnosis (Sdx) ของการทำ Caesarean section โดยมีรหัสโรคตาม ICD-10 TM, ICD-10 และ/ หรือ ICD-9 ดังที่ระบุไว้นี้ 2. จำนวนวันนอนรวมหมายถึง ผลรวมของจำนวนวัน ที่ผู้ป่วยที่ทำ Caesarean section นอนพักรักษาตัวในโรงพยาบาล นับตั้งแต่วันที่รับไว้ในโรงพยาบาล จนถึงวันที่จำหน่ายออก จากโรงพยาบาล ทุกสถานะการจำหน่าย', 'a/b', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 163', 'registered-2026.1', NULL, 'registered'),
    ('CM0107', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Percent of immediate postpartum hemorrhage (Vaginal delivery)', 'ร้อยละการตกเลือดหลังคลอดเฉียบพลันกรณีคลอดทางช่องคลอด', '1. ตกเลือดหลังคลอดเฉียบพลัน หมายถึง สตรีตั้งครรภ์ที่มีการเสียเลือดมากกว่าหรือเท่ากับ 500 มิลลิลิตร ภายใน 2 ชั่วโมง ภายหลังการคลอดทางช่องคลอดด้วยวิธีวัดเชิงวัตถุวิสัย 2. การคำนวณหาอัตราตกเลือดหลังคลอดเฉียบพลัน เป็นการคิดเทียบต่อจำนวนหญิง ตั้งครรภ์คลอดอายุครรภ์ 28 สัปดาห์ขึ้นไปทั้งหมดที่มาคลอดทางช่องคลอดในโรงพยาบาล ช่วงระยะเวลาที่ประเมิน', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 164', 'registered-2026.1', NULL, 'registered'),
    ('CM0109', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Percent of eclampsia in pregnancy induce Hypertension', 'ร้อยละการชักขณะตั้งครรภ์ คลอดหรือหลังคลอด', '1. หญิงตั้งครรภ์ที่มีภาวะชัก หมายถึง หญิงตั้งครรภ์ที่รับไว้รักษาเป็นผู้ป่วยในด้วยปัญหา การชักขณะตั้งครรภ์ คลอดหรือหลังคลอดเนื่องจากครรภ์เป็นพิษ ที่มี Principal diagnosis (Pdx) or Secondary diagnosis (Sdx) อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10 และ/ หรือ ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยใน หมายถึง ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป 3. การคำนวณหาอัตราหญิงตั้งครรภ์ เป็นการคิดเทียบต่อจำนวนหญิงตั้งครรภ์ คลอด หรือหลังคลอด ที่รับไว้รักษาในโรงพยาบาลทั้งหมดในช่วงระยะเวลาที่ประเมิน', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 165', 'registered-2026.1', NULL, 'registered'),
    ('CM0110', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Percent of gestational DM', 'อัตราหญิงตั้งครรภ์ที่มีภาวะเบาหวาน', '1. หญิงตั้งครรภ์ที่มีภาวะเบาหวาน หมายถึง หญิงตั้งครรภ์ที่รับไว้รักษาเป็นผู้ป่วยในด้วย ปัญหาภาวะเบาหวาน ที่มี Principal diagnosis (Pdx) or Secondary diagnosis (Sdx) โดยมีรหัสโรคอยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10 และ/หรือ ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยใน หมายถึง ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาลนานตั้งแต่ 4 ชั่วโมงขึ้นไป 3. การคำนวณหาอัตราหญิงตั้งครรภ์ เป็นการคิดเทียบต่อจำนวนหญิงตั้งครรภ์ คลอด หรือ หลังคลอด ที่รับไว้รักษาในโรงพยาบาลทั้งหมดในช่วงระยะเวลาที่ประเมิน', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 166', 'registered-2026.1', NULL, 'registered'),
    ('CM0116', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'hysterectomy Maternal: Percent of patients who received antibiotic prophylaxis in abdominal hysterectomy', 'ร้อยละการได้รับ prophylactic antibiotic ในการผ่าตัด abdominal hysterectomy', '1. ผู้ป่วยที่ผ่าตัด Abdominal hysterectomy หมายถึง ผู้ป่วยในที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับมดลูกซึ่งจำเป็นต้องให้การรักษาโดยการผ่าตัดเอามดลูกออกโดยมี รหัสโรคอยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับยาปฏิชีวนะแบบป้องกันในการผ่าตัด Abdominal hysterectomy หมายถึง การที่ผู้ป่วยได้รับยาปฏิชีวนะในช่วงระยะเวลาภายใน 1 ชั่วโมงก่อนลงมีดผ่าตัด (กรณีเป็น การให้ยาแบบ IV drip ให้เริ่มนับเวลาเมื่อ drip ยาหมด)', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 167', 'registered-2026.1', NULL, 'registered'),
    ('CM0117', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Percent of abdominal hysterectomy associated infection', 'ร้อยละการติดเชื้อแผลผ่าตัด Abdominal hysterectomy', '1. ผู้ป่วยผ่าตัด Abdominal hysterectomy หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและ ผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับมดลูก ซึ่งจำเป็นต้องให้การรักษา โดยการผ่าตัดเอามดลูกออก โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การติดเชื้อแผลผ่าตัด Abdominal hysterectomy หมายถึง เฉพาะการติดเชื้อครั้งแรก ของแผลผ่าตัด Abdominal hysterectomy ภายในช่วงระยะเวลา 30 วันหลังการผ่าตัด', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 168', 'registered-2026.1', NULL, 'registered'),
    ('CM0118', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Percent of primary cesarean section', 'ร้อยละการผ่าตัดคลอดบุตรปฐมภูมิของโรงพยาบาล', '1) การผ่าตัดคลอดคลอดบุตรปฐมภูมิของโรงพยาบาล (primary cesarean section) หมายถึงการผ่าตัด คลอดบุตรทางหน้าท้องเป็นครั้งแรกของหญิงตั้งครรภ์ที่มี Principal diagnosis (Pdx) หรือSecondary diagnosis (Sdx) ของการคลอดครรภ์เดี่ยวโดยการผ่าท้อง (single delivery by cesarean section) หรือ การคลอดครรภ์แฝดทารกทุกคนคลอดโดยการผ่าท้อง (multiple delivery/all by cesarean section) ทุกสิทธิการรักษาโดยมีรหัสโรคและรหัสหัตถการตามICD-10 TM, ICD-10 และ/หรือICD-9 ตามที่ระบุ ไว้นี้ 2) การคำนวณหาร้อยละการผ่าตัดคลอดบุตรปฐมภูมิของโรงพยาบาล เป็นการคิดจำนวนหญิง ตั้งครรภ์ที่คลอดบุตรในโรงพยาบาลด้วยวิธีการผ่าตัดคลอดครั้งแรกทุกสิทธิการรักษาและ จำหน่ายในเดือนนั้น คิดเทียบต่อจำนวนหญิงตั้งครรภ์ที่คลอดบุตรในโรงพยาบาลที่ไม่มีประวัติการ ผ่าตัดคลอดบุตรทางหน้าท้อง (previous cesarean section) ทั้งหมดในเดือนเดียวกัน', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 169', 'registered-2026.1', NULL, 'registered'),
    ('CM0119', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Maternal: Percent of cesarean section with Pdx = O80-O84 and Sdx = O80-O84 (NHSO health service indicator)', 'ร้อยละการผ่าตัดคลอดบุตรทั้งหมดของโรงพยาบาล', '1) การผ่าตัดคลอดคลอดบุตรทั้งหมดของโรงพยาบาล (overall cesarean section) หมายถึงการ ผ่าตัดคลอดบุตรทางหน้าท้องของหญิงตั้งครรภ์ที่มี Principal diagnosis (Pdx) หรือSecondary diagnosis (Sdx) ของการคลอดครรภ์เดี่ยวโดยการผ่าท้อง (single delivery by cesarean section) หรือการคลอดครรภ์แฝดทารกทุกคนคลอดโดยการผ่าท้อง (multiple delivery/all by cesarean section) ทุกสิทธิการรักษาโดยมีรหัสโรคและรหัสหัตถการตามICD-10 TM, ICD-10 และ/หรือICD-9 ตามที่ระบุไว้นี้ 2) การคำนวณหาร้อยละการผ่าตัดคลอดบุตรทั้งหมดของโรงพยาบาลเป็นการคิดจำนวนหญิง ตั้งครรภ์ที่คลอดบุตรในโรงพยาบาลด้วยวิธีการผ่าตัดคลอดทุกสิทธิการรักษาและจำหน่ายในเดือน นั้นคิดเทียบต่อจำนวนหญิงตั้งครรภ์ที่คลอดบุตรในโรงพยาบาลทั้งหมดในเดือนเดียวกัน', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 170', 'registered-2026.1', NULL, 'registered'),
    ('CM0201', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Child: Perinatal mortality rate (24 weeks)', 'อัตราการตายปริกำเนิด (อายุครรภ์ตั้งแต่ 24 สัปดาห์)', '1. การตายปริกำเนิด หมายถึง การตายของทารกในครรภ์ น้ำหนักตั้งแต่ 500 กรัมขึ้นไป หรืออายุครรภ์ 24 สัปดาห์ หากไม่มีข้อมูลน้ำหนัก (still birth) และการตายของทารกแรก เกิดภายใน 7 วันหลังคลอด 2. การเก็บข้อมูลการตายปริกำเนิด ให้นับเฉพาะการตายปริกำเนิดที่เกิดจากการคลอด(ทั้งที่ คลอดมีชีวิตและไม่มีชีวิต) ขณะมา หรือขณะอยู่ในโรงพยาบาล โดยไม่นับรวมทารกซึ่งส่ง ต่อมาจากโรงพยาบาลอื่น ทั้งนี้ในกรณีที่มีการส่งต่อทารกไปยังโรงพยาบาลอื่นและทารก ตายภายใน 7 วันหลังคลอด ให้นับรวมเป็นการตายปริกำเนิดของโรงพยาบาลผู้ส่งต่อทารก (โดย รพ. ผู้ส่งต่อ ต้องติดตามผลการมีชีวิตรอดของทารกเมื่อครบกำหนด 7 วันหลังคลอด) 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 1,000', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 171', 'registered-2026.1', NULL, 'registered'),
    ('CM0202', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Child: Perinatal mortality rate (28 weeks)', 'อัตราการตายปริกำเนิด (อายุครรภ์ตั้งแต่ 28 สัปดาห์)', '1. การตายปริกำเนิด (ตามนิยามของ WHO สำหรับกลุ่มประเทศกำลังพัฒนา) หมายถึง การเสียชีวิตของทารกที่คลอดตั้งแต่อายุครรภ์ตั้งแต่ 28 สัปดาห์ และมีน้ำหนักแรกเกิดอย่าง น้อย 1,000 กรัม ตั้งแต่แรกคลอดจนถึงอายุ 7 วันหลังคลอด 2. การเก็บข้อมูลการตายปริกำเนิด ให้นับเฉพาะการตายปริกำเนิดที่เกิดจากการคลอด(ทั้งที่ คลอดมีชีวิตและไม่มีชีวิต)ขณะมาโรงพยาบาล หรือขณะอยู่ในโรงพยาบาล โดยไม่นับรวม ทารกซึ่งส่งต่อมาจากโรงพยาบาลอื่น ทั้งนี้ในกรณีที่มีการส่งต่อทารกไปยังโรงพยาบาลอื่น และทารกตายภายใน 7 วันหลังคลอด ให้นับรวมเป็นการตายปริกำเนิดของโรงพยาบาลผู้ส่ง ต่อทารก (โดยโรงพยาบาลผู้ส่งต่อ ต้องติดตามผลการมีชีวิตรอดของทารกเมื่อครบกำหนด 7 วันหลังคลอด) 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 1,000', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 172', 'registered-2026.1', NULL, 'registered'),
    ('CM0203', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Child: Neonatal mortality rate', 'อัตราการตายของทารกแรกเกิด', '1. การตายของทารกแรกเกิด หมายถึง การเสียชีวิตของทารกแรกเกิดมีชีวิต ภายใน 28 วัน หลังการคลอด (นับรวมทารกเกิดมีชีวิตที่ตายปริกำเนิดด้วย) 2. ทารกแรกเกิด หมายถึง ทารกที่เกิดจากการคลอดมีชีวิตของหญิงตั้งครรภ์ที่คลอดขณะมา โรงพยาบาล หรือขณะอยู่ในโรงพยาบาล โดยไม่นับรวมทารกซึ่งส่งต่อมาจากโรงพยาบาลอื่น ทั้งนี้ในกรณีที่มีการส่งต่อทารกไปยังโรงพยาบาลอื่น และทารกตายภายใน 28 วันหลังคลอด ให้นับรวมเป็นการตายของทารกแรกเกิดของโรงพยาบาลผู้ส่งต่อทารก (โดยโรงพยาบาลผู้ส่ง ต่อ ต้องติดตามผลการมีชีวิตรอดของทารกเมื่อครบกำหนด 28 วันหลังคลอด) 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 1,000', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 173', 'registered-2026.1', NULL, 'registered'),
    ('CM0204', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Child: Birth asphyxia rate', 'อัตราการขาดออกซิเจนในทารกแรกเกิด', '1. ทารกแรกเกิด หมายถึง ทารกแรกเกิดมีชีพในโรงพยาบาล จากหญิงตั้งครรภ์ที่มีอายุ ครรภ์ตั้งแต่ 28 สัปดาห์ขึ้นไป 2. การขาดออกซิเจนในทารกแรกเกิดหมายถึงการที่ทารกแรกเกิดมีชีพ มีค่าคะแนน APGAR SCORE ที่ 1 นาที ≤7 โดยมีรหัสโรคตาม ICD-10 TM, ICD-9 และ DRG ดังที่ระบุ ไว้นี้ 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 1,000', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 174', 'registered-2026.1', NULL, 'registered'),
    ('CM0205', 'C', 'rate', 'lower-is-better', 'monthly', 'Care process', 'Child: Severe birth asphyxia rate', 'อัตราการขาดออกซิเจนรุนแรงในทารกแรกเกิด', '1. ทารกแรกเกิด หมายถึง ทารกแรกเกิดมีชีพในโรงพยาบาล จากหญิงตั้งครรภ์ที่มีอายุ ครรภ์ตั้งแต่ 28 สัปดาห์ขึ้นไปและกรณีที่ไม่ทราบอายุครรภ์ ใช้น้ำหนัก 1,000 กรัมขึ้นไป 2. การขาดออกซิเจนในทารกแรกเกิดหมายถึง การที่ทารกแรกเกิดมีชีพ มีค่าคะแนน APGAR SCORE ที่ 5 นาที ≤ 4 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 1,000', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 175', 'registered-2026.1', NULL, 'registered'),
    ('CM0206', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Child: Percent of low birth weight < 2500 grams', 'ร้อยละทารกแรกเกิดน้ำหนักต่ำกว่า 2,500 กรัม', '1. ทารกแรกเกิด หมายถึง ทารกแรกเกิดมีชีพในโรงพยาบาล 2. Low birth weight หมายถึง มีน้ำหนักแรกเกิดต่ำกว่า 2,500 กรัม 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 176', 'registered-2026.1', NULL, 'registered'),
    ('CM0207', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days', 'ร้อยละการเสียชีวิตในโรงพยาบาลของทารกแรกเกิดน้ำหนักต่ำกว่า 1,000 กรัมภายใน 28 วัน', '1. การเสียชีวิตของทารกแรกเกิดน้ำหนักต่ำกว่า 1,000 กรัม หมายถึง การเสียชีวิตของ ทารกแรกเกิดมีชีพในโรงพยาบาลจากหญิงตั้งครรภ์ที่มีอายุครรภ์ตั้งแต่ 28 สัปดาห์ขึ้นไป (ตามนิยามของ WHO สำหรับกลุ่มประเทศกำลังพัฒนา) มีน้ำหนักแรกเกิดต่ำกว่า 1,000 กรัม ภายใน 28 วันหลังคลอด 2. ทารกแรกเกิดมีชีพ หมายถึง ทารกที่เกิดจากการคลอดของหญิงตั้งครรภ์ที่คลอดขณะมา โรงพยาบาล หรือขณะอยู่ในโรงพยาบาล โดยไม่นับรวมทารกซึ่งส่งต่อมาจากโรงพยาบาลอื่น 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 177', 'registered-2026.1', NULL, 'registered'),
    ('CM0208', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days', 'ร้อยละการเสียชีวิตในโรงพยาบาลของทารกแรกเกิดน้ำหนัก 1,000-1,499 กรัม ภายใน 28 วัน', '1. การเสียชีวิตของทารกแรกเกิดน้ำหนัก 1,000-1,499 กรัม หมายถึง การเสียชีวิตของ ทารกแรกเกิดมีชีพในโรงพยาบาลจากหญิงตั้งครรภ์ที่มีอายุครรภ์ตั้งแต่ 28 สัปดาห์ขึ้นไป (ตามนิยามของ WHO สำหรับกลุ่มประเทศกำลังพัฒนา) มีน้ำหนักแรกเกิด 1,000-1,499 กรัม ภายใน 28 วันหลังคลอด 2. ทารกแรกเกิดมีชีพ หมายถึง ทารกที่เกิดจากการคลอดของหญิงตั้งครรภ์ที่คลอดขณะมา หรือขณะอยู่ในโรงพยาบาล โดยไม่นับรวมทารกซึ่งส่งต่อมาจากโรงพยาบาลอื่น 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 178', 'registered-2026.1', NULL, 'registered'),
    ('CM0209', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days', 'ร้อยละการเสียชีวิตในโรงพยาบาลของทารกแรกเกิดน้ำหนัก 1,500 - 2,499 กรัมภายใน 28 วัน', '1. การเสียชีวิตของทารกแรกเกิดน้ำหนัก 1,500-2,499 กรัม หมายถึง การเสียชีวิตของ ทารกแรกเกิดมีชีพในโรงพยาบาลจากหญิงตั้งครรภ์ที่มีอายุครรภ์ตั้งแต่ 28 สัปดาห์ขึ้นไป (ตามนิยามของ WHO สำหรับกลุ่มประเทศกำลังพัฒนา) มีน้ำหนักแรกเกิด 1,500-2,499 กรัม ภายใน 28 วันหลังคลอด 2. ทารกแรกเกิดมีชีพ หมายถึง ทารกที่เกิดจากการคลอดของหญิงตั้งครรภ์ที่คลอดขณะมา โรงพยาบาลหรือขณะอยู่ในโรงพยาบาล โดยไม่นับรวมทารกซึ่งส่งต่อมาจากโรงพยาบาลอื่น 3. การคลอดของหญิงตั้งครรภ์ หมายถึง การคลอดโดยวิธีการทุกประเภทของการคลอด', '(a/b) x 100', 'a', 'b', ARRAY['person_anc', 'person_wbc', 'labor', 'ipt_pregnancy', 'ipt_newborn', 'ipt_labour_infant', 'ipt_labour_child']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 179', 'registered-2026.1', NULL, 'registered'),
    ('CO0101', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Operation: Percent of using surgical safety check list', 'ร้อยละของการใช้แบบตรวจสอบเพื่อความปลอดภัยของผู้ป่วยเมื่อมารับการตรวจรักษา ในห้องผ่าตัด', '1. แบบตรวจสอบเพื่อความปลอดภัยของผู้ป่วยเมื่อมารับการตรวจรักษาในห้องผ่าตัด (surgical safety check list) สามารถใช้ได้ตามบริบทของแต่ละโรงพยาบาล ซึ่งมีการ ออกแบบเอง 2. ให้ใช้ surgical safety check list กับผู้ป่วยที่ได้รับการทำหัตถการทุกหัตถการ (ราย ครั้ง) ที่ทำในห้องผ่าตัด (กรณีมีหลายห้องผ่าตัด ให้รวมทุกห้องผ่าตัด) โดยนับรวมทั้งใน หัตถการที่ดมยาและไม่ดมยา 3. การทำแบบตรวจสอบฯ อย่างสมบูรณ์ หมายถึง ได้ทำตามกระบวนการอย่างถูกต้อง โดย ทำครบทุกขั้นตอนในแต่ละ part (sign in, time out, sign out)', '(a/b) x 100', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'operation_item', 'iptoprt', 'ipt', 'an_stat']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 185', 'registered-2026.1', NULL, 'registered'),
    ('CO0105', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Operation: Percent of peri-operative mortality within 24 hours', 'ร้อยละการเสียชีวิตของผู้ป่วยผ่าตัดใน 24 ชั่วโมง', '1. การผ่าตัด หมายถึง การผ่าตัดใหญ่ (major operation) ที่มีการให้ยาระงับความรู้สึก และเป็นการผ่าตัดแบบไม่ฉุกเฉิน ซึ่งมีระยะเวลาในการเตรียมผู้ป่วยอย่างน้อย 24 ชั่วโมง 2. ผู้ป่วยผ่าตัด หมายถึง ผู้ป่วยใน และ/หรือผู้ป่วยซึ่งมีนัดรับเข้านอนในโรงพยาบาล เพื่อ เตรียมผ่าตัด 3. การเสียชีวิตของผู้ป่วยผ่าตัด หมายถึง การเสียชีวิตของผู้ป่วยที่อยู่ในช่วงระยะเวลา ระหว่างกระบวนการดมยาก่อนผ่าตัด การผ่าตัด และหลังผ่าตัดภายใน 24 ชั่วโมง', '(a/b) x 100', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'operation_item', 'iptoprt', 'ipt', 'an_stat']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 186', 'registered-2026.1', NULL, 'registered'),
    ('CO0107', 'C', 'percent', 'lower-is-better', 'monthly', 'Care process', 'Operation: Percent of re-operation', 'ร้อยละการผ่าตัดซ้ำ', '1. การผ่าตัดซ้ำ (กรณีผู้ป่วยใน) หมายถึง การผ่าตัดซ้ำด้วยโรคเดียวกันตั้งแต่ 1 ครั้งขึ้นไปใน การรับไว้เป็นผู้ป่วยในของโรงพยาบาลในครั้งเดียวกันโดยไม่ได้วางแผน หรือ เป็นการผ่าตัด ซ้ำในผู้ป่วยที่มีการผ่าตัดครั้งแรกซึ่งเป็นการผ่าตัดฉุกเฉิน ทั้งนี้ไม่รวมถึงการผ่าตัดที่มีการ วางแผนไว้ล่วงหน้าว่าจะมีการผ่าตัดแยกเป็นหลายครั้งเป็นการผ่าตัดทีละส่วน 2. การผ่าตัดซ้ำ (กรณีผู้ป่วยนอกที่ต้อง admit โดยไม่ได้วางแผน) หมายถึง การผ่าตัดผู้ป่วย นอกที่นำไปสู่การรับเข้าเป็นผู้ป่วยในทันทีหลังผ่าตัด ทั้งนี้ไม่รวมถึงการผ่าตัดในกรณีผู้ป่วย นอกที่ให้ผู้ป่วยกลับบ้าน หรือสังเกตอาการไม่เกิน 48 ชั่วโมง', '(a/b) x 100', 'a', 'b', ARRAY['operation_list', 'operation_detail', 'operation_item', 'iptoprt', 'ipt', 'an_stat']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 187', 'registered-2026.1', NULL, 'registered'),
    ('CP0101', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Percent of carers of children with ADHD/LD/MDD having good compliance to treatment', 'ร้อยละผู้ปกครองของเด็กสมาธิสั้น/LD/MDD รายใหม่ที่มารับการบำบัดรักษาในรอบ 6 เดือน และมารับการรักษาตามนัด', '1. มารับการบำบัดรักษาตามนัด หมายถึง ผู้ปกครองมาตามวันที่นัด หรือ มาในวันอื่นที่มี การแจ้งเลื่อนนัดในระบบนัด หรือจำนวนผู้ปกครองที่มาตามระบบนัด 2. ผู้ปกครอง หมายถึง ผู้ปกครองของเด็กที่มารับบริการคลินิกพัฒนาการหรือคลินิกจิตเวช เด็กและวัยรุ่น', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 200', 'registered-2026.1', NULL, 'registered'),
    ('CP0201', 'C', 'percent', 'higher-is-better', 'monthly', 'Care process', 'Percent of children with Neurodevelopmental Disorder being diagnosed within 90 days after registration', 'ร้อยละเด็กที่สงสัยโรคในกลุ่มพัฒนาการได้รับการวินิจฉัยภายใน 90 วัน', '1. เด็กที่สงสัยโรคกลุ่มพัฒนาการ หมายถึง เด็กที่มีพัฒนาการล่าช้าด้านใดด้านหนึ่งหรือ หลายด้านร่วมกันที่ยังไม่เคยได้รับการวินิจฉัยและเข้าสู่ระบบบริการในคลินิกพัฒนาการหรือ คลินิกจิตเวชเด็กและวัยรุ่น 2. ได้รับการวินิจฉัยภายใน 90 วัน หมายถึง ได้รับการวินิจฉัยจากแพทย์ภายใน 90 วันนับ จากการมารับบริการครั้งแรก', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 201', 'registered-2026.1', NULL, 'registered'),
    ('DC0103', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'DM: Percent of diabetic retinopathy screening', 'ร้อยละของผู้ป่วยเบาหวานได้รับการคัดกรองเบาหวานเข้าจอประสาทตา', '1. ผู้ป่วยเบาหวาน หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยในและผู้ป่วยนอก ที่ได้รับการ วินิจฉัยโรคเบาหวาน และเป็นผู้ป่วยที่ขึ้นทะเบียนรับการรักษากับโรงพยาบาลซึ่งมารับการ ตรวจติดตามในคลินิก ≥ 2 ครั้งใน 6 เดือน หรือ ≥ 3 ครั้งใน 1 ปี โดยเป็นโรคที่มีรหัสโรค ตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การคัดกรองเบาหวานเข้าจอประสาทตา หมายถึง ผู้ป่วยเบาหวานที่มารับบริการที่ โรงพยาบาลได้รับการตรวจจอประสาทตาอย่างละเอียด โดยจักษุแพทย์ หรือคัดกรองด้วย Fundus Camera อย่างน้อย ปีละ 1ครั้ง', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 92', 'registered-2026.1', NULL, 'registered'),
    ('DC0107', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'DM: Percent of lower-extremity amputation among patients with diabetes', 'ร้อยละผู้ป่วยเบาหวานได้รับการตัดขาจากภาวะแทรกซ้อนของโรคเบาหวาน', '1. ผู้ป่วยเบาหวาน หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยในและผู้ป่วยนอก อายุ 15 ปีขึ้นไป ที่ มี Principal diagnosis (pdx) เป็นโรคเบาหวาน และเป็นผู้ป่วยที่ขึ้นทะเบียนรับการรักษา กับโรงพยาบาลซึ่งมารับการตรวจติดตามในคลินิก ≥ 2 ครั้งใน 6 เดือน หรือ ≥ 3 ครั้งใน 1 ปี โดยเป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การตัดขาจากภาวะแทรกซ้อน หมายถึง การที่ผู้ป่วยเบาหวานไม่สามารถควบคุมระดับ น้ำตาลให้อยู่ในเกณฑ์ได้จนเกิดภาวะแทรกซ้อนที่เท้าซึ่งจำเป็นต้องให้การรักษาโดยการตัดขา 3. ผู้ป่วยเบาหวานที่ได้รับการตัดขา หมายถึง ผู้ป่วยเบาหวานที่ขึ้นทะเบียนรับการรักษาของ โรงพยาบาลซึ่งมีภาวะแทรกซ้อนจนจำเป็นต้องตัดขา โดยนับรวมทั้งรายที่ผ่าตัดเองและราย ที่ส่งไปเพื่อรับการผ่าตัดที่ รพ.อื่น (กรณี ผู้ป่วยที่ได้รับการส่งต่อเพื่อทำการผ่าตัด ให้นับเป็น ยอดผู้ป่วยเบาหวานที่ได้รับการตัดขา ของโรงพยาบาล ผู้ส่ง Refer โดยไม่นับเป็นยอดของ โรงพยาบาล ผู้รับ Refer มาเพื่อทำการผ่าตัด)', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 93', 'registered-2026.1', NULL, 'registered'),
    ('DC0108', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'DM: Percent of good controlled of blood sugar in adult', 'ร้อยละของผู้ป่วยเบาหวานผู้ใหญ่ที่ควบคุมระดับน้ำตาลในเลือดได้ดี', '1. ผู้ป่วยเบาหวานผู้ใหญ่ หมายถึง ผู้ป่วยอายุ ≥ 18 ปี ในสถานะผู้ป่วยนอกที่ได้รับการ วินิจฉัยโรคเบาหวาน และเป็นผู้ป่วยที่ขึ้นทะเบียนรับการรักษากับโรงพยาบาล ซึ่งมารับการ ตรวจติดตามต่อเนื่องในโรงพยาบาลหรือเครือข่ายสถานพยาบาล ≥ 2 ครั้งในระยะช่วงเวลา 6 เดือน หรือ ≥ 3 ครั้งในรอบ 1 ปีที่ผ่านมา โดยเป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD- 10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยเบาหวานผู้ใหญ่ที่ควบคุมระดับน้ำตาลในเลือดได้ดี หมายถึงผู้ป่วยเบาหวานผู้ใหญ่ที่มีระดับ ผลการตรวจHbA1c อยู่ในระดับที่ควบคุมได้ตามกลุ่มอายุ ในช่วงเวลาที่ประเมินดังนี้ 2.1 ผู้ป่วยเบาหวานผู้ใหญ่ อายุ < 60 ปี: มีค่าระดับHbA1c ครั้งล่าสุดภายใน6 ดือน≤ 7 mg% 2.2 ผู้ป่วยเบาหวานผู้ใหญ่ อายุ ≥ 60 ปี: มีค่าระดับ HbA1c ครั้งล่าสุด ≤ 8 mg% 3. ตัวชี้วัดนี้มีวัตถุประสงค์เพื่อส่งเสริมคุณภาพการติดตามระดับน้ำตาลในเลือดตาม มาตรฐานโดยใช้ HbA1c ผ่านกลไกการเทียบเคียงตัวชี้วัด โดยแนะนำให้ตรวจอย่างน้อยปี ละ 2 ครั้ง หากไม่มีผลการตรวจ HbA1c ครั้งล่าสุดในช่วงเวลา 6 เดือนที่ประเมินติดตาม ให้ ยังคงนับผู้ป่วยรายที่ไม่ปรากฏผลการตรวจ HbA1c รวมอยู่ในตัวหาร และแปลผลตัวตั้งที่ไม่ ปรากฎผลตรวจเป็นผู้ป่วยเบาหวานผู้ใหญ่ที่ควบคุมระดับน้ำตาลได้ไม่ดี', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 94', 'registered-2026.1', NULL, 'registered'),
    ('DC0108.1', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'DM: Percent of good controlled of blood sugar in adult aged ≥ 60 years old', 'ร้อยละของผู้ป่วยเบาหวานผู้ใหญ่อายุเกินกว่า 60 ปี ที่ควบคุมระดับน้ำตาลในเลือดได้ดี', '1. ผู้ป่วยเบาหวานผู้ใหญ่อายุเกินกว่า 60 ปี หมายถึง ผู้ป่วยผู้ใหญ่อายุ ≥ 60 ปี ในสถานะ ผู้ป่วยนอกที่ได้รับการวินิจฉัยโรคเบาหวาน และเป็นผู้ป่วยที่ขึ้นทะเบียนรับการรักษากับ โรงพยาบาล ซึ่งมารับการตรวจติดตามต่อเนื่องในโรงพยาบาลหรือเครือข่ายสถานพยาบาล ≥ 2 ครั้งในระยะช่วงเวลา 6 เดือน หรือ ≥ 3 ครั้งในรอบ 1 ปีที่ผ่านมา โดยเป็นโรคที่มีรหัส โรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยเบาหวานผู้ใหญ่อายุเกินกว่า 60 ปี ที่ควบคุมระดับน้ำตาลในเลือดได้ดี หมายถึง ผู้ป่วยเบาหวานผู้ใหญ่ อายุ ≥ 60 ปี ที่มีระดับผลการตรวจ HbA1c ครั้งล่าสุดภายใน 6 เดือน ≤ 8 mg% 3. ตัวชี้วัดนี้มีวัตถุประสงค์เพื่อส่งเสริมคุณภาพการติดตามระดับน้ำตาลในเลือดตาม มาตรฐานโดยใช้ HbA1c ผ่านกลไกการเทียบเคียงตัวชี้วัด โดยแนะนำให้ตรวจอย่างน้อยปี ละ 2 ครั้ง หากไม่มีผลการตรวจ HbA1c ครั้งล่าสุดในช่วงเวลา 6 เดือนที่ประเมินติดตาม ให้ ยังคงนับผู้ป่วยรายที่ไม่ปรากฏผลการตรวจ HbA1c รวมอยู่ในตัวหาร และแปลผลตัวตั้งที่ไม่ ปรากฎผลตรวจเป็นผู้ป่วยเบาหวานผู้ใหญ่ที่ควบคุมระดับน้ำตาลได้ไม่ดี', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 95', 'registered-2026.1', NULL, 'registered'),
    ('DC0108.2', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'DM: Percent of good controlled of blood sugar in adult aged < 60 years old', 'ร้อยละของผู้ป่วยเบาหวานผู้ใหญ่อายุน้อยกว่า 60 ปี ที่ควบคุมระดับน้ำตาลในเลือดได้ดี', '1. ผู้ป่วยเบาหวานผู้ใหญ่อายุน้อยกว่า 60 ปี หมายถึง ผู้ป่วยผู้ใหญ่อายุเกินกว่า 18 ปี แต่ น้อยกว่า 60 ปี ในสถานะผู้ป่วยนอกที่ได้รับการวินิจฉัยโรคเบาหวาน และเป็นผู้ป่วยที่ขึ้น ทะเบียนรับการรักษากับโรงพยาบาล ซึ่งมารับการตรวจติดตามต่อเนื่องในโรงพยาบาลหรือ เครือข่ายสถานพยาบาล ≥ 2 ครั้งในระยะช่วงเวลา 6 เดือน หรือ ≥ 3 ครั้งในรอบ 1 ปีที่ผ่าน มา โดยเป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยเบาหวานผู้ใหญ่อายุน้อยกว่า 60 ปี ที่ควบคุมระดับน้ำตาลในเลือดได้ดี หมายถึง ผู้ป่วยเบาหวานผู้ใหญ่อายุน้อยกว่า 60 ปี ที่มีระดับผลการตรวจ HbA1c ครั้งล่าสุดภายใน 6 เดือน ≤ 7 mg% 3. ตัวชี้วัดนี้มีวัตถุประสงค์เพื่อส่งเสริมคุณภาพการติดตามระดับน้ำตาลในเลือดตาม มาตรฐานโดยใช้ HbA1c ผ่านกลไกการเทียบเคียงตัวชี้วัด โดยแนะนำให้ตรวจอย่างน้อยปี ละ 2 ครั้ง หากไม่มีผลการตรวจ HbA1c ครั้งล่าสุดในช่วงเวลา 6 เดือนที่ประเมินติดตาม ให้ ยังคงนับผู้ป่วยรายที่ไม่ปรากฏผลการตรวจ HbA1c รวมอยู่ในตัวหาร และแปลผลตัวตั้งที่ไม่ ปรากฎผลตรวจเป็นผู้ป่วยเบาหวานผู้ใหญ่ที่ควบคุมระดับน้ำตาลได้ไม่ดี', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 96', 'registered-2026.1', NULL, 'registered'),
    ('DC0201', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'HT: Percent of good controlled of blood pressure', 'ร้อยละผู้ป่วยความดันโลหิตสูงที่ควบคุมความดันโลหิตได้ดี', '1. ผู้ป่วยความดันโลหิตสูง หมายถึง ผู้ป่วยอายุ ≥ 18 ปี ในสถานะผู้ป่วยนอกที่ได้รับการ วินิจฉัยโรคความดันโลหิตสูงทั้งที่เป็นโรคหลักหรือโรคร่วม และเป็นผู้ป่วยที่ขึ้นทะเบียนรับ การรักษากับโรงพยาบาล ซึ่งมารับการตรวจติดตามต่อเนื่องในโรงพยาบาลหรือเครือข่าย สถานพยาบาล ≥ 2 ครั้งในระยะช่วงเวลา 6 เดือน หรือ ≥ 3 ครั้งในรอบ 1 ปีที่ผ่านมา โดย เป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยความดันโลหิตสูงที่ควบคุมระดับความดันโลหิตได้ดี หมายถึง ผู้ป่วยโรคความดัน โลหิตสูงที่มีผลการตรวจวัดความดันโลหิตของผู้ป่วยจากการวัดที่สถานพยาบาล อยู่ในเกณฑ์ ควบคุมตามระดับความดันโลหิตเป้าหมายการรักษา ในช่วงเวลาที่ประเมิน ดังนี้ 2.1 ผู้ป่วยความดันโลหิตสูง อายุ < 65 ปี มีผลการวัดความดันโลหิต 2 ครั้งล่าสุดติดต่อกัน มีค่า ≤ 130/80 mmHg 2.2 ผู้ป่วยความดันโลหิตสูง อายุ ≥ 65 ปี มีผลการวัดความดันโลหิต 2 ครั้งล่าสุดติดต่อกัน มีค่า ≤ 140/80 mmHg', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 97', 'registered-2026.1', NULL, 'registered'),
    ('DC0201.1', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'HT: Percent of good controlled of blood pressure of patient aged < 65 years old', 'ร้อยละผู้ป่วยความดันโลหิตสูงอายุน้อยกว่า 65 ปี ที่ควบคุมความดันโลหิตได้ดี', '1. ผู้ป่วยความดันโลหิตสูงอายุน้อยกว่า 65 ปี หมายถึง ผู้ป่วยอายุ ≥ 18 ปี แต่ < 65 ปี ใน สถานะผู้ป่วยนอกที่ได้รับการวินิจฉัยโรคความดันโลหิตสูงทั้งที่เป็นโรคหลักหรือโรคร่วม และเป็นผู้ป่วยที่ขึ้นทะเบียนรับการรักษากับโรงพยาบาล ซึ่งมารับการตรวจติดตามต่อเนื่อง ในโรงพยาบาลหรือเครือข่ายสถานพยาบาล ≥ 2 ครั้งในระยะช่วงเวลา 6 เดือน หรือ ≥ 3 ครั้งในรอบ 1 ปีที่ผ่านมา โดยเป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ ระบุไว้นี้ 2. ผู้ป่วยความดันโลหิตสูงอายุน้อยกว่า 65 ปี ที่ควบคุมระดับความดันโลหิตได้ดี หมายถึง ผู้ป่วยโรคความดันโลหิตสูงที่มีผลการตรวจวัดความดันโลหิตของผู้ป่วยจากการวัดที่ สถานพยาบาล อยู่ในเกณฑ์ควบคุมตามระดับความดันโลหิตเป้าหมายการรักษา ในช่วงเวลา ที่ประเมิน ดังนี้ 2.1 ผู้ป่วยความดันโลหิตสูง อายุ < 65 ปี มีผลการวัดความดันโลหิต 2 ครั้งล่าสุดติดต่อกัน มีค่า ≤ 130/80 mmHg', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 99', 'registered-2026.1', NULL, 'registered'),
    ('DC0201.2', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'HT: Percent of good controlled of blood pressure of patient aged ≥ 65 years old', 'ร้อยละผู้ป่วยความดันโลหิตสูงอายุเกินกว่า 65 ปี ที่ควบคุมความดันโลหิตได้ดี', '1. ผู้ป่วยความดันโลหิตสูงอายุเกินกว่า 65 ปี หมายถึง ผู้ป่วยอายุ ≥ 65 ปี ในสถานะผู้ป่วย นอกที่ได้รับการวินิจฉัยโรคความดันโลหิตสูงทั้งที่เป็นโรคหลักหรือโรคร่วม และเป็นผู้ป่วยที่ ขึ้นทะเบียนรับการรักษากับโรงพยาบาล ซึ่งมารับการตรวจติดตามต่อเนื่องในโรงพยาบาล หรือเครือข่ายสถานพยาบาล ≥ 2 ครั้งในระยะช่วงเวลา 6 เดือน หรือ ≥ 3 ครั้งในรอบ 1 ปี ที่ผ่านมา โดยเป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยความดันโลหิตสูงอายุเกินกว่า 65 ปี ที่ควบคุมระดับความดันโลหิตได้ดี หมายถึง ผู้ป่วยโรคความดันโลหิตสูงที่มีผลการตรวจวัดความดันโลหิตของผู้ป่วยจากการวัดที่ สถานพยาบาล อยู่ในเกณฑ์ควบคุมตามระดับความดันโลหิตเป้าหมายการรักษา ในช่วงเวลา ที่ประเมิน ดังนี้ 2.1 ผู้ป่วยความดันโลหิตสูง อายุ ≥ 65 ปี มีผลการวัดความดันโลหิต 2 ครั้งล่าสุดติดต่อกัน มีค่า ≤ 140/80 mmHg', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 100', 'registered-2026.1', NULL, 'registered'),
    ('DC0301', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'HIV: Percent of people living with HIV with at least one test viral load (VL) after ARV treatment', 'ร้อยละของผู้ติดเชื้อเอชไอวีที่กินยาต้านไวรัส ได้รับการตรวจ Viral load (VL) อย่างน้อย 1 ครั้งต่อปี', '1. ผู้ป่วย/ผู้ติดเชื้อเอชไอวี หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นผู้ป่วย/ผู้ที่มีผลการตรวจวินิจฉัยโดยมีผลการตรวจเลือด ยืนยันแล้วว่า HIV positive โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วย/ผู้ติดเชื้อเอชไอวีที่กินยาต้านไวรัส หมายถึง ผู้ป่วย/ผู้ติดเชื้อเอชไอวีที่กินยาต้าน ไวรัสสูตรใดสูตรหนึ่งมานานมากกว่า 6 เดือน 3. ผู้ป่วย/ผู้ติดเชื้อเอชไอวีที่กินยาต้านไวรัส ได้รับการตรวจ VL หมายถึง ผู้ป่วย/ผู้ติดเชื้อ เอชไอวีที่ได้รับการรักษาด้วยยาต้านไวรัสสูตรใดสูตรหนึ่งมานานมากกว่า 6 เดือน ได้รับการ ตรวจเลือดหาค่าจำนวนเชื้อไวรัส อย่างน้อย 1 ครั้งต่อปี (โดยผู้ป่วย/ผู้ติดเชื้อเอชไอวีกลุ่มนี้ ควรได้รับการตรวจติดตาม VL ทุก 6-12เดือน)', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 101', 'registered-2026.1', NULL, 'registered'),
    ('DC0302', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'HIV: Percent of people living with HIV with viral load (VL) < 50 copies/ml after ARV treatment 12 months ago', 'ร้อยละของผู้ติดเชื้อเอชไอวีที่มี Viral load (VL) < 50 copies/ml หลังจากกินยาต้านไวรัส มาแล้ว 12 เดือน', '1. ผู้ป่วย/ ผู้ติดเชื้อเอชไอวี หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นผู้ป่วย/ ผู้ที่มีผลการตรวจวินิจฉัยโดยมีผลการตรวจเลือด ยืนยันแล้วว่า HIV positive โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วย/ ผู้ติดเชื้อเอชไอวีที่มี VL < 50 copies/ml หลังจากกินยาต้านไวรัสมาแล้ว 12 เดือน หมายถึง ผู้ป่วย/ ผู้ติดเชื้อเอชไอวีที่ได้รับการรักษาด้วยการกินยาต้านไวรัสสูตรใด สูตรหนึ่งมาแล้ว 12 เดือน ได้รับการตรวจเลือดหาค่าจำนวนเชื้อไวรัส (VL) แล้วพบว่ามี ค่าน้อยกว่า 50 copies/ml', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 102', 'registered-2026.1', NULL, 'registered'),
    ('DC0306', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'HIV: Percent of people living with HIV screening PAP smear', 'ร้อยละของผู้ติดเชื้อเอชไอวีเพศหญิงได้รับการคัดกรองมะเร็งปากมดลูก', '1. ผู้ป่วย/ ผู้ติดเชื้อเอชไอวี หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นผู้ป่วย/ ผู้ที่มีผลการตรวจวินิจฉัยโดยมีผลการตรวจเลือด ยืนยันแล้วว่า HIV positive โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การคัดกรองมะเร็งปากมดลูก หมายถึง การตรวจโดยวิธีการทำ Pap Smear หรือ visual inspection with acetic acid (VIA) โดยผู้ป่วย/ผู้ติดเชื้อเอชไอวีเพศหญิงควรได้รับการ ตรวจอย่างน้อยปีละ 1 ครั้ง', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 103', 'registered-2026.1', NULL, 'registered'),
    ('DC0307', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'HIV: Percent of people living with HIV newly registered who were tested for syphilis', 'ร้อยละของผู้ติดเชื้อเอชไอวีรายใหม่ที่ได้รับการตรวจคัดกรองโรคซิฟิลิส', '1. ผู้ป่วย/ผู้ติดเชื้อเอชไอวี หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นผู้ป่วย/ผู้ที่มีผลการตรวจวินิจฉัยโดยมีผลการตรวจเลือด ยืนยันแล้วว่า HIV Positive โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การตรวจคัดกรองซิฟิลิส มีวัตถุประสงค์เพื่อตรวจหาโรคซิฟิลิสโดยการตรวจเลือด สามารถทำได้โดยการตรวจเลือด (syphilis serologist screening tests) ประกอบด้วย การตรวจ 2 ชนิด คือ 2.1 Non-treponemal test : VDRL, RPR 2.2 Treponemal test : TPHA, TPPA, FTA-ABS', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 104', 'registered-2026.1', NULL, 'registered'),
    ('DC0308', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'HIV: Percent of people living with HIV who were currently receiving antiretroviral therapy', 'ร้อยละของผู้ติดเชื้อเอชไอวี/เอดส์ที่ได้รับการรักษาด้วยยาต้านไวรัส ณ ปัจจุบัน', '1. ผู้ติดเชื้อเอชไอวี/เอดส์ หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยในที่มีผล การตรวจเลือดยืนยันแล้วว่า HIV positive มีผลการตรวจวินิจฉัย โดยเป็นโรคที่มีรหัส โรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ และขึ้นทะเบียนรับการรักษากับ โรงพยาบาล 2. ผู้ติดเชื้อเอชไอวี/เอดส์ที่ได้รับการรักษาด้วยยาต้านไวรัส หมายถึง ผู้ติดเชื้อเอชไอ วี/เอดส์ที่กินยาต้านไวรัสสูตรใดสูตรหนึ่งและมารับยา ตรวจติดตามต่อเนื่องใน โรงพยาบาล ≥ 1 ครั้งใน 1 ปีที่รายงาน', '(a/b) x 100', 'a', 'B', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 105', 'registered-2026.1', NULL, 'registered'),
    ('DC0309', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'HIV: Percent of newly diagnosed people living with HIV were receiving tuberculosis preventive therapy (TPT)', 'ร้อยละของผู้ติดเชื้อเอชไอวีรายใหม่ที่มีข้อบ่งชี้ในการรับยาป้องกันวัณโรค (Tuberculosis preventive therapy, TPT) ได้รับยา TPT', '1. ผู้ติดเชื้อเอชไอวีรายใหม่ หมายถึง ผู้ติดเชื้อเอชไอวีที่ได้รับการวินิจฉัยเป็นครั้งแรก ในช่วงปีที่รายงาน 2. ผู้ติดเชื้อเอชไอวีรายใหม่มีข้อบ่งชี้ ได้แก่ ผู้ติดเชื้อเอชไอวีรายใหม่ที่ไม่ป่วยเป็นวัณ โรค ร่วมกับมี CD4 < 200 cells/wL หรือ ในกรณีที่ CD4 > 200 cells/wL มีผล TST >5 มม. หรือ IGRA positive หรือแพทย์แนะนำให้เริ่มการรับยาป้องกันวัณ โรคโดยไม่จำเป็นต้องมีผลตรวจ 3. ผู้ติดเชื้อเอชไอวีรายใหม่ได้รับการป้องกันวัณโรค (TPT) โดยได้รับประทาน ยาไอ โซไนอะซิด (Isoniazid) ร่วมกับ ไรฟาเพนทิน (Rifapentine) ทุกวันเป็นเวลา 1 เดือน หรือทุกสัปดาห์เป็นเวลา 12 สัปดาห์ หรือได้รับยาสูตรอื่นๆ ตามแนวทาง ประเทศเพื่อป้องกันการป่วยเป็นวัณโรค ภายใน 6 เดือนหลังจากรับยาต้านไวรัส HIVตามแนวทางการตรวจรักษา และป้องกันการติดเชื้อเอชไอวีประเทศไทย ปี 2563/64', '(a/b) x 100', 'a', 'B', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 106', 'registered-2026.1', NULL, 'registered'),
    ('DC0401', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Cancer: Percent of mortality', 'ร้อยละการเสียชีวิตของผู้ป่วยโรคมะเร็ง', '1. ผู้ป่วยมะเร็ง (cancer) หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาลนาน ตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) or Secondary diagnosis (Sdx) เป็นโรคมะเร็ง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วยมะเร็ง (cancer) หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วยที่มี Pdx เป็นมะเร็ง (cancer) หรือ Sdx เป็นมะเร็ง และเสียชีวิตด้วยสาเหตุจาก มะเร็ง 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยใน ออกจากโรงพยาบาล ในทุกสถานะ ทุกกรณี', '(a/b) x 100', 'a', 'b', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 107', 'registered-2026.1', NULL, 'registered'),
    ('DC0402', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Cancer: Percent of unplanned re-admission', 'ร้อยละการรับกลับเข้าโรงพยาบาลก่อนวันนัดโดยไม่ได้วางแผนของผู้ป่วยมะเร็ง', '1. ผู้ป่วยมะเร็ง (cancer) หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) or Secondary diagnosis (Sdx) เป็นโรคมะเร็ง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การรับกลับเข้าโรงพยาบาลก่อนวันนัดโดยไม่ได้วางแผนของผู้ป่วยมะเร็ง (cancer) หมายถึง การที่ผู้ป่วยมะเร็ง (cancer) กลับมารับการตรวจรักษาก่อนถึงกำหนดวันนัดหมาย และจำเป็นต้องรับกลับเข้านอนพักรักษาในโรงพยาบาลโดยไม่ได้วางแผน', '(a/b) x 100', 'a', 'b', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 108', 'registered-2026.1', NULL, 'registered'),
    ('DC0403', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Liver Cancer: Percent of mortality', 'ร้อยละการเสียชีวิตด้วยโรคมะเร็งตับ', '1. ผู้ป่วยมะเร็ง (cancer) หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) or Secondary diagnosis (Sdx) เป็นโรคมะเร็ง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วย Liver cancer หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วย Liver cancer ที่มี Pdx ตามที่ระบุไว้ หรือผู้ป่วยที่มีโรคร่วมหรือโรคแทรกเป็นโรค Liver cancer และมีสาเหตุการตายจากโรคโรค Liver cancer ซึ่งอยู่ในสถานะผู้ป่วยใน', '(a/b) x 100', 'a', 'b', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 109', 'registered-2026.1', NULL, 'registered'),
    ('DC0501', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'CKD: Percent of patients who achieve the kidney function deterioration delayed target', 'ร้อยละของผู้ป่วยโรคไตเรื้อรังที่สามารถชะลอความเสื่อมของไตได้ตามเป้าหมาย', '1) ผู้ป่วยโรคไตเรื้อรัง (CKD) ที่สามารถชะลอความเสื่อมของไตได้ตามเป้าหมาย หมายถึง ผู้ป่วยโรคไตเรื้อรัง (CKD) ระยะที่ 3-4 สัญชาติไทยที่มารับบริการที่แผนกผู้ป่วยนอกของ โรงพยาบาล และได้รับการตรวจ Serum Creatinine โดยมีผล eGFR ≥ 2 ค่าในช่วงเวลาที่ ต่างกันของปีที่เก็บข้อมูล, และมีค่าเฉลี่ยการเปลี่ยนแปลง ลดลง <4 ml/min/1.73 m2/Yr 2) eGFR (estimated Glomerular Filtration Rate) หมายถึง อัตราการกรองของไตที่ได้ จากการคำนวณจากค่า Serum creatinine', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_ckd_member', 'clinic_ckd_member_visit', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 110', 'registered-2026.1', NULL, 'registered'),
    ('DC0502', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'CKD: Percent of patients who are receiving ACEIs or ARBs', 'ร้อยละของผู้ป่วยโรคไตเรื้อรังที่ได้รับยา ACEIs หรือ ARBs', '1) ผู้ป่วยโรคไตเรื้อรัง (CKD) หมายถึง ผู้ป่วยที่ได้รับการวินิจฉัยโรคไตเรื้อรัง (CKD) ระยะที่ 1-4 สัญชาติไทย ที่มารับบริการที่แผนกผู้ป่วยนอกของโรงพยาบาล และได้รับการตรวจ Serum creatinine โดยมีค่า eGFR ≥15 ml/min/1.73 m2/Yr 2) eGFR (estimated Glomerular Filtration Rate) หมายถึง อัตราการกรองของไตที่ได้ จากการคำนวณจากค่า Serum creatinine 3) ACEis หมายถึง ยาในกลุ่ม Angiotensin converting enzyme inhibitor 4) ARBs หมายถึง ยาในกลุ่ม Angiotensin receptor blocker', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_ckd_member', 'clinic_ckd_member_visit', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 112', 'registered-2026.1', NULL, 'registered'),
    ('DE0101', 'D', 'ratio', 'lower-is-better', 'annual', 'Disease', 'Breast Cancer: Consultation time in patient with BIRADS 4 or greater mammography result', 'ระยะเวลาการรอตรวจภายหลังการส่งปรึกษาของผู้ป่วยที่มีผลเมมโมแกรมตั้งแต่ BI-RADS 4 ขึ้นไป', 'จำนวนวันรอตรวจเฉลี่ย หมายถึง จำนวนวันตั้งแต่รังสีแพทย์รายงานผลการตรวจ (แมมโมแกรมเป็น BI-RADS 4 ขึ้นไป) จนถึงวันที่ผู้ป่วยได้เข้ารับการตรวจกับศัลยแพทย์เต้านม', 'a/b', 'A', 'B', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 130', 'registered-2026.1', NULL, 'registered'),
    ('DE0103', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Breast Cancer: Percent of early diagnosis of stage 1, 2', 'ร้อยละการตรวจพบผู้ป่วยมะเร็งเต้านมระยะแรก Stage 1, 2', '1. ผู้ป่วยมะเร็งเต้านม หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยในที่มี Principal diagnosis (Pdx) or Secondary diagnosis (sdx) เป็นโรคมะเร็งเต้านม โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. มะเร็งเต้านมระยะที่ 1 หมายถึง มะเร็งมีการลุกลามออกมานอกเนื้อเยื่อฐานราก แต่ยัง ไม่มีการแพร่กระจายไปสู่ต่อมน้ำเหลืองที่รักแร้ และขนาดก้อนมะเร็งไม่เกิน 2 ซม. 3. มะเร็งเต้านมระยะที่ 2 หมายถึง ก้อนมะเร็งขนาดเกิน 2 ซม. แต่ไม่เกิน 5 ซม. ที่ยังไม่มี การแพร่กระจายไปสู่ต่อมน้ำเหลืองที่รักแร้ หรือมะเร็งขนาดเล็กไม่เกิน 2 ซม. แต่มีการ แพร่กระจายไปสู่ต่อมน้ำเหลืองที่รักแร้แล้ว', '(a/b) ข 100', 'a', 'B', ARRAY['patient_cancer_registeration', 'patient_cancer_visit_stat', 'clinicmember_cancer', 'clinicmember', 'ovst', 'ovstdiag', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 131', 'registered-2026.1', NULL, 'registered'),
    ('DE0501', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Stem Cell Transplantation: Engraftment rate within 45 days', 'อัตราการปลูกถ่ายติด (engraftment) ของผู้ป่วย Stem cell transplantation ภายใน 45 วัน หลังการปลูกถ่ายไขกระดูก', 'การรักษาด้วยการปลูกถ่ายไขกระดูกหรือการปลูกถ่ายเซลล์ต้นกำเนิดเม็ดเลือดที่ประสบ ผลสำเร็จที่มีการปลูกถ่ายติด (engraftment) ภายใน 45 วัน', '(a/b) ข 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'lab_head', 'lab_order', 'lab_items', 'operation_list', 'operation_detail']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 132', 'registered-2026.1', NULL, 'registered'),
    ('DE0801', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'TDT in Pediatrics Patient: Percent of received iron chelator in patient with iron overload (serum ferrous > 1000 ug/L)', 'ร้อยละของผู้ป่วย transfusion dependent thalassemia (TDT) ที่อายุมากกว่า 2 ปี และถึง 15 ปี มีภาวะธาตุเหล็กเกิน (Serum ferritin > 1000 ug/L) ที่ได้รับยาขับธาตุเหล็ก', '1. ผู้ป่วย TDT ที่อายุมากกว่า 2 ปี ถึง 15 ปี ที่มีภาวะธาตุเหล็กเกิน หมายถึง ผู้ได้รับการ ตรวจเช็คระดับ Serum ferritin และ มีค่า Serum ferritin > 1000 ug/L (Hemochromatosis) 2. ผู้ป่วยที่มีค่า Serum ferritin > 1000 ug/L และได้รับยาขับธาตุเหล็ก หรือ Iron Chelator เช่น Deferasirox, Deferoxamine หรือ Deferiprone ชนิดใดชนิดหนึ่ง หรือให้ ร่วมกัน', '(a/b) ข 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'lab_head', 'lab_order', 'lab_items', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 133', 'registered-2026.1', NULL, 'registered'),
    ('DE1201', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Cleft Lip: Percent of patients who had cleft lip repair with under 6 months of age', 'ร้อยละผู้ป่วยที่เข้ารับการผ่าตัดซ่อมแซมปากแหว่งตามเกณฑ์ช่วงอายุไม่เกิน 6 เดือน', 'ผู้ป่วยปากแหว่งเพดานโหว่ทั้งชนิดสมบูรณ์และชนิดไม่สมบูรณ์ข้างเดียวและสองข้าง (unilateral/bilateral complete/incomplete Cleft lip-Cleft palate) และที่มีภาวะ ปากแหว่งอย่างเดียว (cleft lip) ที่คลอดในเขตที่โรงพยาบาลนั้นรับผิดชอบ รวมถึงผู้ป่วยที่ ได้รับการส่งต่อมา ครอบคลุมถึงผู้ป่วยที่ได้รับการจัดสันเหงือกก่อนผ่าตัด เพื่อเข้ารับการ ผ่าตัดปากแหว่งในช่วงอายุไม่เกิน 6 เดือน ที่ให้รหัสโรคตาม ICD-10 กลุ่ม Q35, Q36, Q37', '(a/b)x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 134', 'registered-2026.1', NULL, 'registered'),
    ('DE1202', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Cleft Palate: Percent of patients who had cleft Palate repair with under 18 months of age', 'ร้อยละผู้ป่วยที่เข้ารับการผ่าตัดซ่อมแซมเพดานโหว่ตามช่วงอายุไม่เกิน 18 เดือน', 'ผู้ป่วยปากแหว่งเพดานโหว่ทั้งชนิดสมบูรณ์และชนิดไม่สมบูรณ์ข้างเดียวและสองข้าง (unilateral/bilateral complete/incomplete Cleft lip-Cleft palate) และที่มีภาวะ ปากแหว่งอย่างเดียว (cleft lip) ที่คลอดในเขตที่โรงพยาบาลนั้นรับผิดชอบ รวมถึง ผู้ป่วยที่ได้รับการส่งต่อมา ครอบคลุมถึงผู้ป่วยที่ได้รับการจัดสันเหงือกก่อนผ่าตัดเพื่อ เข้ารับการผ่าตัดปากแหว่งในช่วงอายุไม่เกิน 18 เดือน ที่ให้รหัสโรคตาม ICD-10 กลุ่ม Q35, Q36, Q37', '(a/b)x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 135', 'registered-2026.1', NULL, 'registered'),
    ('DE1301', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per Embryo Transfer following IVF/ICSI and Fresh embryo transfer (age < 34 years)', 'อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบสด (กลุ่มอายุน้อยกว่า 34 ปี)', '1. การทำเด็กหลอดแก้ว หมายถึง การใช้เทคโนโลยีช่วยการเจริญพันธุ์ ด้วยการปฏิสนธินอก ร่างกาย อันได้แก่ การผสมนอกร่างกายในจานเพาะเลี้ยง (standard in vitro fertilisation) และการฉีดตัวอสุจิเข้าเซลล์ไข่โดยตรง (ICSI- intracytoplasmic sperm injection) โดย ทำการย้ายตัวอ่อนรอบสดตามหลังการกระตุ้นและเก็บไข่ เข้าในโพรงมดลูกของสตรี ผู้รับบริการ; 2. Clinical pregnancy หมายถึง การตรวจด้วยเครื่องความถี่สูง ยืนยันการตั้งครรภ์ของ ตัวอ่อนมีชีพ (มีการเต้นของหัวใจ) ในโพรงมดลูกที่อายุครรภ์ 6-8 สัปดาห์ หรือ 3-5 สัปดาห์ หลังการใส่ตัวอ่อน', '(a/b) ข 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 136', 'registered-2026.1', NULL, 'registered'),
    ('DE1302', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age 34 - 39 Years)', 'อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบสด (กลุ่มอายุ 34 - 39 ปี)', '1. การทำเด็กหลอดแก้ว หมายถึง การใช้เทคโนโลยีช่วยการเจริญพันธุ์ ด้วยการปฏิสนธินอก ร่างกาย อันได้แก่ การผสมนอกร่างกายในจานเพาะเลี้ยง (standard in vitro fertilisation) และการฉีดตัวอสุจิเข้าเซลล์ไข่โดยตรง (ICSI- intracytoplasmic sperm injection) โดย ทำการย้ายตัวอ่อนรอบสดตามหลังการกระตุ้นและเก็บไข่ เข้าในโพรงมดลูกของสตรี ผู้รับบริการ 2. Clinical pregnancy หมายถึง การตรวจด้วยเครื่องความถี่สูง ยืนยันการตั้งครรภ์ของตัว อ่อนมีชีพ (มีการเต้นของหัวใจ) ในโพรงมดลูกที่อายุครรภ์ 6-8 สัปดาห์ หรือ 3-5 สัปดาห์ หลังการใส่ตัวอ่อน', '(a/b) ข 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 137', 'registered-2026.1', NULL, 'registered'),
    ('DE1303', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age > 40 years)', 'อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบสด (กลุ่มอายุ 40 ปีขึ้นไป)', '1. การทำเด็กหลอดแก้ว หมายถึง การใช้เทคโนโลยีช่วยการเจริญพันธุ์ ด้วยการปฏิสนธินอก ร่างกาย อันได้แก่ การผสมนอกร่างกายในจานเพาะเลี้ยง (standard in vitro fertilisation) และการฉีดตัวอสุจิเข้าเซลล์ไข่โดยตรง (ICSI- intracytoplasmic sperm injection) โดย ทำการย้ายตัวอ่อนรอบสดตามหลังการกระตุ้นและเก็บไข่ เข้าในโพรงมดลูกของสตรี ผู้รับบริการ 2. Clinical pregnancy หมายถึง การตรวจด้วยเครื่องความถี่สูง ยืนยันการตั้งครรภ์ของตัว อ่อนมีชีพ (มีการเต้นของหัวใจ) ในโพรงมดลูกที่อายุครรภ์ 6-8 สัปดาห์ หรือ 3-5 สัปดาห์ หลังการใส่ตัวอ่อน', '(a/b) ข 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 138', 'registered-2026.1', NULL, 'registered'),
    ('DE1304', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years)', 'อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุน้อยกว่า 34 ปี)', '1. การทำเด็กหลอดแก้ว หมายถึง การใช้เทคโนโลยีช่วยการเจริญพันธุ์ ด้วยการปฏิสนธินอก ร่างกาย อันได้แก่ การผสมนอกร่างกายในจานเพาะเลี้ยง (standard in vitro fertilisation) และการฉีดตัวอสุจิเข้าเซลล์ไข่โดยตรง (ICSI-intracytoplasmic sperm injection) โดยทำ การย้ายตัวอ่อนที่ผ่านการแช่แข็ง ละลาย และ/หรือเพาะเลี้ยงต่อหลังละลายตัวอ่อน เข้าในโพรงมดลูกของสตรีผู้รับบริการ 2. Clinical pregnancy หมายถึง การตรวจด้วยเครื่องความถี่สูง ยืนยันการตั้งครรภ์ของตัว อ่อนมีชีพ (มีการเต้นของหัวใจ) ในโพรงมดลูกที่อายุครรภ์ 6-8 สัปดาห์ หรือ 3-5 สัปดาห์ หลังการใส่ตัวอ่อน', '(a/b) ข 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 139', 'registered-2026.1', NULL, 'registered'),
    ('DE1305', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age 34 - 39 years)', 'อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุ 34 - 39 ปี)', '1. การทำเด็กหลอดแก้ว หมายถึง การใช้เทคโนโลยีช่วยการเจริญพันธุ์ ด้วยการปฏิสนธินอก ร่างกาย อันได้แก่ การผสมนอกร่างกายในจานเพาะเลี้ยง (standard in vitro fertilisation) และการฉีดตัวอสุจิเข้าเซลล์ไข่โดยตรง (ICSI- intracytoplasmic sperm injection) โดย ทำการย้ายตัวอ่อนที่ผ่านการแช่แข็ง ละลาย และ/หรือเพาะเลี้ยงต่อหลังละลายตัวอ่อน เข้าในโพรงมดลูกของสตรีผู้รับบริการ 2. Clinical pregnancy หมายถึง การตรวจด้วยเครื่องความถี่สูง ยืนยันการตั้งครรภ์ของตัว อ่อนมีชีพ (มีการเต้นของหัวใจ) ในโพรงมดลูกที่อายุครรภ์ 6-8 สัปดาห์ หรือ 3-5 สัปดาห์ หลังการใส่ตัวอ่อน', '(a/b) ข 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 140', 'registered-2026.1', NULL, 'registered'),
    ('DE1306', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years)', 'อัตราการตั้งครรภ์ต่อรอบการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็ง (กลุ่มอายุ 40 ปีขึ้นไป)', '1. การทำเด็กหลอดแก้ว หมายถึง การใช้เทคโนโลยีช่วยการเจริญพันธุ์ ด้วยการปฏิสนธินอก ร่างกาย อันได้แก่ การผสมนอกร่างกายในจานเพาะเลี้ยง (standard in vitro fertilisation) และการฉีดตัวอสุจิเข้าเซลล์ไข่โดยตรง (ICSI- intracytoplasmic sperm injection) โดย ทำการย้ายตัวอ่อนที่ผ่านการแช่แข็ง ละลาย และ/หรือเพาะเลี้ยงต่อหลังละลายตัวอ่อน เข้าในโพรงมดลูกของสตรีผู้รับบริการ 2. Clinical pregnancy หมายถึง การตรวจด้วยเครื่องความถี่สูง ยืนยันการตั้งครรภ์ของตัว อ่อนมีชีพ (มีการเต้นของหัวใจ) ในโพรงมดลูกที่อายุครรภ์ 6-8 สัปดาห์ หรือ 3-5 สัปดาห์ หลังการใส่ตัวอ่อน', '(a/b) ข 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 141', 'registered-2026.1', NULL, 'registered'),
    ('DE1401', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of patients who had underwent EGD within 24 hours', 'ร้อยละผู้ป่วย Upper GI hemorrhage (UGIH) ได้รับการส่องกล้องภายใน 24 ชั่วโมง', '1. ผู้ป่วย UGIH หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นาน ≥ 4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคที่มีเลือดออกในระบบทางเดินอาหารส่วน ต้น โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การส่องกล้องทางเดินอาหารส่วนต้น (Esophagogastroduodenoscopy) หมายถึง การส่องกล้องตรวจหลอดอาหาร กระเพาะอาหาร และลำไส้เล็กส่วนต้น 3. ภายใน 24 ชั่วโมง หมายถึง ช่วงเวลา เริ่มนับตั้งแต่ ผู้ป่วยได้รับการวินิจฉัย UGIH และ เข้ารับการรักษาแบบใน จนถึงเวลาที่ผู้ป่วยได้รับการส่องกล้องทางเดินอาหารส่วนต้น', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 142', 'registered-2026.1', NULL, 'registered'),
    ('DE1402', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of high risk patients who had underwent EGD within 24 hours', 'ร้อยละผู้ป่วย Upper GI hemorrhage (UGIH) กลุ่ม high risk ได้รับการส่องกล้องทางเดิน อาหารส่วนต้น ภายใน 24 ชั่วโมง', '1. ผู้ป่วย UGIH หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นาน ≥ 4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคที่มีเลือดออกในระบบทางเดินอาหารส่วน ต้น โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วย UGIH กลุ่ม high risk ได้แก่ ผู้ป่วยอายุ ≥ 60 ปี, มีโรคร่วมอื่นๆ เช่น โรคไตวาย โรคตับแข็ง โรคหัวใจและหลอดเลือด โรคถุงลมโป่งพอง, มีเลือดแดงสดออกจากสาย NG- tube, มีเลือดแดงสดออกจากทวารร่วมกับมีสัญญาณชีพที่ลดต่ำลง, Glasgow-Blatchford score ≥ 2 คะแนน 3. การส่องกล้องทางเดินอาหารส่วนต้น (esophagogastroduodenoscopy) หมายถึง การส่องกล้องตรวจหลอดอาหาร กระเพาะอาหาร และลำไส้เล็กส่วนต้น 4. ภายใน 24 ชั่วโมง หมายถึง ช่วงเวลา เริ่มนับตั้งแต่ ผู้ป่วยได้รับการวินิจฉัย UGIH และ เข้ารับการรักษาแบบใน จนถึงเวลาที่ผู้ป่วยได้รับการส่องกล้องทางเดินอาหารส่วนต้น', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 143', 'registered-2026.1', NULL, 'registered'),
    ('DE1403', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Non-variceal Upper Gastrointestinal Hemorrhage (UGIH): Percent of hemostatic success by endoscopic approach', 'ร้อยละผู้ป่วย Non-variceal UGIH สามารถหยุดเลือดด้วยวิธีการส่องกล้องได้สำเร็จ', '1. ผู้ป่วย Non-variceal UGIH หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นาน ≥ 4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคที่มีเลือดออกใน ระบบทางเดินอาหารส่วนต้นแบบ Non-variceal UGIH โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การส่องกล้องทางเดินอาหารส่วนต้น (esophagogastroduodenoscopy) หมายถึง การส่องกล้องตรวจหลอดอาหาร กระเพาะอาหาร และลำไส้เล็กส่วนต้น 3. การหยุดเลือดด้วยวิธีการส่องกล้อง หมายถึง การส่องกล้องทางเดินอาหารส่วนต้น ร่วมกับ Adrenaline Injection, Heater Probe, Bipolar Electrocautery Probe, Argon Plasma Coagulation (APC), Hemoclipping, Band Ligation และ Histoacryl Injection 4. การหยุดเลือดด้วยวิธีการส่องกล้องทางเดินอาหารส่วนต้นสำเร็จ หมายถึง ไม่พบ เลือดออกหลังการหยุดเลือดด้วยการส่องกล้องในขณะนั้น', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 145', 'registered-2026.1', NULL, 'registered'),
    ('DE1404', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Recurrent rates of UGIH after upper endoscopic treatment', 'ร้อยละผู้ป่วยที่เกิดภาวะเลือดออกซ้ำจากแผลในระบบทางเดินอาหารส่วนต้นภายหลังจาก การหยุดเลือดด้วยการส่องกล้อง', '1. แผลในระบบทางเดินอาหารส่วนต้น หมายถึง แผลในกระเพาะอาหารหรือลำไส้เล็ก ส่วนต้น 2. การหยุดเลือดด้วยวิธีการส่องกล้อง หมายถึง การส่องกล้องทางเดินอาหารส่วนต้น ร่วมกับ Adrenaline Injection, Heater Probe, Bipolar Electrocautery Probe, Argon Plasma Coagulation (APC), Hemoclipping, Band Ligation แ ล ะ Histoacryl injection 3. ผู้ป่วยที่เกิดภาวะเลือดออกซ้ำ หมายถึง ผู้ป่วยที่มี 1) อาเจียนหรือถ่ายเป็นเลือดสด หรือ NG lavage พบเลือดหลังการส่องกล้อง 2) ถ่ายดำหลังจากถ่ายเป็นปกติแล้ว 3) ถ่ายเป็นเลือดสดหลังจากถ่ายเป็นปกติหรือถ่ายดำแล้ว 4) สัญญาณชีพไม่คงที่ (heart rate ≥ 110/min หรือ systolic blood pressure ≤ 90 mmHg หลังจากที่สัญญาณชีพคงที่ ≥1 ชม. โดยไม่มีเหตุอื่น) 5) Hemoglobin ลดลง ≥2 g/dl หลังจากที่ Hb คงที่ (ลดลง <0.5 g/dL ≥3 ชม.) 6) Tachycardia or Hypotension ไม่ดีขึ้นภายใน 8 ชั่วโมงหลังการส่องกล้องทั้งที่ได้ resuscitation ที่เหมาะสมและไม่มีเหตุอื่น ร่วมกับมีถ่ายดำหรือถ่ายเป็นเลือด อย่างต่อเนื่อง', '(a/b) x 100', 'a', 'ต้องยืนยันตามนิยาม PDF และ local rule', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 147', 'registered-2026.1', NULL, 'registered'),
    ('DE1405', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Complication rates of upper endoscopic treatment', 'อัตราการเกิดภาวะแทรกซ้อนจากการส่องกล้องทางเดินอาหารส่วนต้นเพื่อรักษา UGIH', '1. ผู้ป่วย UGIH หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นาน ≥ 4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคที่มีเลือดออกในระบบทางเดินอาหารส่วน ต้น โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การส่องกล้องทางเดินอาหารส่วนต้น (esophagogastroduodenoscopy) หมายถึง การส่องกล้องตรวจหลอดอาหาร กระเพาะอาหาร และลำไส้เล็กส่วนต้น 3. ภาวะแทรกซ้อนจากการส่องกล้อง หมายถึง ทะลุ การติดเชื้อหลังการส่องกล้อง และ ภาวะระบบหายใจและระบบไหลเวียนโลหิตล้มเหลว', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 149', 'registered-2026.1', NULL, 'registered'),
    ('DE1601', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'New born: Percent of hearing screening within 30 days', 'ร้อยละของทารกแรกเกิดที่ได้รับการตรวจคัดกรองการได้ยิน ภายใน 30 วัน', '1.ทารกแรกเกิด หมายถึง ทารกแรกเกิดมีชีพทุกรายที่คลอดในโรงพยาบาลจากหญิง ตั้งครรภ์โดยมีอายุครรภ์ตั้งแต่ 28 สัปดาห์ขึ้นไป ยกเว้นย้ายไปโรงพยาบาลอื่นก่อน 2. การตรวจคัดกรองการได้ยิน หมายถึง การตรวจเพื่อประเมินความผิดปกติของการได้ยิน โดยวัดเสียงสะท้อนจากหูชั้นใน (Otoacoustic emissions: OAE) หรือ การตรวจความ ผิดปกติการได้ยินระดับก้านสมอง (Automated Auditory Brainstem Response: AABR)', '(a/b) ข 100', 'a', 'b', ARRAY['ipt_newborn', 'ipt_pregnancy', 'ipt_pregnancy_vital_sign', 'ipt_labour_infant', 'ipt_labour_child', 'labor', 'person_wbc', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 150', 'registered-2026.1', NULL, 'registered'),
    ('DG0101', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Percent of unplanned re-admission into the hospital within 28 days after last discharge', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย Upper GI Hemorrhage ภายใน 28 วัน โดย ไม่ได้วางแผน', '1. ผู้ป่วย UGIH หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นาน ≥ 4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคที่มีเลือดออกในระบบทางเดินอาหาร ส่วนบนโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. เป็นการรับกลับเข้าโรงพยาบาลของผู้ป่วยโรค Upper GI hemorrhage ภายใน 28วัน โดยไม่ได้วางแผนหลังจำหน่ายออกจาก รพ. ด้วยสถานะการอนุญาตให้กลับบ้าน (status = improve) (ยกเว้นผู้ป่วยที่ไปรักษาที่โรงพยาบาลอื่น หรือไม่ยินยอมรับการรักษาตามแผน)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 120', 'registered-2026.1', NULL, 'registered'),
    ('DG0102', 'D', 'ratio', 'lower-is-better', 'monthly', 'Disease', 'Upper Gastrointestinal Hemorrhage (UGIH): Average length of stay', 'ระยะเวลาวันนอนเฉลี่ยผู้ป่วย Upper GI hemorrhage (UGIH)', '1. ผู้ป่วย UGIH หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล (admit) นาน ≥ 4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคที่มีเลือดออกในระบบทางเดินอาหาร ส่วนบนโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. จำนวนวันนอนรวมของผู้ป่วย UGIH หมายถึง ผลรวมจำนวนวัน ที่ผู้ป่วย UGIH นอนพัก รักษาตัวในโรงพยาบาล นับตั้งแต่วันที่รับไว้ในโรงพยาบาล จนถึงวันที่จำหน่าย (ทุก สถานะการจำหน่าย) ออกจากโรงพยาบาล', 'a/b', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 121', 'registered-2026.1', NULL, 'registered'),
    ('DG0201', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Acute Appendicitis: Percent of abruption', 'ร้อยละการเกิดไส้ติ่งทะลุในผู้ป่วยโรคไส้ติ่งอักเสบ', 'ผู้ป่วยไส้ติ่งทะลุ หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นาน ≥ 4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคไส้ติ่งอักเสบเฉียบพลันและเกิด ภาวะแทรกซ้อนมีแผลทะลุ โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 122', 'registered-2026.1', NULL, 'registered'),
    ('DG0202', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Acute Appendicitis: Percent of mortality', 'ร้อยละการเสียชีวิตจากไส้ติ่งอักเสบ', '1. ผู้ป่วยไส้ติ่งอักเสบเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นาน ≥ 4 ชั่วโมง) ที่มี Principal กiagnosis (Pdx) เป็นโรคไส้ติ่งอักเสบ เฉียบพลัน โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วยไส้ติ่งอักเสบเฉียบพลัน หมายถึง การเสียชีวิตจากทุกสาเหตุของ ผู้ป่วยไส้ติ่งอักเสบเฉียบพลัน 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยใน ออกจากโรงพยาบาลในทุกสถานะ ทุกกรณี', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 123', 'registered-2026.1', NULL, 'registered'),
    ('DH0101', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of mortality', 'ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน', '1. ผู้ป่วย Acute coronary syndrome (ACS) หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพัก รักษาในโรงพยาบาลนานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็นภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วย Acute coronary syndrome (ACS) หมายถึง การเสียชีวิตจาก ทุกสาเหตุของผู้ป่วย ACS ที่มี Pdx ตามที่ระบุไว้ หรือผู้ป่วยที่มีโรคร่วมหรือโรคแทรกเป็น ACS และ มีสาเหตุการตายจากภาวะหัวใจขาดเลือดเฉียบพลัน 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยในออกจากโรงพยาบาล ในทุกสถานะ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 39', 'registered-2026.1', NULL, 'registered'),
    ('DH0101.1', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Acute coronary syndrome (STEMI): Percent of mortality', 'ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI)', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) หมายถึง ผู้ป่วย ใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็นภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วย STEMI ที่มี Pdx ตามที่ระบุไว้ หรือผู้ป่วยที่มี โรคร่วมหรือโรคแทรกเป็น STEMI และ มีสาเหตุการตายจากภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยในออกจากโรงพยาบาล ในทุกสถานะ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 40', 'registered-2026.1', NULL, 'registered'),
    ('DH0101.2', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Acute coronary syndrome (NSTE-ACS): Percent of mortality', 'ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS)', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาลนานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วย NSTE-ACS ที่มี Pdx ตามที่ ระบุไว้ หรือผู้ป่วยที่มีโรคร่วมหรือโรคแทรกเป็น NSTE-ACS และ มีสาเหตุการตายจาก ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยในออกจากโรงพยาบาล ในทุกสถานะ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 41', 'registered-2026.1', NULL, 'registered'),
    ('DH0102', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of patient receiving Aspirin within', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่ได้รับยา Aspirin ภายใน 24 ชั่วโมงเมื่อมาถึง โรงพยาบาล', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่ได้รับ Aspirin ภายใน 24 ชั่วโมงเมื่อมาถึง โรงพยาบาล หมายถึง ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่ไม่มีข้อห้ามของการให้ยานี้ และได้รับ Aspirin ในการรักษา โดยนับระยะเวลาตั้งแต่มีอาการและมาตรวจรักษาที่ ER/OPD และรับไว้ในโรงพยาบาล จนถึงระยะเวลาที่ผู้ป่วยได้รับยา', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 42', 'registered-2026.1', NULL, 'registered'),
    ('DH0103', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Aspirin prescribed at discharge', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับการสั่งยา Aspirin เมื่อจำหน่ายออก จากโรงพยาบาล', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับการสั่งยา Aspirin เมื่อจำหน่ายออกจาก โรงพยาบาล หมายถึง ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ไม่มีข้อห้ามของการให้ ยานี้ และมีการสั่งให้ยา Aspirin เมื่อจำหน่ายผู้ป่วยออกจากโรงพยาบาล โดยนับเฉพาะการ จำหน่ายมีชีวิตด้วยสถานะการอนุญาตให้กลับบ้าน', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 43', 'registered-2026.1', NULL, 'registered'),
    ('DH0104', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of ACE inhibitors or ARB received for patient who have LVSD', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่มี LVSD และได้รับยา ACE inhibitors หรือ ARBs', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่มี LVSD หมายถึง ผู้ป่วย ACS ที่ได้รับการ ตรวจด้วยคลื่นเสียง ultrasound แล้วพบว่ามี LVSD 3. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ได้รับยา ACE inhibitors หรือ ARBs หมายถึง ผู้ป่วย ACS ที่ไม่มีข้อห้าม หรือข้อจำกัด (ผู้ป่วยแพ้ยา, ความดันโลหิตต่ำกว่า 100/60 mmHg) ของการให้ยานี้ และได้รับยา ACE inhibitors หรือ ARBs ในการรักษา', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 44', 'registered-2026.1', NULL, 'registered'),
    ('DH0105', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of smoking cessation advice given', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่สูบบุหรี่และได้รับการแนะนำให้งดบุหรี่ ระหว่างการอยู่โรงพยาบาล', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่สูบบุหรี่และได้รับการแนะนำให้งดบุหรี่ ระหว่างการอยู่โรงพยาบาล หมายถึง ผู้ป่วย ACS ที่มีประวัติสูบบุหรี่ภายใน 1 ปีก่อนได้รับ การตรวจรักษาและรับไว้ในโรงพยาบาล ได้รับคำแนะนำ/Counseling ให้ความรู้ความ เข้าใจเกี่ยวกับผลกระทบของบุหรี่ต่อภาวะของโรคที่เป็น เพื่อให้ผู้ป่วยงดบุหรี่ระหว่างการ อยู่โรงพยาบาล และแนะนำให้อดหรือเลิกบุหรี่ต่อไป', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 46', 'registered-2026.1', NULL, 'registered'),
    ('DH0106', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Beta-blocker receiving during hospital admitted', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับยา Beta-blocker ระหว่างรับไว้รักษา ในโรงพยาบาล', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ได้รับ Beta-blocker ระหว่างรับไว้รักษา ในโรงพยาบาล หมายถึง ผู้ป่วย ACS ที่ไม่มีข้อห้ามของการให้ยานี้ และ ได้รับยา Beta- blocker ในระหว่างรับไว้รักษาในโรงพยาบาล', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 47', 'registered-2026.1', NULL, 'registered'),
    ('DH0107', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Beta-blocker prescribed at discharge', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับการสั่งยา Beta-blocker เมื่อจำหน่าย จากโรงพยาบาล', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ได้รับยา Beta-blocker เมื่อจำหน่ายจาก โรงพยาบาล หมายถึง ผู้ป่วย ACS ที่ไม่มีข้อห้ามของการให้ยานี้ และ มีการสั่งให้ยา Beta- blocker เมื่อจำหน่ายผู้ป่วยออกจากโรงพยาบาลโดยการอนุญาตให้กลับบ้าน', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 48', 'registered-2026.1', NULL, 'registered'),
    ('DH0108', 'D', 'ratio', 'lower-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Average door to EKG time', 'ระยะเวลาเฉลี่ยที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ที่ได้รับการทำ EKG เมื่อมาถึง โรงพยาบาล', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ระยะเวลาที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ได้รับการทำ EKG เมื่อมาถึง โรงพยาบาล หมายถึง ช่วงเวลานับตั้งแต่ผู้ป่วย ACS มาถึงโรงพยาบาล (ในทุก OPD, ER) จนถึงได้รับการทำ EKG ครั้งแรกของการตรวจรักษา โดยมีหน่วยนับเป็นรายนาที', 'a/b', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 49', 'registered-2026.1', NULL, 'registered'),
    ('DH0109', 'D', 'ratio', 'lower-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Average door to refer time', 'ระยะเวลาเฉลี่ยที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน มาถึงโรงพยาบาลจนได้รับการส่งต่อ', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ระยะเวลาที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) มาถึงโรงพยาบาลจนได้รับการ ส่งต่อ หมายถึง ช่วงเวลานับตั้งแต่ผู้ป่วย ACS มาถึงโรงพยาบาล (ในทุก OPD, ER) จนถึง ได้รับการส่งต่อ โดยมีหน่วยนับเป็นนาที 3. กระบวนการส่งต่อผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ต้องไม่อยู่ภายใต้ข้อจำกัด เรื่อง โรงพยาบาลปลายทาง/โรงพยาบาลผู้รับส่งต่อ (refer) กำหนดให้มีการตรวจทาง ห้องปฏิบัติการให้ครบก่อนส่งต่อ', 'a/b', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 50', 'registered-2026.1', NULL, 'registered'),
    ('DH0110', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of Primary Percutaneous Coronary Intervention (PCI) given within 120 minutes or received Fibrinolytic agent within 30 minutes of arrival', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น (STEMI) ที่ได้รับ Primary Percutaneous Coronary Intervention (PPCI) ภายใน 120 นาที หรือ Fibrinolytic Agent ภายใน 30 นาทีเมื่อแรกรับ', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) หมายถึง ผู้ป่วย ใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี principal diagnosis (Pdx) เป็นภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) ซึ่งต้องให้ยาละลายลิ่มเลือด (Fibrinolytic Agent) และ/หรือ การขยายหลอด เลือดหัวใจ (PCI: Percutaneous Coronary Intervention) โดยเป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. เป็นผู้ป่วย STEMI ที่ไม่มีข้อจำกัดของการทำ PPCI หรือไม่มีข้อห้ามของการให้ Thrombolytic agent ในการรักษา 3. การได้รับ PPCI ภายใน 120 นาที หรือ Fibrinolytic agent ภายใน 30 นาที นับตั้งแต่ ระยะเวลาที่ผู้ป่วยได้รับการตรวจรักษาที่ ER/OPD และรับไว้ในโรงพยาบาล จนถึงเวลาที่ ผู้ป่วยได้ทำ PPCI หรือได้รับยา Fibrinolytic agent', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 51', 'registered-2026.1', NULL, 'registered'),
    ('DH0111', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of unplanned re-admission within', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ภายใน 28 วัน โดยไม่ได้วางแผน', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การรับกลับเข้าโรงพยาบาลของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ภายใน 28 วัน โดย ไม่ได้วางแผน หมายถึง ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่รับกลับเข้าโรงพยาบาลหลัง จำหน่ายจากโรงพยาบาลภายใน 28 วัน ด้วยสถานะการอนุญาตให้กลับบ้าน (status=improve) ยกเว้น ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่ไปรักษาที่โรงพยาบาล อื่น หรือไม่ยินยอมรับการรักษาตามแผน', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 53', 'registered-2026.1', NULL, 'registered'),
    ('DH0112', 'D', 'ratio', 'lower-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Average length of stay', 'ระยะเวลาวันนอนเฉลี่ยผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥ 18 ปี ที่มี Principal diagnosis (Pdx) เป็น ภาวะหัวใจขาดเลือดเฉียบพลัน ได้แก่ 1.1) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) 1.2) ภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ระยะเวลาวันนอนเฉลี่ยผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน หมายถึง ผลรวมของ จำนวนวันนอนที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันนอนพักรักษาตัวในโรงพยาบาลโดย นับตั้งแต่วันที่รับไว้จนถึงวันที่จำหน่ายออกจากโรงพยาบาลทุกรายที่จำหน่ายในเดือนนั้น หารด้วยจำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่จำหน่ายในเดือนนั้น 3. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่จำหน่ายออกจากโรงพยาบาล หมายถึง ผู้ป่วย ภาวะหัวใจขาดเลือดเฉียบพลัน ที่จำหน่ายออกจาก โรงพยาบาล ทุกสถานะการจำหน่าย', '(a/b)', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 54', 'registered-2026.1', NULL, 'registered'),
    ('DH0113', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Acute coronary syndrome: Percent of time to Fibrinolytic administration agents within 30 minutes of arrival', 'ร้อยละผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น (STEMI) ที่ได้รับ Fibrinolytic agent ภายใน 30 นาทีเมื่อมาถึงโรงพยาบาล', '1. ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) หมายถึง ผู้ป่วย อายุ ≥ 18 ปี ที่มี principal diagnosis (Pdx) เป็นภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) ซึ่งต้องให้ยาละลายลิ่มเลือด (Fibrinolytic agent) โดยมีรหัส โรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. เป็นผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) ที่ไม่มีข้อ ห้ามของการให้ Thrombolytic agent ในการรักษา 3. การได้รับ Fibrinolytic agent ภายใน 30 นาที นับตั้งแต่ระยะเวลาที่ผู้ป่วยได้รับการ ตรวจรักษาที่ ER/OPD และรับไว้ในโรงพยาบาล จนถึงเวลาที่ผู้ป่วยได้รับยา Fibrinolytic agent', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'opitemrece', 'drugitems', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 55', 'registered-2026.1', NULL, 'registered'),
    ('DH0201', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): Percent of mortality', 'ร้อยละการเสียชีวิตของผู้ป่วยที่ทำ Coronary Artery Bypass Graft (CABG)', '1. ผู้ป่วยที่ทำ CABG หมายถึง ผู้ป่วยที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือด หัวใจซึ่งจำเป็นต้องได้รับการตรวจรักษาด้วยการทำ CABG จากทุกหอผู้ป่วยใน โดยมีรหัส โรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วยที่ทำ CABG หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วยที่ได้รับ การผ่าตัดทำทางเบี่ยงหลอดเลือดหัวใจ (Coronary Artery Bypass Graft: CABG) 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยใน ออกจากโรงพยาบาล ในทุกสถานะ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 57', 'registered-2026.1', NULL, 'registered'),
    ('DH0202', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis', 'ร้อยละการได้รับยาปฏิชีวนะแบบป้องกันในการผ่าตัด Coronary Artery Bypass Graft (CABG)', '1. ผู้ป่วยที่ทำ CABG หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล (admit) นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือดหัวใจซึ่ง จำเป็นต้องได้รับการตรวจรักษาด้วยการทำ CABG โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับยาปฏิชีวนะแบบป้องกันในการผ่าตัด CABG หมายถึง การที่ผู้ป่วยได้รับยา ปฏิชีวนะในช่วงระยะเวลาภายใน 1 ชั่วโมงก่อนลงมีดผ่าตัด (กรณีเป็นการให้ยาแบบ IV drip ให้เริ่มนับเวลาเมื่อ drip ยาหมด)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 58', 'registered-2026.1', NULL, 'registered'),
    ('DH0203', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection', 'ร้อยละการติดเชื้อแผลผ่าตัด Coronary Artery Bypass Graft (CABG)', '1. ผู้ป่วยที่ทำ CABG หมายถึง ผู้ป่วยที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือด หัวใจ ซึ่งจำเป็นต้องได้รับการตรวจรักษาด้วยการทำ CABG โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การติดเชื้อแผลผ่าตัด CABG หมายถึง เฉพาะการติดเชื้อครั้งแรกของแผลผ่าตัด CABG ภายในช่วงระยะเวลา 30 วันหลังการผ่าตัด', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 59', 'registered-2026.1', NULL, 'registered'),
    ('DH0204', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Coronary Artery Bypass Graft (CABG): percent of 30-days hospital mortality', 'ร้อยละการเสียชีวิตของผู้ป่วยที่ทำCABG ภายใน30 วันหลังรับการรักษาแบบผู้ป่วยในวันแรก', '1) ผู้ป่วยที่ทำ CABG หมายถึง ผู้ป่วยที่มี Principle diagnosis (Pdx) เป็นโรคหลอด เลือดหัวใจซึ่งจำเป็นต้องได้รับการตรวจรักษาด้วยการผ่าตัดทำทางเบี่ยงหลอดเลือด หัวใจ (Coronary Artery Bypass Graft: CABG) จากทุกหอผู้ป่วย โดยเป็นการ admit ครั้งแรกหลังทำหัตถการ โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2) การเสียชีวิตของผู้ป่วยที่ทำ CABG ภายใน 30 วันหลังเข้ารับการรักษาแบบผู้ป่วยใน หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วยที่ได้รับการผ่าตัดทำทางเบี่ยงหลอดเลือด หัวใจ (CABG) ภายในระยะเวลา 30 วัน ทั้งขณะรับการรักษาในโรงพยาบาลและ หลังจากจำหน่ายออกจากโรงพยาบาล นับจากวันที่เข้ารับการรักษาแบบผู้ป่วยในวันแรก ยกเว้นเป็นการเสียชีวิตจากสาเหตุที่เกิดจากอุบัติเหตุ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 60', 'registered-2026.1', NULL, 'registered'),
    ('DH0301', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Fraction (HFREF) received Angiotensin II Converting Enzyme inhibitors (ACEIs) or Angiotensin II Receptor Blockers (ARBs) or Mineralocorticoid Receptor Antagonists (MRA)', 'ร้อยละผู้ป่วยในที่มีหัวใจล้มเหลวที่เป็น Heart Failure Reduced Ejection Fraction (HFREF) ได้รับยา Angiotensin II Converting Enzyme inhibitors (ACEIs) หรือ Angiotensin II Receptor Blockers (ARBs) หรือ Mineralocorticoid Receptor Antagonists (MRA)', '1. ผู้ป่วย Heart failure หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาลนาน ตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคหัวใจล้มเหลว โดยมีรหัส โรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ผู้ป่วย Heart Failure Reduced Ejection Fraction (HFREF) หมายถึง ผู้ป่วย Heart failure ที่ได้รับการตรวจด้วยเครื่อง echocardiogram แล้วพบว่ามี LVEF < 40% (โรงพยาบาลต้องมีเครื่อง echocardiogram) 3. เป็นผู้ป่วย HFREF ที่ไม่มีข้อห้าม หรือข้อจำกัด (ผู้ป่วยแพ้ยา, ผู้ป่วยโรคหอบหืด, ผู้ป่วยที่ มีการเต้นหัวใจช้ากว่า 50 ครั้งต่อนาที, และความดันโลหิต systolic ต่ำกว่า 90 mmHg ของการให้ยานี้ และได้รับ ACE inhibitors หรือ ARBs หรือ MRA ในการรักษา)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 61', 'registered-2026.1', NULL, 'registered'),
    ('DH0302', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Heart failure: Percent of smoking cessation advice given', 'ร้อยละของผู้ป่วยที่มีภาวะหัวใจล้มเหลว ที่สูบบุหรี่ ได้รับการแนะนำให้งดบุหรี่ ระหว่างการ อยู่โรงพยาบาล', '1. ผู้ป่วย Heart failure หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นาน ตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคหัวใจล้มเหลว โดยมีรหัสโรค อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การแนะแนวให้อดหรือเลิกบุหรี่ หมายถึง การให้คำแนะนำ/การปรึกษา ให้ความรู้ ความ เข้าใจเกี่ยวกับผลกระทบของบุหรี่ต่อภาวะของโรคที่เป็น เพื่อให้ผู้ป่วยโรคหัวใจล้มเหลวที่มี ประวัติสูบบุหรี่ภายใน 1 ปี ก่อนการได้รับการตรวจรักษาและรับไว้ในโรงพยาบาล อดหรือ เลิกบุหรี่', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 63', 'registered-2026.1', NULL, 'registered'),
    ('DH0401', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Atrial fibrillation: Percent of patient received Warfarin within target', 'ร้อยละของผู้ป่วย AF ได้รับยา Warfarin มีระดับ INR ตามเป้าหมายการรักษา', '1. ผู้ป่วย Atrial fibrillation หมายถึงผู้ป่วยที่มี Principal diagnosis (Pdx) เป็นโรค Atrial Fibrillation โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ที่มาตรวจติดตาม ที่แผนกผู้ป่วยนอก หรือ Warfarin Clinic 2. เป็นผู้ป่วย Atrial fibrillation ที่ไม่มีข้อห้ามหรือข้อจำกัดของการให้ยานี้ และได้รับยา Warfarin ในการรักษา 3. ค่า INR ระดับเป้าหมาย หมายถึง ค่าอัตราส่วนของ PT ของผู้ป่วย Atrial fibrillation ต่อผู้ป่วยปกติอยู่ในช่วง 2-3 ตามเป้าหมายการรักษา 4. ผู้ป่วย AF ที่ได้รับยา Warfarin มีระดับตามเป้าหมายการรักษา หมายถึง ผู้ป่วย AF ที่ ได้รับยา Warfarin ที่มีค่า INR ระดับเป้าหมายในทุกครั้งของการตรวจรักษาในไตรมาสนั้น', '(a/b) x100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 64', 'registered-2026.1', NULL, 'registered'),
    ('DH0402', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Atrial Fibrillation: Percent of major bleeding (intracranial hemorrhage)', 'ร้อยละของการเกิด adverse event (major bleeding) ของผู้ป่วย AF ที่ได้รับยา Warfarin', '1. ผู้ป่วย Atrial fibrillation หมายถึง ผู้ป่วยที่มี Principal diagnosis (Pdx) เป็นโรค Atrial Fibrillation โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD9 ดังที่ระบุไว้นี้ที่มาตรวจ ติดตามที่แผนกผู้ป่วยนอก หรือ Warfarin Clinic 2. เป็นผู้ป่วย Atrial fibrillation ที่ไม่มีข้อห้ามหรือข้อจำกัดของการให้ยานี้ และได้รับยา Warfarin ในการรักษา 3. การเกิด adverse event หมายถึง major bleeding (intracranial hemorrhage and hemorrhage need blood transfusion)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'clinicmember', 'ovstdiag', 'opitemrece', 'drugitems', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 66', 'registered-2026.1', NULL, 'registered'),
    ('DM0101', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'GDD: Percent of children with global development delay that improved after intervented', 'ร้อยละเด็กพัฒนาการล่าช้ารอบด้าน (Global development delay: GDD) มีพัฒนาการดี ขึ้น', '1. เด็กพัฒนาการล่าช้ารอบด้าน หมายถึง เด็กที่ได้รับการวินิจฉัยจากแพทย์เป็น Global developmental delay (F83) หรือ R62 อาจมีหรือไม่มีโรคร่วม 2. พัฒนาการดีขึ้น หมายถึง พัฒนาการด้านที่ล่าช้าดีขึ้นด้านใดด้านหนึ่งใน 5 ด้าน โดยไม่มีด้านใดลดลงภายใน 6 เดือนหลังการรักษา ประเมินโดยใช้เครื่องมือตามบริบทและ ระดับความรุนแรงของโรคตามเกณฑ์ 3. พัฒนาการ 5 ด้าน หมายถึง 1) ด้านการเคลื่อนไหว (gross motor) 2) ด้านการใช้ กล้ามเนื้อมัดเล็กและสติปัญญา (fine motor) 3) ด้านการเข้าใจภาษา (receptive language) 4) ด้านการใช้ภาษา (expressive language) 5) ด้านการช่วยเหลือตนเองและ สังคม (personal and social)', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 151', 'registered-2026.1', NULL, 'registered'),
    ('DM0102', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'GDD: Percent of children with Global development delay that improved after intervented with TEDA4I', 'ร้อยละเด็กพัฒนาการล่าช้ารอบด้าน (Global development delay: GDD) มีพัฒนาการดี ขึ้น จากการประเมินโดยใช้เครื่องมือ TEDA4I', '1. เด็กพัฒนาการล่าช้ารอบด้าน หมายถึง เด็กที่ได้รับการวินิจฉัยจากแพทย์เป็น Global developmental delay (F83) หรือ R62 อาจมีหรือไม่มีโรคร่วม 2. พัฒนาการดีขึ้น หมายถึง พัฒนาการด้านที่ล่าช้าดีขึ้นด้านใดด้านหนึ่งใน 5 ด้าน โดยไม่มีด้านใดลดลงภายใน 6 เดือนหลังการรักษา ประเมินโดยใช้เครื่องมือ TEDA4I 3. พัฒนาการ 5 ด้าน หมายถึง 1) ด้านการเคลื่อนไหว (gross motor) 2) ด้านการใช้ กล้ามเนื้อมัดเล็กและสติปัญญา (fine motor) 3) ด้านการเข้าใจภาษา (receptive language) 4) ด้านการใช้ภาษา (expressive language) 5) ด้านการช่วยเหลือตนเองและ สังคม (personal and social)', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 152', 'registered-2026.1', NULL, 'registered'),
    ('DM0103', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'GDD: Percent of children with global development delay that improved after intervented', 'ร้อยละเด็กพัฒนาการล่าช้ารอบด้าน (Global development delay: GDD) คงอยู่ใน ระบบการศึกษาได้อย่างน้อย 1 ปี', '1. เด็กพัฒนาการล่าช้ารอบด้าน หมายถึง เด็กที่ได้รับการวินิจฉัยจากแพทย์ Global developmental delay (F83) หรือ R62 อาจมีหรือไม่มีโรคร่วม ที่มีอายุอยู่ระหว่าง 3 ถึง 5 ปี 11 เดือน 29 วัน 2. คงอยู่ในระบบการศึกษาได้อย่างน้อย 1 ปี หมายถึง หลังจากได้เข้าสู่ระบบการศึกษา เช่น การเข้าเรียนในโรงเรียนปกติ โรงเรียนเรียนร่วมหรือโรงเรียนการศึกษาพิเศษ หรือศูนย์ พัฒนาเด็กเล็ก ได้อย่างน้อย 1 ปี โดยไม่ถูกส่งกลับหรือถูกปฏิเสธด้วยปัญหาพัฒนาการหรือ พฤติกรรม', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 153', 'registered-2026.1', NULL, 'registered'),
    ('DM0201', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement', 'ร้อยละเด็กออทิสติกมีพัฒนาการด้านภาษาและสังคมดีขึ้น', '1. เด็กออทิสติก หมายถึง เด็กทุกช่วงอายุที่ได้รับการวินิจฉัย Autism Spectrum Disorder (F84.0-F84.9) จากแพทย์ 2. พัฒนาการทางภาษาและสังคมดีขึ้น หมายถึง พัฒนาการด้านการเข้าใจภาษา (receptive language) หรือด้านการใช้ภาษา (expressive language) ร่วมกับด้านการ ช่วยเหลือตัวเองและสังคม (personal and social) ดีขึ้น ประเมินโดยใช้เครื่องมือตาม บริบทและระดับความรุนแรงของโรคตามเกณฑ์', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 154', 'registered-2026.1', NULL, 'registered'),
    ('DM0202', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement with TEDA4I', 'ร้อยละเด็กออทิสติกมีพัฒนาการด้านภาษาและสังคมดีขึ้น จากการประเมินโดยใช้เครื่องมือ TEDA4I', '1. เด็กออทิสติก หมายถึง เด็กทุกช่วงอายุที่ได้รับการวินิจฉัย Autism spectrum disorder (F84.0-F84.9) จากแพทย์ 2. พัฒนาการทางภาษาและสังคมดีขึ้น หมายถึง พัฒนาการด้านการเข้าใจภาษา (receptive language) หรือด้านการใช้ภาษา (expressive language) ร่วมกับด้านการ ช่วยเหลือตัวเองและสังคม (personal and social) ดีขึ้น ประเมินโดยใช้เครื่องมือ TEDA4I', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 155', 'registered-2026.1', NULL, 'registered'),
    ('DM0203', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'ASD: Percent of children with autism spectrum disorder (ASD) that are included in educational system for at least 1 year', 'ร้อยละเด็กออทิสติกคงอยู่ในระบบการศึกษาได้อย่างน้อย 1 ปี', '1. เด็กออทิสติก หมายถึง เด็กอายุ 3-14 ปี 11 เดือน 29 วัน ที่ได้รับการวินิจฉัย Autism Spectrum Disorder (F84.0-F84.9) จากแพทย์ 2. คงอยู่ในระบบการศึกษาได้อย่างน้อย 1 ปี หมายถึง หลังจากได้เข้าสู่ระบบการศึกษา เช่น การเข้าเรียนในโรงเรียนปกติ โรงเรียนเรียนร่วมหรือโรงเรียนการศึกษาพิเศษ หรือศูนย์ พัฒนาเด็กเล็ก หรือการศึกษานอกระบบและการศึกษาตามอัธยาศัย (กศน.) ได้อย่างน้อย 1 ปี โดยไม่ถูกส่งกลับหรือถูกปฏิเสธด้วยปัญหาพัฒนาการหรือพฤติกรรม', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 156', 'registered-2026.1', NULL, 'registered'),
    ('DM0301', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented', 'ร้อยละผู้ป่วยเด็กสมองพิการ (Cerebral palsy) มีพัฒนาการดีขึ้น', '1. เด็กสมองพิการ หมายถึง เด็กที่ได้รับการวินิจฉัยจากแพทย์เป็น Cerebral palsy อาจมี หรือไม่มีโรคร่วม 2. พัฒนาการดีขึ้น หมายถึง พัฒนาการด้านที่ล่าช้าด้านใดด้านหนึ่งใน 5 ด้านดีขึ้นโดยไม่มี ด้านใดลดลง ภายใน 6 เดือน หลังการรักษา ประเมินโดยใช้เครื่องมือตามบริบทและระดับ ความรุนแรงของโรคตามเกณฑ์ 3. พัฒนาการ 5 ด้าน หมายถึง 1) ด้านการเคลื่อนไหว (gross motor) 2) ด้านการใช้ กล้ามเนื้อมัดเล็กและสติปัญญา (fine motor) 3) ด้านการเข้าใจภาษา (receptive language) 4) ด้านการใช้ภาษา (expressive language) 5) ด้านการช่วยเหลือตนเองและ สังคม (personal and social)', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 157', 'registered-2026.1', NULL, 'registered'),
    ('DM0302', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented', 'ร้อยละผู้ป่วยเด็กสมองพิการ (Cerebral palsy) มีพัฒนาการดีขึ้น จากการประเมินโดยใช้ เครื่องมือ TEDA4I', '1. เด็กสมองพิการ หมายถึง เด็กที่ได้รับการวินิจฉัยจากแพทย์เป็น Cerebral palsy อาจมี หรือไม่มีโรคร่วม 2. พัฒนาการดีขึ้น หมายถึง พัฒนาการด้านที่ล่าช้าด้านใดด้านหนึ่งใน 5 ด้านดีขึ้นโดยไม่มี ด้านใดลดลง ภายใน 6 เดือน หลังการรักษา โดย ประเมินโดยใช้เครื่องมือ TEDA4I 3. พัฒนาการ 5 ด้าน หมายถึง 1) ด้านการเคลื่อนไหว (gross motor) 2) ด้านการใช้ กล้ามเนื้อมัดเล็กและสติปัญญา (fine motor) 3) ด้านการเข้าใจภาษา (receptive language) 4) ด้านการใช้ภาษา (expressive language) 5) ด้านการช่วยเหลือตนเองและ สังคม (personal and social)', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 158', 'registered-2026.1', NULL, 'registered'),
    ('DM0401', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Child and adolescent psychiatry: Percent of children with Attention- Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6', 'ร้อยละผู้ป่วยเด็กสมาธิสั้นรายใหม่อาการดีขึ้นภายใน 6 เดือน', 'ผู้ป่วยสมาธิสั้น หมายถึง ผู้ป่วยที่ได้รับการวินิจฉัยเป็นโรคสมาธิสั้น (F90) อาการดีขึ้น หมายถึง คะแนนจากแบบวัด SNAP-IV ฉบับผู้ปกครองลดลงด้านใดด้านหนึ่ง หลังรับการรักษา 6 เดือน', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 159', 'registered-2026.1', NULL, 'registered'),
    ('DM0402', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Child and adolescent psychiatry: Percent of children and adolescents with Major Depressive Disorder (MDD) improved after intervented for', 'ร้อยละผู้ป่วยเด็กซึมเศร้าอาการดีขึ้นภายใน 6 เดือน', 'ผู้ป่วยซึมเศร้า หมายถึง เด็กและวัยรุ่นอายุระหว่าง 6-17 ปี 11 เดือน 29 วัน ที่ได้รับการ วินิจฉัยโรคซึมเศร้า (F32.0-F32.9, F33.0-F33.9, F34.1) อาการดีขึ้น หมายถึง อาการสงบ (clinical remission) หลังรักษาครบ 6 เดือน หรือ คะแนนจากแบบประเมิน Childhood depressive inventory (CDI) น้อยกว่าหรือเท่ากับ 15 คะแนน', '(a/b) ข 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 160', 'registered-2026.1', NULL, 'registered'),
    ('DN0101', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Stroke: Percent of mortality', 'ร้อยละการเสียชีวิตของผู้ป่วย Stroke', '1. ผู้ป่วย Stroke หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือดสมอง โดยมีรหัสโรคอยู่ ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วย Stroke หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วย Stroke 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยใน ออกจากโรงพยาบาล ในทุกสถานะ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 67', 'registered-2026.1', NULL, 'registered'),
    ('DN0102', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Ischemic stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission', 'ร้อยละผู้ป่วยโรคสมองขาดเลือดที่ได้รับยาต้านเกล็ดเลือด (Antiplatelet) ภายใน 2 วัน หลังเข้ารับการรักษาในโรงพยาบาล', '1. ผู้ป่วยโรคสมองขาดเลือดจากภาวะหลอดเลือดสมองตีบหรืออุดตัน (Ischemic stroke) หมายถึง ผู้ป่วยใน อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคสมองขาดเลือด ที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับยาต้านเกล็ดเลือด หมายถึง การที่ผู้ป่วยได้รับการรักษาด้วยการให้ Antiplatelet drugs ภายใน 48 ชั่วโมงหลังเกิดอาการ (นับระยะเวลาตั้งแต่เริ่มมีอาการ และเข้ารับการรักษาในโรงพยาบาล จนถึงเวลาที่ได้รับยา) 3. ผู้ป่วยในที่เข้าเกณฑ์ คือ ผู้ป่วยอายุตั้งแต่ 18 ปีขึ้นไป ที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 2-120 วัน ซึ่งไม่อยู่ในสถานะประคับประคองระยะสุดท้าย หรือถูกคัดเลือกเข้า โครงการวิจัยทางคลินิก หรือ Admit เพื่อทำการผ่าตัดหลอดเลือดแดงคาโรติดแบบไม่ เร่งด่วน หรือไม่ใช่ผู้ป่วยที่ได้รับยาต้านภาวะแข็งตัวของเลือดทางหลอดเลือดภายใน 24 ชั่วโมงก่อนมาถึง โรงพยาบาล หรือไม่ใช่ผู้ป่วยที่มีหลักฐานว่ามีเหตุผลอันสมควรที่ไม่ได้รับ ยาต้านเกล็ดเลือดภายใน 2 วัน หลังเข้ารับการรักษาในโรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 68', 'registered-2026.1', NULL, 'registered'),
    ('DN0103', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Ischemic stroke: Percent of Antiplatelet or Anticoagulant therapy prescribed at discharge', 'ร้อยละผู้ป่วยโรคหลอดเลือดสมองขาดเลือดที่ได้รับการสั่งยาต้านเกล็ดเลือด (Antiplatelet) หรือยาต้านภาวะแข็งตัวของเลือด (Anticoagulant) ขณะจำหน่ายออกจากโรงพยาบาล', '1. ผู้ป่วยโรคหลอดเลือดสมองขาดเลือด (Ischemic stroke) หมายถึง ผู้ป่วยใน อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือดสมองขาดเลือด ที่มีรหัสโรคตาม ICD- 10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับยาต้านเกล็ดเลือดหรือยาต้านภาวะแข็งตัวของเลือด ขณะจำหน่ายออกจาก โรงพยาบาล หมายถึง การที่ผู้ป่วยได้รับ Antiplatelet or Anticoagulant Drugs ขณะ จำหน่ายออกจากโรงพยาบาล โดยนับเฉพาะการจำหน่ายมีชีวิตด้วยสถานะการอนุญาตให้ กลับบ้าน (improve) 3. ผู้ป่วยในที่เข้าเกณฑ์ คือ ผู้ป่วยใน อายุ ≥ 18 ปีที่รับไว้นอนในโรงพยาบาล นานไม่เกิน 120 วัน ซึ่งไม่อยู่ในการประคับประคองระยะสุดท้ายหรือถูกคัดเลือกเข้าโครงการวิจัย หรือ admit เพื่อทำการผ่าตัดหลอดเลือดแดงคาโรติดแบบไม่เร่งด่วน หรือไม่ใช่ผู้ป่วยที่มีหลักฐาน ว่ามีเหตุผลอันสมควรที่ไม่ให้ยาต้านเกล็ดเลือดหรือยากันเลือดเป็นลิ่มขณะจำหน่ายออกจาก โรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 69', 'registered-2026.1', NULL, 'registered'),
    ('DN0104', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Ischemic stroke: Percent of patient with Atrial fibrillation/Flutter receiving Anticoagulation therapy', 'ร้อยละผู้ป่วยโรคหลอดเลือดสมองขาดเลือดที่มีภาวะหัวใจห้องบนเต้นระริกหรือหัวใจห้อง บนเต้นระรัวได้รับยาต้านภาวะแข็งตัวของเลือด (Anticoagulant)', '1. ผู้ป่วยโรคหลอดเลือดสมอง (Stroke) หมายถึง ผู้ป่วยใน อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือดสมอง ที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับยาต้านภาวะแข็งตัวของเลือด หมายถึง การให้ Anticoagulant ในการรักษาแก่ ผู้ป่วยโรคหลอดเลือดสมองขาดเลือดที่มีภาวะหัวใจห้องบนเต้นระริกหรือหัวใจห้องบนเต้น ระรัว ที่รับไว้นอนในโรงพยาบาล นานไม่เกิน 120 วัน ไม่อยู่ในการประคับประคองระยะ สุดท้าย หรือถูกคัดเลือกเข้าโครงการวิจัยหรือ admit เพื่อทำการผ่าตัดหลอดเลือดแดงคาโร ติดแบบไม่เร่งด่วน หรือไม่ใช่ผู้ป่วยที่มีหลักฐานว่ามีเหตุผลอันสมควรที่ไม่ให้ยากันเลือดเป็น ลิ่ม และให้ยาในขณะจำหน่ายออกจากโรงพยาบาล โดยนับเฉพาะการจำหน่ายมีชีวิตด้วย สถานะการอนุญาตให้กลับบ้าน (improve)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 70', 'registered-2026.1', NULL, 'registered'),
    ('DN0105', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Stroke: Percent of patients who were given stroke education during their hospital stay', 'ร้อยละผู้ป่วยโรคหลอดเลือดสมองได้รับความรู้ในขณะอยู่ที่โรงพยาบาล', '1. ผู้ป่วยโรคหลอดเลือดสมอง (Stroke) หมายถึง ผู้ป่วยใน อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือดสมอง ที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับความรู้ หมายถึง การที่ผู้ป่วยโรคหลอดเลือดสมองขาดเลือดหรือโรคหลอดเลือด สมองแตก หรือผู้ดูแล ได้รับคำแนะนำ/ความรู้ ระหว่างอยู่โรงพยาบาล ได้แก่ การแจ้งระบบ การแพทย์ฉุกเฉิน การมาตรวจติดตามหลังจำหน่ายออกจากโรงพยาบาล ยาที่ได้รับขณะ จำหน่ายออกจากโรงพยาบาล ปัจจัยเสี่ยงของโรคหลอดเลือดสมอง รวมทั้งอาการเตือน และอาการของโรคหลอดเลือดสมอง', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 71', 'registered-2026.1', NULL, 'registered'),
    ('DN0106', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Stroke: Percent of treatment, physiotherapy or rehabilitation in stroke or paralytic syndrome within 72 hours', 'ร้อยละผู้ป่วยโรคหลอดเลือดสมองได้รับการประเมินและได้รับการรักษาด้านเวชศาสตร์ ฟื้นฟูเพื่อฟื้นฟูสมรรถภาพภายใน 72 ชั่วโมง', '1. ผู้ป่วยโรคหลอดเลือดสมอง (Stroke) หมายถึง ผู้ป่วยใน อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคหลอดเลือดสมอง ที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การประเมินด้านเวชศาสตร์ฟื้นฟูเพื่อฟื้นฟูสมรรถภาพและได้รับการรักษาทางเวชศาสตร์ ฟื้นฟู ภายใน 72 ชั่วโมงหลังรับไว้ในโรงพยาบาล หมายถึง การที่ผู้ป่วย Stroke ซึ่งไม่มีภาวะ ที่คุกคามชีวิตแล้ว ได้รับการประเมินด้านเวชศาสตร์ฟื้นฟูและได้รับการรักษาทางเวชศาสตร์ ฟื้นฟูเพื่อป้องกันภาวะแทรกซ้อน ลดความพิการ และให้กลับมาช่วยตัวเองได้มากที่สุด ภายใน 72 ชั่วโมง หลังรับไว้ในโรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 72', 'registered-2026.1', NULL, 'registered'),
    ('DN0107', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Stroke: Percent of unplanned re-admission of stroke within 28 days', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย Stroke ด้วยโรคหลอดเลือดสมองเดิม ภายใน 28 วัน โดยไม่ได้วางแผน', '1. ผู้ป่วย Stroke หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล (admit) นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคหลอด เลือดสมอง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การรับกลับเข้าโรงพยาบาลของผู้ป่วย Stroke ภายใน 28 วัน โดยไม่ได้วางแผน หมายถึง ผู้ป่วย Stroke ที่รับกลับเข้าโรงพยาบาลหลังจำหน่ายจากโรงพยาบาลภายใน 28 วัน โดย ไม่ได้วางแผน 3. การจำหน่ายออกจากโรงพยาบาล หมายถึง ผู้ป่วย Stroke ที่จำหน่ายมีชีวิตออกจาก โรงพยาบาล ด้วยสถานะการอนุญาตให้กลับบ้าน (status=improve) ยกเว้นผู้ป่วยที่ไป รักษาที่โรงพยาบาลอื่น หรือไม่ยินยอมรับการรักษาตามแผน', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 73', 'registered-2026.1', NULL, 'registered'),
    ('DN0109', 'D', 'ratio', 'lower-is-better', 'monthly', 'Disease', 'Stroke: Average length of stay', 'ระยะเวลาวันนอนเฉลี่ยของผู้ป่วย Stroke', '1. ผู้ป่วย Stroke หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล (admit) นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคหลอด เลือดสมอง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ระยะเวลาวันนอนเฉลี่ยผู้ป่วย Stroke หมายถึง ผลรวมของจำนวนวันนอนที่ผู้ป่วย Stroke นอนพักรักษาตัวในโรงพยาบาลโดยนับตั้งแต่วันที่รับไว้จนถึงวันที่จำหน่ายออกจาก โรงพยาบาลทุกรายที่จำหน่ายในเดือนนั้น หารด้วยจำนวนผู้ป่วย Stroke ที่จำหน่ายออก จากโรงพยาบาลในเดือนนั้น 3. ผู้ป่วย Stroke ที่จำหน่ายออกจากโรงพยาบาล หมายถึง ผู้ป่วย Stroke ที่จำหน่ายออก จากโรงพยาบาลทุกสถานะการจำหน่าย', 'a/b', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 74', 'registered-2026.1', NULL, 'registered'),
    ('DN0110', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Ischemic Stroke: Percent of time to Thrombolytic administration agents within 60 minutes of arrival', 'ร้อยละผู้ป่วย Ischemic stroke ที่ได้รับ Thrombolytic agents ภายใน 60 นาที เมื่อ มาถึงโรงพยาบาล', '1. ผู้ป่วย Ischemic stroke หมายถึง ผู้ป่วยที่มี Principal diagnosis (Pdx) เป็นโรคเส้น เลือดในสมองตีบหรืออุดตัน โดยเป็นโรคที่มีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ ระบุไว้นี้ 2. ผู้ป่วย Ischemic stroke ที่ได้รับ Thrombolytic agents ภายใน 60 นาทีเมื่อแรกรับ หมายถึง ผู้ป่วยที่ไม่มีข้อห้ามของการให้ยานี้ และ ได้รับ Thrombolytic agents ในการ รักษาภายใน 60 นาที นับตั้งแต่ระยะเวลาที่ผู้ป่วยได้รับการตรวจรักษาที่ ER/OPD และรับ ไว้ในโรงพยาบาล จนถึงระยะเวลาที่ผู้ป่วยได้รับยา (door to needle time)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'er_regist', 'operation_list', 'operation_detail', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 75', 'registered-2026.1', NULL, 'registered'),
    ('DN0301', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Head Injury: Percent of unplanned re-admission of Craniotomy within', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วยที่ทำ Craniotomy โดยมีสาเหตุจากการ บาดเจ็บที่ศีรษะ ภายใน 28 วัน โดยไม่ได้วางแผน', '1. ผู้ป่วยที่ทำ Craniotomy หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล (admit) ≥4 ชั่วโมง) ที่มี Principal diagnosis (Pdx) เป็นโรคบาดเจ็บที่ศีรษะซึ่งจำเป็นต้อง ได้รับการทำ Craniotomy โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การรับกลับเข้าโรงพยาบาลของผู้ป่วยที่ทำ Craniotomy ภายใน 28 วัน หมายถึง ผู้ป่วย ที่ทำ Craniotomy ที่รับกลับเข้าโรงพยาบาลหลังจำหน่ายจากโรงพยาบาลภายใน 28 วัน โดยไม่ได้วางแผน 3. การจำหน่ายออกจากโรงพยาบาล หมายถึง ผู้ป่วยที่ทำ Craniotomy ที่จำหน่ายมีชีวิต ออกจากโรงพยาบาล ด้วยสถานะการอนุญาตให้กลับบ้าน (status = improve) ยกเว้น ผู้ป่วยที่ไปรักษาที่โรงพยาบาลอื่น หรือไม่ยินยอมรับการรักษาตามแผน', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 76', 'registered-2026.1', NULL, 'registered'),
    ('DN0302', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Head Injury: Percent of mortality within 48 hours', 'ร้อยละของผู้ป่วยบาดเจ็บที่ศีรษะที่เสียชีวิตภายใน 48 ชั่วโมง ภายหลังการบาดเจ็บ (เฉพาะผู้ป่วยบาดเจ็บต่อสมอง)', '1. ผู้ป่วย Head Injury หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน รพ. (admit) นาน ตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคของการบาดเจ็บที่ศีรษะซึ่ง เกิดจากแรงที่เข้ามากระทบต่อศีรษะและร่างกายแล้วก่อให้เกิดความบาดเจ็บต่อหนังศีรษะ กะโหลกศีรษะ และ สมอง กับเส้นประสาทสมอง (อ้างอิงนิยามจากแนวทางการ รักษาพยาบาลผู้ป่วยทางศัลยกรรม โดยราชวิทยาลัยศัลยแพทย์แห่งประเทศไทย ร่วมกับ สมาคมประสาทศัลยศาสตร์แห่งประเทศไทย) โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การป่วยตายจากการบาดเจ็บที่ศีรษะ (เฉพาะผู้ป่วยบาดเจ็บต่อสมอง) หมายถึง การตาย จากทุกสาเหตุภายใน 48 ชั่วโมง หลังจากเกิดการบาดเจ็บที่ศีรษะ', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 77', 'registered-2026.1', NULL, 'registered'),
    ('DN0303', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Head Injury: Percent of patient underwent craniotomy for Intracranial', 'ร้อยละการผ่าตัดสมองในผู้ป่วยบาดเจ็บที่ศีรษะที่มี Intracranial injury', '1. ผู้ป่วย Intracranial Injury หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล (admit) นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคของการ บาดเจ็บที่ศีรษะชนิดที่มีการตกเลือดหรือมีความผิดปกติภายในกะโหลกศีรษะ โดยมีรหัสโรค ตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. Intracranial injury craniotomy หมายถึง การผ่าตัดสมองในผู้ป่วยบาดเจ็บที่ศีรษะที่ มีการตกเลือดหรือมีความผิดปกติภายในกะโหลกศีรษะซึ่งต้องให้การรักษาโดยการผ่าตัด', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'operation_list', 'operation_detail', 'operation_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 78', 'registered-2026.1', NULL, 'registered'),
    ('DO0202', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Hip arthroplasty: Percent of patients who received antibiotic prophylaxis in Hip arthroplasty', 'ร้อยละของผู้ป่วยผ่าตัดเปลี่ยนข้อสะโพก ได้รับ prophylactic antibiotic', '1. ผู้ป่วยผ่าตัดเปลี่ยนข้อสะโพก หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาลนานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับข้อ สะโพกซึ่งจำเป็นต้องให้การรักษาโดยการผ่าตัดเปลี่ยนข้อสะโพกโดยมีรหัสโรคอยู่ในกลุ่ม รหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับยาปฏิชีวนะแบบป้องกันในการผ่าตัดเปลี่ยนข้อสะโพก หมายถึง การที่ผู้ป่วย ได้รับยาปฏิชีวนะในช่วงระยะเวลาภายใน 1 ชั่วโมงก่อนลงมีดผ่าตัด (กรณีเป็นการให้ยา แบบ Intravenous drip ให้เริ่มนับเวลาเมื่อ drip ยาหมด)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 114', 'registered-2026.1', NULL, 'registered'),
    ('DO0204', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Hip arthroplasty: Percent of hip arthroplasty associated infection within 1 Year', 'ร้อยละการติดเชื้อแผลผ่าตัดเปลี่ยนข้อสะโพกภายใน 1 ปี', '1. ผู้ป่วยผ่าตัดเปลี่ยนข้อสะโพก หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับข้อสะโพก ซึ่งจำเป็นต้องให้การรักษาโดยการ ผ่าตัดเปลี่ยนข้อสะโพก โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. เป็นการติดเชื้อในข้อสะโพกหลังการผ่าตัดเปลี่ยนข้อสะโพก ภายในช่วงระยะเวลา 1 ปี หลังการผ่าตัด นับเฉพาะการติดเชื้อครั้งแรก', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 115', 'registered-2026.1', NULL, 'registered'),
    ('DO0205', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Hip arthroplasty: Percent of hip arthroplasty associated infection within 90 days', 'ร้อยละการติดเชื้อแผลผ่าตัดเปลี่ยนข้อสะโพกภายใน 90 วัน', '1. ผู้ป่วยผ่าตัดเปลี่ยนข้อสะโพก หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับข้อสะโพก ซึ่งจำเป็นต้องให้การรักษาโดยการ ผ่าตัดเปลี่ยนข้อสะโพก โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. เป็นการติดเชื้อในข้อสะโพกหลังการผ่าตัดเปลี่ยนข้อสะโพก ภายในช่วงระยะเวลา 90 วัน หลังการผ่าตัด นับเฉพาะการติดเชื้อครั้งแรก', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 116', 'registered-2026.1', NULL, 'registered'),
    ('DO0302', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Knee Arthroplasty: Percent of patients who received antibiotic prophylaxis', 'ร้อยละของผู้ป่วยผ่าตัดเปลี่ยนข้อเข่า ได้รับ prophylactic antibiotic', '1. ผู้ป่วยผ่าตัดเปลี่ยนข้อเข่า หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่4ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับข้อเข่าซึ่ง จำเป็นต้องให้การรักษาโดยการผ่าตัดเปลี่ยนข้อเข่าโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การได้รับยาปฏิชีวนะแบบป้องกันในการผ่าตัดเปลี่ยนข้อเข่า หมายถึง การที่ผู้ป่วยได้รับ ยาปฏิชีวนะในช่วงระยะเวลาภายใน 1 ชั่วโมงก่อนลงมีดผ่าตัด (กรณีเป็นการให้ยาแบบ IV drip ให้เริ่มนับเวลาเมื่อ drip ยาหมด)', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 117', 'registered-2026.1', NULL, 'registered'),
    ('DO0303', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Knee Arthroplasty: Percent of surgical infection within 1 year', 'ร้อยละการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่าภายใน 1 ปี', '1. ผู้ป่วยผ่าตัดเปลี่ยนข้อเข่าหมายถึงผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับข้อเข่าซึ่ง จำเป็นต้องให้การรักษาโดยการผ่าตัดเปลี่ยนข้อเข่าโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. เป็นการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่า ภายในระยะเวลา 1 ปี หลังการ ผ่าตัดนับเฉพาะการติดเชื้อครั้งแรก', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 118', 'registered-2026.1', NULL, 'registered'),
    ('DO0304', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Knee Arthroplasty: Percent of surgical infection within 90 days', 'ร้อยละการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่าภายใน 90 วัน', '1. ผู้ป่วยผ่าตัดเปลี่ยนข้อเข่าหมายถึงผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคเกี่ยวกับข้อเข่าซึ่ง จำเป็นต้องให้การรักษาโดยการผ่าตัดเปลี่ยนข้อเข่าโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. เป็นการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่า ภายในระยะเวลา 90 วัน หลังการ ผ่าตัดนับเฉพาะการติดเชื้อครั้งแรก', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'operation_list', 'operation_detail', 'operation_item', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 119', 'registered-2026.1', NULL, 'registered'),
    ('DP0101', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Diabetes in child and adolescent: Percent of good controlled of blood sugar (age < 18 years)', 'ร้อยละของผู้ป่วยเบาหวานชนิดที่ 1 ในเด็กและวัยรุ่นอายุน้อยกว่า 18 ปีที่ควบคุมระดับ น้ำตาลได้ดี', '1. ผู้ป่วยเบาหวานชนิดที่ 1 ในเด็กและวัยรุ่นที่อายุน้อยกว่า 18 ปี หมายถึง ผู้ป่วยที่ได้รับ การวินิจฉัยว่าเป็นเบาหวานชนิดที่ 1 ที่อายุน้อยกว่า 18 ปี เป็นผู้ป่วยที่ขึ้นทะเบียนรับการ รักษากับโรงพยาบาล ซึ่งมารับการตรวจติดตามต่อเนื่องในโรงพยาบาลหรือเครือข่าย สถานพยาบาล > 1 ครั้ง ในช่วงเวลา 6 เดือน หรือ > 3 ครั้งในรอบ 1 ปีที่ผ่านมา โดยเป็น โรคที่มีรหัสโรคตาม ICD -10 TM, ICD-10,ICD-9 ที่ระบุไว้นี้ 2. ผู้ป่วยเบาหวานชนิดที่ 1 ในเด็กและวัยรุ่นอายุน้อยกว่า 18 ปี ที่ควบคุมระดับน้ำตาลได้ดี หมายถึงผู้ป่วยที่มีระดับผลการตรวจ HbA1Cเฉลี่ยใน 1 ปี < 7.5 % 3. ตัวชี้วัดนี้มีวัตถุประสงค์เพื่อส่งเสริมคุณภาพการติดตามระดับน้ำตาลในเลือดตาม มาตรฐานโดยใช้ HbA1C ผ่านกลไกการเทียบคียงตัวชี้วัด โดยแนะนำให้ตรวจอย่างน้อย ปี ละ 2 ครั้ง หากไม่มีผลการตรวจ HbA1c ครั้งล่าสุดในช่วงเวลา 6 เดือนที่ประเมินติดตาม ให้ ยังคงนับผู้ป่วยรายที่ไม่ปรากฏผลการตรวจ HbA1c รวมอยู่ในตัวหาร และแปลผลตัวตั้งที่ไม่ ปรากฎผลตรวจเป็นผู้ป่วยเบาหวานชนิดที่ 1 ในเด็กและวัยรุ่นที่อายุน้อยกว่า 18 ปี ที่ ควบคุมระดับน้ำตาลได้ไม่ดี', '(a/b) x 100', 'a', 'b', ARRAY['person', 'clinicmember', 'ovst', 'ovstdiag', 'opdscreen', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 124', 'registered-2026.1', NULL, 'registered'),
    ('DR0101', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Pneumonia: Percent of mortality after hospital admission', 'ร้อยละการเสียชีวิตหลังจากเข้ารับการรักษาของผู้ป่วยโรคปอดบวม', '1. ผู้ป่วย Pneumonia หมายถึง ผู้ป่วยทุกกลุ่มอายุซึ่งอยู่ในสถานะผู้ป่วยใน (ผู้ป่วยที่รับไว้ นอนพักรักษาในโรงพยาบาล (admit) นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคปอดอักเสบหรือปอดบวม หรือผู้ป่วยที่อยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตหลังจากเข้ารับการรักษาของผู้ป่วยโรคปอดบวม หมายถึง การเสียชีวิตจาก ทุกสาเหตุของผู้ป่วยโรคปอดบวมที่มี Principal Diagnosis (Pdx) ตามที่ระบุไว้ หรือผู้ป่วย ที่มีโรคร่วมหรือโรคแทรกเป็นโรคปอดบวม และ มีสาเหตุการตายจากโรคโรคปอดบวม ซึ่ง อยู่ในสถานะผู้ป่วยใน', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 79', 'registered-2026.1', NULL, 'registered'),
    ('DR0102', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Pneumonia: Percent of unplanned re-admission within 28 days after last discharge', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วยโรคปอดบวมภายใน 28 วัน โดยไม่ได้วางแผน', '1. ผู้ป่วย Pneumonia หมายถึง ผู้ป่วยใน อายุ ≥ 18 ปี (ผู้ป่วยที่รับไว้นอนพักรักษาใน โรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคปอด อักเสบหรือปอดบวม โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การรับกลับเข้าโรงพยาบาลของผู้ป่วยโรคปอดบวมภายใน 28 วัน โดยไม่ได้วางแผน หมายถึง การที่ผู้ป่วยโรคปอดบวมที่รับกลับเข้าโรงพยาบาลหลังจำหน่ายจากโรงพยาบาล ภายใน 28 วัน ด้วยสถานะการอนุญาตให้กลับบ้าน (status=improve) ยกเว้น ผู้ป่วยที่ไป รักษาที่โรงพยาบาลอื่น หรือไม่ยินยอมรับการรักษาตามแผน', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 80', 'registered-2026.1', NULL, 'registered'),
    ('DR0103', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Pneumonia: Percent of smoking cessation advice given', 'ร้อยละผู้ป่วยโรคปอดบวมได้รับคำแนะนำให้อดหรือเลิกบุหรี่ ระหว่างอยู่ในโรงพยาบาล', '1. ผู้ป่วย Pneumonia หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล (admit) นานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal diagnosis (Pdx) เป็นโรคปอดอักเสบ หรือปอดบวม โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การแนะนำให้อดหรือเลิกบุหรี่ หมายถึง การให้คำแนะนำ/การปรึกษา ให้ความรู้ ความ เข้าใจเกี่ยวกับผลกระทบของบุหรี่ต่อภาวะของโรคที่เป็น แก่ผู้ป่วยโรคปอดบวมที่มีประวัติ สูบบุหรี่ภายใน 1 ปีก่อนได้รับการตรวจรักษาในขณะอยู่ในโรงพยาบาล เพื่อให้ผู้ป่วยอดหรือ เลิกบุหรี่', '(a/b) x 100', 'a', 'b', ARRAY['ipt', 'an_stat', 'iptdiag', 'death', 'opitemrece', 'drugitems']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 81', 'registered-2026.1', NULL, 'registered'),
    ('DR0201', 'D', 'percent', 'lower-is-better', 'annual', 'Disease', 'TB: Percent of mortality during 12 months', 'ร้อยละการเสียชีวิตของผู้ป่วยวัณโรคปอดในช่วง 12 เดือน', '1. ผู้ป่วยวัณโรคปอด หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรควัณโรคปอด โดยเป็นโรคที่มีรหัสโรคอยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วยวัณโรคปอดในช่วง 12 เดือน หมายถึง การเสียชีวิตจากทุกสาเหตุ ของผู้ป่วยวัณโรคปอดเสมหะพบเชื้อรายใหม่ ที่อยู่ระหว่างการรักษาวัณโรค ภายในช่วงเวลา 12 เดือนของการรักษา 3. ผู้ป่วยวัณโรคปอดเสมหะพบเชื้อรายใหม่ หมายถึง ผู้ป่วยที่มีการตรวจเสมหะและพบเชื้อ วัณโรคซึ่งเป็นผู้ป่วยวัณโรคปอดระยะแพร่เชื้อรายใหม่ที่ขึ้นทะเบียนรับการรักษา', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 82', 'registered-2026.1', NULL, 'registered'),
    ('DR0202', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'TB: Percentage of people living with HIV having a TB screening', 'ร้อยละของผู้ติดเชื้อเอชไอวี ได้รับการคัดกรองวัณโรคปอด', '1. ผู้ป่วย/ ผู้ติดเชื้อเอชไอวี หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นผู้ป่วย/ ผู้ที่มีผลการตรวจวินิจฉัยโดยมีผลการตรวจเลือด ยืนยันแล้วว่า HIV Positive โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การคัดกรองวัณโรคปอด (Pulmonary TB) หมายถึง การกระทำในข้อใดข้อหนึ่ง และ/ หรือทุกข้อ ดังนี้ (1) การซักประวัติอาการทางคลินิก หรือความเสี่ยงต่อการติดเชื้อวัณโรค เช่น มีอาการไข้ ไอ เบื่ออาหาร น้ำหนักลดเหงื่อออกในเวลากลางคืน ติดต่อกันเกิน 2 สัปดาห์ มีประวัติรักษาวัณโรคมาก่อน เคยอาศัยใกล้ชิดกับผู้ป่วยวัณโรคมาก่อน เคยมี ประวัติต้องขังมาก่อน เป็นต้น (2) ตรวจ CXR (3) ตรวจเสมหะ', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 83', 'registered-2026.1', NULL, 'registered'),
    ('DR0203', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'TB: Percent of treatment success', 'ร้อยละความสำเร็จการรักษาวัณโรค', '1. ผู้ป่วยวัณโรค หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรควัณโรคปอดโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ความสำเร็จของการรักษาวัณโรค เป็นการประเมินผลการรักษาผู้ป่วยวัณโรครายใหม่ที่ขึ้น ทะเบียนรักษาทุกรายย้อนหลัง 1 ปี (12 เดือน) ซึ่งประกอบด้วยจำนวนการรักษาหาย (cure) และ จำนวนการรักษาครบ (complete) รวมกันเมื่อเปรียบเทียบกับจำนวนผู้ป่วยวัณโรคพบเชื้อราย ใหม่ที่ขึ้นทะเบียน 3. การรักษาหาย (cure) หมายถึง ผู้ป่วยวัณโรคเสมหะพบเชื้อที่ได้รับการรักษาจนครบกำหนด และในระหว่างการรักษามีผลการตรวจเสมหะเปลี่ยนเป็นลบ อย่างน้อย 2 ครั้ง โดยเน้นมีการตรวจ ครั้งสุดท้ายเมื่อสิ้นสุดการรักษาเปลี่ยนเป็นลบด้วย 4. การรักษาครบ (complete) หมายถึง ผู้ป่วยวัณโรคเสมหะพบเชื้อ ที่ได้รับการรักษาจนครบ กำหนด ในระหว่างการรักษามีผลการตรวจเสมหะเปลี่ยนเป็นลบ แต่ไม่มีผลกาตรวจครั้งสุดท้าย เมื่อสิ้นสุดการรักษา', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 84', 'registered-2026.1', NULL, 'registered'),
    ('DR0204', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'TB: Percent of TB having a HIV screening', 'ร้อยละผู้ป่วยวัณโรคได้รับการตรวจคัดกรอง HIV', '1. ผู้ป่วยวัณโรค หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรควัณโรคปอดโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ ระบุไว้นี้ 2. การคัดกรอง HIV หมายถึง การคัดกรองภาวะการติดเชื้อเอชไอวี โดยผ่านระบบ Voluntary counseling and testing (VCT) หรือปัจจุบันอาจใช้ DCT (diagnosis counseling and testing) PICT (Provider induce counseling and testing)', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 85', 'registered-2026.1', NULL, 'registered'),
    ('DR0205', 'D', 'percent', 'higher-is-better', 'annual', 'Disease', 'Antiretroviral therapy (ART) TB: Percent of HIV-positive TB patients started on Antiretroviral therapy (ART)', 'ร้อยละผู้ป่วยวัณโรคที่มีผลเลือดเอชไอวีบวกได้รับการรักษาด้วย Antiretroviral therapy (ART)', '1. ผู้ป่วยวัณโรค หมายถึง ผู้ป่วยทั้งในสถานะผู้ป่วยนอกและผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรควัณโรคปอดโดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ ระบุไว้นี้ 2. ผู้ป่วยที่มีผลเลือดเอชไอวีบวก หมายถึง ผู้ป่วย/ผู้ติดเชื้อเอชไอวี ทั้งในสถานะผู้ป่วยนอก และผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นผู้ป่วย/ผู้ที่มีผลการตรวจวินิจฉัยโดยมีผล การตรวจเลือดยืนยันแล้วว่า HIV positive หรือมีรหัสโรคอยู่ในกลุ่มรหัสโรค B20-B24, Z21 3. การรักษาด้วย Antiretroviral therapy (ART) หมายถึง การที่ผู้ป่วย/ผู้ติดเชื้อเอชไอวี ได้รับการรักษาโดยการกินยาต้านไวรัสสูตรใดสูตรหนึ่งมานาน มากกว่า 6 เดือน', '(a/b) x 100', 'a', 'b', ARRAY['clinicmember', 'clinic_visit', 'clinicmember_tb', 'tb_register', 'tb_register_visit', 'tb_lab_examination_sputum', 'arv_tx', 'arv_lab', 'ovstdiag']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 86', 'registered-2026.1', NULL, 'registered'),
    ('DR0301', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'Asthma: Percent of unplanned re-admission within 28 days after last discharge', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย Asthma ภายใน 28 วัน โดยไม่ได้วางแผน', '1. ผู้ป่วย Asthma หมายถึง ผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรคหืด โดยมี รหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การรับผู้ป่วย Asthma กลับเข้าโรงพยาบาล ภายใน 28 วัน โดยไม่ได้วางแผน หมายถึง การที่ผู้ป่วย Asthma กลับมารับการตรวจรักษาโดยไม่ได้วางแผน ภายหลังจากที่จำหน่าย ออกจากโรงพยาบาล ด้วยสถานะการอนุญาตให้กลับบ้าน (status=improve) (ยกเว้น ผู้ป่วยที่ไปรักษาที่โรงพยาบาลอื่น หรือไม่ยินยอมรับการรักษาตามแผน) ภายใน 28 วัน และ ต้องรับกลับเข้านอนพักรักษาในโรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 87', 'registered-2026.1', NULL, 'registered'),
    ('DR0302', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Asthma: Percent of smoking cessation advice given', 'ร้อยละผู้ป่วย Asthma ได้รับคำแนะนำให้อดหรือเลิกบุหรี่ ระหว่างอยู่ในโรงพยาบาล', '1. ผู้ป่วย Asthma หมายถึง ผู้ป่วยใน ที่มี Principal diagnosis (Pdx) เป็นโรคหืด โดยมี รหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การแนะนำให้อดหรือเลิกบุหรี่ หมายถึง การให้คำแนะนำ/การปรึกษา ให้ความรู้ ความ เข้าใจเกี่ยวกับผลกระทบของบุหรี่ต่อภาวะของโรคที่เป็น แก่ผู้ป่วย Asthma ที่มีประวัติสูบ บุหรี่ภายใน 1 ปีก่อนการได้รับการตรวจรักษาในขณะอยู่ในโรงพยาบาล เพื่อให้ผู้ป่วยอด หรือเลิกบุหรี่', '(a/b) x 100', 'a', 'b', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 88', 'registered-2026.1', NULL, 'registered'),
    ('DR0401', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'COPD: Percent of unplanned re-admission into the hospital within 28 days after last discharge', 'ร้อยละการรับกลับเข้าโรงพยาบาลของผู้ป่วย COPD ภายใน 28 วัน โดยไม่ได้วางแผน', '1. ผู้ป่วย COPD หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาลนานตั้งแต่ 4 ชั่วโมงขึ้นไป) ที่มี Principal Diagnosis (Pdx) เป็นโรคปอดอุดกั้นเรื้อรัง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การรับผู้ป่วย COPD กลับเข้าโรงพยาบาล ภายใน 28 วัน โดยไม่ได้วางแผน หมายถึง การที่ผู้ป่วย COPD กลับมารับการตรวจรักษาโดยไม่ได้วางแผน ภายหลังจากที่จำหน่ายออก จาก โรงพยาบาล ด้วยสถานะการอนุญาตให้กลับบ้าน (status = improve) (ยกเว้นผู้ป่วย ที่ไปรักษาที่โรงพยาบาลอื่น หรือไม่ยินยอมรับการรักษาตามแผน) ภายใน 28 วัน และต้อง รับกลับเข้านอนพักรักษาในโรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 89', 'registered-2026.1', NULL, 'registered'),
    ('DR0403', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'COPD: Percent of mortality', 'ร้อยละการเสียชีวิตจากโรคปอดอุดกั้นเรื้อรัง', '1. ผู้ป่วย COPD หมายถึง ผู้ป่วยใน (ผู้ป่วยที่รับไว้นอนพักรักษาในโรงพยาบาล นานตั้งแต่ 4 ชั่วโมงขึ้นไป) อายุ ≥18 ปี ที่มี Principal diagnosis (Pdx) เป็นโรคปอด อุดกั้นเรื้อรัง โดยมีรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. การเสียชีวิตของผู้ป่วย COPD หมายถึง การเสียชีวิตจากทุกสาเหตุของผู้ป่วย COPD ที่มี Pdx ตามที่ระบุไว้ หรือผู้ป่วยที่มีโรคร่วมหรือโรคแทรกเป็น COPD และมีสาเหตุการตาย จากโรค COPD 3. การจำหน่ายทุกสถานะ หมายถึง การที่ผู้ป่วยใน ออกจากโรงพยาบาล ในทุกสถานะ ทุกกรณี', '(a/b) x 100', 'a', 'b', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 90', 'registered-2026.1', NULL, 'registered'),
    ('DR0404', 'D', 'percent', 'lower-is-better', 'monthly', 'Disease', 'COPD: Percent of patient with ongoing smoking', 'ร้อยละของผู้ป่วยโรคปอดอุดกั้นเรื้อรังที่ยังสูบบุหรี่', '1) ผู้ป่วยโรคปอดอุดกั้นเรื้อรังที่ยังสูบบุหรี่ หมายถึง ผู้ป่วยที่ได้รับการวินิจฉัยโรคปอดอุดกั้น เรื้อรังที่ยังสูบบุหรี่อยู่ หรือ เลิกบุหรี่ต่อเนื่องมาเป็นระยะเวลาไม่เกิน 12 เดือน 2) ผู้ป่วยโรคปอดอุดกั้นเรื้อรัง หมายถึงผู้ป่วยที่ได้รับการวินิจฉัยโรคปอดอุดกั้นเรื้อรังที่มารับ การรักษาแบบผู้ป่วยนอกของโรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 91', 'registered-2026.1', NULL, 'registered'),
    ('DS0101', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Methamphetamine Group: 3 months total remission rate', 'ร้อยละของผู้ติดยาเสพติดกลุ่ม Methamphetamine โดยรวมที่หยุดเสพต่อเนื่อง 3 เดือน', 'ผู้ติดยาเสพติดกลุ่ม Methamphetamine หมายถึง ผู้ติดยาเสพติดกลุ่ม Methamphetamine เช่น ยาบ้า ยาไอซ์ ยาอี และยาเลิฟ เป็นต้น หยุดเสพต่อเนื่อง 3 เดือน หมายถึง ผู้ติดยาเสพติดกลุ่ม Methamphetamine ที่เข้ารับการ บำบัดรักษาในระบบสมัครใจ แบบผู้ป่วยนอกและไม่ครบเกณฑ์ในการวินิจฉัย ผู้ติด (dependence) ต่อเนื่อง 3 เดือนหลังจำหน่ายจากการบำบัดรักษา ทั้งนี้ไม่รวมผู้ป่วยถูก จับเสียชีวิต หรือส่งต่อ หลังจำหน่ายจากการบำบัดรักษา', '(a/b) x 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 126', 'registered-2026.1', NULL, 'registered'),
    ('DS0201', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Alcohol Group: 3 months total remission rate', 'ร้อยละของผู้ติดสุราโดยรวม ที่หยุดเสพต่อเนื่อง 3 เดือน', 'ผู้ติดสุรา หมายถึง ผู้ป่วยติดสารเสพติดกลุ่มแอลกอฮอล์ เช่น สุรา เบียร์ เหล้าขาว ฯลฯ หยุดเสพต่อเนื่อง 3 เดือน หมายถึง ผู้ติดสารเสพติดกลุ่มแอลกอฮอล์ ที่เข้ารับการ บำบัดรักษาแบบผู้ป่วยนอกและไม่ครบเกณฑ์ในการวินิจฉัย ผู้ติด (dependence) ต่อเนื่อง 3 เดือนหลังจำหน่ายจากการบำบัดรักษา ทั้งนี้ไม่รวมผู้ป่วยถูกจับ เสียชีวิต หรือส่งต่อ หลัง จำหน่ายจากการบำบัดรักษา', '(a/b) x 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 127', 'registered-2026.1', NULL, 'registered'),
    ('DS0301', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Tobacco Group: 3 months total remission rate', 'ร้อยละของผู้ติดยาสูบโดยรวม ที่หยุดเสพต่อเนื่อง 3 เดือน', 'ผู้ติดยาสูบ (tobacco) หมายถึง ผู้ติดผลิตภัณฑ์จากใบยาสูบทุกชนิด เช่น บุหรี่ (cigarette) บุหรี่มวนเอง (ยาเส้น) ซิการ์ บุหรี่ไฟฟ้า บารากู่ หยุดเสพต่อเนื่อง 3 เดือน หมายถึง ผู้ติดยาสูบ ที่เข้ารับการบำบัดรักษาแบบผู้ป่วยนอก ที่ไม่ครบเกณฑ์ในการวินิจฉัย ผู้ติด (dependence) ต่อเนื่อง 3 เดือนหลังจำหน่ายจากการ บำบัดรักษา ทั้งนี้ไม่รวมผู้ป่วยถูกจับ เสียชีวิต หรือส่งต่อ หลังจำหน่ายจากการบำบัดรักษา', '(a/b) x 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 128', 'registered-2026.1', NULL, 'registered'),
    ('DS0401', 'D', 'percent', 'higher-is-better', 'monthly', 'Disease', 'Opioid Group: 1 year retention rate of opioid in methadone maintenance program', 'อัตราคงอยู่ในการบำบัดรักษา 1 ปีด้วยเมทาโดนระยะยาว ของผู้ติดสารเสพติดในกลุ่ม opioid', '1. ผู้ติดยาเสพติดในกลุ่ม opioid หมายถึง ผู้ติดยาเสพติด ในกลุ่ม เฮโรอีน มอร์ฟีน ฝิ่นและ อนุพันธ์ของฝิ่น 2. คงอยู่ในการบำบัดรักษา 1 ปี หมายถึง ผู้ป่วยที่ติดยาเสพติดในกลุ่ม Opioid ที่มารับการ บำบัดรักษาด้วยเมทาโดนระยะยาว ต่อเนื่องจนครบ 1 ปี โดยไม่ขาดการรักษาต่อเนื่องเกิน 1 เดือน ทั้งนี้ไม่รวมผู้ป่วยที่ถูกจับ เสียชีวิต หรือ ส่งต่อไปรับเมทาโดนระยะยาวที่ สถานพยาบาลอื่น', '(a/b) x 100', 'a', 'b', ARRAY['psych_assess_child', 'psych_plan', 'psych_therapy', 'depression_screen', 'person_wbc', 'ovst', 'ovstdiag', 'clinicmember']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 129', 'registered-2026.1', NULL, 'registered'),
    ('HC0101', 'H', 'ratio', 'lower-is-better', 'annual', 'Health promotion', 'Customer: Asthma patients or their relative(s) who are able to care for the patient''s needs', 'ความสามารถในการดูแลตนเอง/การดูแลผู้ป่วยของญาติโรค Asthma', '1. ผู้ป่วย Asthma หมายถึงผู้ป่วยที่มี Principal diagnosis (Pdx) เป็นโรคหอบหืดโดยมี รหัสโรคอยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้และในที่นี้หมาย รวมถึงเฉพาะผู้ป่วย Asthma ผู้ใหญ่ในแผนกอายุรกรรม 2. ความสามารถในการดูแลตนเองของผู้ป่วย/ญาติผู้ดูแล หมายถึง การที่ผู้ป่วยและญาติ ผู้ดูแลได้รับการเสริมพลังให้สามารถกลับไปใช้ชีวิตประจำวันได้อย่างมีคุณภาพสามารถดูแล ตนเองได้อย่างถูกต้องและใช้บริการในการรักษาได้อย่างเหมาะสม 3. การประเมินความสามารถในการดูแลตนเองของผู้ป่วย Asthma/ญาติผู้ดูแล หมายถึง การประเมินโดยตรวจสอบสัดส่วนของผู้ป่วย Asthma ที่มารับบริการที่ ER กับ OPD มี อัตราเพิ่มขึ้น (จำนวนครั้งที่ ER ลดลง : จำนวนคนที่ OPD เพิ่มขึ้น)', 'a/b', 'a', 'b', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 270', 'registered-2026.1', NULL, 'registered'),
    ('HC0102', 'H', 'percent', 'lower-is-better', 'annual', 'Health promotion', 'Customer: COPD patients or their relative(s) who are able to care for the patient''s needs', 'ความสามารถในการดูแลตนเอง/ การดูแลผู้ป่วยของญาติโรค COPD', '1. ผู้ป่วย COPD หมายถึงผู้ป่วยที่มี Principal diagnosis (Pdx) เป็นโรคปอดอุดกั้นเรื้อรัง โดยมีรหัสโรคอยู่ในกลุ่มรหัสโรคตาม ICD-10 TM, ICD-10, ICD-9 ดังที่ระบุไว้นี้ 2. ความสามารถในการดูแลตนเองของผู้ป่วย/ญาติผู้ดูแล หมายถึง การที่ผู้ป่วยและญาติ ผู้ดูแลได้รับการเสริมพลังให้สามารถกลับไปใช้ชีวิตประจำวันอย่างมีคุณภาพ เข้าใจสภาวะ ของโรคมีความพร้อมในการปรับเปลี่ยนพฤติกรรมในการดูแลตนเอง เข้าใจในการปฏิบัติตัว สามารถดูแลตนเองได้อย่างถูกต้อง เช่น การออกกำลังกายการฟื้นฟูสมรรถภาพ และการ หลีกเลี่ยง/ควบคุมปัจจัยที่ส่งเสริมให้เกิดโรคมากขึ้นเช่นการสูบบุหรี่ เป็นต้น 3. การประเมินความสามารถในการดูแลตนเองของผู้ป่วย COPD/ญาติผู้ดูแล หมายถึง การ ประเมินโดยตรวจสอบสัดส่วนของผู้ป่วย COPD ที่มารับบริการที่ ER กับ OPD มีอัตราลดลง', '(a/b) x 100', 'a', 'b', ARRAY['patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'opdscreen']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 271', 'registered-2026.1', NULL, 'registered'),
    ('HE0101', 'H', 'percent', 'higher-is-better', 'annual', 'Health promotion', 'Employee: Percent of employee check-up', 'ร้อยละบุคลากรได้รับการตรวจร่างกายประจำปี', 'บุคลากรที่เข้ารับการตรวจสุขภาพประจำปี หมายถึง กรณีเป็นข้าราชการและลูกจ้างประจำ ตรวจสุขภาพตามสิทธิ์กระทรวงการคลังกำหนด ส่วนลูกจ้างชั่วคราว ตรวจสุขภาพตาม นโยบายขององค์กร/ หน่วยงาน', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 264', 'registered-2026.1', NULL, 'registered'),
    ('HE0102', 'H', 'percent', 'lower-is-better', 'annual', 'Health promotion', 'Employee: Percent of employee have exceeding BMI', 'ร้อยละบุคลากรที่มีดัชนีมวลกาย (BMI) เกินเกณฑ์มาตรฐาน', 'การประเมินภาวะสุขภาพของบุคลากร หมายถึง เป็นการตรวจประเมินหาค่าดัชนีมวลกาย ซึ่งมีการกระทำพร้อมกันกับการตรวจสุขภาพประจำปีของบุคลากรด้วยการประเมินจาก น้ำหนักและส่วนสูง ค่าดัชนีมวลกายที่เกินกว่าเกณฑ์มาตรฐาน คือมากกว่าหรือเท่ากับ 23.0', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 265', 'registered-2026.1', NULL, 'registered'),
    ('HE0103', 'H', 'percent', 'lower-is-better', 'annual', 'Health promotion', 'Employee: Percent of employee have behavior-smoky', 'ร้อยละบุคลากรที่มีพฤติกรรมการสูบบุหรี่', 'บุคลากรที่มีพฤติกรรมการสูบบุหรี่', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 266', 'registered-2026.1', NULL, 'registered'),
    ('HE0104', 'H', 'percent', 'lower-is-better', 'annual', 'Health promotion', 'Employee: Percent of employee (male) obesity', 'ร้อยละบุคลากรเพศชายมีภาวะอ้วนลงพุง', 'ภาวะอ้วนลงพุง หมายถึง ภาวะที่มีการสะสมของไขมันในร่างกายบริเวณช่องท้องเกิน มาตรฐานวัดรอบเอวตรงตำแหน่งสะดือ โดยใช้สายวัดในช่วงหายใจออกสุด สายวัดแนบกับ ลำตัว ไม่รัดแน่น และให้ระดับของสายวัดวางอยู่ในแนวขนานกับพื้น โดยรอบเอวของผู้ชาย ไม่เกิน 90 เซนติเมตร', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 267', 'registered-2026.1', NULL, 'registered'),
    ('HE0105', 'H', 'percent', 'lower-is-better', 'annual', 'Health promotion', 'Employee: Percent of employee (female) obesity', 'ร้อยละบุคลากรเพศหญิงมีภาวะอ้วนลงพุง', 'ภาวะอ้วนลงพุง หมายถึง ภาวะที่มีการสะสมของไขมันในร่างกายบริเวณช่องท้องเกิน มาตรฐานวัดรอบเอวตรงตำแหน่งสะดือ โดยใช้สายวัดในช่วงหายใจออกสุด สายวัดแนบกับ ลำตัว ไม่รัดแน่น และให้ระดับของสายวัดวางอยู่ในแนวขนานกับพื้น โดยรอบเอวของผู้หญิง ไม่เกิน 80 เซนติเมตร', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 268', 'registered-2026.1', NULL, 'registered'),
    ('HE0106', 'H', 'percent', 'higher-is-better', 'annual', 'Health promotion', 'Employee: Percent of employee received Influenza immunization', 'ร้อยละบุคลากรได้รับวัคซีนไข้หวัดใหญ่', 'บุคลากรได้รับวัคซีนไข้หวัดใหญ่ หมายถึง การที่บุคลากรได้รับการฉีดวัคซีนไข้หวัดใหญ่ตาม ฤดูกาล เพื่อป้องกันโรคไข้หวัดใหญ่ในแต่ละปี', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_stat', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 269', 'registered-2026.1', NULL, 'registered'),
    ('HH0101.1', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percent of smoking tobacco products used by service recipients', 'ร้อยละการคัดกรองสถานะการบริโภคยาสูบของผู้รับบริการที่มีอายุ 15 ปีขึ้นไปที่มาใช้ บริการผู้ป่วยนอกของสถานพยาบาล', 'การบริโภคยาสูบ หมายถึง การบริโภคผลิตภัณฑ์ยาสูบทั้งชนิดมีควัน (Smoking tobacco use) เช่น บุหรี่ซิกาแรต บุหรี่มวนเอง ซิการ์ ไปป์ บารากู่ เป็นต้น และชนิดไม่มีควัน (Smokeless tobacco) ได้แก่ การนำยาเส้นมาสูด ดม อม เคี้ยว เช่น การรับประทาน หมากพลูที่มีส่วนผสมของยาเส้น การสูดยานัตถุ์ที่มีส่วนผสมของยาสูบ การอม/จุก/เคี้ยวยา เส้น เป็นต้น รวมไปถึงการใช้ผลิตภัณฑ์บุหรี่ไฟฟ้าทุกประเภท การคัดกรองสถานะการบริโภคยาสูบที่มาใช้บริการผู้ป่วยนอกของสถานพยาบาล หมายถึง การคัดกรองสถานะการบริโภคยาสูบของผู้รับบริการที่มีอายุ 15 ปีขึ้นไป ที่มาใช้บริการ ผู้ป่วยนอกของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 272', 'registered-2026.1', NULL, 'registered'),
    ('HH0101.2', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percent of Tobacco Use Screened of Service Recipients aged ≥ 15 years old at the Outpatient Service.', 'ร้อยละการคัดกรองสถานะการบริโภคยาสูบของผู้รับบริการที่มีอายุ 15 ปีขึ้นไปที่มาใช้ บริการผู้ป่วยในของสถานพยาบาล', 'การบริโภคยาสูบ หมายถึง การบริโภคผลิตภัณฑ์ยาสูบทั้งชนิดมีควัน (Smoking tobacco use) เช่น บุหรี่ซิกาแรต บุหรี่มวนเอง ซิการ์ ไปป์ บารากู่ เป็นต้น และชนิดไม่มีควัน (Smokeless tobacco) ได้แก่ การนำยาเส้นมาสูด ดม อม เคี้ยว เช่น การรับประทาน หมากพลูที่มีส่วนผสมของยาเส้น การสูดยานัตถุ์ที่มีส่วนผสมของยาสูบ การอม/จุก/เคี้ยวยา เส้น เป็นต้น รวมไปถึงการใช้ผลิตภัณฑ์บุหรี่ไฟฟ้าทุกประเภท การคัดกรองสถานะการบริโภคยาสูบที่มาใช้บริการผู้ป่วยในของสถานพยาบาล หมายถึง การคัดกรองสถานะการบริโภคยาสูบของผู้รับบริการที่มีอายุ 15 ปีขึ้นไป ที่มาใช้บริการ ผู้ป่วยในของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 273', 'registered-2026.1', NULL, 'registered'),
    ('HH0102', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence patients receiving nicotine dependence treatment.', 'ร้อยละของผู้รับบริการที่มีภาวะติดนิโคตินที่ได้รับบริการบำบัดภาวะติดนิโคติน', 'ผู้รับบริการ หมายถึง ผู้รับบริการในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไปทั้งบริการแบบผู้ป่วย นอกและผู้ป่วยใน ที่ได้รับการคัดกรองและวินิจฉัยภาวะติดนิโคติน การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 274', 'registered-2026.1', NULL, 'registered'),
    ('HH0103.1', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in DM patients receiving nicotine dependence treatment.', 'ร้อยละของผู้รับบริการกลุ่มโรคเบาหวานที่มีภาวะติดนิโคตินและได้รับบริการบำบัดภาวะติด นิโคติน', 'ผู้รับบริการกลุ่มโรคเบาหวาน หมายถึง ผู้รับบริการกลุ่มโรคเบาหวานในสถานพยาบาลที่มี อายุ 15 ปีขึ้นไปทั้งบริการแบบผู้ป่วยนอกและผู้ป่วยใน ที่ได้รับการคัดกรองและวินิจฉัย ภาวะติดนิโคติน การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 275', 'registered-2026.1', NULL, 'registered'),
    ('HH0103.2', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Hypertension patients receiving nicotine dependence treatment.', 'ร้อยละของผู้รับบริการกลุ่มโรคความดันโลหิตสูงที่มีภาวะติดนิโคตินและได้รับบริการบำบัด ภาวะติดนิโคติน', 'ผู้รับบริการกลุ่มโรคความดันโลหิตสูง หมายถึง ผู้รับบริการกลุ่มโรคความดันโลหิตสูงใน สถานพยาบาลที่มีอายุ 15 ปีขึ้นไปทั้งบริการแบบผู้ป่วยนอกและผู้ป่วยใน ที่ได้รับการคัด กรองและวินิจฉัยภาวะติดนิโคติน การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 276', 'registered-2026.1', NULL, 'registered'),
    ('HH0103.3', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment', 'ร้อยละของผู้รับบริการกลุ่มโรคหืดที่มีภาวะติดนิโคตินและได้รับบริการบำบัดภาวะติด นิโคติน', 'ผู้รับบริการกลุ่มโรคหืด หมายถึง ผู้รับบริการกลุ่มโรคหืดในสถานพยาบาลที่มีอายุ 15 ปี ขึ้นไปทั้งบริการแบบผู้ป่วยนอกและผู้ป่วยใน ที่ได้รับการคัดกรองและวินิจฉัยภาวะติดนิโคติน การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 277', 'registered-2026.1', NULL, 'registered'),
    ('HH0103.4', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in COPD patients receiving nicotine dependence treatment.', 'ร้อยละของผู้รับบริการกลุ่มโรคถุงลมโป่งพองที่มีภาวะติดนิโคตินและได้รับบริการบำบัด ภาวะติดนิโคติน', 'ผู้รับบริการกลุ่มโรคถุงลมโป่งพอง หมายถึง ผู้รับบริการกลุ่มโรคถุงลมโป่งพองใน สถานพยาบาลที่มีอายุ 15 ปีขึ้นไปทั้งบริการแบบผู้ป่วยนอกและผู้ป่วยใน ที่ได้รับการคัด กรองและวินิจฉัยภาวะติดนิโคติน การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 278', 'registered-2026.1', NULL, 'registered'),
    ('HH0103.5', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Pregnant patients receiving nicotine dependence treatment.', 'ร้อยละของผู้รับบริการกลุ่มหญิงตั้งครรภ์ที่มีภาวะติดนิโคตินและได้รับบริการบำบัดภาวะติด นิโคติน', 'ผู้รับบริการกลุ่มหญิงตั้งครรภ์ หมายถึง ผู้รับบริการกลุ่มหญิงตั้งครรภ์ในสถานพยาบาลที่มี อายุ 15 ปีขึ้นไปทั้งบริการแบบผู้ป่วยนอกและผู้ป่วยใน ที่ได้รับการคัดกรองและวินิจฉัย ภาวะติดนิโคติน การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 279', 'registered-2026.1', NULL, 'registered'),
    ('HH0103.6', 'H', 'percent', 'higher-is-better', 'monthly', 'Health promotion', 'Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment.', 'ร้อยละของผู้รับบริการกลุ่มโรคถุงลมโป่งพองที่มีภาวะติดนิโคตินและได้รับบริการบำบัด ภาวะติดนิโคติน', 'ผู้รับบริการกลุ่มโรคถุงลมโป่งพอง หมายถึง ผู้รับบริการกลุ่มโรคถุงลมโป่งพองใน สถานพยาบาลที่มีอายุ 15 ปีขึ้นไปทั้งบริการแบบผู้ป่วยนอกและผู้ป่วยใน ที่ได้รับการคัด กรองและวินิจฉัยภาวะติดนิโคติน การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 280', 'registered-2026.1', NULL, 'registered'),
    ('HH0104.1', 'H', 'percent', 'higher-is-better', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (DM Patients)', 'ร้อยละของผู้ป่วยกลุ่มโรคเบาหวานที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถ หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน', 'การบริโภคยาสูบ หมายถึง การบริโภคผลิตภัณฑ์ยาสูบทั้งชนิดมีควัน (Smoking tobacco use) เช่น บุหรี่ซิกาแรต บุหรี่มวนเอง ซิการ์ ไปป์ บารากู่ เป็นต้น และชนิดไม่มีควัน (Smokeless tobacco) ได้แก่ การนำยาเส้นมาสูด ดม อม เคี้ยว เช่น การรับประทาน หมากพลูที่มีส่วนผสมของยาเส้น การสูดยานัตถุ์ที่มีส่วนผสมของยาสูบ การอม/จุก/เคี้ยวยา เส้น เป็นต้น รวมไปถึงการใช้ผลิตภัณฑ์บุหรี่ไฟฟ้าทุกประเภท การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หมายถึง สามารถหยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หลังจำหน่ายจากการบำบัดรักษาภาวะติดนิโคติน', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 281', 'registered-2026.1', NULL, 'registered'),
    ('HH0104.2', 'H', 'percent', 'higher-is-better', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (Hypertension Patients)', 'ร้อยละของผู้ป่วยกลุ่มโรคความดันโลหิตสูงที่รับบริการบำบัดรักษาภาวะติดนิโคตินและ สามารถหยุดบริโภคยาสูบต่อเนื่อง 6 เดือน', 'การบริโภคยาสูบ หมายถึง การบริโภคผลิตภัณฑ์ยาสูบทั้งชนิดมีควัน (Smoking tobacco use) เช่น บุหรี่ซิกาแรต บุหรี่มวนเอง ซิการ์ ไปป์ บารากู่ เป็นต้น และชนิดไม่มีควัน (Smokeless tobacco) ได้แก่ การนำยาเส้นมาสูด ดม อม เคี้ยว เช่น การรับประทาน หมากพลูที่มีส่วนผสมของยาเส้น การสูดยานัตถุ์ที่มีส่วนผสมของยาสูบ การอม/จุก/เคี้ยวยา เส้น เป็นต้น รวมไปถึงการใช้ผลิตภัณฑ์บุหรี่ไฟฟ้าทุกประเภท การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หมายถึง สามารถหยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หลังจำหน่ายจากการบำบัดรักษาภาวะติดนิโคติน', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 282', 'registered-2026.1', NULL, 'registered'),
    ('HH0104.3', 'H', 'percent', 'higher-is-better', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (Asthma Patients)', 'ร้อยละของผู้ป่วยกลุ่มโรคหืดที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถหยุด บริโภคยาสูบต่อเนื่อง 6 เดือน', 'การบริโภคยาสูบ หมายถึง การบริโภคผลิตภัณฑ์ยาสูบทั้งชนิดมีควัน (Smoking tobacco use) เช่น บุหรี่ซิกาแรต บุหรี่มวนเอง ซิการ์ ไปป์ บารากู่ เป็นต้น และชนิดไม่มีควัน (Smokeless tobacco) ได้แก่ การนำยาเส้นมาสูด ดม อม เคี้ยว เช่น การรับประทาน หมากพลูที่มีส่วนผสมของยาเส้น การสูดยานัตถุ์ที่มีส่วนผสมของยาสูบ การอม/จุก/เคี้ยวยา เส้น เป็นต้น รวมไปถึงการใช้ผลิตภัณฑ์บุหรี่ไฟฟ้าทุกประเภท การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หมายถึง สามารถหยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หลังจำหน่ายจากการบำบัดรักษาภาวะติดนิโคติน', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 283', 'registered-2026.1', NULL, 'registered'),
    ('HH0104.4', 'H', 'percent', 'higher-is-better', 'annual', 'Health promotion', 'Tobacco use: continuous abstinence rate (CAR) at 6 months (COPD Patients)', 'ร้อยละของผู้ป่วยกลุ่มโรคถุงลมโป่งพองที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถ หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน', 'การบริโภคยาสูบ หมายถึง การบริโภคผลิตภัณฑ์ยาสูบทั้งชนิดมีควัน (Smoking tobacco use) เช่น บุหรี่ซิกาแรต บุหรี่มวนเอง ซิการ์ ไปป์ บารากู่ เป็นต้น และชนิดไม่มีควัน (Smokeless tobacco) ได้แก่ การนำยาเส้นมาสูด ดม อม เคี้ยว เช่น การรับประทาน หมากพลูที่มีส่วนผสมของยาเส้น การสูดยานัตถุ์ที่มีส่วนผสมของยาสูบ การอม/จุก/เคี้ยวยา เส้น เป็นต้น รวมไปถึงการใช้ผลิตภัณฑ์บุหรี่ไฟฟ้าทุกประเภท การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หมายถึง สามารถหยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หลังจำหน่ายจากการบำบัดรักษาภาวะติดนิโคติน', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 284', 'registered-2026.1', NULL, 'registered'),
    ('HH0104.5', 'H', 'percent', 'higher-is-better', 'annual', 'Health promotion', 'Tobacco use: Tobacco use: continuous abstinence rate (CAR) at 6 months (Pregnant Patients)', 'ร้อยละของผู้ป่วยกลุ่มหญิงตั้งครรภ์ที่รับบริการบำบัดรักษาภาวะติดนิโคตินและสามารถ หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน', 'การบริโภคยาสูบ หมายถึง การบริโภคผลิตภัณฑ์ยาสูบทั้งชนิดมีควัน (Smoking tobacco use) เช่น บุหรี่ซิกาแรต บุหรี่มวนเอง ซิการ์ ไปป์ บารากู่ เป็นต้น และชนิดไม่มีควัน (Smokeless tobacco) ได้แก่ การนำยาเส้นมาสูด ดม อม เคี้ยว เช่น การรับประทาน หมากพลูที่มีส่วนผสมของยาเส้น การสูดยานัตถุ์ที่มีส่วนผสมของยาสูบ การอม/จุก/เคี้ยวยา เส้น เป็นต้น รวมไปถึงการใช้ผลิตภัณฑ์บุหรี่ไฟฟ้าทุกประเภท การได้รับบริการบำบัดภาวะติดนิโคติน หมายถึง การเข้ารับบริการในการบำบัดภาวะติด นิโคตินแก่ผู้รับบริการสอดคล้องตามแนวทางการบำบัดภาวะติดนิโคตินของสถานพยาบาล หยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หมายถึง สามารถหยุดบริโภคยาสูบต่อเนื่อง 6 เดือน หลังจำหน่ายจากการบำบัดรักษาภาวะติดนิโคติน', '(a/b) x 100', 'a', 'b', ARRAY['opdscreen', 'patient_asthma_screen', 'patient_copd_screen', 'clinicmember', 'clinic_visit', 'ovst', 'ovstdiag', 'person_anc']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 285', 'registered-2026.1', NULL, 'registered'),
    ('SC0101', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'Customer: Percent of outpatient satisfaction (overall)', 'ร้อยละความพึงพอใจของผู้ป่วยนอก (ภาพรวม)', '1. การประเมินความพึงพอใจในภาพรวมหมายถึงการประเมินโดยใช้แบบสอบถามซึ่งมีข้อ คำถาม "ท่านมีความพึงพอใจต่อบริการที่ได้รับจากโรงพยาบาล…..โดยรวมในระดับใด" สุ่มสอบถามจากผู้รับบริการในกระบวนงานบริการผู้ป่วยนอกทั้งหมด 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อบริการที่ได้รับที่ระบุไว้ในแต่ละ ข้อคำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. การวัดระดับความพึงพอใจ หมายถึง การประเมินความรู้สึกต่อบริการที่ได้รับของผู้ป่วย โดยวัดเฉพาะผู้ป่วยที่มีความพึงพอใจอยู่ในระดับ 4–5 เท่านั้น', '(a/b) x 100', 'A', 'b', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 250', 'registered-2026.1', NULL, 'registered'),
    ('SC0102', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'Customer: Percent of inpatient satisfaction (overall)', 'ร้อยละความพึงพอใจของผู้ป่วยใน (ภาพรวม)', '1. การประเมินความพึงพอใจในภาพรวมหมายถึงการประเมินโดยใช้แบบสอบถามซึ่งมีข้อ คำถาม "ท่านมีความพึงพอใจต่อบริการที่ได้รับจากโรงพยาบาล.......โดยรวมในระดับใด" สุ่มสอบถามจากผู้รับบริการในกระบวนงานบริการผู้ป่วยในทั้งหมดซึ่งมีจำนวนวันนอน มากกว่า 3 วัน 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อบริการที่ได้รับที่ระบุไว้ในแต่ละ ข้อคำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. การวัดระดับความพึงพอใจ หมายถึง การประเมินความรู้สึกต่อบริการที่ได้รับของผู้ป่วย โดยวัดเฉพาะผู้ป่วยที่มีความพึงพอใจอยู่ในระดับ 4–5 เท่านั้น', '(a/b) x 100', 'A', 'b', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 251', 'registered-2026.1', NULL, 'registered'),
    ('SC0103', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'Customer: Percent of outpatients who return to receive care', 'ร้อยละของผู้ป่วยนอกที่จะกลับมาใช้บริการซ้ำ', '1. เป็นความพึงพอใจต่อโรงพยาบาลของผู้รับบริการ และการกลับมารักษาต่อเนื่อง 2. วิธีการประเมิน โดยใช้แบบสอบถามชุดเดียวกับการประเมินความพึงพอใจของผู้ป่วยนอก ซึ่งมีข้อคำถาม "ถ้าท่านสามารถเลือกโรงพยาบาลได้ท่านจะเลือกกลับมาใช้บริการที่ รพ. นี้อีกหรือไม่" และมีคำตอบให้เลือก 2 ข้อ คือ มา/ไม่มา 3. การวัดผลการประเมิน โดยคำนวณหาค่าของผู้รับบริการที่จะกลับมารับบริการซ้ำ', '(a/b) x 100', 'a', 'b', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 252', 'registered-2026.1', NULL, 'registered'),
    ('SC0104', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'Customer: Percent of inpatients who return to receive care', 'ร้อยละของผู้ป่วยในที่จะกลับมาใช้บริการซ้ำ', '1. เป็นความพึงพอใจต่อโรงพยาบาลของผู้รับบริการ และการกลับมารักษาต่อเนื่อง 2. วิธีการประเมิน โดยใช้แบบสอบถามชุดเดียวกับการประเมินความพึงพอใจของผู้ป่วยใน ซึ่งมีข้อคำถาม "ถ้าท่านสามารถเลือกโรงพยาบาลได้ท่านจะเลือกกลับมาใช้บริการที่ รพ. นี้อีกหรือไม่" และมีคำตอบให้เลือก 2 ข้อ คือมา/ไม่มา 3. การวัดผลการประเมิน โดยคำนวณหาค่าของผู้รับบริการที่จะกลับมารับบริการซ้ำ', '(a/b) x 100', 'a', 'b', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 253', 'registered-2026.1', NULL, 'registered'),
    ('SC0105', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'Customer: Percent of outpatients who would recommend friends or family to receive care at this facility', 'ร้อยละผู้ป่วยนอกที่จะแนะนำญาติหรือคนรู้จักมาใช้บริการ', '1. เป็นการแนะนำญาติหรือคนรู้จักมาใช้บริการต่อไป 2. วิธีการประเมิน โดยใช้แบบสอบถามชุดเดียวกับการประเมินความพึงพอใจของผู้ป่วยนอก ซึ่งมีข้อคำถาม "ท่านจะแนะนำญาติหรือคนรู้จักมาใช้บริการที่โรงพยาบาลนี้ หรือไม่" และมีคำตอบให้เลือก 2 ข้อ คือ แนะนำ/ ไม่แนะนำ 3. การวัดผลการประเมิน โดยคำนวณหาค่าของผู้รับบริการที่จะแนะนำให้มารับบริการ', '(a/b) x 100', 'a', 'b', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 254', 'registered-2026.1', NULL, 'registered'),
    ('SC0106', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'Customer: Percent of inpatients who would recommend friends or family to receive care at this facility', 'ร้อยละของผู้ป่วยในที่จะแนะนำญาติหรือคนรู้จักมาใช้บริการ', '1. เป็นการแนะนำญาติหรือคนรู้จักมาใช้บริการต่อไป 2. วิธีการประเมิน โดยใช้แบบสอบถามชุดเดียวกับการประเมินความพึงพอใจของผู้ป่วยใน ซึ่งมีข้อคำถาม "ท่านจะแนะนำญาติหรือคนรู้จักมาใช้บริการที่โรงพยาบาลนี้ หรือไม่" และมีคำตอบให้เลือก 2 ข้อ คือ แนะนำ/ ไม่แนะนำ 3. การวัดผลการประเมิน โดยคำนวณหาค่าของผู้รับบริการที่จะกลับมารับบริการซ้ำโดยใช้ จำนวนผู้ตอบแบบสอบถามประมาณ 20% ของจำนวนผู้ป่วยที่เข้ารับการตรวจรักษาใน โรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['survey_satisfy_head_pcu', 'survey_satisfy_screen_pcu', 'survey_satisfy_choice_pcu', 'dis_satisfied', 'dis_satisfied_result', 'dis_satisfied_topic']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 255', 'registered-2026.1', NULL, 'registered'),
    ('SF0101', 'S', 'ratio', 'higher-is-better', 'annual', 'System', 'Financial: Current ratio', 'อัตราส่วนทุนหมุนเวียน', '1. อัตราส่วนทุนหมุนเวียน (current ratio) คือ อัตราส่วนระหว่างสินทรัพย์ หมุนเวียน และ หนี้สินหมุนเวียน ซึ่งบ่งบอกถึงสภาพคล่องของกิจการในการที่จะชำระหนี้ ระยะสั้น หาก <1 อาจมีปัญหาในการชำระหนี้ระยะสั้น หาก >1 แสดงว่ากิจการมีสินทรัพย์ หมุนเวียนมากพอที่จะชำระหนี้ระยะสั้น แต่หากมีค่าสูงกว่า 1 มากๆ อาจหมายถึง ประสิทธิภาพในการใช้สินทรัพย์ของกิจการไม่ดีพอ 2. สินทรัพย์หมุนเวียน (current assets) หมายถึง สินทรัพย์ที่เป็นเงินสดหรือสามารถ เปลี่ยนเป็นเงินสดได้ภายใน 1 รอบระยะเวลาของการดำเนินธุรกิจหรือ 1 ปี ได้แก่ เงินสด เงินฝากธนาคารเงินลงทุนระยะสั้นลูกหนี้การค้าตั๋วเงินรับสินค้าคงเหลือลูกหนี้อื่นๆ รายได้ ค้างรับค่าใช้จ่ายจ่ายล่วงหน้าวัสดุสิ้นเปลือง (supplies) 3. หนี้สินหมุนเวียน (current liabilities) หมายถึง หนี้สินที่กิจการมีภาระผูกพันที่จะต้อง ชำระคืนภายในระยะเวลาไม่เกิน 1 ปี ได้แก่ เงินเบิกเกินบัญชีธนาคารเงินกู้ยืมธนาคารระยะ สั้นเจ้าหนี้การค้าตั๋วเงินจ่าย รายได้รับล่วงหน้าค่าใช้จ่ายค้างจ่ายเจ้าหนี้อื่น', 'a/b', 'a', 'b', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 244', 'registered-2026.1', NULL, 'registered'),
    ('SF0102', 'S', 'ratio', 'higher-is-better', 'annual', 'System', 'Financial: Quick ratio', 'อัตราส่วนทุนหมุนเวียนเร็ว (อัตราส่วนสินทรัพย์สภาพคล่อง)', 'คือ อัตราส่วนที่ปรับปรุงมาจากอัตราส่วนทุนหมุนเวียน (current ratio) ซึ่งในการคำนวณ จะไม่นำสินค้าคงเหลือมาคิดรวมกับสินทรัพย์หมุนเวียนอื่นๆ เช่น เงินสด ลูกหนี้การค้า และ สินทรัพย์ในความต้องการของตลาด เนื่องจากสินค้าคงเหลือสามารถแปลงเป็นเงินสดได้ช้า กว่าและอาจมีมูลค่าต่ำกว่ามูลค่าทางบัญชี ทำให้อัตราส่วนทุนหมุนเวียนเร็วบอกถึงสภาพ คล่องของกิจการได้ดีกว่าอัตราส่วนทุนหมุนเวียน (เป็นตัวชี้วัดที่ใช้เป็นเครื่องวัด ความสามารถในการชำระหนี้อย่างทันทีทันใด)', 'a/b', 'a', 'b', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 245', 'registered-2026.1', NULL, 'registered'),
    ('SF0103', 'S', 'ratio', 'higher-is-better', 'annual', 'System', 'Financial: Fixed asset turnover', 'อัตราหมุนเวียนของสินทรัพย์ถาวร', 'อัตราหมุนเวียนของสินทรัพย์ถาวร (fixed asset turnover) เป็นการคำนวณหาอัตราส่วน ระหว่างรายได้จากบริการ หรือรายได้จากการดำเนินกิจการ กับสินทรัพย์ถาวรโดยสินทรัพย์ ถาวร (fixed assets) หมายถึง สินทรัพย์ที่มีตัวตนและมีอายุการใช้งานเกิน 1 ปี ที่องค์กรมี ไว้เพื่อที่จะใช้ผลิตสินค้าหรือบริการเพื่อที่จะก่อให้เกิดรายได้', 'a/b', 'a', 'b', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 246', 'registered-2026.1', NULL, 'registered'),
    ('SF0104', 'S', 'ratio', 'lower-is-better', 'annual', 'System', 'Financial: Day in account receivable (average collection period for account receivables)', 'ระยะเวลาถัวเฉลี่ยในการเรียกเก็บลูกหนี้ค่ารักษาสุทธิ', 'ระยะเวลาถัวเฉลี่ยในการเรียกเก็บลูกหนี้ค่ารักษาสุทธิ เป็นการหาค่าระยะเวลาถัวเฉลี่ยใน การเรียกเก็บหนี้ ที่แสดงให้เห็นถึงระยะเวลาในการเรียกเก็บหนี้ว่าสั้นหรือยาว (จำนวนวันที่ ต้องรอเพื่อเก็บเงินจากลูกหนี้ค่ารักษาพยาบาล) เพื่อให้ทราบถึงคุณภาพของลูกหนี้ค่า รักษาพยาบาล ประสิทธิภาพในการเรียกเก็บหนี้ และนโยบายในการให้สินเชื่อ', 'a/b', 'a', 'b', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 247', 'registered-2026.1', NULL, 'registered'),
    ('SF0105', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'Financial: Net profit margin', 'อัตราส่วนระหว่างกำไรสุทธิ กับยอดขายสุทธิ', '1. หมายถึง กำไรสุทธิ (net profit)/ยอดขายสุทธิ (sales) มีค่ายิ่งสูงยิ่งดี แสดงให้เห็น ประสิทธิภาพในการดำเนินงานของโรงพยาบาลในการทำกำไร หลังจากหักต้นทุนค่าใช้จ่าย รวมทั้งภาษีเงินได้หมดแล้ว 2. กำไรสุทธิ เป็นค่าที่ได้จากผลรวมของรายได้ทั้งหมด (รายได้จากบริการและรายได้อื่นๆ นอกเหนือจากการบริการ) หักค่าใช้จ่าย ค่าเสื่อม และต้นทุนแล้ว 3. ยอดขายสุทธิ หมายถึง รายได้เฉพาะส่วนที่เกิดจากการบริการเท่านั้น', '(a/b) x 100', 'a', 'b', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 248', 'registered-2026.1', NULL, 'registered'),
    ('SF0106', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'Financial: Return on asset (ROA)', 'อัตราผลตอบแทนจากสินทรัพย์รวม', 'เป็นการหาค่าที่ใช้ในการวัดความสามารถในการทำกำไรของสินทรัพย์ทั้งหมดที่ใช้ในการ ดำเนินงาน ว่าให้ผลตอบแทนจากการดำเนินงานได้มากน้อยเพียงใด ค่ายิ่งสูงยิ่งดี หากมีค่า สูงแสดงถึงการใช้สินทรัพย์อย่างมีประสิทธิภาพ', '(a/b) x 100', 'a', 'b', ARRAY['an_stat', 'ipt', 'opitemrece', 'stock_item', 'stock_trancation']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 249', 'registered-2026.1', NULL, 'registered'),
    ('SG0104', 'S', 'ratio', 'higher-is-better', 'monthly', 'System', 'Governance: Percent of recycled waste', 'สัดส่วนของขยะรีไซเคิล', '1. ขยะรีไซเคิล หมายถึง ขยะที่สามารถนำกลับมาใช้ใหม่ได้ โดยนำไปผ่านกระบวนการแปร รูปในระบบอุตสาหกรรม 2. ระบบการดำเนินการเกี่ยวกับขยะรีไซเคิล เป็นการประเมินว่าองค์กรมีระบบและ แผนปฏิบัติการกำจัดขยะรีไซเคิล ที่มีประสิทธิภาพ บุคลากรทุกระดับสามารถปฏิบัติตาม แนวทางได้', 'a/b', 'a', 'b', ARRAY['stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'supply_sterile', 'supply_sterile_item']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 256', 'registered-2026.1', NULL, 'registered'),
    ('SH0101', 'S', 'percent', 'lower-is-better', 'annual', 'System', 'HRM: Turnover rate', 'อัตราการลาออกของบุคลากร', '1. การลาออกของบุคลากร หมายถึง การที่บุคลากร (รวมทุกประเภททุกตำแหน่ง) ของ องค์กรลาออกโดยสมัครใจ ไม่นับกลุ่มที่ให้ออก, ไล่ออก, ปลดออก, เกษียณอายุ, เข้า โครงการเกษียณก่อนอายุ, ถึงแก่กรรม และโอน ย้าย 2. ค่าเฉลี่ยของจำนวนบุคลากรที่ลาออกในรอบปีงบประมาณ หมายถึง ผลรวมของจำนวน บุคลากรที่ลาออกทั้งหมดในรอบปีงบประมาณ หารด้วย 12 3. ค่าเฉลี่ยของจำนวนบุคลากร ณ วันแรกและวันสุดท้ายของปีงบประมาณ หมายถึง ผลรวมของจำนวนบุคลากรที่คงอยู่ณ วันแรกและวันสุดท้ายของปีงบประมาณ หารด้วย 2', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 212', 'registered-2026.1', NULL, 'registered'),
    ('SH0102', 'S', 'percent', 'lower-is-better', 'annual', 'System', 'HRM: Percent of employee work-related Injury', 'ร้อยละบุคลากรที่บาดเจ็บจากการทำงาน', '1. บุคลากร (employee) หมายถึง บุคลากรผู้ปฏิบัติงานภายใต้การจ้างงานหรือภายใต้การ ดูแลขององค์กรโดยตรง 2. การบาดเจ็บจากการทำงาน (work-related injury) หมายถึง การบาดเจ็บที่เกิดจาก อุบัติเหตุที่มีเหตุการณ์เกิดที่ชัดเจน มีกลไกการเกิดที่ชัดเจน เช่น เข็มทิ่มตำ สะดุด เครื่องจักรหนีบ ของหล่นทับก่อให้เกิดการบาดเจ็บโดยตรงที่กระดูก กล้ามเนื้อ เอ็น หลอด เลือด หรือเส้นประสาท 3. จำนวนบุคลากรเฉลี่ยปีงบประมาณ หมายถึง ผลรวมของจำนวนบุคลากรที่คงอยู่ ณ วัน แรกและวันสุดท้ายของปีงบประมาณ หารด้วย 2', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 213', 'registered-2026.1', NULL, 'registered'),
    ('SH0103', 'S', 'percent', 'lower-is-better', 'annual', 'System', 'HRM: Percent of employee work-related Illness', 'ร้อยละบุคลากรที่เจ็บป่วยจากการทำงาน', '1. บุคลากร (employee) หมายถึง บุคลากรผู้ปฏิบัติงานภายใต้การจ้างงานหรือภายใต้การ ดูแลขององค์กรโดยตรง 2. การเจ็บป่วยจากการทำงาน (work-related illness) หมายถึง การเจ็บป่วยที่เกิดจาก การสัมผัสสิ่งที่เป็นอันตรายในการทำงาน (แสง เสียง รังสี ความสั่นสะเทือน ความร้อน สารเคมี ยาเคมีบำบัด เชื้อโรค ฝุ่นละอองต่างๆ) รวมถึง การเจ็บป่วยซึ่งไม่ได้เกิดโดยตรงจาก การทำงาน แต่การทำงานทำให้การเจ็บป่วยเป็นมากขึ้น ได้แก่ ปวดหลัง และความเครียด จากงาน 3. จำนวนบุคลากรเฉลี่ยปีงบประมาณ หมายถึง ผลรวมของจำนวนบุคลากรที่คงอยู่ ณ วัน แรกและวันสุดท้ายของปีงบประมาณ หารด้วย 2', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 214', 'registered-2026.1', NULL, 'registered'),
    ('SH0104', 'S', 'percent', 'lower-is-better', 'monthly', 'System', 'HRM: Turnover rate of physician and dentist', 'อัตราการลาออก ของแพทย์/ทันตแพทย์', 'คำนวณในกลุ่มที่ลาออกโดยสมัครใจ ไม่นับกลุ่มที่ให้ออก ไล่ออก ปลดออก เกษียณอายุ เข้า โครงการเกษียณก่อนอายุ ถึงแก่กรรม และโอน ย้าย โดยแยกเป็นกลุ่มวิชาชีพและไม่ใช่ วิชาชีพ', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 215', 'registered-2026.1', NULL, 'registered'),
    ('SH0105', 'S', 'percent', 'lower-is-better', 'monthly', 'System', 'HRM: Turnover rate of nurses', 'อัตราการลาออก ของพยาบาลวิชาชีพ', 'คำนวณในกลุ่มที่ลาออกโดยสมัครใจ ไม่นับกลุ่มที่ให้ออก ไล่ออก ปลดออก เกษียณอายุ เข้า โครงการเกษียณก่อนอายุ ถึงแก่กรรม และโอน ย้าย โดยแยกเป็นกลุ่มวิชาชีพและไม่ใช่ วิชาชีพ', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 216', 'registered-2026.1', NULL, 'registered'),
    ('SH0106', 'S', 'percent', 'lower-is-better', 'monthly', 'System', 'HRM: Turnover rate of allied health personnel', 'อัตราการลาออก ของบุคลากรสาย allied health', '1. บุคลากรสาย allied health หมายถึง บุคลากรในกลุ่มสัมผัสผู้ป่วยโดยตรง (ยกเว้น แพทย์/ ทันตแพทย์/ พยาบาลวิชาชีพ) และไม่ใช่บุคลากรสายสนับสนุน (back office) 2. บุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรง ได้แก่ แพทย์, ทันตแพทย์, พยาบาลวิชาชีพ, ผดุงครรภ์วิชาชีพ, เภสัชกร, ผู้ช่วยแพทย์, จนท.ด้านอาชีวอนามัยและสิ่งแวดล้อม, นักกายภาพบำบัด, โภชนากร, นักเวชศาสตร์สื่อความหมาย, นักทัศนมาตรวิชาชีพ, นักอาชีวบำบัด, เจ้าหน้าที่เทคนิคพยาธิวิทยาและห้องปฏิบัติการ, ผู้ช่วยเภสัชกร, จนท.อุปกรณ์การแพทย์เทียม, พนักงานการพยาบาล, ผู้ช่วยทันตแพทย์, เจ้าหน้าที่เวช ระเบียนและข้อมูลสุขภาพ, เจ้าหน้าที่สุขภาพชุมชน, ช่างประกอบแว่นตา, ผู้ช่วยนักกายภาพบำบัด, ผู้ตรวจสอบด้านอาชีวอนามัยและสิ่งแวดล้อม, ผู้ปฏิบัติงานด้าน รถพยาบาล, เจ้าหน้าที่จ่ายกลาง เวชภัณฑ์กลาง 3. คำนวณในกลุ่มที่ลาออกโดยสมัครใจ ไม่นับกลุ่มที่ให้ออก ไล่ออก ปลดออก เกษียณอายุ เข้าโครงการเกษียณก่อนอายุ ถึงแก่กรรม และโอน ย้าย โดยแยกเป็นกลุ่มวิชาชีพ และไม่ใช่วิชาชีพ', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 217', 'registered-2026.1', NULL, 'registered'),
    ('SH0107', 'S', 'percent', 'lower-is-better', 'monthly', 'System', 'HRM: Turnover rate of back office personnel', 'อัตราการลาออก ของบุคลากรสายสนับสนุน', '1. บุคลากรสายสนับสนุน (back office) หมายถึง บุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรง ได้แก่ นักบริหารด้านบริการสุขภาพ, นักวิทยาศาสตร์สิ่งมีชีวิต, นักสังคมสงเคราะห์ ผู้ให้คำปรึกษา, เจ้าหน้าที่ด้านบริหาร ธุรการ คลัง บุคคล ตลาด พัสดุ กฎหมาย ประกัน คุณภาพ, เจ้าหน้าที่สารสนเทศ, เจ้าหน้าที่วิเทศสัมพันธ์ ประชาสัมพันธ์ ผู้รับบริการสัมพันธ์, เจ้าหน้าที่งานสวนและสนาม, เจ้าหน้าที่ดูแลความสะอาดอาคารและห้องสุขา, ผู้ช่วยงานใน โรงครัว, ช่างไม้, ช่างประปา, ช่างระบบปรับอากาศและความเย็น, ช่างทาสี, ช่างเชื่อม, ช่างกลและเครื่องจักร, ช่างไฟฟ้าและอิเล็กทรอนิกส์, เจ้าหน้าที่งานตัด-เย็บ 2. คำนวณในกลุ่มที่ลาออกโดยสมัครใจ ไม่นับกลุ่มที่ให้ออก ไล่ออก ปลดออก เกษียณอายุ เข้าโครงการเกษียณก่อนอายุ ถึงแก่กรรม และโอน ย้าย โดยแยกเป็นกลุ่มวิชาชีพและไม่ใช่ วิชาชีพ', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุก 3 เดือน (รายไตรมาส)', 'THIP KPI Dictionary 2025 · หน้า 218', 'registered-2026.1', NULL, 'registered'),
    ('SH0201', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percent of physician/dentist satisfaction (level 4-5)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของแพทย์/ทันตแพทย์ (ระดับ 4-5)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 219', 'registered-2026.1', NULL, 'registered'),
    ('SH0202', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percent of nurse satisfaction (level 4-5)', 'ร้อยละความพึงพอใจ ของบุคลากรในองค์กรในภาพรวมของพยาบาลวิชาชีพ (ระดับ 4-5)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น5ระดับจากน้อยที่สุดไปถึงมากที่สุด', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 220', 'registered-2026.1', NULL, 'registered'),
    ('SH0203', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percent of allied health personel satisfaction (level 4-5)', 'ร้อยละความพึงพอใจ ของบุคลากรในองค์กรในภาพรวมของบุคลากรสาย Allied Health (ระดับ 4-5)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. บุคลากรสาย allied health หมายถึง บุคลากรในกลุ่มสัมผัสผู้ป่วยโดยตรง (ยกเว้น แพทย์/ ทันตแพทย์/ พยาบาลวิชาชีพ) และไม่ใช่บุคลากรสายสนับสนุน (back office) 4. บุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรง ได้แก่ แพทย์, ทันตแพทย์, พยาบาลวิชาชีพ, ผดุงครรภ์ วิชาชีพ, เภสัชกร, ผู้ช่วยแพทย์, เจ้าหน้าที่ด้านอาชีวอนามัยและสิ่งแวดล้อม, นักกายภาพบำบัด, โภชนากร, นักเวชศาสตร์สื่อความหมาย, นักทัศนมาตรวิชาชีพ, นักอาชีวบำบัด, เจ้าหน้าที่เทคนิคพยาธิวิทยาและห้องปฏิบัติการ, ผู้ช่วยเภสัชกร, เจ้าหน้าที่ อุปกรณ์การแพทย์เทียม, พนักงานการพยาบาล, ผู้ช่วยทันตแพทย์, เจ้าหน้าที่เวชระเบียน และข้อมูลสุขภาพ, เจ้าหน้าที่สุขภาพชุมชน, ช่างประกอบแว่นตา, ผู้ช่วยนักกายภาพบำบัด, ผู้ตรวจสอบด้านอาชีวอนามัยและสิ่งแวดล้อม, ผู้ปฏิบัติงานด้านรถพยาบาล, เจ้าหน้าที่จ่าย กลาง เวชภัณฑ์กลาง', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 221', 'registered-2026.1', NULL, 'registered'),
    ('SH0204', 'S', 'ratio', 'higher-is-better', 'annual', 'System', 'HRD: Training hour per person per year of physician/dentist', 'สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของแพทย์/ ทันตแพทย์', '1. การฝึกอบรมที่นับจำนวนชั่วโมง ได้แก่ ศึกษา, ฝึกอบรม, ปฏิบัติงานวิจัย (ที่ระยะเวลา ไม่เกิน 3 เดือน), ดูงาน, การให้บริการทางวิชาการ, ประชุม, ประชุมและเป็นวิทยากร, ประชุมและเสนอผลงาน, อบรม, สัมมนา ที่มีกำหนดการประชุมและ/ หรือช่วงเวลาเริ่มต้น- สิ้นสุดที่ชัดเจน 1.1 กรณีไปเป็นวิทยากรโดยไม่เข้าร่วมประชุม จะนับชั่วโมงจริงเฉพาะช่วงเวลาที่เป็น วิทยากรเท่านั้น 1.2 กรณีไปเป็นวิทยากรและเข้าร่วมประชุม, กรณีประชุมและเสนอผลงาน จะนับชั่วโมง รวมเป็นประชุม 2. การฝึกอบรมที่ไม่นับจำนวนชั่วโมง ได้แก่ การไปปฏิบัติงานตามภาระงานบริหารหรือที่ ได้รับมอบหมายด้านการบริหาร (ไปราชการ) 3. จำนวนชั่วโมงอบรม 1 วัน =6 ชั่วโมง (ไม่คิดช่วงเวลาพักทานอาหารกลางวัน) 1 เดือน =23 วันทำการ (กรณีไม่มีกำหนดการอบรมจะไม่คิดวันเสาร์/อาทิตย์ ตาม มาตรฐานการคิดเวลาทำงาน)', 'a/b', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 222', 'registered-2026.1', NULL, 'registered'),
    ('SH0205', 'S', 'ratio', 'higher-is-better', 'annual', 'System', 'HRD: HRD: Training hour per person per Year of nurse', 'สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของพยาบาลวิชาชีพ', '1. การฝึกอบรมที่นับจำนวนชั่วโมง ได้แก่ ศึกษา, ฝึกอบรม, ปฏิบัติงานวิจัย (ที่ระยะเวลา ไม่เกิน 3 เดือน), ดูงาน, การให้บริการทางวิชาการ, ประชุม, ประชุมและเป็นวิทยากร, ประชุมและเสนอผลงาน, อบรม, สัมมนา ที่มีกำหนดการประชุมและ/หรือช่วงเวลาเริ่มต้น- สิ้นสุดที่ชัดเจน 1.1 กรณีไปเป็นวิทยากรโดยไม่เข้าร่วมประชุม จะนับชั่วโมงจริงเฉพาะช่วงเวลาที่เป็น วิทยากรเท่านั้น 1.2 กรณีไปเป็นวิทยากรและเข้าร่วมประชุม, กรณีประชุมและเสนอผลงาน จะนับชั่วโมง รวมเป็นประชุม 2. การฝึกอบรมที่ไม่นับจำนวนชั่วโมง ได้แก่ การไปปฏิบัติงานตามภาระงานบริหารหรือที่ ได้รับมอบหมายด้านการบริหาร (ไปราชการ) 3. จำนวนชั่วโมงอบรม 1 วัน =6 ชั่วโมง (ไม่คิดช่วงเวลาพักทานอาหารกลางวัน) 1 เดือน =23 วันทำการ (กรณีไม่มีกำหนดการอบรมจะไม่คิดวันเสาร์/อาทิตย์ ตาม มาตรฐานการคิดเวลาทำงาน)', 'a/b', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 223', 'registered-2026.1', NULL, 'registered'),
    ('SH0206', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percent of physician and dentist satisfaction (average)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของแพทย์/ทันตแพทย์ (ค่าเฉลี่ย)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 224', 'registered-2026.1', NULL, 'registered'),
    ('SH0207', 'S', 'percent', 'lower-is-better', 'annual', 'System', 'HRD: Percent of physician and dentist satisfaction (level 1-2)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของแพทย์/ทันตแพทย์(ระดับ 1-2)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 225', 'registered-2026.1', NULL, 'registered'),
    ('SH0208', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percentage of nurse satisfaction (average)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของพยาบาลวิชาชีพ (ค่าเฉลี่ย)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 226', 'registered-2026.1', NULL, 'registered'),
    ('SH0209', 'S', 'percent', 'lower-is-better', 'annual', 'System', 'HRD: Percentage of nurse satisfaction (level 1-2)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของพยาบาลวิชาชีพ (ระดับ 1-2)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 227', 'registered-2026.1', NULL, 'registered'),
    ('SH0210', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percent of allied health personnel satisfaction (average)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสาย allied health (ค่าเฉลี่ย)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจหมายถึงระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น5ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. บุคลากรสาย allied health หมายถึง บุคลากรในกลุ่มสัมผัสผู้ป่วยโดยตรง (ยกเว้น แพทย์/ ทันตแพทย์/ พยาบาลวิชาชีพ) และไม่ใช่บุคลากรสายสนับสนุน (back office) 4. บุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรง ได้แก่ แพทย์, ทันตแพทย์, พยาบาลวิชาชีพ, ผดุงครรภ์ วิชาชีพ, เภสัชกร, ผู้ช่วยแพทย์, เจ้าหน้าที่ด้านอาชีวอนามัยและสิ่งแวดล้อม, นักกายภาพบำบัด, โภชนากร, นักเวชศาสตร์สื่อความหมาย, นักทัศนมาตรวิชาชีพ, นักอาชีวบำบัด, เจ้าหน้าที่เทคนิคพยาธิวิทยาและห้องปฏิบัติการ, ผู้ช่วยเภสัชกร, เจ้าหน้าที่ อุปกรณ์การแพทย์เทียม, พนักงานการพยาบาล, ผู้ช่วยทันตแพทย์, เจ้าหน้าที่เวชระเบียน และข้อมูลสุขภาพ, เจ้าหน้าที่สุขภาพชุมชน, ช่างประกอบแว่นตา, ผู้ช่วยนักกายภาพบำบัด, ผู้ตรวจสอบด้านอาชีวอนามัยและสิ่งแวดล้อม, ผู้ปฏิบัติงานด้านรถพยาบาล, เจ้าหน้าที่จ่ายกลาง เวชภัณฑ์กลาง', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 228', 'registered-2026.1', NULL, 'registered'),
    ('SH0211', 'S', 'percent', 'lower-is-better', 'annual', 'System', 'HRD: Percent of allied health personnel satisfaction (level 1-2)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสาย allied health (ระดับ 1-2)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. บุคลากรสาย allied health หมายถึง บุคลากรในกลุ่มสัมผัสผู้ป่วยโดยตรง (ยกเว้น แพทย์/ ทันตแพทย์/ พยาบาลวิชาชีพ) และไม่ใช่บุคลากรสายสนับสนุน (back office) 4. บุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรง ได้แก่ แพทย์, ทันตแพทย์, พยาบาลวิชาชีพ, ผดุงครรภ์ วิชาชีพ, เภสัชกร, ผู้ช่วยแพทย์, เจ้าหน้าที่ด้านอาชีวอนามัยและสิ่งแวดล้อม, นักกายภาพบำบัด, โภชนากร, นักเวชศาสตร์สื่อความหมาย, นักทัศนมาตรวิชาชีพ, นักอาชีวบำบัด, เจ้าหน้าที่เทคนิคพยาธิวิทยาและห้องปฏิบัติการ, ผู้ช่วยเภสัชกร, เจ้าหน้าที่ อุปกรณ์การแพทย์เทียม, พนักงานการพยาบาล, ผู้ช่วยทันตแพทย์, เจ้าหน้าที่เวชระเบียน และข้อมูลสุขภาพ, เจ้าหน้าที่สุขภาพชุมชน, ช่างประกอบแว่นตา, ผู้ช่วยนักกายภาพบำบัด, ผู้ตรวจสอบด้านอาชีวอนามัยและสิ่งแวดล้อม, ผู้ปฏิบัติงานด้านรถพยาบาล, เจ้าหน้าที่จ่าย กลาง เวชภัณฑ์กลาง', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 229', 'registered-2026.1', NULL, 'registered'),
    ('SH0212', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percent of back office personnel satisfaction (average)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสายสนับสนุน(ค่าเฉลี่ย)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. บุคลากรสายสนับสนุน (back office) หมายถึง บุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรง ได้แก่ นักบริหารด้านบริการสุขภาพ, นักวิทยาศาสตร์สิ่งมีชีวิต, นักสังคมสงเคราะห์ ผู้ให้คำปรึกษา, เจ้าหน้าที่ด้านบริหาร ธุรการ คลัง บุคคล ตลาด พัสดุ กฎหมาย ประกัน คุณภาพ, เจ้าหน้าที่สารสนเทศ, เจ้าหน้าที่วิเทศสัมพันธ์ ประชาสัมพันธ์ ผู้รับบริการสัมพันธ์, เจ้าหน้าที่งานสวนและสนาม, เจ้าหน้าที่ดูแลความสะอาดอาคารและห้องสุขา, ผู้ช่วยงานใน โรงครัว, ช่างไม้, ช่างประปา, ช่างระบบปรับอากาศและความเย็น, ช่างทาสี, ช่างเชื่อม, ช่างกลและเครื่องจักร, ช่างไฟฟ้าและอิเล็กทรอนิกส์, เจ้าหน้าที่งานตัด-เย็บ', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 230', 'registered-2026.1', NULL, 'registered'),
    ('SH0213', 'S', 'percent', 'higher-is-better', 'annual', 'System', 'HRD: Percentage of back office personnel satisfaction (level 4-5)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสายสนับสนุน (ระดับ 4-5)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น5ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. บุคลากรสายสนับสนุน (back office) หมายถึง บุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรง ได้แก่ นักบริหารด้านบริการสุขภาพ, นักวิทยาศาสตร์สิ่งมีชีวิต, นักสังคมสงเคราะห์ ผู้ให้คำปรึกษา, เจ้าหน้าที่ด้านบริหาร ธุรการ คลัง บุคคล ตลาด พัสดุ กฎหมาย ประกัน คุณภาพ, เจ้าหน้าที่สารสนเทศ, เจ้าหน้าที่วิเทศสัมพันธ์ ประชาสัมพันธ์ ผู้รับบริการสัมพันธ์, เจ้าหน้าที่งานสวนและสนาม, เจ้าหน้าที่ดูแลความสะอาดอาคารและห้องสุขา, ผู้ช่วยงานใน โรงครัว, ช่างไม้, ช่างประปา, ช่างระบบปรับอากาศและความเย็น, ช่างทาสี, ช่างเชื่อม, ช่างกลและเครื่องจักร, ช่างไฟฟ้าและอิเล็กทรอนิกส์, เจ้าหน้าที่งานตัด-เย็บ', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 231', 'registered-2026.1', NULL, 'registered'),
    ('SH0214', 'S', 'percent', 'lower-is-better', 'annual', 'System', 'HRD: Percentage of back office personnel satisfaction (level 1-2)', 'ร้อยละความพึงพอใจของบุคลากรในองค์กรในภาพรวมของบุคลากรสายสนับสนุน (ระดับ 1-2)', '1. โดยใช้แบบสอบถามตามบริบทของแต่ละองค์กร แต่กำหนดให้ใช้เฉพาะข้อคำถาม “ท่านมีความพึงพอใจต่อองค์กร โดยรวม ในระดับใด” 2. ระดับความพึงพอใจ หมายถึง ระดับความรู้สึกพึงพอใจต่อองค์กรที่ระบุไว้ในแต่ละข้อ คำถามของแบบสอบถามซึ่งแบ่งออกเป็น 5 ระดับจากน้อยที่สุดไปถึงมากที่สุด 3. บุคลากรสายสนับสนุน (back office) หมายถึง บุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรง ได้แก่ นักบริหารด้านบริการสุขภาพ, นักวิทยาศาสตร์สิ่งมีชีวิต, นักสังคมสงเคราะห์ ผู้ให้คำปรึกษา, เจ้าหน้าที่ด้านบริหาร ธุรการ คลัง บุคคล ตลาด พัสดุ กฎหมาย ประกัน คุณภาพ, เจ้าหน้าที่สารสนเทศ, เจ้าหน้าที่วิเทศสัมพันธ์ ประชาสัมพันธ์ ผู้รับบริการสัมพันธ์, เจ้าหน้าที่งานสวนและสนาม, เจ้าหน้าที่ดูแลความสะอาดอาคารและห้องสุขา, ผู้ช่วยงานใน โรงครัว, ช่างไม้, ช่างประปา, ช่างระบบปรับอากาศและความเย็น, ช่างทาสี, ช่างเชื่อม, ช่างกลและเครื่องจักร, ช่างไฟฟ้าและอิเล็กทรอนิกส์, เจ้าหน้าที่งานตัด-เย็บ', '(a/b) x 100', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 232', 'registered-2026.1', NULL, 'registered'),
    ('SH0215', 'S', 'ratio', 'higher-is-better', 'annual', 'System', 'HRD: Training hour per person per year of allied health personnel', 'สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของบุคลากรสาย allied health', '1. การฝึกอบรมที่นับจำนวนชั่วโมง ได้แก่ ศึกษา, ฝึกอบรม, ปฏิบัติงานวิจัย (ที่ระยะเวลาไม่ เกิน 3 เดือน), ดูงาน, การให้บริการทางวิชาการ, ประชุม, ประชุมและเป็นวิทยากร, ประชุม และเสนอผลงาน, อบรม, สัมมนา ที่มีกำหนดการประชุมและ/หรือช่วงเวลาเริ่มต้น-สิ้นสุดที่ ชัดเจน 1.1 กรณีไปเป็นวิทยากรโดยไม่เข้าร่วมประชุม จะนับชั่วโมงจริงเฉพาะช่วงเวลาที่เป็น วิทยากรเท่านั้น 1.2 กรณีไปเป็นวิทยากรและเข้าร่วมประชุม, กรณีประชุมและเสนอผลงาน จะนับชั่วโมง รวมเป็นประชุม 2. การฝึกอบรมที่ไม่นับจำนวนชั่วโมง ได้แก่ การไปปฏิบัติงานตามภาระงานบริหารหรือที่ ได้รับมอบหมายด้านการบริหาร (ไปราชการ) 3. จำนวนชั่วโมงอบรม 1 วัน =6 ชั่วโมง (ไม่คิดช่วงเวลาพักทานอาหารกลางวัน) 1 เดือน =23 วันทำการ (กรณีไม่มีกำหนดการอบรมจะไม่คิดวันเสาร์/อาทิตย์-ตาม มาตรฐานการคิดเวลาทำงาน)', 'a/b', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 233', 'registered-2026.1', NULL, 'registered'),
    ('SH0216', 'S', 'ratio', 'higher-is-better', 'annual', 'System', 'HRD: Training hour per person per year of back office personnel', 'สัดส่วนชั่วโมงการฝึกอบรมต่อคนต่อปีของบุคลากรสายสนับสนุน', '1. การฝึกอบรมที่นับจำนวนชั่วโมง ได้แก่ ศึกษา, ฝึกอบรม, ปฏิบัติงานวิจัย (ที่ระยะเวลาไม่ เกิน 3 เดือน), ดูงาน, การให้บริการทางวิชาการ, ประชุม, ประชุมและเป็นวิทยากร, ประชุม และเสนอผลงาน, อบรม, สัมมนา ที่มีกำหนดการประชุมและ/หรือช่วงเวลาเริ่มต้น-สิ้นสุดที่ ชัดเจน 1.1 กรณีไปเป็นวิทยากรโดยไม่เข้าร่วมประชุม จะนับชั่วโมงจริงเฉพาะช่วงเวลาที่เป็น วิทยากรเท่านั้น 1.2 กรณีไปเป็นวิทยากรและเข้าร่วมประชุม, กรณีประชุมและเสนอผลงาน จะนับชั่วโมง รวมเป็นประชุม 2. การฝึกอบรมที่ไม่นับจำนวนชั่วโมง ได้แก่ การไปปฏิบัติงานตามภาระงานบริหารหรือที่ ได้รับมอบหมายด้านการบริหาร (ไปราชการ) 3. จำนวนชั่วโมงอบรม 1 วัน =6 ชั่วโมง (ไม่คิดช่วงเวลาพักทานอาหารกลางวัน) 1 เดือน =23 วันทำการ (กรณีไม่มีกำหนดการอบรมจะไม่คิดวันเสาร์/อาทิตย์ ตาม มาตรฐานการคิดเวลาทำงาน)', 'a/b', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกปี (รายปี)', 'THIP KPI Dictionary 2025 · หน้า 234', 'registered-2026.1', NULL, 'registered'),
    ('SH0301', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'HRH: Injury (Illnesses) Frequency Rate (IFR)', 'อัตราความถี่การบาดเจ็บ/ เจ็บป่วยของบุคลากรที่เกี่ยวเนื่องจากงาน', '1. เป็นการวัดอัตราการบาดเจ็บของบุคลากรที่มีการบาดเจ็บซึ่งมีสาเหตุจากการปฏิบัติงาน ในหน้าที่และในเวลางานเท่านั้นเป็นตัวชี้วัดที่สะท้อนผลการดำเนินงานในอดีตเท่านั้น 2. จำนวนชั่วโมงการทำงานของบุคลากร เป็นการคิดคำนวณชั่วโมงการทำงานของบุคลากร ทั้งหมดในองค์กร ตามจำนวนเวรที่ปฏิบัติงานในเดือนนั้น ๆ คูณด้วยจำนวนชั่วโมงในแต่ละ เวร (เช่น ในเดือนนั้นมีบุคลากรมาปฎิบัติงาน 50 คน เข้าเวร 8 ชั่วโมง จำนวนเวรทั้งหมด 200 เวร รวมชั่วโมงการทำงานทั้งหมดในเดือนนั้นคิดเป็น 8 X 200 = 1,600 ชั่วโมงการ ทำงาน)', '(a/b) x 1,000,000', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 235', 'registered-2026.1', NULL, 'registered'),
    ('SH0302', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'HRH: Injury Severity Rate: ISR of Direct Contact with Patients', 'อัตราความรุนแรงของการบาดเจ็บของบุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรง', '1. เป็นการประเมินความรุนแรงของการบาดเจ็บจากจำนวนวันทั้งหมดที่พนักงานต้องหยุด งาน เพื่อรักษาพยาบาลจนกว่าจะกลับไปทำงานใหม่ได้ ต่อชั่วโมงการทำงาน 1,000,000 ชั่วโมงโดยไม่นับวันที่เข้ารับการปฐมพยาบาลหากมีการเสียชีวิตในงานให้คิดเป็น 8,000 ชั่วโมงที่หายไป 2. จำนวนชั่วโมงการทำงานของบุคลากร เป็นการคิดคำนวณชั่วโมงการทำงานของบุคลากร ทั้งหมดในองค์กร ตามจำนวนเวรที่ปฏิบัติงานในเดือนนั้นๆ คูณด้วยจำนวนชั่วโมงในแต่ละ เวร (เช่น ในเดือนนั้นมีบุคลากรมาปฎิบัติงาน 50 คน เข้าเวร 8 ชั่วโมง จำนวนเวรทั้งหมด 200 เวร รวมชั่วโมงการทำงานทั้งหมดคิดเป็น 8X200=1,600 ชั่วโมงการทำงาน) 3. การบาดเจ็บ (injury) หมายถึง เฉพาะการบาดเจ็บเท่านั้น ไม่รวมถึงการเจ็บป่วย (illness) จากโรคที่เกิดจากการทำงาน', '(a/b) x 1,000,000', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 236', 'registered-2026.1', NULL, 'registered'),
    ('SH0303', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'HRH: Injury Severity Rate: ISRof non Direct Contact with Patients', 'อัตราความรุนแรงของการบาดเจ็บของบุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรง', '1. เป็นการประเมินความรุนแรงของการบาดเจ็บจากจำนวนวันทั้งหมดที่พนักงานต้องหยุด งาน เพื่อรักษาพยาบาลจนกว่าจะกลับไปทำงานใหม่ได้ ต่อชั่วโมงการทำงาน 1,000,000 ชั่วโมงโดยไม่นับวันที่เข้ารับการปฐมพยาบาลหากมีการเสียชีวิตในงานให้คิดเป็น 8,000 ชั่วโมงที่หายไป 2. จำนวนชั่วโมงการทำงานของบุคลากร เป็นการคิดคำนวณชั่วโมงการทำงานของบุคลากร ทั้งหมดในองค์กร ตามจำนวนเวรที่ปฏิบัติงานในเดือนนั้นๆ คูณด้วยจำนวนชั่วโมงในแต่ละ เวร (เช่น ในเดือนนั้นมีบุคลากรมาปฎิบัติงาน 50 คน เข้าเวร 8 ชั่วโมง จำนวน 150 เวร และเข้าเวร 10 ชั่วโมง จำนวน 50 เวร รวมชั่วโมงการทำงานทั้งหมด คิดเป็น {(8*150) + (10*50)} =1,700 ชั่วโมงการทำงาน)', '(a/b) x 1,000,000', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 238', 'registered-2026.1', NULL, 'registered'),
    ('SH0306', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'HRH: Injury (illnesses) Frequency Rate: IFR of direct contact with patients', 'อัตราความถี่การบาดเจ็บ/เจ็บป่วยของบุคลากรที่เกี่ยวเนื่องจากงาน ของบุคลากรกลุ่ม สัมผัสผู้ป่วยโดยตรง', '1. เป็นการวัดอัตราการบาดเจ็บ/เจ็บป่วยของบุคลากร ซึ่งมีสาเหตุจากการปฏิบัติงานใน หน้าที่และในเวลางานเท่านั้น เป็นตัวชี้วัดที่สะท้อนผลการดำเนินงานในอดีตเท่านั้น 2. จำนวนชั่วโมงการทำงานของบุคลากร เป็นการคิดคำนวณชั่วโมงการทำงานของบุคลากร ทั้งหมดในองค์กร ตามจำนวนเวรที่ปฏิบัติงานในเดือนนั้นๆ คูณด้วยจำนวนชั่วโมงในแต่ละ เวร (เช่น ในเดือนนั้นมีบุคลากรมาปฎิบัติงาน 50 คน เข้าเวร 8 ชั่วโมง จำนวนเวรทั้งหมด 200 เวร รวมชั่วโมงการทำงานทั้งหมดคิดเป็น 8X200 = 1,600 ชั่วโมงการทำงาน)', '(a/b) x 1,000,000', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 240', 'registered-2026.1', NULL, 'registered'),
    ('SH0307', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'HRH: Injury (Illnesses) Frequency Rate : IFR of Non-direct Contact with Patients', 'อัตราความถี่การบาดเจ็บ/เจ็บป่วยของบุคลากรที่เกี่ยวเนื่องจากงานของบุคลากรกลุ่มที่ ไม่ได้สัมผัสผู้ป่วยโดยตรง', '1. เป็นการวัดอัตราการบาดเจ็บ/เจ็บป่วยของบุคลากร ซึ่งมีสาเหตุจากการปฏิบัติงานใน หน้าที่และในเวลางานเท่านั้น เป็นตัวชี้วัดที่สะท้อนผลการดำเนินงานในอดีตเท่านั้น 2. จำนวนชั่วโมงการทำงานของบุคลากร เป็นการคิดคำนวณชั่วโมงการทำงานของบุคลากร ทั้งหมดในองค์กร ตามจำนวนเวรที่ปฏิบัติงานในเดือนนั้นๆ คูณด้วยจำนวนชั่วโมงในแต่ละ เวร (เช่น ในเดือนนั้นมีบุคลากรมาปฎิบัติงาน 50 คน เข้าเวร 8 ชั่วโมง จำนวน 150 เวร และเข้าเวร 10 ชั่วโมง จำนวน 50 เวร รวมชั่วโมงการทำงานทั้งหมดคิดเป็น {(8X150) + (10X50)} = 1,700 ชั่วโมงการทำงาน)', '(a/b) x 1,000,000', 'a', 'b', ARRAY['emp', 'emp_history', 'emp_in_out', 'emp_resign', 'emp_stat', 'emp_work_sick', 'emp_work_status', 'emp_work_summary', 'emp_work_schedule', 'emp_position', 'emp_department', 'emp_education']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 242', 'registered-2026.1', NULL, 'registered'),
    ('SI0101', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'VAP: Rate of ventilator-associated pneumonia (All)', 'อัตราการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจ (ภาพรวม)', 'การติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจสำหรับผู้ป่วยในจากทุกหอผู้ป่วย โดยนับ รวมผู้ป่วยทั้งที่อยู่ในและนอกห้อง ICU (Ventilator-associated pneumonia: VAP) หมายถึง ภาวะปอดอักเสบที่เกิดขึ้นใหม่ในผู้ป่วยที่ใส่ท่อช่วยหายใจและใช้เครื่องช่วยหายใจ โดยเกิดหลังจากผู้ป่วยใช้เครื่องช่วยหายใจมากกว่า 2 วันปฏิทิน (วันแรกที่ใส่เครื่องช่วย หายใจนับเป็น 1 วันปฏิทิน) หรือหลังจากถอดเครื่องช่วยหายใจภายใน 2 วันปฏิทิน (the ventilator was in place on the date of event or the day before)', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 202', 'registered-2026.1', NULL, 'registered'),
    ('SI0102', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'VAP: Rate of ventilator-associated pneumonia in ICU', 'อัตราการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจ ของผู้ป่วยที่นอนรักษาใน ICU', '1. การติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจสำหรับผู้ป่วยที่รักษาในห้อง ICU (Ventilator-associated pneumonia: VAP) (in ICU) หมายถึง ภาวะปอดอักเสบที่เกิดขึ้นใหม่ใน ผู้ป่วยที่รักษาในห้อง ICU ที่ใส่ท่อช่วยหายใจและใช้เครื่องช่วยหายใจ โดยเกิดหลังจากผู้ป่วยใช้ เครื่องช่วยหายใจมากกว่า 2 วันปฏิทิน (วันแรกที่ใส่เครื่องช่วยหายใจนับเป็น 1 วันปฏิทิน) หรือ หลังจากถอดเครื่องช่วยหายใจภายใน 2วันปฏิทิน (the ventilator was in place on the date of event or the day before) (หากโรงพยาบาลมีหลาย ICU ให้รวมยอดจากทุก ICU) 2. ไอ ซี ยู คือ หอผู้ป่วยจำเพาะที่ให้การดูแลรักษาผู้ป่วยวิกฤตที่มีโรคหรือการบาดเจ็บรุนแรงจน อาจเสียชีวิต โดยการรักษาเหตุของโรคและการรักษาประคับประคองเพื่อรอให้อวัยวะที่เสื่อมสภาพ กลับฟื้นมาทำงานร่วมกับการติดตามเฝ้าระวังโดยบุคลากรและการใช้เครื่องมือต่างๆอย่างใกล้ชิด', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 203', 'registered-2026.1', NULL, 'registered'),
    ('SI0103', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'VAP: Rate of ventilator-associated pneumonia outside ICU', 'อัตราการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจ ของผู้ป่วยที่นอนรักษานอก ICU ของโรงพยาบาล', '1. การติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจ ของผู้ป่วยที่อยู่นอกห้อง ICU (VAP outside ICU) โดยนับเฉพาะผู้ป่วยที่รักษาอยู่นอกห้อง ICU หมายถึง ภาวะปอดอกเสบที่ เกิดขึ้นใหม่ในผู้ป่วยที่รักษาอยู่นอกห้อง ICU ทั้งหมดที่ใส่ท่อช่วยหายใจและใช้เครื่องช่วย หายใจ โดยเกิดหลังจากผู้ป่วยใช้เครื่องช่วยหายใจมากกว่า 2 วันปฏิทิน (วันแรกที่ใส่ เครื่องช่วยหายใจนับเป็น 1 วันปฏิทิน) หรือหลังจากถอดเครื่องช่วยหายใจภายใน 2 วัน ปฏิทิน (the ventilator was in place on the date of event or the day before) 2. ไอ ซี ยู คือ หอผู้ป่วยจำเพาะที่ให้การดูแลรักษาผู้ป่วยวิกฤตที่มีโรคหรือการบาดเจ็บ รุนแรงจนอาจเสียชีวิต โดยการรักษาเหตุของโรคและการรักษาประคับประคองเพื่อรอให้ อวัยวะที่เสื่อมสภาพกลับฟื้นมาทำงาน ร่วมกับการติดตามเฝ้าระวังโดยบุคลากรและการใช้ เครื่องมือต่างๆ อย่างใกล้ชิด', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 204', 'registered-2026.1', NULL, 'registered'),
    ('SI0201', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'BSI: Rate of CABSI (All)', 'อัตราการติดเชื้อในกระแสเลือดจากการคาสายสวนหลอดเลือดส่วนกลาง (ภาพรวม)', 'เป็นการติดเชื้อในกระแสเลือดหลังจากใส่สายสวนหลอดเลือดส่วนกลางมากกว่า 2 วัน ปฏิทิน (วันแรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และเมื่อถอดสายสวนหลอดเลือดออกภายใน 1 วันปฏิทิน (*in place on the date of event or the day before) ของผู้ป่วยในจาก ทุกหอผู้ป่วยโดยนับรวมผู้ป่วยทั้งที่อยู่ในและนอกห้อง ICU', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 205', 'registered-2026.1', NULL, 'registered'),
    ('SI0202', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'BSI: Rate of CABSI in ICU', 'อัตราการติดเชื้อในกระแสเลือดจากการคาสายสวนหลอดเลือดส่วนกลาง ของผู้ป่วยที่นอน รักษาใน ICU', '1. ผู้ป่วยติดเชื้อในกระแสเลือดหลังจากใส่สายสวนหลอดเลือดส่วนกลางมากกว่า 2 วัน ปฏิทิน (วันแรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และเมื่อถอดสายสวนหลอดเลือดออกภายใน 1 วันปฏิทิน (* in place on the date of event or the day before) สำหรับผู้ป่วยที่ รักษาในห้อง ICU (หากโรงพยาบาล มีหลาย ICU ให้รวมยอดจากทุก ICU) 2. ไอ ซี ยู คือ หอผู้ป่วยจำเพาะที่ให้การดูแลรักษาผู้ป่วยวิกฤตที่มีโรคหรือการบาดเจ็บ รุนแรงจนอาจเสียชีวิต โดยการรักษาเหตุของโรคและการรักษาประคับประคองเพื่อรอให้ อวัยวะที่เสื่อมสภาพกลับฟื้นมาทำงาน ร่วมกับการติดตามเฝ้าระวังโดยบุคลากรและการใช้ เครื่องมือต่างๆ อย่างใกล้ชิด', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 206', 'registered-2026.1', NULL, 'registered'),
    ('SI0203', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'BSI: Rate of CABSI outside ICU', 'อัตราการติดเชื้อในกระแสเลือดจากการคาสายสวนหลอดเลือดส่วนกลาง ของผู้ป่วยที่นอน รักษานอก ICU ของโรงพยาบาล', '1. ผู้ป่วยติดเชื้อในกระแสเลือดหลังจากใส่สายสวนหลอดเลือดส่วนกลางมากกว่า 2 วัน ปฏิทิน (วันแรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และเมื่อถอดสายสวนหลอดเลือดออกภายใน 1 วันปฏิทิน (*in place on the date of event or the day before)โดยนับเฉพาะผู้ป่วย ที่รักษานอกห้อง ICU ทั้งหมด 2. ไอ ซี ยู คือ หอผู้ป่วยจำเพาะที่ให้การดูแลรักษาผู้ป่วยวิกฤตที่มีโรคหรือการบาดเจ็บ รุนแรงจนอาจเสียชีวิต โดยการรักษาเหตุของโรคและการรักษาประคับประคองเพื่อรอให้ อวัยวะที่เสื่อมสภาพกลับฟื้นมาทำงาน ร่วมกับการติดตามเฝ้าระวังโดยบุคลากร และการใช้ เครื่องมือต่างๆ อย่างใกล้ชิด', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 207', 'registered-2026.1', NULL, 'registered'),
    ('SI0301', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'CAUTI: Rate of CAUTI (All)', 'อัตราการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะ (ภาพรวม)', 'เป็นการติดเชื้อในระบบทางเดินปัสสาวะ (นับเฉพาะชนิดที่มีอาการ ไม่นับการติดเชื้อที่ไม่มี อาการ (Asymptomatic bacteriuria) แต่มีการติดเชื้อในเลือด โดยเชื้อในเลือดเป็นชนิด เดียวกับที่พบในปัสสาวะ) อันเป็นผลมาจากการคาสายสวนปัสสาวะเกิน 2 วันปฏิทิน (วัน แรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และหลังเอาสายสวนปัสสาวะออกภายใน 2 วันปฏิทิน (*in place on the date of event or the day before) ของผู้ป่วยใน จากทุกหอผู้ป่วย โดยนับรวมผู้ป่วยทั้งที่อยู่ใน และนอกห้อง ICU', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 208', 'registered-2026.1', NULL, 'registered'),
    ('SI0302', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'CAUTI: Rate of CAUTI in ICU', 'อัตราการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะ ของผู้ป่วยที่นอนรักษา ใน ICU', '1. การติดเชื้อของผู้ป่วยในระบบทางเดินปัสสาวะ (นับเฉพาะชนิดที่มีอาการ ไม่นับการติด เชื้อที่ไม่มีอาการ (asymptomatic bacteriuria) แต่มีการติดเชื้อในเลือดโดยเชื้อในเลือด เป็นชนิดเดียวกับที่พบในปัสสาวะ) อันเป็นผลมาจากการคาสายสวนปัสสาวะเกิน 2 วัน ปฏิทิน (วันแรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และหลังเอาสายสวนปัสสาวะออกภายใน 2 วันปฏิทิน (*in place on the date of event or the day before) สำหรับผู้ป่วยที่ รักษาในห้อง ICU (หากโรงพยาบาลมีหลาย ICU ให้รวมยอดจากทุก ICU) 2. ไอ ซี ยู คือ หอผู้ป่วยจำเพาะที่ให้การดูแลรักษาผู้ป่วยวิกฤตที่มีโรคหรือการบาดเจ็บ รุนแรงจนอาจเสียชีวิต โดยการรักษาเหตุของโรคและการรักษาประคับประคองเพื่อรอให้ อวัยวะที่เสื่อมสภาพกลับฟื้นมาทำงาน ร่วมกับการติดตามเฝ้าระวังโดยบุคลากรและการใช้ เครื่องมือต่างๆ อย่างใกล้ชิด', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 209', 'registered-2026.1', NULL, 'registered'),
    ('SI0303', 'S', 'rate', 'lower-is-better', 'monthly', 'System', 'CAUTI: Rate of CAUTI outside ICU', 'อัตราการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะ ของผู้ป่วยที่นอนรักษา นอก ICU ของโรงพยาบาล', '1. การติดเชื้อของผู้ป่วยในระบบทางเดินปัสสาวะ(นับเฉพาะชนิดที่มีอาการ ไม่นับการติด เชื้อที่ไม่มีอาการ (asymptomatic bacteriuria) แต่มีการติดเชื้อในเลือดโดยเชื้อในเลือด เป็นชนิดเดียวกับที่พบในปัสสาวะ) อันเป็นผลมาจากการคาสายสวนปัสสาวะเกิน 2 วัน ปฏิทิน (วันแรกที่ใส่นับเป็นวันที่ 1 วันปฏิทิน) และหลังเอาสายสวนปัสสาวะออกภายใน 2 วันปฏิทิน (*in place on the date of event or the day before) เฉพาะผู้ป่วยที่รักษา นอกห้อง ICU 2. ไอ ซี ยู คือ หอผู้ป่วยจำเพาะที่ให้การดูแลรักษาผู้ป่วยวิกฤตที่มีโรคหรือการบาดเจ็บ รุนแรงจนอาจเสียชีวิต โดยการรักษาเหตุของโรคและการรักษาประคับประคองเพื่อรอให้ อวัยวะที่เสื่อมสภาพกลับฟื้นมาทำงาน ร่วมกับการติดตามเฝ้าระวังโดยบุคลากรและการใช้ เครื่องมือต่างๆ อย่างใกล้ชิด', '(a/b) x 1,000', 'a', 'b', ARRAY['ipd_nurse_note', 'ipt', 'iptbedmove', 'ward', 'operation_list', 'operation_detail', 'lab_head', 'lab_order', 'lab_items']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 210', 'registered-2026.1', NULL, 'registered'),
    ('SL0101', 'S', 'ratio', 'lower-is-better', 'monthly', 'System', 'Crossmatch-to-Transfusion ratios (C:T) in selective surgery cases', 'อัตราส่วนการขอใช้โลหิตต่อการใช้โลหิตจริงในกลุ่มผู้ป่วยผ่าตัดประเภทต่าง ๆ', '1. อัตราส่วนการขอใช้โลหิตต่อการใช้โลหิตจริงในกลุ่มผู้ป่วยผ่าตัดประเภทต่าง ๆ หมายถึง อัตราส่วนของ จำนวนโลหิตที่ทำการ crossmatch ต่อ จำนวนโลหิตที่ถูกนำไป transfused ในเดือนที่ทำการเก็บข้อมูล 2. การขอใช้โลหิตมากเกินความจำเป็น หมายถึง อัตราส่วนของการขอใช้โลหิตที่มีค่า C : T มากกว่า 2.5:1 3. อัตราส่วนการขอใช้โลหิตต่อการใช้โลหิตจริง ในกลุ่มผู้ป่วยผ่าตัดประเภทต่างๆ ช่วยสะท้อน ผลลัพธ์ในการพัฒนาประสิทธิภาพของการขอใช้โลหิต ลดการขอใช้โลหิตอย่างไม่จำเป็น, มีโลหิต สำรองหมุนเวียนใช้เพียงพอ, ลดการทิ้งโลหิตจากสาเหตุหมดอายุ, และลดWorkload', 'C:T ratio = a/b', 'a', 'b', ARRAY['blood_request', 'ipt', 'an_stat', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 211', 'registered-2026.1', NULL, 'registered'),
    ('SM0102', 'S', 'percent', 'lower-is-better', 'monthly', 'System', 'Medication Use: Percent of Antibiotic prescribing rate on Upper respiratory infection', 'ร้อยละการใช้ยาปฏิชีวนะในผู้ป่วยโรคติดเชื้อทางเดินหายใจส่วนบน', '1. ยาปฏิชีวนะ (antibiotics) หมายถึง ยาที่มีฤทธิ์ฆ่าหรือยับยั้งเชื้อแบคทีเรีย ใช้ในการ รักษาหรือป้องกันโรคที่เกิดจากการติดเชื้อแบคทีเรีย 2. ผู้ป่วยโรคติดเชื้อทางเดินหายใจส่วนบน (upper respiratory infection: URI) หมายถึง ผู้ป่วย (เฉพาะผู้ป่วยนอก) ที่ป่วยในกลุ่มโรคติดเชื้อทางเดินหายใจส่วนบน ซึ่งมี Pdx ตามรหัสโรค ICD-10 ที่กำหนด', '(a/b) x 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'opitemrece', 'drugitems', 'stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'stock_trancation_itemdata']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 260', 'registered-2026.1', NULL, 'registered'),
    ('SM0103', 'S', 'percent', 'lower-is-better', 'monthly', 'System', 'Medication Use: Percent of Antibiotic prescribing on Acute diarrhea', 'ร้อยละการใช้ยาปฏิชีวนะในผู้ป่วยอุจจาระร่วงเฉียบพลัน', '1. ยาปฏิชีวนะ (antibiotics) หมายถึง ยาที่มีฤทธิ์ฆ่าหรือยับยั้งเชื้อแบคทีเรีย ใช้ในการ รักษาหรือป้องกันโรคที่เกิดจากการติดเชื้อแบคทีเรีย 2. ผู้ป่วยอุจจาระร่วงเฉียบพลัน (acute diarrhea: AD) หมายถึง ผู้ป่วย (เฉพาะผู้ป่วย นอก) ที่ป่วยในกลุ่มโรคอุจจาระร่วงเฉียบพลัน ซึ่งมี Pdx ตาม ICD-10 ที่กำหนด', '(a/b) x 100', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'opitemrece', 'drugitems', 'stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'stock_trancation_itemdata']::text[], 'ทุก 6 เดือน (รายครึ่งปี)', 'THIP KPI Dictionary 2025 · หน้า 261', 'registered-2026.1', NULL, 'registered'),
    ('SM0201', 'S', 'ratio', 'neutral', 'monthly', 'System', 'Medication management: Inventory turn', 'จำนวนเดือนสำรองคลังยา', '1. จำนวนเดือนที่ยาของฝ่าย/กลุ่มงานเภสัชกรรมในคลังยามีเพียงพอสำหรับการให้บริการ ผู้ป่วย 2. คลังยา หมายถึง ทุกคลังยาที่สำรองยาที่โรงพยาบาลจัดซื้อ และเป็นคลังใหญ่ที่จ่ายยา ให้แก่คลังยาย่อยโดยไม่ได้จ่ายยาให้ผู้ป่วยโดยตรง 3. คลังยาย่อย หมายถึงหน่วยจ่ายยาที่สำรองยาและจ่ายให้ผู้ป่วยโดยตรง 4. มูลค่ายา หมายถึง ราคาทุนที่ใช้ในการจัดซื้อ คำนวณจากราคาทุนต่อหน่วยคูณด้วย จำนวน(ปริมาณ) 5. มูลค่ายาที่จ่ายไป หมายถึง มูลค่าการขาย และ มูลค่าการใช้ (ที่มีการเบิกไปใช้จ่ายเป็น ต้นทุนการให้บริการต่างๆ)', 'มูลค่ายาสำรองคงหลือรวม (คลังยาและคลังยาย่อย) ณ สิ้นเดือน (a) มูลค่ายารวมที่จ่ายไป ณ เดือนนั้น (b)', 'a', 'b', ARRAY['ovst', 'ovstdiag', 'opitemrece', 'drugitems', 'stock_item', 'stock_trancation', 'stock_daily_balance_record', 'stock_item_balance_history', 'stock_trancation_itemdata']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 262', 'registered-2026.1', NULL, 'registered'),
    ('SS0101', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'CSSD: Percent of examination of effective sterilization', 'ร้อยละการตรวจสอบประสิทธิภาพการทำปราศจากเชื้อผ่านเกณฑ์', '1. วิธีการตรวจสอบการทำปราศจากเชื้อ (ทั้งการนึ่งฆ่าเชื้อด้วยไอน้ำ และการอบฆ่าเชื้อด้วย ก๊าซ) ประกอบด้วยกรรมวิธี 3 ด้าน คือ 1.1 ตัวบ่งชี้ทางเชิงกล (mechanical indicator) เพื่อบ่งบอกสภาวะของเครื่องที่ทำให้ ปราศจากเชื้อ โดยดูจากมาตรวัดอุณหภูมิ มาตรวัดความดัน สัญญาณไฟต่างๆ และแผ่น บันทึกการทำงานของเครื่อง 1.2 ตัวบ่งชี้ทางเคมี (chemical indicator) โดยดูจากการเปลี่ยนสีของตัวบ่งชี้ทางเคมี ภายนอก และการเปลี่ยนสีของตัวบ่งชี้ทางเคมีภายใน 1.3 ตัวบ่งชี้ทางชีวภาพ (biological indicator) โดยดูจากผลการตรวจ spore test negative 2. อุณหภูมิและความดันที่ปรากฏที่มาตรวัดตลอดจนตัวบ่งชี้ทางเคมีและชีวภาพ ที่ทำให้ ปราศจากเชื้อ ต้องสอดคล้องเป็นไปตามข้อกำหนดและคู่มือการใช้งานของบริษัทผู้ผลิต', '(a/b) x 100', 'a', 'b', ARRAY['supply_sterile', 'supply_sterile_item', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 257', 'registered-2026.1', NULL, 'registered'),
    ('SS0102', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'CSSD: Percent of exact medical equipment prepared for specific procedures', 'ร้อยละการจัดอุปกรณ์เครื่องมือทางการแพทย์ ถูกต้องครบถ้วน', 'เป็นการประเมินประสิทธิภาพของการจัดอุปกรณ์เครื่องมือทางการแพทย์ ตามมาตรฐาน หรือข้อตกลงที่กำหนดโดยคณะกรรมการของโรงพยาบาล', '(a/b) x 100', 'a', 'b', ARRAY['supply_sterile', 'supply_sterile_item', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 258', 'registered-2026.1', NULL, 'registered'),
    ('SS0103', 'S', 'percent', 'higher-is-better', 'monthly', 'System', 'CSSD: Percent of medical supplies which are accurately provided by the CSSD', 'ร้อยละการจ่ายอุปกรณ์เครื่องมือทางการแพทย์ให้หน่วยงานถูกต้อง', 'อัตราการจ่ายอุปกรณ์เครื่องมือทางการแพทย์ให้หน่วยงานถูกต้อง เป็นการประเมิน ประสิทธิภาพของการจ่ายอุปกรณ์เครื่องมือทางการแพทย์ถูกต้อง ครบถ้วน (ความถูกต้อง ครบถ้วน ทันเวลา) ของหน่วย CSSD', '(a/b) x 100', 'a', 'b', ARRAY['supply_sterile', 'supply_sterile_item', 'operation_list', 'operation_detail']::text[], 'ทุกเดือน (รายเดือน)', 'THIP KPI Dictionary 2025 · หน้า 259', 'registered-2026.1', NULL, 'registered')
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
),
-- Registered HOSxP codes get a complete fact grid: a period whose registered
-- query ran and found an empty cohort is a measured zero cohort (0 facts, NULL
-- value), never a fabricated rate. External-fact codes (hospital-loaded
-- staging) and pending tiers stay out of the grid, so a missing source row
-- remains an explicit unavailable row in the outer SELECT instead of a zero.
facts AS (
  SELECT
    e.indicator_code,
    fp.period_start,
    fp.fiscal_year,
    fp.fiscal_month,
    COALESCE(fe.numerator, 0) AS numerator,
    CASE WHEN m.unit = 'count' THEN fe.denominator ELSE COALESCE(fe.denominator, 0) END AS denominator,
    fe.value
  FROM expected e
  JOIN metadata m
    ON m.indicator_code = e.indicator_code
   AND m.tier = 'registered'
   AND NOT (m.indicator_code = ANY(ARRAY['CG0103', 'CG0104', 'DE1301', 'DE1302', 'DE1303', 'DE1304', 'DE1305', 'DE1306', 'DE1601', 'DM0103', 'DM0203', 'DM0401', 'DM0402', 'DS0101', 'DS0201', 'DS0301', 'SC0101', 'SC0102', 'SC0103', 'SC0104', 'SC0105', 'SC0106', 'SF0101', 'SF0102', 'SF0103', 'SF0104', 'SF0105', 'SF0106', 'SG0104', 'SH0201', 'SH0202', 'SH0203', 'SH0204', 'SH0205', 'SH0206', 'SH0207', 'SH0208', 'SH0209', 'SH0210', 'SH0211', 'SH0212', 'SH0213', 'SH0214', 'SH0215', 'SH0216', 'SI0101', 'SI0102', 'SI0103', 'SI0201', 'SI0202', 'SI0203', 'SI0301', 'SI0302', 'SI0303', 'SS0101']::text[]))
  JOIN fiscal_periods fp
    ON fp.fiscal_month = e.fiscal_month
  LEFT JOIN fact_events fe
    ON fe.indicator_code = e.indicator_code
   AND fe.period_start = fp.period_start
   AND fe.fiscal_month = fp.fiscal_month
   AND fe.fiscal_year = fp.fiscal_year
)
SELECT
  m.indicator_code,
  fp.period_start,
  fp.fiscal_year,
  fp.fiscal_month,
  CASE WHEN m.tier = 'registered' THEN f.numerator ELSE NULL END AS numerator,
  CASE WHEN m.tier = 'registered' THEN f.denominator ELSE NULL END AS denominator,
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
