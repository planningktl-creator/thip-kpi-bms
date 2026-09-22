import type { IndicatorDirection, IndicatorStatus } from '@/types/thip';

/**
 * Shared status semantics for one measured value against its approved target.
 * - No value -> `no-data`; no target (or neutral direction) -> `unbenchmarked`.
 * - `higher-is-better`: at/above target is on-track, within 8% (min 0.02) below is watch.
 * - `lower-is-better`: at/below target is on-track, within 8% (min 0.02) above is watch.
 */
export function getStatus(
  value: number | null,
  target: number | null,
  direction: IndicatorDirection,
): IndicatorStatus {
  if (value === null) return 'no-data';
  if (target === null || direction === 'neutral') return 'unbenchmarked';
  const margin = Math.max(Math.abs(target) * 0.08, 0.02);
  if (direction === 'higher-is-better') {
    if (value >= target) return 'on-track';
    if (value >= target - margin) return 'watch';
    return 'action';
  }
  if (value <= target) return 'on-track';
  if (value <= target + margin) return 'watch';
  return 'action';
}
