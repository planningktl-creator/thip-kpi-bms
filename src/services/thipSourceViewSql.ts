import { thipCatalogue } from '@/data/thipCatalogue';
import { getDictionaryEntry } from '@/data/thipDictionary';
import { getRuleUnit, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { getExpectedFiscalMonths, getReportingCadence, reportingCadenceLabels } from '@/data/thipReporting';
import { getPendingReason, getImplementationTier, pendingLocalSourceCodes, registeredRuleCodes } from '@/data/thipImplementation';
import { FISCAL_MONTH_GENERATED_EXPR, FISCAL_YEAR_GENERATED_EXPR, ipdBaseCte } from '@/services/thipIpdBase';
import { extendedBaseCte } from '@/services/thipFamilyBase';
import { externalRegisteredCodes, registeredBranches } from '@/services/queryRegistry';
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
  const dictionary = getDictionaryEntry(code);
  const cadence = getReportingCadence(code);
  const unit = getRuleUnit(rule);
  const tier = getImplementationTier(code);
  const targetScope = cadence === 'annual' ? 'annual' : 'monthly';
  const sourceTables = rule.candidateSourceTables.length ? [...rule.candidateSourceTables] : ['thip_kpi_monthly'];
  const category = groupMeta[entry.group].label;
  // Printed metadata (definition, formula, a/b labels, direction) comes from
  // the THIP KPI dictionary; the rule manifest only fills gaps.
  const definition = dictionary?.definition ?? `ตัวชี้วัดกลุ่ม ${rule.queryFamily} ตาม THIP KPI Dictionary 2025; ${
    tier === 'registered'
      ? 'มี registered query และต้องยืนยัน local clinical rule'
      : 'ยังต้องทำ local mapping และ source view'
  }`;
  const formula = dictionary?.formula ?? rule.formulaScale;
  const numeratorLabel = dictionary?.numeratorLabel ?? 'ต้องยืนยันตามนิยาม PDF และ local rule';
  const denominatorLabel = dictionary?.denominatorLabel ?? 'ต้องยืนยันตามนิยาม PDF และ local rule';
  const direction = dictionary?.direction ?? 'neutral';
  const reference = `THIP KPI Dictionary 2025 · หน้า ${rule.pdfPage}`;
  const pendingReason = getPendingReason(code);

  return `    (${[
    sqlText(code),
    sqlText(entry.group),
    sqlText(unit),
    sqlText(direction),
    sqlText(targetScope),
    sqlText(category),
    sqlText(entry.title),
    sqlText(entry.titleTh),
    sqlText(definition),
    sqlText(formula),
    sqlText(numeratorLabel),
    sqlText(denominatorLabel),
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
);

-- Hospital-loaded aggregate staging for KPIs whose denominator or source lives
-- outside HOSxP (population registers, finance, surveys, custom registries).
-- Load exactly one row per indicator code x reporting-period anchor; rows read
-- by the thipExternalFoundation query and the refresh above through the
-- external_facts CTE. Aggregate values only — never patient rows.
CREATE TABLE IF NOT EXISTS ${schema}.thip_external_facts (
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
);`;
}

/**
 * Parameterized refresh: replaces one fiscal year of rows with the full
 * cadence grid. Bind `:fiscal_year` (integer), `:start_date` (YYYY-10-01) and
 * `:end_date` (YYYY-10-01 of the next year, exclusive).
 */
export function buildSourceViewRefreshSql(schema = 'reporting', table = 'thip_kpi_monthly'): string {
  const externalCodes = externalRegisteredCodes;
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
${ipdBaseCte('standard')},
${extendedBaseCte(true)},
fact_events AS (
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
   AND NOT (m.indicator_code = ANY(${sqlArray(externalCodes)}))
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
