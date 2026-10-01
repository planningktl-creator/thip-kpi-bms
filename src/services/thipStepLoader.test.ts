import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { BmsRequestError, parseRetryAfter } from './bmsErrors';
import { ThipStepLoader, createThipStepLoader, validateCandidateRows, type StepTask } from './thipStepLoader';
import { executeRegisteredQuery, hosxpRegisteredBranches, queryRegistry } from './queryRegistry';
import { planFoundationRequests } from './thipFoundationPlan';

const aggregate = (code = 'DH0101', month = 1, numerator = 1, denominator = 130, value: number | null = 100 / 130) => ({ indicator_code: code, fiscal_year: 2026, fiscal_month: month, period_start: month === 1 ? '2025-10-01' : '2025-11-01', numerator, denominator, value });
const task = (code: string, run: StepTask['run'] = vi.fn(async () => [aggregate(code)])): StepTask => ({ code, run });

beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date('2026-10-01T00:00:00Z')); });
afterEach(() => { vi.useRealTimers(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });

describe('sequential aggregate steps', () => {
  it('publishes first result immediately and leaves one second between requests', async () => {
    const one = task('DH0101'), two = task('DH0112');
    const progress = vi.fn(); const loader = new ThipStepLoader(2026, [one, two], progress, 1000, []);
    const done = loader.start(); await vi.advanceTimersByTimeAsync(0);
    expect(one.run).toHaveBeenCalledTimes(1); expect(two.run).not.toHaveBeenCalled();
    expect(loader.snapshot()).toMatchObject({ succeeded: 1, finished: 1, state: 'running' });
    expect(progress.mock.calls.some(([snapshot]) => snapshot.succeeded === 1)).toBe(true);
    await vi.advanceTimersByTimeAsync(999); expect(two.run).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1); await done;
    expect(two.run).toHaveBeenCalledTimes(1); expect(loader.snapshot().state).toBe('complete');
  });

  it('pauses after the active request, resumes without duplicates, and never overlaps requests', async () => {
    let finish!: (rows: unknown[]) => void;
    const one = task('DH0101', vi.fn(() => new Promise<unknown[]>((resolve) => { finish = resolve; })));
    const two = task('DH0112'); const loader = new ThipStepLoader(2026, [one, two], vi.fn(), 1000, []);
    const done = loader.start(); await vi.advanceTimersByTimeAsync(0);
    loader.pause(); expect(loader.snapshot().state).toBe('pausing');
    expect(two.run).not.toHaveBeenCalled(); finish([aggregate()]); await done;
    expect(loader.snapshot().state).toBe('paused'); await vi.advanceTimersByTimeAsync(5000);
    expect(two.run).not.toHaveBeenCalled(); await loader.resume();
    expect(one.run).toHaveBeenCalledTimes(1); expect(two.run).toHaveBeenCalledTimes(1);
  });

  it('cancels the gap and keeps successes without dispatching more work', async () => {
    const one = task('DH0101'), two = task('DH0112');
    const loader = new ThipStepLoader(2026, [one, two], vi.fn(), 1000, []);
    const done = loader.start(); await vi.advanceTimersByTimeAsync(0); loader.cancel(); await done;
    await vi.advanceTimersByTimeAsync(5000); await loader.resume();
    expect(two.run).not.toHaveBeenCalled(); expect(loader.snapshot()).toMatchObject({ state: 'cancelled', succeeded: 1 });
    expect(vi.getTimerCount()).toBe(0);
  });

  it('aborts an active request and rejects late old-year results', async () => {
    let signal: AbortSignal | undefined; let finish!: (rows: unknown[]) => void;
    const active: StepTask = { code: 'DH0101', run: vi.fn((next: AbortSignal) => { signal = next; return new Promise<unknown[]>((resolve) => { finish = resolve; }); }) };
    const old = new ThipStepLoader(2026, [active], vi.fn(), 1000, []);
    const done = old.start(); await vi.advanceTimersByTimeAsync(0); old.cancel();
    expect(signal?.aborted).toBe(true); finish([aggregate()]); await done;
    expect(old.snapshot().steps[0].rows).toEqual([]);
    const next = new ThipStepLoader(2027, [], vi.fn(), 1000, []);
    expect(next.snapshot()).toMatchObject({ fiscalYear: 2027, succeeded: 0 });
  });

  it('isolates code failures, retains successes and retries only failed steps', async () => {
    const one = task('DH0101'); const two = task('DH0112', vi.fn().mockRejectedValueOnce(new BmsRequestError('api', 'http', 'route', 404)).mockResolvedValue([]));
    const loader = new ThipStepLoader(2026, [one, two], vi.fn(), 1000, []);
    const done = loader.start(); await vi.runAllTimersAsync(); await done;
    expect(loader.snapshot()).toMatchObject({ succeeded: 1, failed: 1, state: 'complete' });
    expect(loader.snapshot().steps[1].reason).toContain('ไม่สรุปว่าเกิน query budget');
    const retry = loader.retryFailed(); await vi.runAllTimersAsync(); await retry;
    expect(one.run).toHaveBeenCalledTimes(1); expect(two.run).toHaveBeenCalledTimes(2);
    expect(loader.snapshot()).toMatchObject({ succeeded: 2, failed: 0 });
  });

  it('pauses on session rejection and does not leak the server error', async () => {
    const one = task('DH0101', vi.fn().mockRejectedValue(new BmsRequestError('api', 'message', 'PRIVATE_SQL_TOKEN_CANARY', 501, { messageCode: 401 })));
    const two = task('DH0112'); const loader = new ThipStepLoader(2026, [one, two], vi.fn(), 1000, []);
    await loader.start(); await loader.resume(); await loader.retryFailed();
    expect(loader.snapshot()).toMatchObject({ state: 'paused', blockedBySession: true });
    expect(JSON.stringify(loader.snapshot())).not.toContain('PRIVATE_SQL_TOKEN_CANARY');
    expect(two.run).not.toHaveBeenCalled();
  });

  it('honors Retry-After and requires an explicit resume', async () => {
    const one = task('DH0101', vi.fn().mockRejectedValue(new BmsRequestError('api', 'http', 'rate', 429, { retryAfterMs: 5000 })));
    const two = task('DH0112'); const loader = new ThipStepLoader(2026, [one, two], vi.fn(), 1000, []);
    await loader.start(); await loader.resume(); expect(two.run).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(5000); expect(two.run).not.toHaveBeenCalled();
    await loader.resume(); expect(two.run).toHaveBeenCalledTimes(1);
  });

  it('pauses on three consecutive network/server failures, retaining prior results', async () => {
    const fail = (code: string) => task(code, vi.fn().mockRejectedValue(new BmsRequestError('api', 'network', 'offline')));
    const last = task('DH0102');
    const loader = new ThipStepLoader(2026, [task('DH0101'), fail('DH0112'), fail('CE0102'), fail('HH0102'), last], vi.fn(), 1000, []);
    const done = loader.start(); await vi.runAllTimersAsync(); await done;
    expect(loader.snapshot()).toMatchObject({ state: 'paused', failed: 3, succeeded: 1 }); expect(last.run).not.toHaveBeenCalled();
  });

  it('pauses during the gap, resumes quickly and still honors the original gap', async () => {
    const two = task('DH0112'); const loader = new ThipStepLoader(2026, [task('DH0101'), two], vi.fn(), 1000, []);
    const first = loader.start(); await vi.advanceTimersByTimeAsync(0); loader.pause();
    const resumed = loader.resume(); await vi.advanceTimersByTimeAsync(999); expect(two.run).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1); await first; await resumed; expect(two.run).toHaveBeenCalledTimes(1);
  });

  it('plans 177 single-code queries, starts DH0101/DH0112, and skips 55 external codes', async () => {
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(JSON.stringify({ result: [aggregate()] }), { status: 200 })); vi.stubGlobal('fetch', fetchMock);
    const loader = createThipStepLoader({ apiUrl: 'https://synthetic.invalid', bearerToken: 'TEST_ONLY', appIdentifier: 'THIP.KPI.BMS' }, 2026, vi.fn());
    expect(loader.snapshot().total).toBe(177); expect(loader.snapshot().steps.slice(0, 2).map((step) => step.code)).toEqual(['DH0101', 'DH0112']);
    expect(loader.snapshot().steps.filter((step) => step.status === 'skipped')).toHaveLength(55);
    const done = loader.start(); await vi.advanceTimersByTimeAsync(0); loader.cancel(); await done;
    const bodyText = fetchMock.mock.calls[0][1]?.body;
    if (typeof bodyText !== 'string') throw new Error('missing request body');
    const body = JSON.parse(bodyText);
    expect(body.params.start_date.value).toBe('2025-10-01'); expect(body.params.end_date.value).toBe('2026-10-01');
    expect(body.sql.match(/'([A-Z]{2}\d{4}(?:\.\d)?)' AS indicator_code/g)).toHaveLength(1);
  });
});

describe('candidate validation and transport', () => {
  it('retains source versus derived values without publishing or manufacturing freshness', () => {
    const [row] = validateCandidateRows([aggregate('DH0101', 1, 1, 130, 0)], 'DH0101', 2026);
    expect(row.derivedValue).toBeCloseTo(0.769230769); expect(row).toMatchObject({ sourceValue: 0, discrepancy: true, approval: 'unapproved', dataThrough: null, refreshedAt: null });
  });
  it('keeps 0/0 provenance unknown unless the registered query confirms a fact row', () => {
    expect(validateCandidateRows([aggregate('DH0101', 1, 0, 0, null)], 'DH0101', 2026)[0].measurement).toBe('unknown');
    expect(validateCandidateRows([{ ...aggregate('DH0101', 1, 0, 0, null), fact_present: true }], 'DH0101', 2026)[0].measurement).toBe('zero-cohort');
    expect(validateCandidateRows([{ ...aggregate(), fact_present: false }], 'DH0101', 2026)[0]).toMatchObject({ measurement: 'unknown', numerator: null, denominator: null, sourceValue: null });
  });
  it('rejects duplicates, wrong FY, wrong anchors, bad facts and non-null rates with zero denominator', () => {
    for (const input of [[aggregate(), aggregate()], [{ ...aggregate(), fiscal_year: 2569 }], [{ ...aggregate(), period_start: '2025-11-01' }], [{ ...aggregate(), numerator: 'bad' }], [{ ...aggregate(), denominator: 0 }]]) expect(() => validateCandidateRows(input, 'DH0101', 2026)).toThrow();
    expect(() => validateCandidateRows([aggregate('SH0101', 2)], 'SH0101', 2026)).toThrow();
  });
  it('keeps future monthly facts null at the Bangkok boundary', () => {
    const inputs = [{ ...aggregate(), fiscal_year: 2027, fiscal_month: 2, period_start: '2026-11-01' }];
    expect(validateCandidateRows(inputs, 'DH0101', 2027)[0]).toMatchObject({ measurement: 'future', sourceValue: null, numerator: null });
  });
  it('current runtime ratios use numeric multiplication before division; full-window cadence is unchanged', () => {
    expect(hosxpRegisteredBranches.join('\n')).not.toMatch(/\*\s*(100|1000|100000)\s*\//);
    const annual = planFoundationRequests({ fiscalYear: 2026, codes: ['SH0101'], chunkSize: 1 });
    expect(annual).toHaveLength(1); expect(annual[0]).toMatchObject({ start: '2025-10-01', end: '2026-10-01' });
    expect(annual[0].query.sql).toContain("('SH0101', 1)"); expect(annual[0].query.sql).not.toContain("('SH0101', 2)");
  });
  it('parses JSON auth errors before HTTP 501 and respects Retry-After', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ MessageCode: '401', Message: 'expired' }), { status: 501 })).mockResolvedValueOnce(new Response('{}', { status: 429, headers: { 'Retry-After': '7' } })));
    const runtime = { apiUrl: 'https://synthetic.invalid', bearerToken: 'TEST_ONLY', appIdentifier: 'THIP.KPI.BMS' };
    await expect(executeRegisteredQuery(queryRegistry.versionProbe, runtime)).rejects.toMatchObject({ status: 501, messageCode: 401 });
    await expect(executeRegisteredQuery(queryRegistry.versionProbe, runtime)).rejects.toMatchObject({ status: 429, retryAfterMs: 7000 });
    expect(parseRetryAfter(new Date(Date.now() + 9000).toUTCString())).toBe(9000);
  });
});
