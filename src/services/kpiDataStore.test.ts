import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { KpiDataStore } from './kpiDataStore';
import { ThipStepLoader, validateCandidateRows } from './thipStepLoader';
import { MemoryCacheRepository } from './thipStepCache';
import type { BmsRuntimeConfig } from './bmsSession';
import type { StepSnapshot } from './thipStepLoader';
import { runtimeMonitoringBridges } from '@/data/thipRuntime';
import { getReportingCadence } from '@/data/thipReporting';
import { sharedKpiCsv } from './kpiExport';
import {
  buildCodeSourceQuery,
  validateMonitoringProjection,
  validateReportingProjection,
} from './kpiQueue';
import { unavailableCell } from '@/monitoring/contract';
import { monitoringRulesByCode } from '@/monitoring/rules';

const runtime: BmsRuntimeConfig = {
  apiUrl: 'https://synthetic.invalid',
  bearerToken: 'SYNTHETIC_ONLY',
  appIdentifier: 'THIP.KPI.BMS',
};
const input = (code = 'DH0101', month = 1, value = 10, year = 2026) => ({
  indicator_code: code,
  fiscal_year: year,
  fiscal_month: month,
  period_start: `${month <= 3 ? year - 1 : year}-${String(month <= 3 ? month + 9 : month - 3).padStart(2, '0')}-01`,
  numerator: 1,
  denominator: 10,
  value,
  fact_present: true,
});
let stores: KpiDataStore[] = [];
beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-10-01T00:00:00Z'));
});
afterEach(() => {
  stores.forEach((store) => store.dispose());
  stores = [];
  vi.useRealTimers();
  vi.restoreAllMocks();
});
function make(factory: ConstructorParameters<typeof KpiDataStore>[2]) {
  const store = new KpiDataStore(2026, new MemoryCacheRepository(), factory);
  stores.push(store);
  return store;
}

describe('one app data owner', () => {
  it('projects the same cumulative facts to reporting and its explicit monthly bridge without extra queries', async () => {
    const run = vi.fn(async () => [{ ...input(), numerator: 10, denominator: 100 }, { ...input('DH0101', 2, 50), numerator: 10, denominator: 20 }]);
    const store = make(async (_runtime, year, _repo, _signal, update) => new ThipStepLoader(year, [{ code: 'DH0101', run }], update, 0, []));
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    for (const series of ['thip-report', 'monthly-monitoring'] as const) {
      const row = store.grid(series, 'review').find(row => row.code === 'DH0101')!;
      expect(row.cells[1].cumulative.value).toBeCloseTo(16.6666667);
      expect(row.cells[1].cumulative.complete).toBe(false);
      expect(row.cells[2].cumulative.value).toBeNull();
      expect(store.grid(series, 'approved').find(row => row.code === 'DH0101')!.cells[1].cumulative.value).toBeNull();
    }
    expect(run).toHaveBeenCalledTimes(1);
  });
  it('does not bypass an expired session by clearing cache or changing year', async () => {
    const factory = vi.fn(
      async (_runtime, year, _repo, _signal, update) =>
        new ThipStepLoader(year, [], update, 0, [])
    );
    const store = make(factory);
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    const { BmsRequestError } = await import('./bmsErrors');
    store.holdSource(
      new BmsRequestError('api', 'http', 'SYNTHETIC_UNAUTHORIZED', 401)
    );
    await store.clearAll();
    await store.start();
    expect(factory).toHaveBeenCalledTimes(1);
    store.configure(runtime, 2027);
    await vi.advanceTimersByTimeAsync(0);
    expect(factory).toHaveBeenCalledTimes(1);
    expect(store.snapshot().blockedBySession).toBe(true);
    store.configure({ ...runtime, bearerToken: 'SYNTHETIC_RECONNECTED' }, 2027);
    await vi.advanceTimersByTimeAsync(0);
    expect(factory).toHaveBeenCalledTimes(2);
  });
  it('retains Retry-After outside the queue snapshot and exports reporting cadence only', async () => {
    const factory = vi.fn(
      async (_runtime, year, _repo, _signal, update) =>
        new ThipStepLoader(year, [], update, 0, [])
    );
    const store = make(factory);
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    const { BmsRequestError } = await import('./bmsErrors');
    store.holdSource(
      new BmsRequestError('api', 'http', 'SYNTHETIC_RATE', 429, {
        retryAfterMs: 2000,
      })
    );
    await store.clearAll();
    await store.start();
    expect(factory).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(2001);
    await store.start();
    expect(factory).toHaveBeenCalledTimes(2);
    expect(
      sharedKpiCsv(
        store.grid('thip-report', 'review'),
        2026,
        'thip-report',
        'review'
      ).split('\r\n')
    ).toHaveLength(1553);
    expect(
      sharedKpiCsv(
        store.grid('monthly-monitoring', 'review'),
        2026,
        'monthly-monitoring',
        'review'
      ).split('\r\n')
    ).toHaveLength(2785);
  });
  it('publishes progressively to both series without querying again for another reader', async () => {
    const one = vi.fn(async () => [input()]),
      two = vi.fn(async () => [input('DH0112')]);
    const factory = vi.fn(async (_runtime, year, _repo, signal, update) => {
      const loader = new ThipStepLoader(
        year,
        [
          { code: 'DH0101', run: one },
          { code: 'DH0112', run: two },
        ],
        update,
        1000,
        []
      );
      signal.addEventListener('abort', () => loader.cancel());
      return loader;
    });
    const store = make(factory);
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    const report = store
      .grid('thip-report', 'review')
      .find((row) => row.code === 'DH0101')!;
    expect(report.cells[0].value).toBe(10);
    expect(
      store
        .grid('monthly-monitoring', 'review')
        .find((row) => row.code === 'DH0101')!.cells[0]
    ).toMatchObject({ value: 10, lineage: 'reporting-monthly-bridge/1' });
    expect(
      store
        .grid('thip-report', 'approved')
        .find((row) => row.code === 'DH0101')!.cells[0]
    ).toMatchObject({ value: null, status: 'rule-unapproved' });
    store.configure(runtime, 2026);
    store.grid('thip-report', 'review');
    store.reportingSteps();
    store.officialIndicator('DH0101');
    expect(factory).toHaveBeenCalledTimes(1);
    expect(one).toHaveBeenCalledTimes(1);
    expect(two).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1000);
    expect(two).toHaveBeenCalledTimes(1);
    expect(
      store.grid('thip-report', 'review').find((row) => row.code === 'DH0101')
    ).toBe(report);
  });
  it('has 2784 slots but only 1552 reporting cells; quarterly/annual facts are not copied', async () => {
    const store = make(
      async (_runtime, year, _repo, _signal, update) =>
        new ThipStepLoader(
          year,
          [{ code: 'SH0101', run: async () => [input('SH0101')] }],
          update,
          0,
          []
        )
    );
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    const grid = store.grid('thip-report', 'review');
    expect(grid.length).toBe(232);
    expect(grid.flatMap((row) => row.cells).length).toBe(2784);
    expect(
      grid
        .flatMap((row) => row.cells)
        .filter((cell) => cell.status !== 'not-applicable').length
    ).toBe(1552);
    expect(
      grid
        .find((row) => row.code === 'SH0101')!
        .cells.filter((cell) => cell.value !== null)
    ).toHaveLength(1);
    expect(grid.find((row) => row.code === 'SH0101')!.cells[0].periodEnd).toBe(
      '2026-10-01'
    );
    expect(
      store
        .grid('monthly-monitoring', 'review')
        .find((row) => row.code === 'SH0101')!
        .cells.every((cell) => cell.value === null)
    ).toBe(true);
    expect(
      store.grid('monthly-monitoring', 'review').flatMap((row) => row.cells)
    ).toHaveLength(2784);
    expect(
      runtimeMonitoringBridges.every(
        (bridge) =>
          getReportingCadence(bridge.code) === 'monthly' &&
          !!bridge.cohortHash &&
          !!bridge.evidence
      )
    ).toBe(true);
  });
  it('clears immediately on year/session changes and ignores old asynchronous callbacks', async () => {
    const updates: ((snapshot: StepSnapshot) => void)[] = [];
    const store = make(async (_runtime, year, _repo, _signal, update) => {
      updates.push(update);
      return new ThipStepLoader(year, [], update, 0, []);
    });
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    const old = store.snapshot().progress!;
    store.configure(runtime, 2027);
    expect(store.snapshot().progress).toBeNull();
    updates[0](old);
    expect(store.snapshot().progress).toBeNull();
    await vi.advanceTimersByTimeAsync(0);
    expect(store.snapshot().fiscalYear).toBe(2027);
    store.configure({ ...runtime, bearerToken: 'SYNTHETIC_OTHER' }, 2027);
    expect(store.snapshot().progress).toBeNull();
  });
  it('retains source value for review when arithmetic differs and labels the CSV', async () => {
    const store = make(
      async (_runtime, year, _repo, _signal, update) =>
        new ThipStepLoader(
          year,
          [{ code: 'DH0101', run: async () => [input('DH0101', 1, 0)] }],
          update,
          0,
          []
        )
    );
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    const row = store
      .grid('thip-report', 'review')
      .find((row) => row.code === 'DH0101')!;
    expect(row.cells[0]).toMatchObject({
      value: 0,
      derivedValue: 10,
      discrepancy: true,
    });
    const csv = sharedKpiCsv([row], 2026, 'thip-report', 'review');
    expect(csv).toContain('UNAPPROVED REVIEW');
    expect(csv.split('\r\n')).toHaveLength(13);
    expect(csv).toContain('พ.ศ. 2568');
    expect(() =>
      sharedKpiCsv([row], 2026, 'thip-report', 'approved')
    ).toThrow();
    expect(() => sharedKpiCsv([row], 2027, 'thip-report', 'review')).toThrow();
    const malicious = {
      ...row,
      cells: row.cells.map((cell) => ({
        ...cell,
        reason: '=SYNTHETIC_FORMULA()',
      })),
    };
    expect(sharedKpiCsv([malicious], 2026, 'thip-report', 'review')).toContain(
      "'=SYNTHETIC_FORMULA()"
    );
  });
  it('invalidates expired cached results without turning them into zero and clear stops the queue', async () => {
    const store = make(
      async (_runtime, year, _repo, _signal, update) =>
        new ThipStepLoader(
          year,
          [{ code: 'DH0101', run: async () => [] }],
          update,
          0,
          [],
          {
            read: async () => [
              {
                code: 'DH0101',
                rows: validateCandidateRows([input()], 'DH0101', year),
                observedAt: new Date().toISOString(),
                expiresAt: Date.now() + 1000,
              },
            ],
            write: async () => null,
          }
        )
    );
    store.configure(runtime, 2026);
    await vi.advanceTimersByTimeAsync(0);
    expect(
      store.grid('thip-report', 'review').find((row) => row.code === 'DH0101')!
        .cells[0].value
    ).toBe(10);
    await vi.advanceTimersByTimeAsync(1001);
    expect(
      store.grid('thip-report', 'review').find((row) => row.code === 'DH0101')!
        .cells[0]
    ).toMatchObject({ value: null, status: 'expired' });
    await store.clearAll();
    expect(store.snapshot()).toMatchObject({ progress: null, stopped: true });
  });
  it('keeps missing monthly source and future months explicit', () => {
    const store = make(
      async (_r, year, _repo, _s, update) =>
        new ThipStepLoader(year, [], update)
    );
    store.configure(null, 2027);
    const row = store
      .grid('monthly-monitoring', 'review')
      .find((row) => row.code === 'SH0101')!;
    expect(row.cells[0]).toMatchObject({
      value: null,
      status: 'missing-source',
    });
    expect(row.cells[1]).toMatchObject({ value: null, status: 'future' });
  });
});
describe('per-code normalized source boundary', () => {
  it('binds code without splitting observation windows and prohibits identifiers outside manifest', () => {
    const report = buildCodeSourceQuery(
      'reporting.thip_kpi_monthly',
      'DH0101',
      false
    );
    expect(report.sql).toContain('indicator_code = :indicator_code');
    expect(report.sql).toContain(':start_date');
    expect(report.sql).toContain(':end_date');
    const monitor = buildCodeSourceQuery(
      'reporting.thip_monthly_monitoring',
      'DH0101',
      true
    );
    expect(monitor.sql).toContain('code = :indicator_code');
    expect(monitor.sql).toContain(':fiscal_year');
    expect(() =>
      buildCodeSourceQuery('bad; DROP TABLE patient', 'DH0101', false)
    ).toThrow();
    expect(() =>
      buildCodeSourceQuery('reporting.good', 'NOT_IN_MANIFEST', false)
    ).toThrow();
  });
  it('validates monitoring drafts while publication stays separate; rejects patient fields/duplicates', () => {
    const rule = monitoringRulesByCode.get('DH0101')!,
      base = unavailableCell(rule, 2026, 1);
    const measured = {
      ...base,
      dataStatus: 'measured',
      value: 10,
      numerator: 1,
      denominator: 10,
      dataThrough: '2025-10-31',
      refreshedAt: '2026-10-01T00:00:00Z',
    };
    expect(
      validateMonitoringProjection([measured], 'monitoring/DH0101', 2026)[0]
    ).toMatchObject({ sourceValue: 10, approval: 'unapproved' });
    expect(() =>
      validateMonitoringProjection(
        [measured, measured],
        'monitoring/DH0101',
        2026
      )
    ).toThrow();
    expect(() =>
      validateMonitoringProjection(
        [{ ...measured, hn: 'SYNTHETIC_HN' }],
        'monitoring/DH0101',
        2026
      )
    ).toThrow();
    expect(() =>
      validateReportingProjection(
        [{ ...input(), hn: 'SYNTHETIC_HN' }],
        'DH0101',
        2026
      )
    ).toThrow();
  });
});
