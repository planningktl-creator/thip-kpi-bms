import { BmsRequestError } from '@/services/bmsErrors';
import { thipKpiRulesByCode } from '@/data/thipKpiRules';
import { registeredRuleCodes } from '@/data/thipImplementation';
import { FISCAL_MONTH_EXPR, FISCAL_YEAR_EXPR, ipdBaseCte, type IpdBaseVariant } from '@/services/thipIpdBase';
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

const fiscalMonthExpr = FISCAL_MONTH_EXPR;
const fiscalYearExpr = FISCAL_YEAR_EXPR;

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
const asthmaWhere = "LEFT(pdx, 3) IN ('J45', 'J46')";
const copdWhere = "LEFT(pdx, 3) = 'J44'";
const cancerWhere = "pdx IN ('C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C33','C34','C37','C38','C39','C40','C41','C43','C44','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65','C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C77','C78','C79','C80','C81','C82','C83','C84','C85','C86','C87','C88','C89','C90','C91','C92','C93','C94','C95','C96','C97','D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','Z510','Z511')";
const tbWhere = "pdx IN ('A15', 'A16')";
const appendicitisWhere = "pdx IN ('K35', 'K352', 'K353', 'K358')";
const csWhere = "pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')";

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

/** A mortality branch that only needs `pdx` and `died`, valid on both base variants. */
function pdxMortalityBranch(code: string, where: string): string {
  return branch(code, 'COUNT(*) FILTER (WHERE died)', 'COUNT(*)', ratioValue('COUNT(*) FILTER (WHERE died)', 'COUNT(*)'), where);
}

/** A 28-day readmission branch that only needs `pdx`, `died`, `hn`, `an`, `dchdate`. */
function readmitBranch(code: string, where: string): string {
  return branch(code, readmitSubquery, 'COUNT(*) FILTER (WHERE NOT died)', ratioValue(readmitSubquery, 'COUNT(*) FILTER (WHERE NOT died)'), where);
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
    readmitBranch('DH0111', "age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')"),
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
    branch('DG0201', "COUNT(*) FILTER (WHERE pdx = 'K352')", 'COUNT(*)', ratioValue("COUNT(*) FILTER (WHERE pdx = 'K352')", 'COUNT(*)'), appendicitisWhere),
  ],
  ASTHMA_COPD: [
    pdxMortalityBranch('DR0403', copdWhere),
    readmitBranch('DR0301', asthmaWhere),
    readmitBranch('DR0401', copdWhere),
  ],
  UGIH: [
    branch('DG0102', 'ROUND(SUM(los)::numeric, 2)', 'COUNT(*)', 'ROUND(AVG(los), 2)', ugihWhere),
    readmitBranch('DG0101', ugihWhere),
  ],
  HEAD_INJURY: [
    branch('DN0302', 'COUNT(*) FILTER (WHERE died_within_48h)', 'COUNT(*)', ratioValue('COUNT(*) FILTER (WHERE died_within_48h)', 'COUNT(*)'), "pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')"),
  ],
  CANCER: [
    pdxMortalityBranch('DC0401', cancerWhere),
  ],
  HIV_TB: [
    pdxMortalityBranch('DR0201', tbWhere),
  ],
  MATERNAL_CHILD: [
    branch('CM0105', 'ROUND(SUM(los)::numeric, 2)', 'COUNT(*)', 'ROUND(AVG(los), 2)', csWhere),
  ],
};

/** Codes covered by each family, restricted to the registered rule codes. */
const FAMILY_CODES: Readonly<Record<string, readonly string[]>> = Object.fromEntries(
  Object.keys(FAMILY_BRANCHES).map((family) => [
    family,
    registeredRuleCodes.filter((code) => thipKpiRulesByCode.get(code)?.queryFamily === family),
  ]),
);

function familyBranches(family: string): readonly string[] {
  const codes = FAMILY_CODES[family] ?? [];
  const branches = FAMILY_BRANCHES[family] ?? [];
  return branches.filter((sql) => codes.some((code) => sql.includes(`'${code}' AS indicator_code`)));
}

export const registeredBranches = registeredRuleCodes.flatMap((code) => {
  const family = thipKpiRulesByCode.get(code)?.queryFamily ?? '';
  return familyBranches(family).filter((sql) => sql.includes(`'${code}' AS indicator_code`));
});

function expectedCodeValues(codes: readonly string[]): string {
  return codes.map((code) => `('${code}')`).join(', ');
}

/**
 * Assembles a registered read-only foundation query from one or more family
 * fact branches. Every query returns one row per indicator x reporting period
 * and never exposes a patient row.
 */
function buildFoundationQuery(key: string, description: string, codes: readonly string[], branches: readonly string[], variant: IpdBaseVariant = 'standard'): RegisteredQuery {
  return {
    key,
    description,
    sql: `
      ${ipdBaseCte(variant)},
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
    registeredRuleCodes,
    registeredBranches,
  ),
  // Opt-in variant for sites whose coded diagnosis lives in `ipt_drg_result`.
  // It shares the pdx-only branches, so it covers mortality/readmission/LOS
  // that do not need the extra `iptdiag` flags.
  thipIpdDrgResultFoundation: buildFoundationQuery(
    'thipIpdDrgResultFoundation',
    'ผลลัพธ์จริงรายเดือนจาก ipt_drg_result (pdx-only) สำหรับโรงพยาบาลที่เก็บ coded diagnosis ในตารางนี้',
    registeredRuleCodes,
    [
      pdxMortalityBranch('DH0101', "pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')"),
      pdxMortalityBranch('DH0101.1', "pdx IN ('I210', 'I211', 'I212', 'I213')"),
      pdxMortalityBranch('DH0101.2', "pdx IN ('I214', 'I219')"),
      pdxMortalityBranch('DN0101', strokeWhere),
      pdxMortalityBranch('DR0101', "LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')"),
      pdxMortalityBranch('DR0403', copdWhere),
      pdxMortalityBranch('DR0201', tbWhere),
      pdxMortalityBranch('DG0202', "LEFT(pdx, 3) = 'K35'"),
      pdxMortalityBranch('DN0302', "pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')"),
      pdxMortalityBranch('DC0401', cancerWhere),
      pdxMortalityBranch('CI0101', "pdx IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651')"),
      readmitBranch('DN0107', strokeWhere),
      readmitBranch('DR0102', "LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')"),
      readmitBranch('DG0101', ugihWhere),
    ],
    'drgResult',
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
