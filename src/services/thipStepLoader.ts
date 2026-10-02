import { runtimeCatalogueByCode as thipCatalogueByCode } from '@/data/thipRuntime';
import { getExpectedFiscalMonths, getReportingCadence } from '@/data/thipReporting';
import { getFormulaScale, getRuleUnit } from '@/data/thipRuleLogic';
import { runtimeRulesByCode as thipKpiRulesByCode, runtimeSignatures } from '@/data/thipRuntime';
import { monitoringRulesByCode } from '@/monitoring/rules';
import type { MonitoringUnit } from '@/monitoring/types';
import { getFiscalMonthPeriods, getCurrentFiscalYear } from '@/utils/fiscal';
import { BmsRequestError } from './bmsErrors';
import type { BmsRuntimeConfig } from './bmsSession';
import { executeRegisteredQuery, hosxpRegisteredCodes, externalRegisteredCodes } from './queryRegistry';
import { planFoundationRequests } from './thipFoundationPlan';
import type { StepCachePort } from './thipStepCache';
import { aggregateQueryLane } from './aggregateQueryLane';

export type CandidateAggregate = {
  code: string; fiscalYear: number; fiscalMonth: number; periodStart: string;
  numerator: number | null; denominator: number | null; sourceValue: number | null;
  derivedValue: number | null; discrepancy: boolean; reason: string | null;
  measurement: 'measured' | 'zero-cohort' | 'unknown' | 'future';
  unit: MonitoringUnit; ruleVersion: string; observedAt: string;
  dataThrough: null; refreshedAt: null; approval: 'unapproved'; series: 'thip-report';
};
export type StepStatus = 'pending' | 'running' | 'success' | 'failed' | 'skipped';
export type StepResult = { code: string; status: StepStatus; rows: readonly CandidateAggregate[]; reason: string | null; latencyMs: number | null; attempts: number; origin?: 'cache' | 'query'; cachedAt?: string; expiresAt?: number };
export type StepSnapshot = Readonly<{
  fiscalYear: number; series: 'thip-report'; state: 'idle' | 'running' | 'pausing' | 'paused' | 'cancelled' | 'complete';
  steps: readonly Readonly<StepResult>[]; total: number; succeeded: number; failed: number; finished: number;
  activeCode: string | null; pauseReason: string | null; blockedBySession: boolean; retryAt: number;
  cacheHits: number; querySucceeded: number;
}>;
export type StepTask = { code: string; run: (signal: AbortSignal) => Promise<unknown[]>; queryLatencyMs?(): number | undefined };

function numeric(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  if ((typeof value !== 'number' && typeof value !== 'string') || String(value).trim() === '') throw new Error('invalid numeric fact');
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0) throw new Error('invalid numeric fact');
  return number;
}

function freezeAggregate<T>(value: T): T {
  if (value && typeof value === 'object' && !Object.isFrozen(value)) {
    for (const child of Object.values(value)) freezeAggregate(child);
    Object.freeze(value);
  }
  return value;
}

/** Validate seven-column aggregates without inventing approval, freshness or targets. */
export function validateCandidateRows(inputs: unknown[], code: string, fiscalYear: number, now = new Date()): CandidateAggregate[] {
  const rule = thipKpiRulesByCode.get(code);
  if (!rule || !thipCatalogueByCode.has(code)) throw new Error('unknown candidate code');
  const seen = new Set<number>();
  const periods = getFiscalMonthPeriods(fiscalYear);
  const expected = getExpectedFiscalMonths(code);
  const currentFy = getCurrentFiscalYear(now);
  const currentParts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Bangkok', month: 'numeric' }).formatToParts(now);
  const month = Number(currentParts.find((part) => part.type === 'month')?.value);
  const currentMonth = month >= 10 ? month - 9 : month + 3;
  return inputs.map((input) => {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw new Error('invalid candidate row');
    const row = input as Record<string, unknown>;
    const columns = ['indicator_code', 'fiscal_year', 'fiscal_month', 'period_start', 'numerator', 'denominator', 'value'];
    if (columns.some((column) => !(column in row)) || Object.keys(row).some((column) => !columns.includes(column) && column !== 'fact_present')) throw new Error('invalid candidate columns');
    const fiscalMonth = numeric(row.fiscal_month);
    if (row.indicator_code !== code || numeric(row.fiscal_year) !== fiscalYear || fiscalMonth === null || !expected.includes(fiscalMonth) || seen.has(fiscalMonth)) throw new Error('invalid or duplicate candidate period');
    seen.add(fiscalMonth);
    const period = periods[fiscalMonth - 1]!;
    if (typeof row.period_start !== 'string' || !/^\d{4}-\d{2}-\d{2}(?:[ T]00:00:00(?:\.000)?Z?)?$/.test(row.period_start) || row.period_start.slice(0, 10) !== period.periodStart) throw new Error('invalid candidate date');
    const numerator = numeric(row.numerator), denominator = numeric(row.denominator), sourceValue = numeric(row.value);
    if (sourceValue !== null && (denominator === null || denominator === 0 || numerator === null)) throw new Error('rate requires positive denominator and numerator');
    if (row.fact_present !== undefined && typeof row.fact_present !== 'boolean') throw new Error('invalid fact presence');
    const future = fiscalYear > currentFy || (fiscalYear === currentFy && fiscalMonth > currentMonth);
    const absent = row.fact_present === false;
    const derived = numerator !== null && denominator !== null && denominator > 0 ? numerator / denominator * getFormulaScale(rule.formulaScale) : null;
    const discrepancy = derived !== null && sourceValue !== null && Math.abs(derived - sourceValue) > 0.0051;
    return {
      code, fiscalYear, fiscalMonth, periodStart: period.periodStart,
      numerator: future || absent ? null : numerator, denominator: future || absent ? null : denominator,
      sourceValue: future || absent ? null : sourceValue, derivedValue: future || absent ? null : derived,
      discrepancy: !future && !absent && discrepancy,
      measurement: future ? 'future' : absent ? 'unknown' : denominator === 0 && row.fact_present === true ? 'zero-cohort' : sourceValue !== null ? 'measured' : 'unknown',
      reason: future ? 'เดือนอนาคตตาม Asia/Bangkok' : absent ? 'ไม่พบ fact row; ไม่ถือเป็น zero cohort' : discrepancy ? 'source value ต่างจากอัตราคำนวณ; ต้องสอบทาน arithmetic' : sourceValue === null ? row.fact_present === true && denominator === 0 ? 'query รายงาน denominator ศูนย์; อัตราเป็น NULL' : 'ไม่มีค่า; source/zero-cohort ยังยืนยันไม่ได้' : null,
      unit: monitoringRulesByCode.get(code)?.unit ?? getRuleUnit(rule), ruleVersion: rule.ruleVersion ?? 'candidate-unversioned', observedAt: now.toISOString(),
      dataThrough: null, refreshedAt: null, approval: 'unapproved', series: 'thip-report',
    };
  });
}

function failure(error: unknown): { reason: string; session: boolean; rateLimit: boolean; retryMs: number; global: boolean } {
  if (!(error instanceof BmsRequestError)) return { reason: 'รูปแบบ aggregate ไม่ถูกต้อง; ตรวจ code/งวด/ตัวเลขก่อนลองใหม่', session: false, rateLimit: false, retryMs: 0, global: false };
  const status = error.messageCode ?? error.status;
  const session = status === 401 || status === 403 || error.status === 401 || error.status === 403 || /session\s+(?:expired|unauthorized)/i.test(error.message);
  const rateLimit = status === 429 || error.status === 429;
  const reason = session ? 'session หมดอายุหรือไม่มีสิทธิ์; กรุณาเชื่อมต่อใหม่'
    : rateLimit ? 'BMS จำกัดคำขอ; พักคิวตาม Retry-After'
    : error.failure === 'timeout' ? 'query timeout; คง observation window เต็ม ไม่แบ่งวันที่'
    : error.failure === 'network' ? 'เครือข่าย/API ไม่พร้อม; ลองใหม่เมื่อพร้อม'
    : error.status === 404 ? 'HTTP 404; ตรวจ endpoint/config ไม่สรุปว่าเกิน query budget'
    : `อ่าน aggregate ไม่สำเร็จ${status ? ` (รหัส ${status})` : ''}; ตรวจ source และ query ที่ลงทะเบียน`;
  return { reason, session, rateLimit, retryMs: error.retryAfterMs ?? (rateLimit ? 1000 : 0), global: error.failure === 'network' || (error.failure === 'http' && (error.status ?? 0) >= 500) };
}

/** One request at a time. Only immutable aggregate snapshots escape this controller. */
export class ThipStepLoader {
  private steps: StepResult[];
  private state: StepSnapshot['state'] = 'idle';
  private controller = new AbortController();
  private gapController: AbortController | null = null;
  private pump: Promise<void> | null = null;
  private paused = false;
  private activeCode: string | null = null;
  private pauseReason: string | null = null;
  private blockedBySession = false;
  private retryAt = 0;
  private nextAt = 0;
  private consecutiveFailures = 0;
  private hydrated = false;

  constructor(private readonly fiscalYear: number, private readonly tasks: StepTask[], private readonly onProgress: (snapshot: StepSnapshot) => void, private readonly gapMs = 1000, skipped = externalRegisteredCodes, private readonly cache?: StepCachePort, private readonly validator = validateCandidateRows) {
    if (!Number.isInteger(fiscalYear) || fiscalYear < 2000 || fiscalYear > 2100 || new Set(tasks.map((task) => task.code)).size !== tasks.length) throw new Error('Invalid step plan');
    this.steps = [...tasks.map((task): StepResult => ({ code: task.code, status: 'pending', rows: [], reason: null, latencyMs: null, attempts: 0 })), ...skipped.map((code): StepResult => ({ code, status: 'skipped', rows: [], reason: 'รอ external aggregate source; ไม่เติมศูนย์', latencyMs: null, attempts: 0 }))];
  }

  private views = new WeakMap<StepResult, { stamp: string; rows: readonly CandidateAggregate[]; view: Readonly<StepResult> }>();
  private presentation(step: StepResult): Readonly<StepResult> {
    const stamp = JSON.stringify([step.status, step.reason, step.latencyMs, step.attempts, step.origin, step.cachedAt, step.expiresAt]);
    const cached = this.views.get(step);
    if (cached?.stamp === stamp && cached.rows === step.rows) return cached.view;
    const view = Object.freeze({ ...step, rows: Object.freeze(step.rows.map(row => freezeAggregate({ ...row }))) });
    this.views.set(step, { stamp, rows: step.rows, view });
    return view;
  }
  snapshot(): StepSnapshot {
    const succeeded = this.steps.filter((step) => step.status === 'success').length, failed = this.steps.filter((step) => step.status === 'failed').length;
    return Object.freeze({ fiscalYear: this.fiscalYear, series: 'thip-report', state: this.state, steps: Object.freeze(this.steps.map(step => this.presentation(step))), total: this.tasks.length, succeeded, failed, finished: succeeded + failed, activeCode: this.activeCode, pauseReason: this.pauseReason, blockedBySession: this.blockedBySession, retryAt: this.retryAt, cacheHits: this.steps.filter((step) => step.origin === 'cache').length, querySucceeded: this.steps.filter((step) => step.status === 'success' && step.origin === 'query').length });
  }
  private emit() { this.onProgress(this.snapshot()); }
  start(): Promise<void> { return this.resume(); }
  pause(): void {
    if (this.state !== 'running') return;
    this.paused = true;
    this.pauseReason = 'พักโดยผู้ใช้';
    this.state = this.activeCode ? 'pausing' : 'paused';
    this.gapController?.abort();
    this.emit();
  }
  holdSource(error: BmsRequestError): void {
    const info = failure(error);
    this.paused = true; this.pauseReason = info.reason; this.blockedBySession = info.session;
    this.retryAt = info.rateLimit ? Date.now() + info.retryMs : 0;
    this.state = this.activeCode ? 'pausing' : 'paused'; this.gapController?.abort(); this.emit();
  }
  cancel(): void {
    this.state = 'cancelled'; this.controller.abort(); this.gapController?.abort();
    if (this.activeCode) { const step = this.steps.find((item) => item.code === this.activeCode)!; if (step.status === 'running') { step.status = 'pending'; step.reason = 'ยกเลิกคำขอ'; } }
    this.activeCode = null; this.emit();
  }
  resume(): Promise<void> {
    if (this.controller.signal.aborted || this.blockedBySession || Date.now() < this.retryAt) return Promise.resolve();
    if (this.state === 'paused') this.consecutiveFailures = 0;
    this.paused = false; this.pauseReason = null;
    if (this.pump) {
      this.state = 'running'; this.emit();
      // If pause ended a pump just before resume, start the remaining work after it settles.
      return this.pump.then(() => this.state === 'complete' || this.state === 'cancelled' || this.paused ? undefined : this.resume());
    }
    this.state = 'running'; this.emit();
    const run = this.drain();
    this.pump = run.finally(() => { this.pump = null; });
    return this.pump;
  }
  retryFailed(code?: string): Promise<void> {
    if (this.state === 'running' || this.state === 'pausing' || this.controller.signal.aborted || this.blockedBySession || Date.now() < this.retryAt) return Promise.resolve();
    for (const step of this.steps) if (step.status === 'failed' && (!code || code === step.code)) step.status = 'pending';
    this.consecutiveFailures = 0;
    return this.resume();
  }
  private async waitGap(): Promise<void> {
    const remaining = this.nextAt - Date.now();
    if (remaining <= 0) return;
    const controller = new AbortController(); this.gapController = controller;
    await new Promise<void>((resolve) => {
      const done = () => { clearTimeout(timer); controller.signal.removeEventListener('abort', done); resolve(); };
      const timer = setTimeout(done, remaining);
      controller.signal.addEventListener('abort', done, { once: true });
    });
    this.gapController = null;
  }
  private async drain(): Promise<void> {
    if (!this.hydrated) {
      this.hydrated = true;
      const cached = await this.cache?.read(this.controller.signal).catch(() => []) ?? [];
      if (this.controller.signal.aborted) return;
      for (const entry of cached) {
        const step = this.steps.find((item) => item.code === entry.code && item.status === 'pending');
        if (!step || entry.expiresAt <= Date.now()) continue;
        Object.assign(step, { status: 'success', rows: entry.rows, origin: 'cache', cachedAt: entry.observedAt, expiresAt: entry.expiresAt, reason: entry.rows.length ? null : 'query สำเร็จแต่ไม่พบแถว; ไม่เติมศูนย์' });
      }
      this.emit();
    }
    while (!this.controller.signal.aborted) {
      if (this.paused) { this.state = 'paused'; this.emit(); return; }
      const step = this.steps.find((item) => item.status === 'pending');
      if (!step) { this.state = 'complete'; this.emit(); return; }
      await this.waitGap();
      if (this.paused || this.controller.signal.aborted) continue;
      if (Date.now() < this.nextAt) continue;
      const started = Date.now();
      const task = this.tasks.find((item) => item.code === step.code)!;
      this.activeCode = step.code; step.status = 'running'; step.reason = null; step.attempts++; this.emit();
      try {
        const inputs = await task.run(this.controller.signal);
        if (this.controller.signal.aborted) return;
        step.rows = this.validator(inputs, step.code, this.fiscalYear);
        step.origin = 'query';
        step.status = 'success'; step.reason = step.rows.length ? null : 'query สำเร็จแต่ไม่พบแถว; ไม่เติมศูนย์';
        this.consecutiveFailures = 0;
        step.latencyMs = task.queryLatencyMs?.() ?? Date.now() - started;
        this.emit();
        const saved = await this.cache?.write(step.code, step.rows, this.controller.signal).catch(() => null);
        if (this.controller.signal.aborted) return;
        if (saved) { step.cachedAt = saved.observedAt; step.expiresAt = saved.expiresAt; }
      } catch (error) {
        if (this.controller.signal.aborted) return;
        const info = failure(error);
        step.status = 'failed'; step.reason = info.reason;
        this.consecutiveFailures = info.global ? this.consecutiveFailures + 1 : 0;
        if (info.session || info.rateLimit || this.consecutiveFailures >= 3) {
          this.paused = true; this.pauseReason = info.reason;
          this.blockedBySession = info.session;
          this.retryAt = info.rateLimit ? Date.now() + info.retryMs : 0;
        }
      }
      if (step.status !== 'success') step.latencyMs = task.queryLatencyMs?.() ?? Date.now() - started;
      this.activeCode = null;
      this.nextAt = Date.now() + this.gapMs;
      if (this.paused) this.state = 'paused';
      this.emit();
    }
  }
}

export function planThipSteps(fiscalYear: number) {
  const ordered = ['DH0101', 'DH0112', ...hosxpRegisteredCodes.filter((code) => !['DH0101', 'DH0112'].includes(code)).sort()];
  return ordered.map((code) => {
    const request = planFoundationRequests({ fiscalYear, chunkSize: 1, codes: [code] })[0]!;
    const key = `thipReportCandidate_${code.replace(/\./g, '_')}`;
    return { ...request, code, key, query: { ...request.query, key } };
  });
}

export function createThipStepLoader(runtime: BmsRuntimeConfig, fiscalYear: number, onProgress: (snapshot: StepSnapshot) => void, cache?: StepCachePort): ThipStepLoader {
  const tasks = runtimeSignatures.map(({ code }): StepTask => {
    let queryMs: number | undefined;
    return { code, queryLatencyMs: () => queryMs, run: async (signal) => {
      queryMs = undefined;
      const payload = await aggregateQueryLane(runtime).run(signal, async () => {
        const request = planFoundationRequests({ fiscalYear, chunkSize: 1, codes: [code] })[0]!;
        const query = { ...request.query, key: `thipReportCandidate_${code.replace(/\./g, '_')}` };
        const started = Date.now();
        try { return await executeRegisteredQuery(query, runtime, { start_date: { value: request.start, value_type: 'date' }, end_date: { value: request.end, value_type: 'date' } }, runtime.marketplaceToken, { signal }); }
        finally { queryMs = Date.now() - started; }
      });
      const rows = payload.data ?? payload.result;
      if (!Array.isArray(rows)) throw new BmsRequestError('data', 'response', 'Missing aggregate array');
      return rows;
    } };
  });
  return new ThipStepLoader(fiscalYear, tasks, onProgress, 1000, externalRegisteredCodes, cache);
}

export { getReportingCadence };
