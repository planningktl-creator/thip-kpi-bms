import { afterEach, describe, expect, it, vi } from 'vitest';
import { executeRegisteredQuery, queryRegistry } from '@/services/queryRegistry';
import { getQueryTelemetry, resetQueryTelemetry, responseRowCount } from '@/services/queryTelemetry';

const runtime = { apiUrl: 'https://bms.test', bearerToken: 'test-token', appIdentifier: 'THIP.KPI.BMS' };

afterEach(() => {
  resetQueryTelemetry();
  vi.unstubAllGlobals();
});

describe('query telemetry', () => {
  it('counts rows without reading row values', () => {
    expect(responseRowCount({ record_count: 12 })).toBe(12);
    expect(responseRowCount({ data: [{ a: 1 }, { a: 2 }] })).toBe(2);
    expect(responseRowCount({ result: [{ a: 1 }] })).toBe(1);
    expect(responseRowCount({})).toBe(0);
  });

  it('records only aggregate fields after a successful query', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{ indicator_code: 'DH0101' }] })),
    }));

    await executeRegisteredQuery(queryRegistry.versionProbe, runtime);
    const telemetry = getQueryTelemetry('versionProbe');

    expect(telemetry).toMatchObject({ key: 'versionProbe', calls: 1, failures: 0, lastRowCount: 1, lastOutcome: 'success' });
    expect(Object.keys(telemetry!)).not.toContain('sql');
    expect(Object.keys(telemetry!)).not.toContain('params');
  });

  it('records a failure outcome without exposing the query text', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 502,
      text: vi.fn().mockResolvedValue(''),
    }));

    await expect(executeRegisteredQuery(queryRegistry.versionProbe, runtime)).rejects.toThrow();
    const telemetry = getQueryTelemetry('versionProbe');

    expect(telemetry).toMatchObject({ calls: 1, failures: 1, failureRate: 1, lastOutcome: 'http' });
  });
});
