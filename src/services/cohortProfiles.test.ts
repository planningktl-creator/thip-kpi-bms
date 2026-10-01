import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cohortProfiles, emptyProfile, loadCohortProfile, profileFailure, profileIsFuture, validateProfileRows, type CohortProfileKey } from './cohortProfiles';
import { MemoryCacheRepository, createStepCache, STEP_CACHE_TTL } from './thipStepCache';
import { BmsRequestError } from './bmsErrors';
import { assertRegisteredReadOnlyQuery } from './queryRegistry';
import { thipKpiRulesWithEvidence, getRuleReadiness } from '@/data/thipKpiRules';
const runtime = () => ({ apiUrl: 'https://cohort.invalid', hospitalCode: 'TEST', appIdentifier: 'TEST', bearerToken: 'SYNTHETIC_PROFILE_CREDENTIAL', marketplaceToken: 'SYNTHETIC_MARKETPLACE' });
const signal = () => new AbortController().signal;
const rows = (key: CohortProfileKey, count = 1) => cohortProfiles.find((p) => p.key === key)!.metrics.map((m) => ({ profile_key: key, metric_key: m.key, count_value: count }));
function mockFetch(value: unknown) { const fetch = vi.fn(async () => ({ ok: true, status: 200, text: async () => JSON.stringify({ result: value }) })); vi.stubGlobal('fetch', fetch); return fetch; }
beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date('2026-10-01T00:00:00Z')); });
afterEach(() => { vi.useRealTimers(); vi.restoreAllMocks(); vi.unstubAllGlobals(); });
describe('cohort profile contract', () => {
  it('keeps all 232 dictionary definitions outside publication readiness', () => {
    expect(thipKpiRulesWithEvidence).toHaveLength(232);
    for (const rule of thipKpiRulesWithEvidence) { expect(rule.cohortDefinition?.code).toBe(rule.code); expect(rule.cohortDefinition?.numeratorSql).toBeTruthy(); expect(rule.cohortDefinition?.denominatorSql).toBeTruthy(); expect(rule.cohortDefinition?.publicationApproval).toBe('unapproved'); expect(getRuleReadiness(rule).ready).toBe(false); }
  });
  it('registers six read-only queries with only three outer aggregate columns', () => {
    for (const profile of cohortProfiles) { assertRegisteredReadOnlyQuery(profile.query); const outer = profile.query.sql.slice(profile.query.sql.indexOf("SELECT '")); expect(outer.split('FROM stats')[0]).not.toMatch(/\b(hn|cid|vn|an|emp_cid|patient_hn|loginname)\b/i); }
  });
  it('requires all metrics and rejects identifiers, duplicates, other profiles and invalid counts', () => {
    expect(validateProfileRows(rows('patient'), 'patient').rows).toBe(1);
    for (const input of [[], rows('patient').slice(1), [...rows('patient'), rows('patient')[0]], rows('patient').map((r) => ({ ...r, hn: 'FORBIDDEN' })), rows('person'), rows('patient').map((r) => ({ ...r, count_value: null })), rows('patient').map((r) => ({ ...r, count_value: -1 })), rows('patient').map((r) => ({ ...r, count_value: .5 }))]) expect(() => validateProfileRows(input, 'patient')).toThrow();
  });
  it('distinguishes not loaded, future, empty episode cohort and unverified staff', async () => {
    expect(emptyProfile('patient', 2026, 1).metrics.rows).toBeNull(); expect(profileIsFuture(2027, 2)).toBe(true);
    const fetch = mockFetch(rows('visits', 0)); const repo = new MemoryCacheRepository();
    const future = await loadCohortProfile(runtime(), 'visits', 2027, 2, repo, signal()); expect(future.status).toBe('future'); expect(future.metrics.rows).toBeNull(); expect(fetch).not.toHaveBeenCalled();
    expect((await loadCohortProfile(runtime(), 'visits', 2026, 1, repo, signal())).status).toBe('zero-cohort');
    mockFetch(rows('employees', 0)); expect((await loadCohortProfile(runtime(), 'employees', 2026, 1, repo, signal())).status).toBe('unverified-source');
    mockFetch(rows('patient', 0)); expect((await loadCohortProfile(runtime(), 'patient', 2026, 1, repo, signal())).status).toBe('unverified-source');
  });
  it('hashes context and caches only sanitized aggregates in a separate namespace', async () => {
    const rt = runtime(), repo = new MemoryCacheRepository(); const write = vi.spyOn(repo, 'write'); const fetch = mockFetch(rows('patient'));
    expect((await loadCohortProfile(rt, 'patient', 2026, 1, repo, signal())).origin).toBe('query');
    expect((await loadCohortProfile(rt, 'patient', 2026, 1, repo, signal())).origin).toBe('cache'); expect(fetch).toHaveBeenCalledTimes(1);
    const entry = write.mock.calls[0][0]; expect(entry.key).toContain(':cohort-profile:'); expect(entry.facts).toEqual([]); expect(entry.expiresAt - Date.now()).toBe(STEP_CACHE_TTL);
    expect(JSON.stringify(entry)).not.toMatch(/SYNTHETIC_|cohort\.invalid|bearerToken|marketplaceToken|FORBIDDEN/);
    const kpiCache = await createStepCache(rt, 2026, repo, signal()); await kpiCache.clear(); expect((await loadCohortProfile(rt, 'patient', 2026, 1, repo, signal())).origin).toBe('cache');
    await repo.clear(); expect(await repo.read(entry.key)).toBeUndefined();
  });
  it('isolates month/year/session and rejects rule/query/schema drift and excessive expiry', async () => {
    const repo = new MemoryCacheRepository(), rt = runtime(); const write = vi.spyOn(repo, 'write'); const fetch = mockFetch(rows('patient'));
    await loadCohortProfile(rt, 'patient', 2026, 1, repo, signal()); const entry = write.mock.calls[0][0];
    for (const changed of [{ ...entry, ruleVersion: 'other' }, { ...entry, fingerprint: 'other' }, { ...entry, version: 999 }, { ...entry, expiresAt: entry.expiresAt + 1 }]) {
      await repo.write(changed, signal()); const result = loadCohortProfile(rt, 'patient', 2026, 1, repo, signal()); await vi.advanceTimersByTimeAsync(1000); expect((await result).origin).toBe('query');
    }
    const otherMonth = loadCohortProfile(rt, 'patient', 2026, 2, repo, signal()); await vi.advanceTimersByTimeAsync(1000); expect((await otherMonth).origin).toBe('query');
    expect((await loadCohortProfile({ ...rt, bearerToken: 'OTHER' }, 'patient', 2026, 1, repo, signal())).origin).toBe('query');
    const otherYear = loadCohortProfile(rt, 'patient', 2025, 1, repo, signal()); await vi.advanceTimersByTimeAsync(1000); expect((await otherYear).origin).toBe('query'); expect(fetch.mock.calls.length).toBe(8);
  });
  it('expires at 24h and does not cache a late response after cancellation', async () => {
    const repo = new MemoryCacheRepository(), rt = runtime(); mockFetch(rows('patient')); await loadCohortProfile(rt, 'patient', 2026, 1, repo, signal());
    await vi.advanceTimersByTimeAsync(STEP_CACHE_TTL); expect((await loadCohortProfile(rt, 'patient', 2026, 1, repo, signal())).origin).toBe('query');
    vi.useRealTimers();
    let finish!: (value: unknown) => void; vi.stubGlobal('fetch', vi.fn(() => new Promise((resolve) => { finish = resolve; })));
    const abort = new AbortController(), lateRepo = new MemoryCacheRepository(), write = vi.spyOn(lateRepo, 'write'); const result = loadCohortProfile(runtime(), 'patient', 2026, 1, lateRepo, abort.signal); const rejected = expect(result).rejects.toBeDefined();
    await vi.waitFor(() => expect(finish).toBeTypeOf('function'));
    abort.abort(); finish({ ok: true, status: 200, text: async () => JSON.stringify({ result: rows('patient') }) }); await rejected; expect(write).not.toHaveBeenCalled();
  });
  it('does not expose server errors or classify every 404 as a query budget', () => {
    const error = new BmsRequestError('api', 'http', 'SYNTHETIC_SECRET_ERROR', 404); expect(profileFailure(error).reason).toContain('route/config'); expect(profileFailure(error).reason).not.toContain('SECRET');
    expect(profileFailure(new BmsRequestError('api', 'http', 'secret', 401)).session).toBe(true); expect(profileFailure(new BmsRequestError('api', 'http', 'secret', 429, { retryAfterMs: 3000 })).retryAt).toBe(Date.now() + 3000);
  });
});
