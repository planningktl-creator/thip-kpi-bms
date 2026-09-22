import { describe, expect, it } from 'vitest';
import type { Indicator, MonthlyResult } from '@/types/thip';
import { createNoDataIndicator, thipCatalogue } from '@/data/thipCatalogue';
import { aggregateFacts, quarterDefs, rollupAnnual, rollupMonths, rollupQuarters } from '@/utils/rollup';

function indicatorWith(code: string, values: Array<Partial<MonthlyResult> & { fiscalMonth: number }>): Indicator {
  const entry = thipCatalogue.find((candidate) => candidate.code === code)!;
  const indicator = createNoDataIndicator(entry, 2026);
  return {
    ...indicator,
    monthly: indicator.monthly.map((month) => {
      const override = values.find((value) => value.fiscalMonth === month.fiscalMonth);
      return override ? { ...month, ...override } : month;
    }),
  };
}

describe('THIP time rollups', () => {
  it('rolls monthly facts into weighted quarters (Q1 = ต.ค.–ธ.ค.)', () => {
    const indicator = indicatorWith('DH0101', [
      { fiscalMonth: 1, numerator: 1, denominator: 10, value: 10, status: 'on-track' },
      { fiscalMonth: 2, numerator: 2, denominator: 10, value: 20, status: 'on-track' },
      { fiscalMonth: 4, numerator: 4, denominator: 20, value: 20, status: 'on-track' },
    ]);
    const quarters = rollupQuarters(indicator);

    expect(quarters).toHaveLength(4);
    expect(quarters[0]).toMatchObject({ key: 'Q1', numerator: 3, denominator: 20, value: 15, measuredCellCount: 2 });
    expect(quarters[1]).toMatchObject({ key: 'Q2', numerator: 4, denominator: 20, value: 20, measuredCellCount: 1 });
    expect(quarters[2]).toMatchObject({ key: 'Q3', value: null, measuredCellCount: 0, status: 'no-data' });
    expect(quarters[3]?.measuredCellCount).toBe(0);
  });

  it('weights the quarter by denominators instead of averaging period percentages', () => {
    // 10% of 10 and 50% of 10: weighted 30%, arithmetic mean would be 30% here,
    // so use unequal denominators: 10/100 (10%) and 10/20 (50%) -> 20/120 = 16.67%.
    const indicator = indicatorWith('DH0101', [
      { fiscalMonth: 1, numerator: 10, denominator: 100, value: 10 },
      { fiscalMonth: 2, numerator: 10, denominator: 20, value: 50 },
    ]);
    const quarters = rollupQuarters(indicator);
    expect(quarters[0]?.value).toBe(16.67);
    expect(quarters[0]?.denominator).toBe(120);
  });

  it('sums count indicators instead of dividing', () => {
    const entry = thipCatalogue.find((candidate) => candidate.code === 'DH0101')!;
    const base = createNoDataIndicator(entry, 2026);
    const countIndicator: Indicator = { ...base, unit: 'count', formula: 'a', monthly: base.monthly.map((month) => ({ ...month })) };
    const withValues: Indicator = {
      ...countIndicator,
      monthly: countIndicator.monthly.map((month) => (
        month.fiscalMonth <= 3 ? { ...month, numerator: month.fiscalMonth * 2, value: month.fiscalMonth * 2 } : month
      )),
    };
    const quarters = rollupQuarters(withValues);
    expect(quarters[0]).toMatchObject({ numerator: 12, value: 12 });
  });

  it('keeps denominator-zero periods out of the weighted value without faking zeroes', () => {
    const indicator = indicatorWith('DH0101', [
      { fiscalMonth: 1, numerator: 0, denominator: 0, value: null },
      { fiscalMonth: 2, numerator: 2, denominator: 4, value: 50 },
    ]);
    const quarters = rollupQuarters(indicator);
    expect(quarters[0]).toMatchObject({ value: 50, denominator: 4, measuredCellCount: 1 });
  });

  it('mirrors the annual result and exposes one row per month', () => {
    const indicator: Indicator = {
      ...indicatorWith('DH0101', [
        { fiscalMonth: 1, numerator: 10, denominator: 100, value: 10 },
        { fiscalMonth: 2, numerator: 30, denominator: 100, value: 30 },
      ]),
      annual: { fiscalYear: 2026, numerator: 40, denominator: 200, value: 20, target: null, status: 'unbenchmarked' },
    };
    const months = rollupMonths(indicator);
    const annual = rollupAnnual(indicator);

    expect(months).toHaveLength(12);
    expect(months[0]).toMatchObject({ key: 'M1', value: 10, fiscalMonths: [1] });
    expect(months[5]?.status).toBe('no-data');
    expect(annual).toMatchObject({ key: 'FY', numerator: 40, denominator: 200, value: 20 });
    expect(annual.value).toBe(indicator.annual.value);
  });

  it('exposes four quarter definitions covering all twelve fiscal months', () => {
    expect(quarterDefs.flatMap((quarter) => quarter.fiscalMonths)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
  });

  it('returns null facts for an indicator without measured data', () => {
    const entry = thipCatalogue.find((candidate) => candidate.code === 'DR0101')!;
    const indicator = createNoDataIndicator(entry, 2026);
    const facts = aggregateFacts(indicator.monthly, indicator);
    expect(facts).toMatchObject({ numerator: null, denominator: null, value: null, measuredCellCount: 0 });
  });
});
