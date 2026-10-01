import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';
import { MemoryCacheRepository, ResilientCacheRepository, createStepCache, candidateCacheExpiry, STEP_CACHE_TTL, type CacheEntry, type StepCachePort } from './thipStepCache';
import { ThipStepLoader, validateCandidateRows } from './thipStepLoader';

const runtime = { apiUrl: 'https://synthetic.invalid', hospitalCode: 'TEST_HOSPITAL', appIdentifier: 'TEST_APP', bearerToken: 'SYNTHETIC_CACHE_CREDENTIAL', marketplaceToken: 'SYNTHETIC_MARKETPLACE' };
const raw = { indicator_code: 'DH0101', fiscal_year: 2026, fiscal_month: 1, period_start: '2025-10-01', numerator: 1, denominator: 130, value: 0, fact_present: true };
const rows = () => validateCandidateRows([raw], 'DH0101', 2026);
const signal = () => new AbortController().signal;
beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date('2026-10-01T00:00:00Z')); });
afterEach(() => { vi.useRealTimers(); vi.restoreAllMocks(); });

describe('candidate cache contract', () => {
  it('stores a validated projection, hashes capabilities and restores arithmetic with no approval', async () => {
    const repo = new MemoryCacheRepository(); const write = vi.spyOn(repo, 'write');
    const cache = await createStepCache(runtime, 2026, repo, signal());
    await cache.write('DH0101', rows(), signal());
    const entry = write.mock.calls[0][0];
    expect(entry.expiresAt - Date.now()).toBe(STEP_CACHE_TTL);
    expect(JSON.stringify(entry)).not.toMatch(/SYNTHETIC_CACHE_CREDENTIAL|SYNTHETIC_MARKETPLACE|synthetic\.invalid|bearerToken|marketplaceToken/);
    expect(Object.keys(entry.facts[0]).sort()).toEqual(['denominator', 'fiscal_month', 'fiscal_year', 'indicator_code', 'numerator', 'period_start', 'value']);
    const restored = await cache.read(signal());
    expect(restored[0].rows[0]).toMatchObject({ sourceValue: 0, discrepancy: true, approval: 'unapproved', refreshedAt: null, dataThrough: null });
    expect(restored[0].rows[0].derivedValue).toBeCloseTo(100 / 130);
    expect(restored[0].rows[0].observedAt).toBe(rows()[0].observedAt);
  });
  it('isolates endpoint/hospital/session/marketplace/app/year and allows the original context back', async () => {
    const repo = new MemoryCacheRepository(); const cache = await createStepCache(runtime, 2026, repo, signal()); await cache.write('DH0101', rows(), signal());
    for (const other of [{ ...runtime, apiUrl: 'https://other.invalid' }, { ...runtime, hospitalCode: 'OTHER' }, { ...runtime, bearerToken: 'OTHER' }, { ...runtime, marketplaceToken: 'OTHER' }, { ...runtime, appIdentifier: 'OTHER' }]) expect(await (await createStepCache(other, 2026, repo, signal())).read(signal())).toEqual([]);
    expect(await (await createStepCache(runtime, 2027, repo, signal())).read(signal())).toEqual([]);
    expect(await (await createStepCache(runtime, 2026, repo, signal())).read(signal())).toHaveLength(1);
  });
  it('expires exactly at 24 hours and prunes on reopen', async () => {
    const repo = new MemoryCacheRepository(); const cache = await createStepCache(runtime, 2026, repo, signal()); await cache.write('DH0101', rows(), signal());
    await vi.advanceTimersByTimeAsync(STEP_CACHE_TTL - 1); expect(await cache.read(signal())).toHaveLength(1);
    await vi.advanceTimersByTimeAsync(1); expect(await cache.read(signal())).toEqual([]);
    const prune = vi.spyOn(repo, 'prune'); await createStepCache(runtime, 2026, repo, signal()); expect(prune).toHaveBeenCalledWith(Date.now());
  });
  it('caps current-year expiry at Bangkok month/year boundaries', () => {
    const sept = Date.parse('2026-09-30T16:30:00Z');
    expect(candidateCacheExpiry(2026, sept)).toBe(Date.parse('2026-09-30T17:00:00Z'));
    const dec = Date.parse('2026-12-31T16:30:00Z');
    expect(candidateCacheExpiry(2027, dec)).toBe(Date.parse('2026-12-31T17:00:00Z'));
    expect(candidateCacheExpiry(2025, sept)).toBe(sept + STEP_CACHE_TTL);
  });
  it('rejects corrupt facts, rule/query/schema drift and excessive expiry', async () => {
    const repo = new MemoryCacheRepository(); const write = vi.spyOn(repo, 'write'); const cache = await createStepCache(runtime, 2026, repo, signal()); await cache.write('DH0101', rows(), signal());
    const entry = write.mock.calls[0][0];
    for (const bad of [{ ...entry, ruleVersion: 'changed' }, { ...entry, fingerprint: 'changed' }, { ...entry, version: 999 }, { ...entry, expiresAt: entry.expiresAt + 1 }, { ...entry, observedAt: 'bad' }, { ...entry, facts: [{ ...raw, hn: 'FORBIDDEN' }] }, { ...entry, facts: [raw, raw] }, { ...entry, facts: [{ ...raw, denominator: 0 }] }]) {
      await repo.write(bad as CacheEntry, signal()); expect(await cache.read(signal())).toEqual([]);
    }
  });
  it('preserves zero-cohort/unknown/future instead of manufacturing zeros', async () => {
    const repo = new MemoryCacheRepository(); const cache = await createStepCache(runtime, 2026, repo, signal());
    for (const fact of [{ ...raw, numerator: 0, denominator: 0, value: null, fact_present: true }, { ...raw, numerator: 0, denominator: 0, value: null, fact_present: undefined }, { ...raw, fact_present: false }]) {
      const valid = validateCandidateRows([fact], 'DH0101', 2026); await cache.write('DH0101', valid, signal());
      expect((await cache.read(signal()))[0].rows[0]).toEqual(valid[0]);
    }
    const futureCache = await createStepCache(runtime, 2027, repo, signal());
    const future = validateCandidateRows([{ ...raw, fiscal_year: 2027, fiscal_month: 2, period_start: '2026-11-01' }], 'DH0101', 2027);
    await futureCache.write('DH0101', future, signal()); expect((await futureCache.read(signal()))[0].rows[0]).toMatchObject({ measurement: 'future', sourceValue: null });
  });
  it('clears only the selected context/year, and clear-all removes every aggregate', async () => {
    const repo = new MemoryCacheRepository(); const one = await createStepCache(runtime, 2026, repo, signal()); const two = await createStepCache({ ...runtime, hospitalCode: 'OTHER' }, 2026, repo, signal());
    await one.write('DH0101', rows(), signal()); await two.write('DH0101', rows(), signal());
    await one.clear(); expect(await one.read(signal())).toEqual([]); expect(await two.read(signal())).toHaveLength(1);
    await repo.clear(); expect(await two.read(signal())).toEqual([]);
  });
  it('does not persist after context cancellation or accept late reads', async () => {
    const repo = new MemoryCacheRepository(); const context = new AbortController(); const cache = await createStepCache(runtime, 2026, repo, context.signal);
    context.abort(); await cache.write('DH0101', rows(), signal()); expect(await cache.read(signal())).toEqual([]);
    await expect(createStepCache(runtime, 2026, repo, context.signal)).rejects.toMatchObject({ name: 'AbortError' });
  });
  it('context cancellation also aborts a transaction already writing', async () => {
    const repo = new MemoryCacheRepository(); const original = repo.write.bind(repo); let finish!: () => void; let transactionSignal!: AbortSignal;
    vi.spyOn(repo, 'write').mockImplementation((entry, next) => { transactionSignal = next; return new Promise<void>((resolve) => { finish = () => { void original(entry, next).then(resolve); }; }); });
    const context = new AbortController(); const cache = await createStepCache(runtime, 2026, repo, context.signal);
    const writing = cache.write('DH0101', rows(), signal()); context.abort();
    expect(transactionSignal.aborted).toBe(true); finish(); expect(await writing).toBeNull();
    expect(await (await createStepCache(runtime, 2026, repo, signal())).read(signal())).toEqual([]);
  });
  it('uses memory when opening/writing storage fails and still attempts disk clear', async () => {
    const disk = new MemoryCacheRepository(); vi.spyOn(disk, 'read').mockRejectedValue(new Error('private mode')); const clear = vi.spyOn(disk, 'clear'); const warning = vi.fn();
    const repo = new ResilientCacheRepository(disk, warning); const cache = await createStepCache(runtime, 2026, repo, signal()); await cache.read(signal());
    await cache.write('DH0101', rows(), signal()); expect(await cache.read(signal())).toHaveLength(1); expect(warning).toHaveBeenCalledTimes(1);
    await repo.clear(); expect(clear).toHaveBeenCalled(); expect(await cache.read(signal())).toEqual([]);
    const quotaDisk = new MemoryCacheRepository(); vi.spyOn(quotaDisk, 'write').mockRejectedValue(new Error('quota exceeded'));
    const fallback = await createStepCache(runtime, 2026, new ResilientCacheRepository(quotaDisk, warning), signal()); await fallback.write('DH0101', rows(), signal()); expect(await fallback.read(signal())).toHaveLength(1);
  });
  it('reports a failed disk clear while removing the memory fallback', async () => {
    const disk = new MemoryCacheRepository(); vi.spyOn(disk, 'write').mockRejectedValue(new Error('quota')); vi.spyOn(disk, 'clear').mockRejectedValue(new Error('blocked'));
    const repo = new ResilientCacheRepository(disk, vi.fn()); const cache = await createStepCache(runtime, 2026, repo, signal());
    await cache.write('DH0101', rows(), signal()); expect(await cache.read(signal())).toHaveLength(1);
    await expect(repo.clear()).rejects.toThrow('could not be cleared'); expect(await cache.read(signal())).toEqual([]);
  });
});

describe('cached queue', () => {
  it('shows cache first, skips its request, and counts only fresh queries as query successes', async () => {
    const one = vi.fn(async () => [raw]); const two = vi.fn(async () => []);
    const cache: StepCachePort = { read: vi.fn(async () => [{ code: 'DH0101', rows: rows(), observedAt: rows()[0].observedAt, expiresAt: Date.now() + 10000 }]), write: vi.fn(async () => null) };
    const progress = vi.fn(); const loader = new ThipStepLoader(2026, [{ code: 'DH0101', run: one }, { code: 'DH0112', run: two }], progress, 1000, [], cache);
    await loader.start(); expect(one).not.toHaveBeenCalled(); expect(two).toHaveBeenCalledTimes(1);
    expect(loader.snapshot()).toMatchObject({ succeeded: 2, cacheHits: 1, querySucceeded: 1 });
    expect(progress.mock.calls.some(([snapshot]) => snapshot.cacheHits === 1 && snapshot.querySucceeded === 0)).toBe(true);
    expect(cache.write).toHaveBeenCalledTimes(1);
  });
  it('ignores an expired seed and never writes failed queries', async () => {
    const cache: StepCachePort = { read: vi.fn(async () => [{ code: 'DH0101', rows: rows(), observedAt: rows()[0].observedAt, expiresAt: Date.now() }]), write: vi.fn(async () => null) };
    const run = vi.fn().mockRejectedValue(new Error('bad response')); const loader = new ThipStepLoader(2026, [{ code: 'DH0101', run }], vi.fn(), 1000, [], cache);
    await loader.start(); expect(run).toHaveBeenCalledTimes(1); expect(cache.write).not.toHaveBeenCalled(); expect(loader.snapshot()).toMatchObject({ cacheHits: 0, failed: 1 });
  });
  it('cancels an outstanding write while preserving successful results', async () => {
    let finish!: () => void; let writeSignal!: AbortSignal;
    const cache: StepCachePort = { read: async () => [], write: (_code, _rows, next) => { writeSignal = next; return new Promise((resolve) => { finish = () => resolve(null); }); } };
    const loader = new ThipStepLoader(2026, [{ code: 'DH0101', run: async () => [raw] }], vi.fn(), 1000, [], cache);
    const done = loader.start(); await vi.advanceTimersByTimeAsync(0); loader.cancel(); finish(); await done;
    expect(writeSignal.aborted).toBe(true); expect(loader.snapshot()).toMatchObject({ state: 'cancelled', succeeded: 1 });
  });
  it('cache errors do not convert successful queries to failures', async () => {
    const cache: StepCachePort = { read: async () => { throw new Error('storage'); }, write: async () => { throw new Error('quota'); } };
    const loader = new ThipStepLoader(2026, [{ code: 'DH0101', run: async () => [raw] }], vi.fn(), 1000, [], cache);
    await loader.start(); expect(loader.snapshot()).toMatchObject({ succeeded: 1, failed: 0, state: 'complete' });
  });
});
