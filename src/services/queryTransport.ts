import { recordAppPerformance } from './appPerformance';
import { abortable } from './abortable';
import { BmsRequestError, parseRetryAfter } from './bmsErrors';
import { recordQueryTelemetry, responseRowCount, type QueryTelemetryOutcome } from './queryTelemetry';

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
    else options.signal.addEventListener('abort', abort, { once: true });
  }
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const startedAt = Date.now();
  const record = (outcome: QueryTelemetryOutcome, rowCount = 0) => {
    recordQueryTelemetry({ key: query.key, outcome, latencyMs: Date.now() - startedAt, rowCount, at: new Date().toISOString() });
    recordAppPerformance({ phase: 'query', key: query.key, durationMs: Date.now() - startedAt, success: outcome === 'success' });
  };

  try {
  let response: Response;
  try {
    response = await abortable(fetch(`${config.apiUrl.replace(/\/$/, '')}/api/sql`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.bearerToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    }), controller.signal);
  } catch (error) {
    if (controller.signal.aborted) {
      record('timeout');
      throw new BmsRequestError('api', 'timeout', `BMS API request timed out after ${timeoutMs} ms`, undefined, { cause: error });
    }
    record('network');
    throw new BmsRequestError('api', 'network', 'BMS API request failed', undefined, { cause: error });
  }

  let responseText: string;
  try { responseText = await abortable(response.text(), controller.signal); }
  catch (error) {
    const failure = controller.signal.aborted ? 'timeout' : 'network';
    record(failure);
    throw new BmsRequestError('api', failure, 'BMS response body did not complete', undefined, { cause: error });
  }
  let payload: BmsSqlResponse = {};
  if (responseText.trim()) {
    try {
      payload = JSON.parse(responseText) as BmsSqlResponse;
    } catch (error) {
      if (!response.ok) {
        record('http');
        throw new BmsRequestError('api', 'http', `BMS API returned HTTP ${response.status}`, response.status, { retryAfterMs: response.status === 429 ? parseRetryAfter(response.headers?.get('Retry-After') ?? null) : undefined });
      }
      record('response');
      throw new BmsRequestError('api', 'response', 'BMS API returned invalid JSON', response.status, { cause: error });
    }
  }
  const messageCode = payload.MessageCode === undefined ? undefined : Number(payload.MessageCode);
  if (messageCode !== undefined && Number.isFinite(messageCode) && messageCode >= 400) {
    record('message');
    throw new BmsRequestError('api', 'message', payload.Message || 'BMS API rejected the query', response.status, { messageCode, retryAfterMs: messageCode === 429 ? parseRetryAfter(response.headers?.get('Retry-After') ?? null) : undefined });
  }
  if (!response.ok) {
    record('http');
    throw new BmsRequestError('api', 'http', `BMS API returned HTTP ${response.status}`, response.status, { retryAfterMs: response.status === 429 ? parseRetryAfter(response.headers?.get('Retry-After') ?? null) : undefined });
  }
  record('success', responseRowCount(payload));
  return payload;
  } finally {
    clearTimeout(timer);
    options?.signal?.removeEventListener('abort', abort);
  }
}

export const versionProbe: RegisteredQuery = { key: 'versionProbe', description: 'ตรวจสอบชนิดฐานข้อมูลของ BMS session', sql: 'SELECT VERSION() AS version' };
