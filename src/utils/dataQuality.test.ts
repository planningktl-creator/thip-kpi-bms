import { describe, expect, it } from 'vitest';
import { getDataQualitySummary, getFreshnessState } from '@/utils/dataQuality';

describe('data quality summary', () => {
  const base = {
    liveIndicatorCount: 232,
    expectedIndicatorCount: 232,
    coveredCellCount: 1552,
    expectedCellCount: 1552,
  };
  const now = new Date('2026-09-11T12:00:00Z');

  it('treats a missing refresh timestamp as unavailable', () => {
    expect(getFreshnessState(null, now)).toBe('unavailable');
    expect(getFreshnessState('not-a-date', now)).toBe('unavailable');
  });

  it('marks a timestamp older than the SLA as stale', () => {
    expect(getFreshnessState('2026-09-09T00:00:00Z', now)).toBe('stale');
    expect(getFreshnessState('2026-09-11T06:00:00Z', now)).toBe('fresh');
  });

  it('never presents unavailable data as a zero result', () => {
    const summary = getDataQualitySummary({ ...base, dataSource: 'unavailable', refreshedAt: null, now });
    expect(summary.tone).toBe('error');
    expect(summary.label).toBe('ไม่มีข้อมูลจริง');
  });

  it('distinguishes partial from complete live coverage', () => {
    const partial = getDataQualitySummary({
      ...base,
      liveIndicatorCount: 1,
      coveredCellCount: 1,
      dataSource: 'partial',
      refreshedAt: '2026-09-11T11:00:00Z',
      now,
    });
    const live = getDataQualitySummary({ ...base, dataSource: 'live', refreshedAt: '2026-09-11T11:00:00Z', now });
    expect(partial.tone).toBe('warning');
    expect(partial.label).toBe('ข้อมูลบางส่วน');
    expect(live.tone).toBe('good');
    expect(live.label).toBe('ข้อมูลครบถ้วน');
  });

  it('flags a complete but stale live source', () => {
    const summary = getDataQualitySummary({ ...base, dataSource: 'live', refreshedAt: '2026-09-01T00:00:00Z', now });
    expect(summary.freshness).toBe('stale');
    expect(summary.tone).toBe('warning');
    expect(summary.label).toBe('ข้อมูลล่าช้า');
  });
});
