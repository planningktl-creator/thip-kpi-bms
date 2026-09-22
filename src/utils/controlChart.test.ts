import { describe, expect, it } from 'vitest';
import type { Indicator, MonthlyResult } from '@/types/thip';
import { createNoDataIndicator, thipCatalogue } from '@/data/thipCatalogue';
import { buildControlChart } from '@/utils/controlChart';

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

describe('THIP per-indicator control chart', () => {
  it('builds a p-chart with weighted center line and per-period 3-sigma limits', () => {
    const indicator = indicatorWith('DH0101', Array.from({ length: 8 }, (_, index) => ({
      fiscalMonth: index + 1,
      numerator: 5,
      denominator: 100,
      value: 5,
    })));
    const chart = buildControlChart(indicator);

    expect(chart.kind).toBe('p-chart');
    expect(chart.cl).toBe(5);
    const point = chart.points[0]!;
    // sigma = sqrt(0.05*0.95/100) * 100 = 2.18%; UCL = 5 + 3*2.18 = 11.54
    expect(point.ucl).toBeCloseTo(11.54, 1);
    expect(point.lcl).toBeCloseTo(0, 1);
    expect(point.inControl).toBe(true);
    expect(chart.hasLimits).toBe(true);
    expect(chart.beyondLimitsCount).toBe(0);
  });

  it('flags a point beyond its limits as a special-cause signal', () => {
    const steady = Array.from({ length: 8 }, (_, index) => ({
      fiscalMonth: index + 1,
      numerator: 5,
      denominator: 100,
      value: 5,
    }));
    const indicator = indicatorWith('DH0101', [
      ...steady,
      { fiscalMonth: 9, numerator: 40, denominator: 100, value: 40 },
    ]);
    const chart = buildControlChart(indicator);

    expect(chart.beyondLimitsCount).toBe(1);
    expect(chart.points[8]).toMatchObject({ signal: 'beyond-limits', inControl: false });
  });

  it('widen limits for small denominators instead of treating them as outliers', () => {
    const indicator = indicatorWith('DH0101', [
      ...Array.from({ length: 6 }, (_, index) => ({ fiscalMonth: index + 1, numerator: 5, denominator: 500, value: 5 })),
      { fiscalMonth: 7, numerator: 4, denominator: 10, value: 40 },
    ]);
    const chart = buildControlChart(indicator);
    const smallCohort = chart.points[6]!;
    expect(smallCohort.ucl).toBeGreaterThan(chart.points[0]!.ucl!);
  });

  it('uses an individuals chart for count indicators', () => {
    const entry = thipCatalogue.find((candidate) => candidate.code === 'DH0101')!;
    const base = createNoDataIndicator(entry, 2026);
    const countIndicator: Indicator = {
      ...base,
      unit: 'count',
      formula: 'a',
      monthly: base.monthly.map((month) => (
        month.fiscalMonth <= 6 ? { ...month, numerator: 10 + month.fiscalMonth, value: 10 + month.fiscalMonth } : month
      )),
    };
    const chart = buildControlChart(countIndicator);

    expect(chart.kind).toBe('individuals');
    expect(chart.cl).toBeCloseTo(13.5, 4);
    // MR between consecutive points is 1 -> MRbar = 1 -> 2.66 * MRbar = 2.66
    expect(chart.points[0]!.ucl).toBeCloseTo(16.16, 2);
    expect(chart.points[0]!.lcl).toBeCloseTo(10.84, 2);
  });

  it('clips the lower limit at zero for non-negative units', () => {
    const entry = thipCatalogue.find((candidate) => candidate.code === 'DH0101')!;
    const base = createNoDataIndicator(entry, 2026);
    const countIndicator: Indicator = {
      ...base,
      unit: 'count',
      formula: 'a',
      monthly: base.monthly.map((month) => (
        month.fiscalMonth <= 5 ? { ...month, value: month.fiscalMonth % 2 === 0 ? 1 : 3, numerator: 1 } : month
      )),
    };
    const chart = buildControlChart(countIndicator);
    expect(chart.points.every((point) => point.lcl === null || point.lcl >= 0)).toBe(true);
  });

  it('detects a run of eight consecutive points on one side of the center line', () => {
    const values = [5, 5, 5, 5, 5, 5, 5, 5, 30, 30, 30, 30];
    const indicator = indicatorWith('DH0101', values.map((value, index) => ({
      fiscalMonth: index + 1,
      numerator: value,
      denominator: 100,
      value,
    })));
    const chart = buildControlChart(indicator);
    expect(chart.runSignalCount).toBeGreaterThanOrEqual(1);
  });

  it('reports no limits when fewer than two periods are measured', () => {
    const indicator = indicatorWith('DH0101', [
      { fiscalMonth: 1, numerator: 5, denominator: 100, value: 5 },
    ]);
    const chart = buildControlChart(indicator);
    expect(chart.hasLimits).toBe(false);
    expect(chart.points[0]).toMatchObject({ ucl: null, lcl: null, inControl: null, signal: 'none' });
  });

  it('never judges a period without measured facts', () => {
    const indicator = indicatorWith('DH0101', Array.from({ length: 4 }, (_, index) => ({
      fiscalMonth: index + 1,
      numerator: 5,
      denominator: 100,
      value: 5,
    })));
    const chart = buildControlChart(indicator);
    expect(chart.points[5]).toMatchObject({ value: null, ucl: null, lcl: null, inControl: null, signal: 'none' });
  });
});
