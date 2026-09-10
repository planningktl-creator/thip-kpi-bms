import { describe, expect, it, vi } from 'vitest';
import { BmsRequestError } from '@/services/bmsErrors';
import { buildIndicatorFromRows, buildSourceViewQuery, loadBmsIndicators, quoteSourceView } from '@/services/bmsData';

describe('BMS KPI data adapter', () => {
  it('maps monthly source facts and calculates a weighted annual result', () => {
    const indicator = buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, numerator: '2', denominator: '10', value: '20', percentile: 71 },
      { indicator_code: 'DH0101', fiscal_month: 2, numerator: 1, denominator: 5, value: 20, percentile: 73 },
    ], 2026);

    expect(indicator?.dataSource).toBe('bms');
    expect(indicator?.monthly[0]).toMatchObject({ numerator: 2, denominator: 10, value: 20, percentile: 71 });
    expect(indicator?.monthly[2]?.value).toBeNull();
    expect(indicator?.annual).toMatchObject({ numerator: 3, denominator: 15, value: 20 });
  });

  it('rejects duplicate indicator-month rows', () => {
    expect(() => buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, numerator: 1, denominator: 2 },
      { indicator_code: 'DH0101', fiscal_month: 1, numerator: 2, denominator: 3 },
    ], 2026)).toThrow(BmsRequestError);
  });

  it('quotes only safe source-view identifiers', () => {
    expect(quoteSourceView('public.thip_kpi_monthly')).toBe('"public"."thip_kpi_monthly"');
    expect(() => quoteSourceView('public.thip_kpi_monthly; DROP TABLE patient')).toThrow();
    expect(buildSourceViewQuery('thip_kpi_monthly').sql).toContain('FROM "thip_kpi_monthly"');
  });

  it('classifies API failures during the KPI load as data failures', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 502,
      text: vi.fn().mockResolvedValue(''),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toMatchObject({ phase: 'data', failure: 'http', status: 502 });
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
