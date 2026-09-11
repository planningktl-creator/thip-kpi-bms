import { thipCatalogue } from '@/data/thipCatalogue';
import { getRuleUnit, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { getExpectedFiscalMonths, getReportingCadence, reportingCadenceLabels } from '@/data/thipReporting';
import { getPendingReason, getImplementationTier, pendingLocalSourceCodes, registeredRuleCodes } from '@/data/thipImplementation';
import { FISCAL_MONTH_GENERATED_EXPR, FISCAL_YEAR_GENERATED_EXPR, ipdBaseCte } from '@/services/thipIpdBase';
import { registeredBranches } from '@/services/queryRegistry';
import { groupMeta } from '@/data/thipMeta';

/**
 * Generates the reporting-layer artifact that a hospital provisions behind
 * `VITE_BMS_KPI_SOURCE_VIEW`.
 *
 * The artifact is a physical table populated per fiscal year (the read query
 * filters by `period_start`/`fiscal_year`). It is built from the same rule
 * manifest and family branches as the registered foundation queries, so the
 * reporting layer and the in-app validation path cannot drift.
 *
 * Registered codes carry measured numerator/denominator/value. Codes that still
 * need a local source carry an explicit `unavailable` row (denominator = NULL,
 * value = NULL) with a `pending_reason`; they are never written as a zero.
 */

const sqlText = (value: string): string => `'${value.replace(/'/g, "''")}'`;
const sqlArray = (values: readonly string[]): string => `ARRAY[${values.map(sqlText).join(', ')}]::text[]`;

function metadataRow(code: string): string {
  const entry = thipCatalogue.find((candidate) => candidate.code === code);
  const rule = thipKpiRulesByCode.get(code);
  if (!entry || !rule) throw new Error(`Source-view metadata requested an unknown code: ${code}`);
  const cadence = getReportingCadence(code);
  const unit = getRuleUnit(rule);
  const tier = getImplementationTier(code);
  const targetScope = cadence === 'annual' ? 'annual' : 'monthly';
  const sourceTables = rule.candidateSourceTables.length ? [...rule.candidateSourceTables] : ['thip_kpi_monthly'];
  const category = groupMeta[entry.group].label;
  const definition = `ตัวชี้วัดกลุ่ม ${rule.queryFamily} ตาม THIP KPI Dictionary 2025; ${
    tier === 'registered'
      ? 'มี registered query และต้องยืนยัน local clinical rule'
      : 'ยังต้องทำ local mapping และ source view'
  }`;
  const reference = `THIP KPI Dictionary 2025 · หน้า ${rule.pdfPage}`;
  const pendingReason = getPendingReason(code);

  return `    (${[
    sqlText(code),
    sqlText(entry.group),
    sqlText(unit),
    sqlText('neutral'),
    sqlText(targetScope),
    sqlText(category),
    sqlText(entry.title),
    sqlText(entry.title),
    sqlText(definition),
    sqlText(rule.formulaScale),
    sqlText('ต้องยืนยันตามนิยาม PDF และ local rule'),
    sqlText('ต้องยืนยันตามนิยาม PDF และ local rule'),
    sqlArray(sourceTables),
    sqlText(reportingCadenceLabels[cadence]),
    sqlText(reference),
    sqlText(tier === 'registered' ? 'registered-2026.1' : 'pending-local-source-2026.1'),
    pendingReason === null ? 'NULL' : sqlText(pendingReason),
    sqlText(tier),
  ].join(', ')})`;
}

/** DDL for the reporting table, including the tier and pending_reason columns. */
export function buildSourceViewDdl(schema = 'reporting', table = 'thip_kpi_monthly'): string {
  return `-- THIP KPI normalized source-view table (read-only reporting layer).
-- Populate per fiscal year with buildSourceViewRefreshSql(); the app reads it
-- through VITE_BMS_KPI_SOURCE_VIEW and never writes to HOSxP.
CREATE TABLE IF NOT EXISTS ${schema}.${table} (
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
);`;
}

/**
 * Parameterized refresh: replaces one fiscal year of rows with the full
 * cadence grid. Bind `:fiscal_year` (integer), `:start_date` (YYYY-10-01) and
 * `:end_date` (YYYY-10-01 of the next year, exclusive).
 */
export function buildSourceViewRefreshSql(schema = 'reporting', table = 'thip_kpi_monthly'): string {
  const expectedValues = thipCatalogue
    .flatMap((entry) => getExpectedFiscalMonths(entry.code).map((month) => `    (${sqlText(entry.code)}, ${month})`))
    .join(',\n');
  const metadataValues = thipCatalogue.map((entry) => metadataRow(entry.code)).join(',\n');

  return `-- Refresh one fiscal year of the normalized THIP source view.
-- Bind: :fiscal_year (integer), :start_date = YYYY-10-01, :end_date = next YYYY-10-01 (exclusive).
DELETE FROM ${schema}.${table} WHERE fiscal_year = :fiscal_year;

INSERT INTO ${schema}.${table} (
  indicator_code, period_start, fiscal_year, fiscal_month,
  numerator, denominator, value, target, target_scope, percentile,
  indicator_group, unit, direction, category, title, title_th,
  definition, formula, numerator_label, denominator_label,
  source_tables, frequency, reference, rule_version, pending_reason, tier, refreshed_at
)
WITH
${ipdBaseCte('standard')},
facts AS (
${registeredBranches.join('\n\n  UNION ALL\n')}
),
expected(indicator_code, fiscal_month) AS (
  VALUES
${expectedValues}
),
metadata(
  indicator_code, indicator_group, unit, direction, target_scope,
  category, title, title_th, definition, formula,
  numerator_label, denominator_label, source_tables, frequency, reference,
  rule_version, pending_reason, tier
) AS (
  VALUES
${metadataValues}
),
fiscal_periods AS (
  SELECT
    generated.period_start::date AS period_start,
    ${FISCAL_MONTH_GENERATED_EXPR} AS fiscal_month,
    ${FISCAL_YEAR_GENERATED_EXPR} AS fiscal_year
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
ORDER BY m.indicator_code, fp.period_start;`;
}

export type SourceViewArtifact = {
  registeredCodeCount: number;
  pendingCodeCount: number;
  expectedCellCount: number;
  ddl: string;
  refresh: string;
};

export function buildSourceViewArtifact(): SourceViewArtifact {
  const expectedCellCount = thipCatalogue.reduce((sum, entry) => sum + getExpectedFiscalMonths(entry.code).length, 0);
  return {
    registeredCodeCount: registeredRuleCodes.length,
    pendingCodeCount: pendingLocalSourceCodes.length,
    expectedCellCount,
    ddl: buildSourceViewDdl(),
    refresh: buildSourceViewRefreshSql(),
  };
}
