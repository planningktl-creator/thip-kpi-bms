import {
  runtimeCatalogue,
  runtimeMonitoringRules,
  runtimeMonitoringBridges,
  runtimeSignatures,
  runtimeRulesByCode,
  runtimeReportingDefinitions,
} from '@/data/thipRuntime';
import {
  getExpectedFiscalMonths,
  getReportingCadence,
} from '@/data/thipReporting';
import { getFiscalMonthPeriods, bangkokDate } from '@/utils/fiscal';
import type { BmsRuntimeConfig } from './bmsSession';
import type { CacheRepository } from './thipStepCache';
import type { StepSnapshot, StepResult } from './thipStepLoader';
import type {
  KpiCellViewModel,
  KpiDataSnapshot,
  KpiGridRow,
  KpiMode,
  KpiQueuePort,
  KpiSeries,
  SharedKpiFact,
} from './kpiTypes';
import type { Indicator } from '@/types/thip';
import type { BmsRequestError } from './bmsErrors';
import { assessMonitoring } from '@/monitoring/calculation';
import { withKpiCumulative } from './kpiCumulative';

const emptyCumulative = Object.freeze({
  numerator: null,
  denominator: null,
  value: null,
  through: null,
  complete: false,
});
const rules = new Map(runtimeMonitoringRules.map((rule) => [rule.code, rule]));
const bridges = new Map(
  runtimeMonitoringBridges.map((rule) => [rule.code, rule])
);
type Factory = (
  runtime: BmsRuntimeConfig,
  year: number,
  repository: CacheRepository,
  signal: AbortSignal,
  update: (snapshot: StepSnapshot) => void
) => Promise<KpiQueuePort>;

/** One owner per app/tab. Routing never controls this object's lifecycle. */
export class KpiDataStore {
  private value: KpiDataSnapshot;
  private listeners = new Set<() => void>();
  private abort: AbortController | null = null;
  private queue: KpiQueuePort | null = null;
  private runtime: BmsRuntimeConfig | null = null;
  private generation = 0;
  private timer: ReturnType<typeof setTimeout> | null = null;
  private rowCache = new Map<
    string,
    {
      stamp: string;
      step?: Readonly<StepResult>;
      report?: Readonly<StepResult>;
      row: KpiGridRow;
    }
  >();
  private grids = new Map<string, readonly KpiGridRow[]>();
  private official = new WeakMap<object, Indicator | null>();
  private officialProjection:
    | typeof import('./kpiQueue').approvedReportingIndicator
    | null = null;
  repository: CacheRepository | null;
  clearEpoch = 0;

  constructor(
    year: number,
    repository: CacheRepository | null = null,
    private readonly factory?: Factory
  ) {
    this.repository = repository;
    this.value = {
      fiscalYear: year,
      owner: null,
      progress: null,
      cacheUnavailable: false,
      preparing: false,
      error: null,
      stopped: false,
      clearIncomplete: false,
      blockedBySession: false,
      retryAt: 0,
    };
  }
  snapshot = () => this.value;
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  private publish(patch: Partial<KpiDataSnapshot>) {
    this.value = Object.freeze({ ...this.value, ...patch });
    this.grids.clear();
    this.listeners.forEach((listener) => listener());
  }
  configure(runtime: BmsRuntimeConfig | null, year: number) {
    if (runtime === this.runtime && year === this.value.fiscalYear) { this.scheduleExpiry(); return; }
    const newSession = runtime !== this.runtime;
    this.abort?.abort();
    this.queue = null;
    this.generation++;
    this.runtime = runtime;
    if (this.timer) clearTimeout(this.timer);
    this.rowCache.clear();
    this.official = new WeakMap();
    this.clearEpoch++;
    this.publish({
      fiscalYear: year,
      owner: runtime,
      progress: null,
      error: null,
      preparing:
        Boolean(runtime) &&
        (newSession ||
          (!this.value.blockedBySession && this.value.retryAt <= Date.now())),
      stopped: false,
      clearIncomplete: false,
      blockedBySession: newSession ? false : this.value.blockedBySession,
      retryAt: newSession ? 0 : this.value.retryAt,
    });
    this.scheduleExpiry();
    if (runtime) void this.start();
  }
  start = async () => {
    const runtime = this.runtime;
    if (this.value.blockedBySession || this.value.retryAt > Date.now()) return;
    if (
      this.queue &&
      this.value.progress?.steps.some(
        (step) => step.expiresAt !== undefined && step.expiresAt <= Date.now()
      )
    ) {
      this.abort?.abort();
      this.queue = null;
    }
    if (!runtime || this.queue) return;
    const generation = ++this.generation;
    const abort = new AbortController();
    this.abort?.abort();
    this.abort = abort;
    this.publish({ preparing: true, stopped: false, error: null });
    try {
      if (!this.repository) {
        const { ResilientCacheRepository, IndexedDbCacheRepository } =
          await import('./thipStepCache');
        this.repository = new ResilientCacheRepository(
          new IndexedDbCacheRepository(),
          () => this.publish({ cacheUnavailable: true })
        );
      }
      const module = this.factory ? null : await import('./kpiQueue');
      if (abort.signal.aborted || generation !== this.generation) return;
      if (module) this.officialProjection = module.approvedReportingIndicator;
      const lane = await import('./aggregateQueryLane');
      lane.aggregateQueryLane(runtime).allow();
      const queue = await (this.factory ?? module!.createKpiQueue)(
        runtime,
        this.value.fiscalYear,
        this.repository,
        abort.signal,
        (snapshot) => {
          if (abort.signal.aborted || generation !== this.generation) return;
          this.publish({
            progress: snapshot,
            preparing: false,
            blockedBySession: snapshot.blockedBySession,
            retryAt: snapshot.retryAt,
          });
          this.scheduleExpiry();
        }
      );
      if (abort.signal.aborted || generation !== this.generation) {
        queue.cancel();
        return;
      }
      this.queue = queue;
      await queue.start();
    } catch {
      if (!abort.signal.aborted && generation === this.generation)
        this.publish({
          preparing: false,
          error: 'เตรียมคิวไม่สำเร็จ กดเริ่มโหลดเพื่อลองอีกครั้ง',
        });
    }
  };
  pause = () => this.queue?.pause();
  resume = async () => {
    const lane = await import('./aggregateQueryLane');
    if (this.runtime) lane.aggregateQueryLane(this.runtime).allow();
    await this.queue?.resume();
  };
  cancel = () => {
    this.queue?.cancel();
    this.abort?.abort();
    this.queue = null;
    this.publish({ preparing: false, stopped: true });
  };
  retryFailed = async (code?: string) => {
    const lane = await import('./aggregateQueryLane');
    if (this.runtime) lane.aggregateQueryLane(this.runtime).allow();
    await this.queue?.retryFailed(code);
  };
  holdSource = (error: BmsRequestError) => {
    const status = error.messageCode ?? error.status;
    if (status === 401 || status === 403 || status === 429)
      this.publish({
        blockedBySession: status === 401 || status === 403,
        retryAt:
          status === 429
            ? Date.now() + (error.retryAfterMs ?? 1000)
            : this.value.retryAt,
      });
    this.queue?.holdSource(error);
  };
  refresh = async () => {
    const runtime = this.runtime,
      year = this.value.fiscalYear;
    this.cancel();
    const generation = this.generation;
    this.clearEpoch++;
    this.publish({ progress: null, preparing: true, clearIncomplete: false });
    try {
      if (runtime && this.repository) {
        const { candidateCacheScope } = await import('./thipStepCache');
        await this.repository.clear(await candidateCacheScope(runtime), year);
      }
    } catch {
      this.publish({ cacheUnavailable: true, clearIncomplete: true });
    }
    if (generation === this.generation && runtime === this.runtime) {
      const lane = await import('./aggregateQueryLane');
      if (runtime) lane.aggregateQueryLane(runtime).allow();
      await this.start();
    }
  };
  clearAll = async () => {
    this.cancel();
    this.generation++;
    this.clearEpoch++;
    this.publish({ progress: null, clearIncomplete: false });
    try {
      await this.repository?.clear();
    } catch {
      this.publish({ cacheUnavailable: true, clearIncomplete: true });
    }
  };
  dispose() {
    this.abort?.abort();
    this.queue?.cancel();
    this.generation++;
    if (this.timer) clearTimeout(this.timer);
  }
  invalidateExpired = () => {
    this.grids.clear();
    this.publish({});
    this.scheduleExpiry();
  };
  private scheduleExpiry() {
    if (this.timer) clearTimeout(this.timer);
    const expiry = this.value.progress?.steps
      .map((step) => step.expiresAt)
      .filter((time): time is number => time !== undefined && time > Date.now())
      .sort((a, b) => a - b)[0];
    const today = bangkokDate(),
      year = Number(today.slice(0, 4)),
      month = Number(today.slice(5, 7));
    const monthBoundary = Date.UTC(year, month, 1) - 7 * 3600 * 1000;
    this.timer = setTimeout(
      this.invalidateExpired,
      Math.min(
        Math.min(expiry ?? Infinity, monthBoundary) - Date.now() + 1,
        2147483647
      )
    );
  }
  reportingSteps = () =>
    this.value.progress?.steps.filter(
      (step) => !step.code.startsWith('monitoring/')
    ) ?? [];
  private reportingComplete() {
    const steps = this.reportingSteps();
    if (
      steps.length !== 232 ||
      steps.some(
        (step) =>
          step.status !== 'success' ||
          step.rows.length !== getExpectedFiscalMonths(step.code).length ||
          (step.expiresAt !== undefined && step.expiresAt <= Date.now())
      )
    )
      return false;
    const refreshes = new Set(
      steps.flatMap((step) =>
        (step.rows as SharedKpiFact[]).map(
          (row) => row.normalized?.refreshed_at
        )
      )
    );
    return refreshes.size === 1 && !refreshes.has(undefined);
  }
  officialIndicator(code: string): Indicator | null {
    // Keep the existing complete-source publication boundary. Draft facts may
    // stream immediately while an incomplete production contract stays withheld.
    const requireComplete =
      import.meta.env.PROD ||
      /^(true|1|yes|on)$/i.test(
        import.meta.env.VITE_BMS_KPI_REQUIRE_COMPLETE_SOURCE_VIEW ?? ''
      );
    if (requireComplete && import.meta.env.VITE_BMS_KPI_SOURCE_VIEW?.trim()) {
      if (!this.reportingComplete()) return null;
    }
    const step = this.value.progress?.steps.find((step) => step.code === code);
    if (
      !step ||
      step.status !== 'success' ||
      (step.expiresAt !== undefined && step.expiresAt <= Date.now())
    )
      return null;
    if (this.official.has(step)) return this.official.get(step)!;
    const result =
      this.officialProjection?.(
        code,
        step.rows as SharedKpiFact[],
        this.value.fiscalYear
      ) ?? null;
    this.official.set(step, result);
    return result;
  }
  grid(series: KpiSeries, mode: KpiMode): readonly KpiGridRow[] {
    const key = `${series}:${mode}`;
    const existing = this.grids.get(key);
    if (existing) return existing;
    const year = this.value.fiscalYear,
      now = Date.now(),
      monthKey = bangkokDate().slice(0, 7);
    const steps = new Map(
      this.value.progress?.steps.map((step) => [step.code, step])
    );
    const periods = getFiscalMonthPeriods(year);
    const publicationKey =
      import.meta.env.VITE_BMS_KPI_SOURCE_VIEW?.trim() && mode === 'approved'
        ? this.reportingComplete()
        : '';
    const rows = runtimeCatalogue.map((entry) => {
      const report = steps.get(entry.code),
        step = steps.get(
          series === 'thip-report' ? entry.code : `monitoring/${entry.code}`
        );
      const expired = (item?: Readonly<StepResult>) =>
        item?.expiresAt !== undefined && item.expiresAt <= now;
      const stamp = `${year}:${monthKey}:${expired(step)}:${expired(report)}:${publicationKey}`;
      const rowKey = `${key}:${entry.code}`,
        cached = this.rowCache.get(rowKey);
      if (
        cached?.stamp === stamp &&
        cached.step === step &&
        cached.report === report
      )
        return cached.row;
      const rule = rules.get(entry.code)!;
      const bridge = bridges.get(entry.code);
      const canBridge = Boolean(
        bridge &&
          bridge.unit === rule.unit &&
          bridge.scale === rule.scale &&
          bridge.sourceRuleHash ===
            runtimeSignatures.find((signature) => signature.code === entry.code)
              ?.ruleHash
      );
      const chosen =
        series === 'monthly-monitoring' && !step && canBridge ? report : step;
      const facts = !expired(chosen)
        ? (chosen?.rows as readonly SharedKpiFact[] | undefined)
        : undefined;
      const approved =
        mode === 'approved' && series === 'thip-report'
          ? this.officialIndicator(entry.code)
          : null;
      const cells = periods.map((period): KpiCellViewModel => {
        const expected = getExpectedFiscalMonths(entry.code),
          applicable =
            series !== 'thip-report' || expected.includes(period.fiscalMonth);
        const width =
          getReportingCadence(entry.code) === 'annual'
            ? 12
            : getReportingCadence(entry.code) === 'semiannual'
              ? 6
              : getReportingCadence(entry.code) === 'quarterly'
                ? 3
                : 1;
        const endMonth =
          series === 'thip-report'
            ? Math.min(period.fiscalMonth + width - 1, 12)
            : period.fiscalMonth;
        const periodEnd =
          endMonth === 12 ? `${year}-10-01` : periods[endMonth].periodStart;
        const fact = facts?.find(
          (fact) => fact.fiscalMonth === period.fiscalMonth
        );
        const monitoring = fact?.monitoring;
        const approval =
          series === 'thip-report'
            ? approved?.dataSource === 'bms'
            : rule.approval === 'approved' &&
              !!rule.approvalEvidence &&
              rule.effectiveFrom !== null &&
              rule.effectiveFrom <= period.periodStart &&
              (rule.effectiveTo === null || rule.effectiveTo >= periodEnd);
        const officialMonth = approved?.monthly.find(
          (month) => month.fiscalMonth === period.fiscalMonth
        );
        let status: KpiCellViewModel['status'] = !applicable
          ? 'not-applicable'
          : period.periodStart.slice(0, 7) > monthKey
            ? 'future'
            : expired(chosen)
              ? 'expired'
              : chosen?.status === 'running'
                ? 'loading'
                : chosen?.status === 'failed'
                  ? 'failed'
                  : chosen?.status === 'pending' ||
                      (!chosen && series === 'thip-report')
                    ? 'pending'
                    : (monitoring?.dataStatus ??
                      (fact?.measurement === 'unknown'
                        ? 'missing-source'
                        : fact?.measurement) ??
                      'missing-source');
        if (
          applicable &&
          status !== 'future' &&
          status !== 'not-applicable' &&
          mode === 'approved' &&
          !approval
        )
          status = 'rule-unapproved';
        const usable = status === 'measured' || status === 'zero-cohort';
        const targetApproval = runtimeRulesByCode.get(
          entry.code
        )?.hospitalTargetApproval;
        const sourceTarget = fact?.normalized?.target;
        const target =
          monitoring?.target ??
          (usable &&
          targetApproval?.source &&
          targetApproval.unit === rule.unit &&
          targetApproval.from <= period.periodStart &&
          targetApproval.until >= periodEnd &&
          sourceTarget !== null &&
          sourceTarget !== undefined
            ? {
                value: Number(sourceTarget),
                lower: null,
                upper: null,
                unit: rule.unit,
                source: targetApproval.source,
                kind: 'hospital' as const,
                validFrom: targetApproval.from,
                validTo: targetApproval.until,
                mappingConfirmed: true as const,
              }
            : null);
        const reason =
          status === 'not-applicable'
            ? 'ไม่มีงวดรายงานในเดือนนี้; ผลแสดงเฉพาะเดือนเริ่มงวด'
            : status === 'future'
              ? 'เดือนอนาคตตาม Asia/Bangkok'
              : status === 'rule-unapproved'
                ? `${rule.reason}; ยังไม่มี publication approval/version/effective period ที่ครอบคลุม`
                : status === 'expired'
                  ? 'Cache หมดอายุ กดเริ่มโหลดเพื่ออ่านใหม่'
                  : (chosen?.reason ??
                    fact?.reason ??
                    (usable
                      ? 'aggregate เพื่อสอบทาน; ยังไม่รับรอง'
                      : series === 'monthly-monitoring'
                        ? rule.reason
                        : 'ยังไม่โหลด; ค่าเป็น NULL'));
        return Object.freeze({
          code: entry.code,
          fiscalYear: year,
          fiscalMonth: period.fiscalMonth,
          series,
          periodStart: period.periodStart,
          periodEnd,
          label: period.label,
          value: usable
            ? mode === 'approved' && series === 'thip-report'
              ? (officialMonth?.value ?? null)
              : (fact?.sourceValue ?? null)
            : null,
          numerator: usable ? (fact?.numerator ?? null) : null,
          denominator: usable ? (fact?.denominator ?? null) : null,
          derivedValue: usable ? (fact?.derivedValue ?? null) : null,
          unit: rule.unit,
          status,
          approval: mode === 'approved' && approval ? 'approved' : 'unapproved',
          assessment: assessMonitoring(
            {
              value: usable ? (fact?.sourceValue ?? null) : null,
              dataStatus: status === 'measured' ? 'measured' : 'missing-source',
              unit: rule.unit,
              periodStart: period.periodStart,
              periodEnd,
              target,
            },
            rule
          ),
          target: usable ? target : null,
          cumulative: usable
            ? (monitoring?.cumulative ?? emptyCumulative)
            : emptyCumulative,
          cumulativeBasis: usable && monitoring?.cumulative.value !== null && monitoring?.cumulative.value !== undefined ? 'source' : null,
          cumulativeReason: usable && monitoring?.cumulative.value !== null && monitoring?.cumulative.value !== undefined
            ? 'ผลสะสมจากแหล่งข้อมูลตามกฎที่ลงทะเบียน' : '',
          discrepancy: usable && (fact?.discrepancy ?? false),
          reason,
          ruleVersion: fact?.ruleVersion ?? rule.version,
          formula:
            series === 'thip-report'
              ? runtimeReportingDefinitions.get(entry.code)!.formula
              : (monitoring?.formula ?? rule.formula),
          method:
            series === 'thip-report'
              ? runtimeReportingDefinitions.get(entry.code)!.method
              : (monitoring?.method ?? rule.method),
          accumulation:
            series === 'thip-report'
              ? canBridge
                ? rule.accumulation
                : 'source-period-result'
              : rule.accumulation,
          lineage:
            series === 'monthly-monitoring' && !monitoring && canBridge
              ? bridge!.version
              : monitoring
                ? 'monitoring-source'
                : fact?.normalized
                  ? 'reporting-source'
                  : 'native-seven-column',
          observedAt: fact?.observedAt ?? null,
          refreshedAt:
            monitoring?.refreshedAt ??
            (fact?.normalized ? String(fact.normalized.refreshed_at) : null),
          dataThrough: monitoring?.dataThrough ?? null,
          origin: chosen?.origin ?? null,
          expiresAt: chosen?.expiresAt ?? null,
        });
      });
      const accumulated = withKpiCumulative(cells, rule);
      const row = Object.freeze({
        code: entry.code,
        cells: Object.freeze(accumulated),
      });
      this.rowCache.set(rowKey, { stamp, step, report, row });
      return row;
    });
    this.grids.set(key, rows);
    return rows;
  }
}
