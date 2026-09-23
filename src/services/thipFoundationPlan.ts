/**
 * Fan-out plan for the HOSxP foundation queries.
 *
 * A single foundation statement carries every registered branch (177 in the
 * current contract). Measured against a live hospital HOSxP over the BMS API,
 * that statement (≈470 KB of SQL) never finishes inside the endpoint's ~10 s
 * request ceiling, so the no-source-view path returned nothing at all.
 *
 * The plan below splits the registered codes into bounded chunks that are small
 * enough to execute, and keeps the split deterministic so the audit trail and
 * tests stay stable. Chunking is by code, never by period: every chunk carries
 * the full fiscal-year window so cadence-aware bucketing is unaffected.
 */

import { getExpectedFiscalMonths, getReportingCadence } from '@/data/thipReporting';
import { ipdBaseCte } from '@/services/thipIpdBase';
import { extendedBaseCte } from '@/services/thipFamilyBase';
import {
  hosxpRegisteredBranches,
  hosxpRegisteredCodes,
  type RegisteredQuery,
} from '@/services/queryRegistry';
import { getCurrentFiscalYear } from '@/utils/fiscal';

/**
 * Codes per request when the foundation query has to be fanned out.
 *
 * Measured per-code latency on a live site: median ≈ 3 s, p90 ≈ 9 s, with the
 * heaviest branches (multi-condition OR + EXISTS over `opitemrece`/`ovstdiag`)
 * sitting close to the ceiling on their own. Requests execute sequentially, so
 * this stays deliberately small; the adaptive pass may cut it further, never
 * raise it.
 */
export const FOUNDATION_CHUNK_SIZE = 4;

/** Codes whose branch measured under half the per-request ceiling. */
const FAST_CODE_MS = 4_000;
/** Codes that measured close to the ceiling and are safest executed alone. */
const SLOW_CODE_MS = 8_000;

const BASE_CHAIN = `WITH\n      ${ipdBaseCte('standard').replace(/^WITH\s+/, '')},\n      ${extendedBaseCte(false)}`;

function chunkSql(codes: readonly string[], branches: readonly string[]): string {
  const pairs = codes
    .flatMap((code) => getExpectedFiscalMonths(code).map((month) => `('${code}', ${month})`))
    .join(', ');
  return `
      ${BASE_CHAIN},
      facts AS (
      ${branches.join('\n\n      UNION ALL\n')}
      ), expected_codes(indicator_code, fiscal_month) AS (
        VALUES
          ${pairs}
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
      JOIN fiscal_periods
        ON fiscal_periods.fiscal_month = expected_codes.fiscal_month
      LEFT JOIN facts
        ON facts.indicator_code = expected_codes.indicator_code
       AND facts.period_start = fiscal_periods.period_start
       AND facts.fiscal_month = fiscal_periods.fiscal_month
       AND facts.fiscal_year = fiscal_periods.fiscal_year
      ORDER BY expected_codes.indicator_code, fiscal_periods.period_start
    `.trim();
}

/** Ordered (code, branch) pairs of the HOSxP-only contract, one branch per code. */
export function registeredCodeBranchPairs(): ReadonlyArray<readonly [string, string]> {
  return hosxpRegisteredCodes.map((code, index) => [code, hosxpRegisteredBranches[index]!] as const);
}

const BRANCH_BY_CODE = new Map(registeredCodeBranchPairs());

/** Builds one executable request for an explicit set of codes. */
function makeChunk(codes: readonly string[], key: string, description: string): RegisteredQuery {
  const branches = codes.map((code) => {
    const branch = BRANCH_BY_CODE.get(code);
    if (!branch) throw new Error(`no registered HOSxP branch for ${code}`);
    return branch;
  });
  return { key, description, sql: chunkSql(codes, branches) };
}

export type FoundationPlanOptions = {
  /** Codes per request for codes without a measured latency. */
  chunkSize?: number;
  /** Measured per-code wall clock in ms, keyed by indicator code. */
  observedMs?: Readonly<Record<string, number>>;
  /** Subset to plan for; defaults to the whole HOSxP contract. */
  codes?: readonly string[];
};

/**
 * Deterministic chunking of the registered codes. Each chunk executes the full
 * fiscal-year window, so `loadBmsIndicators` receives the same rows it would have
 * received from the single whole-contract statement.
 */
export function planFoundationChunks(options: FoundationPlanOptions = {}): RegisteredQuery[] {
  const chunkSize = Math.max(1, options.chunkSize ?? FOUNDATION_CHUNK_SIZE);
  const observed = options.observedMs ?? {};
  const wanted = options.codes ? new Set(options.codes) : null;
  const pairs = registeredCodeBranchPairs().filter(([code]) => (wanted ? wanted.has(code) : true));

  const chunks: Array<Array<readonly [string, string]>> = [];
  let current: Array<readonly [string, string]> = [];
  const flush = () => {
    if (current.length > 0) chunks.push(current);
    current = [];
  };

  for (const pair of pairs) {
    const code = pair[0];
    const elapsed = observed[code];
    // Codes that measured close to the ceiling get a request to themselves.
    if (elapsed !== undefined && elapsed >= SLOW_CODE_MS) {
      flush();
      chunks.push([pair]);
      continue;
    }
    const limit = elapsed !== undefined && elapsed < FAST_CODE_MS ? chunkSize : Math.max(1, Math.floor(chunkSize / 2));
    if (current.length >= limit) flush();
    current.push(pair);
  }
  flush();

  return chunks.map((chunk, index) => makeChunk(
    chunk.map(([code]) => code),
    `thipIpdFoundationChunk${String(index).padStart(3, '0')}`,
    `ผลลัพธ์จริงรายงวดสำหรับตัวชี้วัด THIP ชุดที่ ${index + 1}/${chunks.length} (${chunk.length} ตัวชี้วัด)`,
  ));
}

/** Total number of codes covered by a plan, for contract assertions. */
export function plannedCodeCount(chunks: readonly RegisteredQuery[]): number {
  const seen = new Set<string>();
  for (const chunk of chunks) {
    for (const match of chunk.sql.matchAll(/'([A-Z]{2}\d{4}(?:\.\d)?)' AS indicator_code/g)) {
      seen.add(match[1]!);
    }
  }
  return seen.size;
}

/**
 * Splits one chunk into two halves (by code) after the endpoint refused it —
 * a timeout on a slow branch is the measured failure mode, so the caller can
 * bisect until a request fits the ceiling. Returns an empty array when the chunk
 * already holds a single code, which means the code cannot be measured alone.
 */
export function splitFoundationChunk(chunk: RegisteredQuery): RegisteredQuery[] {
  const codes: string[] = [];
  for (const match of chunk.sql.matchAll(/'([A-Z]{2}\d{4}(?:\.\d)?)' AS indicator_code/g)) codes.push(match[1]!);
  const unique = Array.from(new Set(codes));
  if (unique.length < 2) return [];
  const middle = Math.ceil(unique.length / 2);
  const groups = [unique.slice(0, middle), unique.slice(middle)];
  return groups.map((group, index) => makeChunk(
    group,
    `${chunk.key}.${index + 1}`,
    `${chunk.description} (bisect ${index + 1}/2)`,
  ));
}

// ---------------------------------------------------------------------------
// Window-level splitting
// ---------------------------------------------------------------------------

/** One executable request: a registered statement plus the date window to run it over. */
export type FoundationRequest = {
  key: string;
  query: RegisteredQuery;
  /** Inclusive ISO start date. */
  start: string;
  /** Exclusive ISO end date. */
  end: string;
};

/** Fiscal-year window in ISO terms: 1 Oct of the previous calendar year to 1 Oct. */
export function fiscalYearWindow(fiscalYear: number): { start: string; end: string } {
  return { start: `${fiscalYear - 1}-10-01`, end: `${fiscalYear}-10-01` };
}

function monthsBetween(start: string, end: string): number {
  const [startYear, startMonth] = start.split('-').map(Number) as [number, number];
  const [endYear, endMonth] = end.split('-').map(Number) as [number, number];
  return (endYear - startYear) * 12 + (endMonth - startMonth);
}

function addMonths(iso: string, months: number): string {
  const [year, month] = iso.split('-').map(Number) as [number, number];
  const total = year * 12 + (month - 1) + months;
  return `${Math.floor(total / 12)}-${String((total % 12) + 1).padStart(2, '0')}-01`;
}

function codesOfChunk(chunk: RegisteredQuery): string[] {
  return Array.from(new Set(
    Array.from(chunk.sql.matchAll(/'([A-Z]{2}\d{4}(?:\.\d)?)' AS indicator_code/g), (match) => match[1]!),
  ));
}

/**
 * Splits a request's date window in half.
 *
 * Loss-free for every cadence except `annual`: fact branches bucket to their
 * cadence anchor, so a monthly/quarterly/semiannual code measured over Oct-Mar and
 * Apr-Sep produces exactly the cells it would produce over the whole fiscal year.
 * An annual code covers the year in one bucket, so it can never be windowed — the
 * function returns an empty array and the caller must treat the code as unmeasurable
 * rather than reporting half a year as if it were the annual result.
 */
export function splitFoundationRequestByWindow(request: FoundationRequest): FoundationRequest[] {
  const codes = codesOfChunk(request.query);
  if (codes.some((code) => getReportingCadence(code) === 'annual')) return [];
  const months = monthsBetween(request.start, request.end);
  if (months < 2) return [];
  const middle = addMonths(request.start, Math.ceil(months / 2));
  return [
    { ...request, key: `${request.key}.w1`, end: middle },
    { ...request, key: `${request.key}.w2`, start: middle },
  ];
}

export type FoundationRequestPlanOptions = FoundationPlanOptions & {
  /** Fiscal year used for the request windows. Defaults to the current fiscal year. */
  fiscalYear?: number;
};

/** Plans the fallback load as bounded requests over the full fiscal-year window. */
export function planFoundationRequests(options: FoundationRequestPlanOptions = {}): FoundationRequest[] {
  const window = fiscalYearWindow(options.fiscalYear ?? getCurrentFiscalYear());
  return planFoundationChunks(options).map((query) => ({ key: query.key, query, ...window }));
}
