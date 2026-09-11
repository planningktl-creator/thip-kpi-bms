import { describe, expect, it, vi } from 'vitest';
import { BmsRequestError } from '@/services/bmsErrors';
import { buildCompletenessAuditQuery, buildDuplicateCheckQuery, buildIndicatorFromRows, buildSourceViewQuery, loadBmsIndicators, quoteSourceView } from '@/services/bmsData';

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

  it('builds a completeness audit covering every catalogue code x fiscal month', () => {
    const query = buildCompletenessAuditQuery('thip_kpi_monthly');
    expect(query.key).toBe('thipCompletenessAudit');
    expect(query.sql).toContain('completeness_status');
    expect(query.sql).toContain('"thip_kpi_monthly"');
    expect(query.sql).toContain("('AA0101')");
    expect(query.sql).toContain("('DH0101')");
    expect(query.sql).toContain('zero-denominator');
  });

  it('builds a duplicate check that flags repeated indicator-month rows', () => {
    const query = buildDuplicateCheckQuery('thip_kpi_monthly');
    expect(query.sql).toContain('HAVING COUNT(*) <> 1');
    expect(query.sql).toContain('"thip_kpi_monthly"');
  });

  it('builds average-length-of-stay indicators as ratio units', () => {
    const los = buildIndicatorFromRows('DH0112', [
      { indicator_code: 'DH0112', fiscal_month: 1, numerator: 42, denominator: 6, value: 7 },
    ], 2026);
    expect(los?.unit).toBe('ratio');
    expect(los?.direction).toBe('neutral');
    expect(los?.target).toBeNull();
    expect(los?.monthly[0]).toMatchObject({ numerator: 42, denominator: 6, value: 7 });
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

  it('surfaces a 401 as a data-phase http failure for session-expiry messaging', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: vi.fn().mockResolvedValue(''),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'expired-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toMatchObject({ phase: 'data', failure: 'http', status: 401 });
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('maps a hung BMS API request to a timeout failure', async () => {
    vi.stubGlobal('fetch', vi.fn((_url: string, init?: RequestInit) => new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')));
    })));

    const abort = new AbortController();
    setTimeout(() => abort.abort(), 50);

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
        marketplaceToken: undefined,
      }, 2026, { signal: abort.signal })).rejects.toMatchObject({ phase: 'data', failure: 'timeout' });
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('stamps the load result with a refresh timestamp', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({
        data: [{
          indicator_code: 'DH0101',
          period_start: '2025-10-01',
          fiscal_year: 2026,
          fiscal_month: 1,
          numerator: 1,
          denominator: 4,
          value: 25,
        }],
      })),
    }));

    try {
      const result = await loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026);
      expect(Number.isNaN(Date.parse(result.refreshedAt))).toBe(false);
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('accepts the BMS result response envelope', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({
        result: [{
          indicator_code: 'DH0101',
          period_start: '2025-10-01',
          fiscal_year: 2026,
          fiscal_month: 1,
          numerator: 1,
          denominator: 4,
          value: 25,
        }],
      })),
    }));

    try {
      const result = await loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026);
      expect(result.liveCodes).toEqual(['DH0101']);
      expect(result.indicators.find((indicator) => indicator.code === 'DH0101')).toMatchObject({ dataSource: 'bms' });
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
