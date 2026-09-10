import { describe, expect, it } from 'vitest';
import { demoIndicators, fiscalMonthLabels } from '@/data/thipData';

describe('THIP demo data contract', () => {
  it('keeps one result for each fiscal month', () => {
    expect(demoIndicators.length).toBeGreaterThan(0);
    for (const indicator of demoIndicators) {
      expect(indicator.monthly).toHaveLength(fiscalMonthLabels.length);
      expect(indicator.monthly.map((month) => month.fiscalMonth)).toEqual(
        fiscalMonthLabels.map((_, index) => index + 1),
      );
    }
  });

  it('preserves numerator and denominator for computed values', () => {
    const indicator = demoIndicators.find((item) => item.code === 'DH0101');
    expect(indicator).toBeDefined();
    const first = indicator!.monthly[0];
    expect(first.numerator).toBeGreaterThan(0);
    expect(first.denominator).toBeGreaterThan(first.numerator!);
    expect(first.value).toBeCloseTo((first.numerator! / first.denominator!) * 100, 2);
  });
});
