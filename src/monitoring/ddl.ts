/** Reporting-layer artifact only. No DDL is sent to BMS/HOSxP. */
export function monitoringDdl(): string {
  return `-- Monthly monitoring is independent of THIP's 1,552 cadence cells.
-- Aggregate data only. Hospital owners must approve rules before publication.
CREATE SCHEMA IF NOT EXISTS reporting;
CREATE TABLE IF NOT EXISTS reporting.thip_monthly_monitoring (
  code varchar(10) NOT NULL,
  fiscal_year integer NOT NULL,
  fiscal_month smallint NOT NULL CHECK (fiscal_month BETWEEN 1 AND 12),
  period_start date NOT NULL,
  period_end date NOT NULL,
  data_through date,
  numerator numeric, denominator numeric, value numeric,
  unit text NOT NULL CHECK (unit IN ('percent','rate','count','ratio','minute','day','month','hour-per-person')),
  target jsonb,
  cumulative jsonb NOT NULL,
  accumulation text NOT NULL CHECK (accumulation IN ('sum','count','weighted-ratio','fixed-denominator','snapshot','distinct-cohort','custom')),
  formula text NOT NULL, method text NOT NULL,
  data_status text NOT NULL CHECK (data_status IN ('measured','zero-cohort','missing-source','rule-unapproved','future')),
  assessment text NOT NULL CHECK (assessment IN ('on-track','watch','action','no-target','not-assessable')),
  reason text, rule_version text NOT NULL,
  refreshed_at timestamptz,
  synthetic boolean NOT NULL DEFAULT FALSE CHECK (synthetic = FALSE),
  CHECK (period_start = (make_date(fiscal_year - 1, 10, 1) + (fiscal_month - 1) * interval '1 month')::date),
  CHECK (period_end = (period_start + interval '1 month')::date),
  CHECK (denominator IS NULL OR denominator >= 0),
  CHECK (numerator IS NULL OR numerator >= 0),
  CHECK (unit = 'count' OR denominator IS DISTINCT FROM 0 OR value IS NULL),
  CHECK (data_status NOT IN ('missing-source','rule-unapproved','future') OR (value IS NULL AND numerator IS NULL AND denominator IS NULL AND reason IS NOT NULL)),
  UNIQUE (code, fiscal_year, fiscal_month)
);
-- Grant SELECT only to the BMS reporting role. Refresh by the hospital platform,
-- never the frontend. JSON target/cumulative fields follow docs/THIP-MONITORING-CONTRACT.md.
`;
}
