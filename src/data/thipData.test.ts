import { describe, expect, it } from 'vitest';
import { DEMO_FISCAL_YEAR, fiscalMonthLabels, groupMeta, sourceDictionaryCount } from '@/data/thipData';

describe('THIP source data', () => {
  it('exposes the fiscal month labels for the demo fiscal year', () => {
    expect(fiscalMonthLabels).toHaveLength(12);
    expect(fiscalMonthLabels[0]).toBe('ต.ค.');
    expect(fiscalMonthLabels[11]).toBe('ก.ย.');
  });

  it('keeps group metadata for the five THIP groups', () => {
    expect(Object.keys(groupMeta)).toHaveLength(5);
    expect(groupMeta.D.shortLabel).toBe('รายโรค');
    expect(groupMeta.A.shortLabel).toBe('ผู้ป่วยนอก');
  });

  it('tracks the THIP 2025 dictionary size', () => {
    expect(sourceDictionaryCount).toBe(232);
    expect(DEMO_FISCAL_YEAR).toBe(2026);
  });
});
