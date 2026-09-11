import { describe, expect, it } from 'vitest';
import { groupMeta, sourceDictionaryCount } from '@/data/thipMeta';
import { getFiscalMonthPeriods } from '@/utils/fiscal';

describe('THIP metadata', () => {
  it('exposes fiscal month labels from the requested year', () => {
    const periods = getFiscalMonthPeriods(2026);
    expect(periods).toHaveLength(12);
    expect(periods[0]?.monthLabel).toBe('ต.ค.');
    expect(periods[11]?.monthLabel).toBe('ก.ย.');
  });

  it('keeps group metadata for the five THIP groups', () => {
    expect(Object.keys(groupMeta)).toHaveLength(5);
    expect(groupMeta.D.shortLabel).toBe('รายโรค');
    expect(groupMeta.A.shortLabel).toBe('ผู้ป่วยนอก');
  });

  it('tracks the THIP 2025 dictionary size', () => {
    expect(sourceDictionaryCount).toBe(232);
  });
});
