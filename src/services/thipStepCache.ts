import type { BmsRuntimeConfig } from './bmsSession';
import { planThipSteps, validateCandidateRows, type CandidateAggregate } from './thipStepLoader';
import { thipKpiRulesByCode } from '@/data/thipKpiRules';
import { monitoringRulesByCode } from '@/monitoring/rules';
import { getCurrentFiscalYear } from '@/utils/fiscal';

export const STEP_CACHE_DB = 'thip-candidate-cache';
export const STEP_CACHE_VERSION = 1;
export const STEP_CACHE_TTL = 24 * 60 * 60 * 1000;
type Fact = { indicator_code: string; fiscal_year: number; fiscal_month: number; period_start: string; numerator: number | null; denominator: number | null; value: number | null; fact_present?: boolean };
export type CacheEntry = { key: string; scope: string; version: number; fiscalYear: number; code: string; fingerprint: string; ruleVersion: string; observedAt: string; expiresAt: number; facts: Fact[] };
export type CachedStep = { code: string; rows: CandidateAggregate[]; observedAt: string; expiresAt: number };
export interface StepCachePort {
  read(signal: AbortSignal): Promise<CachedStep[]>;
  write(code: string, rows: CandidateAggregate[], signal: AbortSignal): Promise<CachedStep | null>;
}
export interface CacheRepository {
  read(key: string): Promise<unknown>;
  write(entry: CacheEntry, signal: AbortSignal): Promise<void>;
  clear(scope?: string, fiscalYear?: number, namespace?: string): Promise<void>;
  prune(now: number): Promise<void>;
}
const clone = <T,>(value: T): T => structuredClone(value);
export class MemoryCacheRepository implements CacheRepository {
  private entries = new Map<string, CacheEntry>();
  async read(key: string) { return clone(this.entries.get(key)); }
  async write(entry: CacheEntry, signal: AbortSignal) { if (!signal.aborted) this.entries.set(entry.key, clone(entry)); }
  async clear(scope?: string, fiscalYear?: number, namespace?: string) { for (const [key, entry] of this.entries) if ((!scope || (entry.scope === scope && entry.fiscalYear === fiscalYear)) && (!namespace || key.includes(`:${namespace}:`))) this.entries.delete(key); }
  async prune(now: number) { for (const [key, entry] of this.entries) if (!Number.isFinite(entry.expiresAt) || entry.expiresAt <= now) this.entries.delete(key); }
}

/** Transactions are bounded; blocked/private-mode storage must not block the KPI queue. */
export class IndexedDbCacheRepository implements CacheRepository {
  private database: Promise<IDBDatabase> | null = null;
  private open(): Promise<IDBDatabase> {
    if (!this.database) this.database = new Promise((resolve, reject) => {
      const request = indexedDB.open(STEP_CACHE_DB, STEP_CACHE_VERSION);
      let abandoned = false;
      const timer = setTimeout(() => { abandoned = true; reject(new Error('Cache open timeout')); }, 3000);
      request.onupgradeneeded = () => { if (!request.result.objectStoreNames.contains('entries')) request.result.createObjectStore('entries', { keyPath: 'key' }); };
      request.onerror = () => { abandoned = true; clearTimeout(timer); reject(new Error('Cache unavailable')); };
      request.onblocked = () => { abandoned = true; clearTimeout(timer); reject(new Error('Cache blocked')); };
      request.onsuccess = () => { clearTimeout(timer); if (abandoned) { request.result.close(); return; } request.result.onversionchange = () => request.result.close(); resolve(request.result); };
    });
    return this.database;
  }
  private async transaction<T>(mode: IDBTransactionMode, action: (store: IDBObjectStore, set: (value: T) => void) => void, signal?: AbortSignal): Promise<T> {
    const db = await this.open();
    if (signal?.aborted) throw new DOMException('Cancelled', 'AbortError');
    return new Promise<T>((resolve, reject) => {
      const tx = db.transaction('entries', mode); let result: T;
      const abort = () => tx.abort();
      const timer = setTimeout(() => { try { tx.abort(); } catch { /* already completed */ } }, 3000);
      const clean = () => { clearTimeout(timer); signal?.removeEventListener('abort', abort); };
      signal?.addEventListener('abort', abort, { once: true });
      tx.oncomplete = () => { clean(); resolve(result); };
      tx.onabort = tx.onerror = () => { clean(); reject(new Error('Cache transaction unavailable')); };
      try { action(tx.objectStore('entries'), (value) => { result = value; }); }
      catch (error) { clean(); tx.abort(); reject(error); }
    });
  }
  read(key: string) { return this.transaction<unknown>('readonly', (store, set) => { store.get(key).onsuccess = (event) => set((event.target as IDBRequest).result); }); }
  write(entry: CacheEntry, signal: AbortSignal) { return this.transaction<void>('readwrite', (store) => { store.put(entry); }, signal); }
  clear(scope?: string, fiscalYear?: number, namespace?: string) {
    return this.transaction<void>('readwrite', (store) => {
      if (!scope && !namespace) { store.clear(); return; }
      store.openCursor().onsuccess = (event) => { const cursor = (event.target as IDBRequest<IDBCursorWithValue | null>).result; if (!cursor) return; if ((!scope || (cursor.value.scope === scope && cursor.value.fiscalYear === fiscalYear)) && (!namespace || cursor.key.toString().includes(`:${namespace}:`))) cursor.delete(); cursor.continue(); };
    });
  }
  prune(now: number) {
    return this.transaction<void>('readwrite', (store) => {
      store.openCursor().onsuccess = (event) => { const cursor = (event.target as IDBRequest<IDBCursorWithValue | null>).result; if (!cursor) return; if (!Number.isFinite(cursor.value.expiresAt) || cursor.value.expiresAt <= now) cursor.delete(); cursor.continue(); };
    });
  }
}

export class ResilientCacheRepository implements CacheRepository {
  private persistent = true;
  private readonly memory = new MemoryCacheRepository();
  constructor(private readonly disk: CacheRepository, private readonly onUnavailable: () => void) {}
  private async attempt<T>(work: () => Promise<T>): Promise<T | undefined> {
    if (!this.persistent) return;
    try { return await work(); } catch { if (this.persistent) { this.persistent = false; this.onUnavailable(); } }
  }
  async read(key: string) { return await this.attempt(() => this.disk.read(key)) ?? this.memory.read(key); }
  async write(entry: CacheEntry, signal: AbortSignal) {
    if (signal.aborted) return;
    // Cancellation is not a storage failure. Aborted disk transactions never fall back to a stale write.
    if (this.persistent) { try { await this.disk.write(entry, signal); } catch { if (!signal.aborted && this.persistent) { this.persistent = false; this.onUnavailable(); } } }
    if (!signal.aborted) await this.memory.write(entry, signal);
  }
  async clear(scope?: string, fiscalYear?: number, namespace?: string) {
    await this.memory.clear(scope, fiscalYear, namespace);
    try { await this.disk.clear(scope, fiscalYear, namespace); }
    catch { if (this.persistent) { this.persistent = false; this.onUnavailable(); } throw new Error('Persistent cache could not be cleared'); }
  }
  async prune(now: number) { await this.memory.prune(now); await this.attempt(() => this.disk.prune(now)); }
}

export function candidateCacheExpiry(fiscalYear: number, now: number): number {
  if (fiscalYear !== getCurrentFiscalYear(new Date(now))) return now + STEP_CACHE_TTL;
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Bangkok', year: 'numeric', month: 'numeric' }).formatToParts(now);
  const year = Number(parts.find((part) => part.type === 'year')?.value), month = Number(parts.find((part) => part.type === 'month')?.value);
  return Math.min(now + STEP_CACHE_TTL, Date.UTC(year, month, 1) - 7 * 3600 * 1000);
}
export async function cacheDigest(value: unknown): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(value)));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}
export function candidateCacheScope(runtime: BmsRuntimeConfig): Promise<string> {
  return cacheDigest([runtime.apiUrl.replace(/\/+$/, ''), runtime.hospitalCode ?? '', runtime.appIdentifier, runtime.bearerToken, runtime.marketplaceToken ?? '']);
}

export async function createStepCache(runtime: BmsRuntimeConfig, fiscalYear: number, repository: CacheRepository, signal: AbortSignal): Promise<StepCachePort & { clear(): Promise<void> }> {
  // Persist only an opaque digest of the verified capability, never runtime/session fields.
  const scope = await candidateCacheScope(runtime);
  const descriptors = await Promise.all(planThipSteps(fiscalYear).map(async (plan) => {
    const ruleVersion = thipKpiRulesByCode.get(plan.code)?.ruleVersion ?? 'candidate-unversioned';
    const fingerprint = await cacheDigest([plan.query.sql, plan.start, plan.end, thipKpiRulesByCode.get(plan.code), monitoringRulesByCode.get(plan.code)?.unit]);
    return { code: plan.code, fingerprint, ruleVersion, key: `${scope}:${fiscalYear}:thip-report:${plan.code}:${fingerprint}` };
  }));
  if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
  await repository.prune(Date.now());
  function restore(value: unknown, descriptor: typeof descriptors[number]): CachedStep | null {
    try {
      if (!value || typeof value !== 'object') return null;
      const entry = value as CacheEntry;
      const now = Date.now();
      if (entry.version !== STEP_CACHE_VERSION || entry.key !== descriptor.key || entry.scope !== scope || entry.code !== descriptor.code || entry.fiscalYear !== fiscalYear || entry.fingerprint !== descriptor.fingerprint || entry.ruleVersion !== descriptor.ruleVersion || !Number.isFinite(entry.expiresAt) || entry.expiresAt <= now || !Array.isArray(entry.facts)) return null;
      const observed = Date.parse(entry.observedAt);
      if (!Number.isFinite(observed) || observed > now || entry.expiresAt > candidateCacheExpiry(fiscalYear, observed)) return null;
      const rows = validateCandidateRows(entry.facts, entry.code, fiscalYear, new Date(now)).map((row) => ({ ...row, observedAt: entry.observedAt }));
      return { code: entry.code, rows, observedAt: entry.observedAt, expiresAt: entry.expiresAt };
    } catch { return null; }
  }
  return {
    async read(readSignal) {
      const entries = await Promise.all(descriptors.map(async (descriptor) => ({ descriptor, value: await repository.read(descriptor.key) })));
      if (signal.aborted || readSignal.aborted) return [];
      return entries.map(({ value, descriptor }) => restore(value, descriptor)).filter((entry): entry is CachedStep => entry !== null);
    },
    async write(code, rows, writeSignal) {
      const descriptor = descriptors.find((entry) => entry.code === code);
      if (!descriptor || signal.aborted || writeSignal.aborted) return null;
      const observedAt = rows[0]?.observedAt ?? new Date().toISOString();
      const facts: Fact[] = rows.map((row) => ({ indicator_code: code, fiscal_year: fiscalYear, fiscal_month: row.fiscalMonth, period_start: row.periodStart, numerator: row.numerator, denominator: row.denominator, value: row.sourceValue, ...(row.measurement === 'zero-cohort' ? { fact_present: true } : row.measurement === 'unknown' && row.numerator === null && row.denominator === null ? { fact_present: false } : {}) }));
      const entry: CacheEntry = { ...descriptor, scope, version: STEP_CACHE_VERSION, fiscalYear, observedAt, expiresAt: candidateCacheExpiry(fiscalYear, Date.parse(observedAt)), facts };
      const validated = restore(entry, descriptor);
      if (!validated) return null;
      const linked = new AbortController(); const abort = () => linked.abort();
      signal.addEventListener('abort', abort, { once: true }); writeSignal.addEventListener('abort', abort, { once: true });
      if (signal.aborted || writeSignal.aborted) linked.abort();
      try { await repository.write(entry, linked.signal); }
      finally { signal.removeEventListener('abort', abort); writeSignal.removeEventListener('abort', abort); }
      return signal.aborted || writeSignal.aborted ? null : validated;
    },
    clear: () => repository.clear(scope, fiscalYear, 'thip-report'),
  };
}
