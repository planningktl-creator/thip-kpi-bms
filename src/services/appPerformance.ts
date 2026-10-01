export type PerformancePhase = 'cache-prepare' | 'cache-read' | 'queue-wait' | 'query' | 'monitoring-ready';
export type PerformanceSample = { phase: PerformancePhase; key: string; durationMs: number; success: boolean };
const samples: PerformanceSample[] = [];
/** Bounded numeric diagnostics in memory; no URL, SQL, parameters or facts. */
export function recordAppPerformance(sample: PerformanceSample): void {
  if (!/^[\w.-]{1,80}$/.test(sample.key) || !Number.isFinite(sample.durationMs) || sample.durationMs < 0) return;
  samples.push(Object.freeze({ ...sample }));
  if (samples.length > 256) samples.shift();
}
export function getAppPerformance(): readonly PerformanceSample[] { return samples.slice(); }
export function clearAppPerformance(): void { samples.length = 0; }
