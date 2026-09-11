export type QueryTelemetryOutcome = 'success' | 'timeout' | 'http' | 'network' | 'message' | 'response';

export type QueryTelemetrySample = {
  key: string;
  outcome: QueryTelemetryOutcome;
  latencyMs: number;
  rowCount: number;
  at: string;
};

export type QueryTelemetryAggregate = {
  key: string;
  calls: number;
  failures: number;
  failureRate: number;
  averageLatencyMs: number;
  maxLatencyMs: number;
  lastRowCount: number;
  lastOutcome: QueryTelemetryOutcome;
  lastAt: string;
};

const MAX_SAMPLES_PER_KEY = 50;

/**
 * In-memory, aggregate-only telemetry for registered queries. It records query
 * key, outcome, latency, and row count. It never records SQL text, parameters,
 * session tokens, or row values.
 */
const samples = new Map<string, QueryTelemetrySample[]>();

export function recordQueryTelemetry(sample: QueryTelemetrySample): void {
  const existing = samples.get(sample.key) ?? [];
  const next = [...existing, sample];
  samples.set(sample.key, next.slice(-MAX_SAMPLES_PER_KEY));
}

export function getQueryTelemetry(key: string): QueryTelemetryAggregate | null {
  const entries = samples.get(key);
  if (!entries?.length) return null;
  const failures = entries.filter((entry) => entry.outcome !== 'success').length;
  const totalLatency = entries.reduce((sum, entry) => sum + entry.latencyMs, 0);
  const last = entries[entries.length - 1]!;
  return {
    key,
    calls: entries.length,
    failures,
    failureRate: failures / entries.length,
    averageLatencyMs: Math.round(totalLatency / entries.length),
    maxLatencyMs: Math.max(...entries.map((entry) => entry.latencyMs)),
    lastRowCount: last.rowCount,
    lastOutcome: last.outcome,
    lastAt: last.at,
  };
}

export function getAllQueryTelemetry(): QueryTelemetryAggregate[] {
  return Array.from(samples.keys()).map((key) => getQueryTelemetry(key)!).filter(Boolean);
}

export function resetQueryTelemetry(): void {
  samples.clear();
}

/** Extracts the row count from a BMS response without touching row values. */
export function responseRowCount(payload: { data?: unknown[]; result?: unknown[]; record_count?: number }): number {
  if (typeof payload.record_count === 'number') return payload.record_count;
  if (Array.isArray(payload.data)) return payload.data.length;
  if (Array.isArray(payload.result)) return payload.result.length;
  return 0;
}
