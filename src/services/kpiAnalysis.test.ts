import { describe, expect, it } from 'vitest';
import { KpiDataStore } from './kpiDataStore';
import { withKpiCumulative } from './kpiCumulative';
import { sharedControlChart } from './kpiAnalysis';
import { sharedKpiCsv } from './kpiExport';
import { monitoringRulesByCode } from '@/monitoring/rules';
import { buildPeriodControlChart } from '@/utils/controlChartCore';
import type { KpiCellViewModel } from './kpiTypes';
import type { AccumulationMethod } from '@/monitoring/types';

const rule = monitoringRulesByCode.get('DH0101')!;
function cells(facts: Array<[number, number] | null>, method: AccumulationMethod = 'weighted-ratio') {
  const store = new KpiDataStore(2026);
  const base = store.grid('monthly-monitoring', 'review').find(row => row.code === 'DH0101')!.cells;
  store.dispose();
  return base.map((cell, index): KpiCellViewModel => {
    const fact = facts[index];
    return { ...cell, ruleVersion: rule.version, lineage: 'synthetic-test', accumulation: method,
      status: fact ? 'measured' : 'missing-source', numerator: fact?.[0] ?? null,
      denominator: fact?.[1] ?? null, value: fact ? fact[0] / fact[1] * 100 : null,
      discrepancy: false, cumulativeBasis: null, cumulativeReason: '',
    };
  });
}

describe('shared KPI fiscal cumulative results', () => {
  it('weights unequal denominators, preserves facts and never certifies native coverage', () => {
    const result = withKpiCumulative(cells([[10, 100], [10, 20]]), rule);
    expect(result[1].value).toBe(50);
    expect(result[1].cumulative).toMatchObject({ numerator: 20, denominator: 120, complete: false, through: null });
    expect(result[1].cumulative.value).toBeCloseTo(16.6666667);
    expect(result[1].cumulativeBasis).toBe('period-facts');
    expect(result[2].cumulative.value).toBeNull();
  });
  it('does not skip missing months or arithmetic mismatches when summing YTD', () => {
    const input = cells([[1, 10], null, [2, 10]]);
    expect(withKpiCumulative(input, rule)[2].cumulative.value).toBeNull();
    const discrepant = cells([[1, 10], [2, 10]]);
    discrepant[0] = { ...discrepant[0], discrepancy: true };
    expect(withKpiCumulative(discrepant, rule)[1].cumulative.value).toBeNull();
  });
  it('uses fixed denominator once and rejects changing bases', () => {
    const fixed = { ...rule, accumulation: 'fixed-denominator' as const };
    expect(withKpiCumulative(cells([[10, 100], [20, 100]], fixed.accumulation), fixed)[1].cumulative.value).toBe(30);
    expect(withKpiCumulative(cells([[10, 100], [20, 200]], fixed.accumulation), fixed)[1].cumulative.value).toBeNull();
  });
  it('sums counts but uses only the latest snapshot even after a missing month', () => {
    const input = cells([[10, 100], [20, 100]], 'count').map((cell, i) => ({ ...cell, value: i < 2 ? (i + 1) * 10 : null, unit: 'count' as const }));
    expect(withKpiCumulative(input, { ...rule, accumulation: 'count', unit: 'count' })[1].cumulative.value).toBe(30);
    expect(withKpiCumulative(cells([[10, 100], null, [20, 100]], 'snapshot'), { ...rule, accumulation: 'snapshot' })[2].cumulative.value).toBe(20);
  });
  it.each(['distinct-cohort', 'custom'] as const)('requires source YTD for %s; preserves source-confirmed coverage', method => {
    const input = cells([[10, 100], [20, 100]], method);
    expect(withKpiCumulative(input, { ...rule, accumulation: method })[1].cumulative.value).toBeNull();
    input[1] = { ...input[1], cumulativeBasis: 'source', cumulative: { numerator: 25, denominator: 120, value: 25 / 120 * 100, complete: true, through: '2025-11-30' } };
    expect(withKpiCumulative(input, { ...rule, accumulation: method })[1].cumulative).toEqual(input[1].cumulative);
  });
  it('withholds future, unapproved and non-additive reporting rows; rejects changed versions', () => {
    const input = cells([[10, 100], [20, 100]]);
    for (const status of ['future', 'rule-unapproved', 'not-applicable'] as const) {
      expect(withKpiCumulative([{ ...input[0], status }], rule)[0].cumulative.value).toBeNull();
    }
    expect(withKpiCumulative([{ ...input[0], accumulation: 'source-period-result' }], rule)[0].cumulative.value).toBeNull();
    expect(withKpiCumulative([input[0], { ...input[1], ruleVersion: 'different' }], rule)[1].cumulative.value).toBeNull();
  });
  it('exports both period and YTD facts with provenance and does not leak review YTD as approved', () => {
    const result = withKpiCumulative(cells([[10, 100], [10, 20]]), rule);
    const csv = sharedKpiCsv([{ code: 'DH0101', cells: result }], 2026, 'monthly-monitoring', 'review');
    const lines = csv.replace(/^\uFEFF/, '').split('\r\n').map(line => line.split(','));
    expect(lines[2][lines[0].indexOf('value')]).toBe('50');
    expect(Number(lines[2][lines[0].indexOf('ytd_value')])).toBeCloseTo(16.6666667);
    expect(lines[2][lines[0].indexOf('ytd_basis')]).toBe('period-facts');
    expect(lines[2][lines[0].indexOf('ytd_complete')]).toBe('false');
    expect(() => sharedKpiCsv([{ code: 'DH0101', cells: [{ ...result[1], value: null }] }], 2026, 'monthly-monitoring', 'approved')).toThrow('approval');
  });
});

describe('shared per-period control chart', () => {
  it('uses monthly raw facts even when cumulative values are present, and weights the p-chart CL', () => {
    const result = withKpiCumulative(cells([[10, 100], [10, 20]]), rule);
    const { model } = sharedControlChart(result);
    expect(model.kind).toBe('p-chart');
    expect(model.cl).toBeCloseTo(16.6666667);
    expect(model.points[1].value).toBe(50);
    expect(model.points[1].ucl).toBeGreaterThan(model.points[0].ucl!);
  });
  it('excludes discrepancy, future and unapproved values; refuses a mixed-version baseline', () => {
    const input = cells([[5, 100], [6, 100], [7, 100]]);
    input[0] = { ...input[0], discrepancy: true };
    input[1] = { ...input[1], status: 'future' };
    expect(sharedControlChart(input).model.measuredPointCount).toBe(1);
    input[2] = { ...input[2], status: 'rule-unapproved' };
    expect(sharedControlChart(input).model.measuredPointCount).toBe(0);
    const mixed = cells([[5, 100], [6, 100]]);
    mixed[1] = { ...mixed[1], ruleVersion: 'another-version' };
    expect(sharedControlChart(mixed).model.hasLimits).toBe(false);
  });
  it('matches the NIST Individuals example and does not build MR across missing periods', () => {
    const values = [49.6, 47.6, 49.9, 51.3, 47.8, 51.2, 52.6, 52.4, 53.6, 52.1];
    const points = values.map((value, index) => ({ fiscalMonth: index + 1, label: '', value, numerator: null, denominator: null }));
    const model = buildPeriodControlChart(points, 1, false);
    expect(model.cl).toBeCloseTo(50.81);
    expect(model.points[0].ucl).toBeCloseTo(55.8041);
    expect(model.points[0].lcl).toBeCloseTo(45.8159);
    expect(buildPeriodControlChart([points[0], { ...points[1], value: null }, points[2]], 1, false).hasLimits).toBe(false);
  });
  it('caps proportions at 100%, detects outliers and breaks runs at missing points', () => {
    const input = cells(Array.from({ length: 12 }, (_, index) => [index < 8 ? 5 : 30, 100] as [number, number]));
    expect(sharedControlChart(input).model.runSignalCount).toBe(1);
    input[4] = { ...input[4], value: null, status: 'missing-source' };
    expect(sharedControlChart(input).model.runSignalCount).toBe(0);
    const outlier = sharedControlChart(cells(Array.from({ length: 9 }, (_, i) => [i < 8 ? 5 : 40, 100] as [number, number]))).model;
    expect(outlier.beyondLimitsCount).toBe(1);
    const high = sharedControlChart(cells([[9, 10], [10, 10]])).model;
    expect(high.points[0].ucl).toBe(100);
  });
});
