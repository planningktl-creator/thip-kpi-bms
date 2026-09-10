import { describe, expect, it } from 'vitest';
import { DEMO_FISCAL_YEAR, demoIndicators, fiscalMonthLabels } from '@/data/thipData';

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

  it('rolls monthly source facts up to the selected fiscal year', () => {
    const indicator = demoIndicators.find((item) => item.code === 'DH0101');
    expect(indicator).toBeDefined();
    expect(indicator!.fiscalYear).toBe(DEMO_FISCAL_YEAR);
    expect(indicator!.annual.fiscalYear).toBe(DEMO_FISCAL_YEAR);
    expect(indicator!.annual.numerator).toBeGreaterThan(0);
    expect(indicator!.annual.denominator).toBeGreaterThan(indicator!.annual.numerator!);
    expect(indicator!.annual.value).toBeCloseTo((indicator!.annual.numerator! / indicator!.annual.denominator!) * 100, 2);
  });

  it('keeps an annual target separate from monthly target cells', () => {
    const indicator = demoIndicators.find((item) => item.code === 'HE0101');
    expect(indicator).toBeDefined();
    expect(indicator!.targetScope).toBe('annual');
    expect(indicator!.annual.target).toBe(90);
    expect(indicator!.monthly.every((month) => month.target === null)).toBe(true);
  });
});
