import { BmsRequestError } from '@/services/bmsErrors';
import { foundationRuleCodes, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { recordQueryTelemetry, responseRowCount, type QueryTelemetryOutcome } from '@/services/queryTelemetry';

export type BmsParamType = 'string' | 'integer' | 'float' | 'date' | 'time' | 'datetime' | 'text';

export type BmsParam = {
  value: string | number | null;
  value_type: BmsParamType;
};

export type RegisteredQuery = {
  key: string;
  sql: string;
  description: string;
  params?: Record<string, BmsParam>;
};

export type BmsSqlResponse = {
  MessageCode?: number;
  Message?: string;
  data?: Array<Record<string, unknown>>;
  result?: Array<Record<string, unknown>>;
  record_count?: number;
};

const foundationExpectedCodeValues = foundationRuleCodes
  .map((code) => `('${code}')`)
  .join(', ');

/**
 * Shared IPD base cohort for the foundation family queries. It keeps the
 * per-admission flags in one place so every family query uses the same
 * episode grain and dotless ICD-10 comparison.
 */
const IPD_FOUNDATION_CTE = `
  WITH ipd AS (
    SELECT
      i.an,
      i.hn,
      i.regdate,
      i.regtime,
      i.dchdate,
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
  )
`.trim();

const fiscalMonthExpr = "CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END";
const fiscalYearExpr = "CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END";

function branch(code: string, numerator: string, denominator: string, value: string, where: string, options: { groupBy?: string } = {}): string {
  const groupBy = options.groupBy ?? 'period_start, calendar_month';
  return `
      SELECT
        '${code}' AS indicator_code,
        period_start,
        ${fiscalMonthExpr} AS fiscal_month,
        ${fiscalYearExpr} AS fiscal_year,
        ${numerator} AS numerator,
        ${denominator} AS denominator,
        ${value} AS value
      FROM periodized
      WHERE ${where}
      GROUP BY ${groupBy}`;
}

const acsWhere = "age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') OR has_acs_sdx)";
const stemiWhere = "age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213') OR has_stemi_sdx)";
const nsteWhere = "age_y >= 18 AND (pdx IN ('I214', 'I219') OR has_nste_sdx)";
const strokeWhere = "LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')";
const pneumoniaWhere = "LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18') OR has_pneumonia_sdx";
const sepsisCeWhere = "pdx IN ('A400', 'A419', 'R572', 'R651') OR has_ce0101_sepsis";
const sepsisCiWhere = "pdx IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651') OR has_ci0101_sepsis";
const ugihWhere = "pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')";

const readmitSubquery = `
        COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))`;

const acsDeathNumerator = "COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND died) OR (has_acs_sdx AND died_from_acs))";
const stemiDeathNumerator = "COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213') AND died) OR (has_stemi_sdx AND died_from_stemi))";
const nsteDeathNumerator = "COUNT(*) FILTER (WHERE (pdx IN ('I214', 'I219') AND died) OR (has_nste_sdx AND died_from_nste))";
const pneumoniaDeathNumerator = "COUNT(*) FILTER (WHERE (LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia))";
const aspSubquery = `
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.name ILIKE '%aspirin%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 86400`;
const broadSubquery = `
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.antibiotic = 'Y'
            AND di.drugcategory ILIKE '%broad%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 10800`;

function ratioValue(numerator: string, denominator: string): string {
  return `ROUND((${numerator} * 100.0) / NULLIF(${denominator}, 0), 2)`;
}

const FAMILY_BRANCHES: Readonly<Record<string, readonly string[]>> = {
  ACS: [
    branch('DH0101', acsDeathNumerator, 'COUNT(*)', ratioValue(acsDeathNumerator, 'COUNT(*)'), acsWhere),
    branch('DH0101.1', stemiDeathNumerator, 'COUNT(*)', ratioValue(stemiDeathNumerator, 'COUNT(*)'), stemiWhere),
    branch('DH0101.2', nsteDeathNumerator, 'COUNT(*)', ratioValue(nsteDeathNumerator, 'COUNT(*)'), nsteWhere),
    branch('DH0102',
      `COUNT(*) FILTER (WHERE EXISTS (${aspSubquery}))`,
      'COUNT(*)',
      ratioValue(`COUNT(*) FILTER (WHERE EXISTS (${aspSubquery}))`, 'COUNT(*)'),
      "age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')"),
    branch('DH0112', 'ROUND(SUM(los)::numeric, 2)', 'COUNT(*)', 'ROUND(AVG(los), 2)',
      "age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')"),
  ],
  STROKE: [
    branch('DN0101', 'COUNT(*) FILTER (WHERE died)', 'COUNT(*)', ratioValue('COUNT(*) FILTER (WHERE died)', 'COUNT(*)'), strokeWhere),
    branch('DN0107', readmitSubquery, 'COUNT(*) FILTER (WHERE NOT died)', ratioValue(readmitSubquery, 'COUNT(*) FILTER (WHERE NOT died)'), strokeWhere),
    branch('DN0109', 'ROUND(SUM(los)::numeric, 2)', 'COUNT(*)', 'ROUND(AVG(los), 2)', strokeWhere),
  ],
  PNEUMONIA: [
    branch('DR0101', pneumoniaDeathNumerator, 'COUNT(*)', ratioValue(pneumoniaDeathNumerator, 'COUNT(*)'), pneumoniaWhere),
    branch('DR0102', readmitSubquery, 'COUNT(*) FILTER (WHERE NOT died)', ratioValue(readmitSubquery, 'COUNT(*) FILTER (WHERE NOT died)'), pneumoniaWhere),
  ],
  SEPSIS_ER: [
    branch('CE0101',
      `COUNT(*) FILTER (WHERE EXISTS (${broadSubquery}))`,
      'COUNT(*)',
      ratioValue(`COUNT(*) FILTER (WHERE EXISTS (${broadSubquery}))`, 'COUNT(*)'),
      sepsisCeWhere),
    branch('CI0101', 'COUNT(*) FILTER (WHERE died)', 'COUNT(*)', ratioValue('COUNT(*) FILTER (WHERE died)', 'COUNT(*)'), sepsisCiWhere),
  ],
  APPENDICITIS: [
    branch('DG0202', 'COUNT(*) FILTER (WHERE died)', 'COUNT(*)', ratioValue('COUNT(*) FILTER (WHERE died)', 'COUNT(*)'), "LEFT(pdx, 3) = 'K35'"),
  ],
  ASTHMA_COPD: [
    branch('DR0403', 'COUNT(*) FILTER (WHERE died)', 'COUNT(*)', ratioValue('COUNT(*) FILTER (WHERE died)', 'COUNT(*)'), "LEFT(pdx, 3) = 'J44'"),
  ],
  UGIH: [
    branch('DG0102', 'ROUND(SUM(los)::numeric, 2)', 'COUNT(*)', 'ROUND(AVG(los), 2)', ugihWhere),
  ],
  HEAD_INJURY: [
    branch('DN0302', 'COUNT(*) FILTER (WHERE died_within_48h)', 'COUNT(*)', ratioValue('COUNT(*) FILTER (WHERE died_within_48h)', 'COUNT(*)'), "pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')"),
  ],
};

/** Codes covered by each family, derived from the registered foundation rules. */
const FAMILY_CODES: Readonly<Record<string, readonly string[]>> = Object.fromEntries(
  Object.keys(FAMILY_BRANCHES).map((family) => [
    family,
    foundationRuleCodes.filter((code) => thipKpiRulesByCode.get(code)?.queryFamily === family),
  ]),
);

/** Branches for one family, restricted to the codes the manifest registers. */
function familyBranches(family: string): readonly string[] {
  const codes = FAMILY_CODES[family] ?? [];
  const branches = FAMILY_BRANCHES[family] ?? [];
  return branches.filter((sql) => codes.some((code) => sql.includes(`'${code}' AS indicator_code`)));
}

function expectedCodeValues(codes: readonly string[]): string {
  return codes.map((code) => `('${code}')`).join(', ');
}

/**
 * Assembles a registered read-only foundation query from one or more family
 * fact branches. Every query returns one row per indicator x reporting period
 * and never exposes a patient row.
 */
function buildFoundationQuery(key: string, description: string, codes: readonly string[], branches: readonly string[]): RegisteredQuery {
  return {
    key,
    description,
    sql: `
      ${IPD_FOUNDATION_CTE},
      facts AS (
      ${branches.join('\n\n      UNION ALL\n')}
      ), expected_codes(indicator_code) AS (
        VALUES
          ${expectedCodeValues(codes)}
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
          CAST(:start_date AS date),
          CAST(:end_date AS date) - INTERVAL '1 month',
          INTERVAL '1 month'
        ) AS generated(period_start)
      )
      SELECT
        expected_codes.indicator_code,
        fiscal_periods.period_start,
        fiscal_periods.fiscal_month,
        fiscal_periods.fiscal_year,
        COALESCE(facts.numerator, 0) AS numerator,
        COALESCE(facts.denominator, 0) AS denominator,
        facts.value
      FROM expected_codes
      CROSS JOIN fiscal_periods
      LEFT JOIN facts
        ON facts.indicator_code = expected_codes.indicator_code
       AND facts.period_start = fiscal_periods.period_start
       AND facts.fiscal_month = fiscal_periods.fiscal_month
       AND facts.fiscal_year = fiscal_periods.fiscal_year
      ORDER BY expected_codes.indicator_code, fiscal_periods.period_start
    `.trim(),
  };
}

const allFoundationBranches = foundationRuleCodes.flatMap((code) => {
  const rule = thipKpiRulesByCode.get(code);
  const family = rule?.queryFamily ?? '';
  return familyBranches(family).filter((sql) => sql.includes(`'${code}' AS indicator_code`));
});

export const foundationFamilyQueries: Readonly<Record<string, RegisteredQuery>> = Object.fromEntries(
  Object.entries(FAMILY_BRANCHES).map(([family]) => [
    family,
    buildFoundationQuery(
      `thip${family.replace(/_/g, '')}Foundation`,
      `ผลลัพธ์จริงรายเดือนสำหรับตัวชี้วัด THIP กลุ่ม ${family} จาก HOSxP`,
      FAMILY_CODES[family] ?? [],
      familyBranches(family),
    ),
  ]),
);

export const queryRegistry = {
  versionProbe: {
    key: 'versionProbe',
    description: 'ตรวจสอบชนิดฐานข้อมูลของ BMS session',
    sql: 'SELECT VERSION() AS version',
  },
  ipdMonthlyFoundation: {
    key: 'ipdMonthlyFoundation',
    description: 'โครงสร้างตั้งต้นสำหรับตรวจสอบข้อมูล IPD รายเดือน (ยังไม่ใช่ THIP calculation)',
    sql: `
      SELECT
        DATE_TRUNC('month', ipt.dchdate)::date AS month_start,
        COUNT(DISTINCT ipt.an)::integer AS discharges,
        COUNT(DISTINCT CASE WHEN NULLIF(TRIM(ipt.drg), '') IS NULL THEN ipt.an END)::integer AS uncoded_cases,
        AVG(ipt.adjrw)::numeric AS mean_adjrw
      FROM ipt
      WHERE ipt.dchdate >= :start_date
        AND ipt.dchdate < :end_date
      GROUP BY DATE_TRUNC('month', ipt.dchdate)
      ORDER BY month_start
    `.trim(),
  },
  thipIpdFoundation: buildFoundationQuery(
    'thipIpdFoundation',
    'ผลลัพธ์จริงรายเดือนสำหรับตัวชี้วัด THIP กลุ่ม IPD จาก HOSxP',
    foundationRuleCodes,
    allFoundationBranches,
  ),
  ...foundationFamilyQueries,
} as const satisfies Record<string, RegisteredQuery>;

export type FoundationFamily = keyof typeof FAMILY_BRANCHES;

const allowedStart = /^(select|with|show|describe|desc|explain)\b/i;
const blockedSql = /\b(insert|update|delete|merge|drop|alter|truncate|create|grant|revoke|copy|call|do|execute|begin|commit|rollback)\b/i;

/** Default wall-clock budget for a registered query round-trip. */
export const QUERY_TIMEOUT_MS = 30_000;

export function assertRegisteredReadOnlyQuery(query: RegisteredQuery): void {
  const normalized = query.sql.trim();
  if (!allowedStart.test(normalized) || blockedSql.test(normalized)) {
    throw new Error(`Query ${query.key} is not an allowed read-only statement.`);
  }
}

export async function executeRegisteredQuery(
  query: RegisteredQuery,
  config: { apiUrl: string; bearerToken: string; appIdentifier: string },
  params?: Record<string, BmsParam>,
  marketplaceToken?: string,
  options?: { timeoutMs?: number; signal?: AbortSignal },
): Promise<BmsSqlResponse> {
  assertRegisteredReadOnlyQuery(query);
  const body: Record<string, unknown> = {
    sql: query.sql,
    app: config.appIdentifier,
  };
  if (params && Object.keys(params).length > 0) body.params = params;
  if (marketplaceToken) body['marketplace-token'] = marketplaceToken;

  const timeoutMs = options?.timeoutMs ?? QUERY_TIMEOUT_MS;
  const controller = new AbortController();
  const abort = () => controller.abort();
  if (options?.signal) {
    if (options.signal.aborted) controller.abort();
    else options.signal.addEventListener('abort', () => controller.abort(), { once: true });
  }
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const startedAt = Date.now();
  const record = (outcome: QueryTelemetryOutcome, rowCount = 0) => {
    recordQueryTelemetry({ key: query.key, outcome, latencyMs: Date.now() - startedAt, rowCount, at: new Date().toISOString() });
  };

  let response: Response;
  try {
    response = await fetch(`${config.apiUrl.replace(/\/$/, '')}/api/sql`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.bearerToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } catch (error) {
    if (controller.signal.aborted) {
      record('timeout');
      throw new BmsRequestError('api', 'timeout', `BMS API request timed out after ${timeoutMs} ms`, undefined, { cause: error });
    }
    record('network');
    throw new BmsRequestError('api', 'network', 'BMS API request failed', undefined, { cause: error });
  } finally {
    clearTimeout(timer);
  }

  const responseText = await response.text();
  if (!response.ok) {
    record('http');
    throw new BmsRequestError('api', 'http', `BMS API returned HTTP ${response.status}`, response.status);
  }

  let payload: BmsSqlResponse = {};
  if (responseText.trim()) {
    try {
      payload = JSON.parse(responseText) as BmsSqlResponse;
    } catch (error) {
      record('response');
      throw new BmsRequestError('api', 'response', 'BMS API returned invalid JSON', response.status, { cause: error });
    }
  }
  if (payload.MessageCode !== undefined && payload.MessageCode >= 400) {
    record('message');
    throw new BmsRequestError('api', 'message', payload.Message || 'BMS API rejected the query', response.status);
  }
  record('success', responseRowCount(payload));
  return payload;
}
