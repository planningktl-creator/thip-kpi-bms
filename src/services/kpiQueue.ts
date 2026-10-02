// Loaded after a verified session; SQL and rich dictionary modules stay off the first page.
import {
  ThipStepLoader,
  validateCandidateRows,
  type CandidateAggregate,
  type StepTask,
  type StepSnapshot,
} from './thipStepLoader';
import {
  runtimeCatalogue,
  runtimeRulesByCode,
  runtimeSignatures,
  runtimeReportingDefinitions,
} from '@/data/thipRuntime';
import { aggregateQueryLane } from './aggregateQueryLane';
import {
  executeRegisteredQuery,
  externalRegisteredCodes,
} from './queryRegistry';
import {
  buildSourceViewQuery,
  assertNormalizedSourceViewRows,
  buildIndicatorFromRows,
} from './bmsData';
import { publishApprovedThip } from './publication';
import { buildMonitoringQuery } from '@/monitoring/provider';
import { validateMonitoringRow } from '@/monitoring/contract';
import { monitoringRulesByCode } from '@/monitoring/rules';
import {
  createStepCache,
  cacheDigest,
  candidateCacheScope,
  candidateCacheExpiry,
  type CacheRepository,
  type CacheEntry,
  type CachedStep,
  type StepCachePort,
} from './thipStepCache';
import { planFoundationRequests } from './thipFoundationPlan';
import { BmsRequestError } from './bmsErrors';
import type { BmsRuntimeConfig } from './bmsSession';
import type { SharedKpiFact } from './kpiTypes';

const reportColumns = [
  'indicator_code',
  'period_start',
  'fiscal_year',
  'fiscal_month',
  'numerator',
  'denominator',
  'value',
  'target',
  'target_scope',
  'percentile',
  'indicator_group',
  'unit',
  'direction',
  'category',
  'title',
  'title_th',
  'definition',
  'formula',
  'numerator_label',
  'denominator_label',
  'source_tables',
  'frequency',
  'reference',
  'rule_version',
  'pending_reason',
  'refreshed_at',
];
const orderedCodes = [
  'DH0101',
  'DH0112',
  ...runtimeCatalogue
    .map((item) => item.code)
    .filter((code) => !['DH0101', 'DH0112'].includes(code))
    .sort(),
];
export function buildCodeSourceQuery(
  view: string,
  code: string,
  monitoring: boolean
) {
  if (!runtimeRulesByCode.has(code)) throw new Error('Unknown registered KPI');
  const query = monitoring
    ? buildMonitoringQuery(view)
    : buildSourceViewQuery(view);
  return {
    ...query,
    key: `${monitoring ? 'thipMonitoringSource' : 'thipReportingSource'}_${code.replace(/\./g, '_')}`,
    sql: query.sql.replace(
      /ORDER BY/i,
      `AND ${monitoring ? 'code' : 'indicator_code'} = :indicator_code ORDER BY`
    ),
  };
}

export function validateReportingProjection(
  input: unknown[],
  code: string,
  fiscalYear: number
): SharedKpiFact[] {
  const projected = input.map((value) => {
    if (
      !value ||
      typeof value !== 'object' ||
      Array.isArray(value) ||
      Object.keys(value).some((key) => !reportColumns.includes(key)) ||
      reportColumns.some((key) => !(key in value))
    )
      throw new Error('Reporting projection contains unknown fields');
    return value as Record<string, unknown>;
  });
  if (projected.some((row) => row.indicator_code !== code))
    throw new Error('Reporting source returned another KPI');
  assertNormalizedSourceViewRows(projected, fiscalYear);
  if (
    projected.some(
      (row) =>
        typeof row.refreshed_at !== 'string' ||
        !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(row.refreshed_at) ||
        !Number.isFinite(Date.parse(row.refreshed_at))
    )
  )
    throw new Error('Invalid source freshness timestamp');
  const facts = validateCandidateRows(
    projected.map((row) => ({
      indicator_code: code,
      fiscal_year: row.fiscal_year,
      fiscal_month: row.fiscal_month,
      period_start: row.period_start,
      numerator: row.numerator,
      denominator: row.denominator,
      value: row.value,
      fact_present:
        !row.pending_reason &&
        (row.numerator !== null ||
          row.denominator !== null ||
          row.value !== null),
    })),
    code,
    fiscalYear
  );
  return facts.map((row, index) => ({
    ...row,
    ruleVersion: String(projected[index].rule_version),
    normalized: {
      ...projected[index],
      numerator: row.numerator,
      denominator: row.denominator,
      value: row.sourceValue,
    },
  }));
}

export function validateMonitoringProjection(
  input: unknown[],
  taskCode: string,
  fiscalYear: number
): SharedKpiFact[] {
  const code = taskCode.replace(/^monitoring\//, '');
  const seen = new Set<number>();
  return input.map((value) => {
    const monitoring = validateMonitoringRow(
      value,
      fiscalYear,
      monitoringRulesByCode,
      false,
      new Date(),
      false
    );
    if (monitoring.code !== code || seen.has(monitoring.fiscalMonth))
      throw new Error('Invalid or duplicate monitoring source code/month');
    seen.add(monitoring.fiscalMonth);
    const rule = monitoringRulesByCode.get(code)!;
    const derivedValue =
      rule.accumulation !== 'custom' &&
      rule.unit !== 'count' &&
      monitoring.numerator !== null &&
      monitoring.denominator !== null &&
      monitoring.denominator > 0
        ? (monitoring.numerator / monitoring.denominator) * rule.scale
        : null;
    const discrepancy =
      derivedValue !== null &&
      monitoring.value !== null &&
      Math.abs(derivedValue - monitoring.value) > 0.0051;
    return {
      code,
      fiscalYear,
      fiscalMonth: monitoring.fiscalMonth,
      periodStart: monitoring.periodStart,
      numerator: monitoring.numerator,
      denominator: monitoring.denominator,
      sourceValue: monitoring.value,
      derivedValue,
      discrepancy,
      reason: discrepancy
        ? 'source value ต่างจากอัตราคำนวณ; ต้องสอบทาน arithmetic'
        : monitoring.reason,
      measurement:
        monitoring.dataStatus === 'measured'
          ? 'measured'
          : monitoring.dataStatus === 'zero-cohort'
            ? 'zero-cohort'
            : monitoring.dataStatus === 'future'
              ? 'future'
              : 'unknown',
      unit: monitoring.unit,
      ruleVersion: monitoring.ruleVersion,
      observedAt: new Date().toISOString(),
      dataThrough: null,
      refreshedAt: null,
      approval: 'unapproved',
      series: 'thip-report',
      monitoring,
    };
  });
}

export function approvedReportingIndicator(
  code: string,
  rows: readonly SharedKpiFact[],
  fiscalYear: number
) {
  const projected = rows.flatMap((row) =>
    row.normalized ? [row.normalized] : []
  );
  if (!projected.length) return null;
  const indicator = buildIndicatorFromRows(code, projected, fiscalYear);
  if (!indicator) return null;
  const coverage = {
    expectedIndicatorCount: 232,
    liveIndicatorCount: 1,
    measuredIndicatorCount: 1,
    expectedCellCount: 1552,
    coveredCellCount: projected.length,
    availableCellCount: projected.length,
    unavailableCellCount: 0,
    unexpectedCellCount: 0,
    complete: false,
    liveCodes: [code],
  };
  return publishApprovedThip({
    indicators: [indicator],
    liveCodes: [code],
    coverage,
    rowCount: projected.length,
    refreshedAt: String(projected[0].refreshed_at),
    sourceView: 'shared-projection',
  }).indicators[0];
}

export async function createKpiQueue(
  runtime: BmsRuntimeConfig,
  fiscalYear: number,
  repository: CacheRepository,
  signal: AbortSignal,
  onProgress: (snapshot: StepSnapshot) => void
) {
  const reportingView = import.meta.env.VITE_BMS_KPI_SOURCE_VIEW?.trim();
  await repository.prune(Date.now());
  const monitoringView =
    import.meta.env.VITE_BMS_MONITORING_SOURCE_VIEW?.trim();
  const nativeCache = reportingView
    ? null
    : await createStepCache(runtime, fiscalYear, repository, signal);
  const reportCodes = reportingView
    ? orderedCodes
    : runtimeSignatures.map((item) => item.code);
  // The first two reporting results remain first. Then interleave independent
  // series so configured monitoring does not wait behind an entire reporting FY.
  const taskCodes = monitoringView
    ? [
        ...reportCodes.slice(0, 2),
        ...reportCodes.slice(0, 2).map((code) => `monitoring/${code}`),
        ...orderedCodes
          .filter((code) => !reportCodes.slice(0, 2).includes(code))
          .flatMap((code) => [
            ...(reportCodes.includes(code) ? [code] : []),
            `monitoring/${code}`,
          ]),
      ]
    : reportCodes;
  const scope = await candidateCacheScope(runtime);
  const descriptorMap = new Map(
    await Promise.all(
      taskCodes
        .filter((code) => code.startsWith('monitoring/') || reportingView)
        .map(async (taskCode) => {
          const monitoring = taskCode.startsWith('monitoring/');
          const code = taskCode.replace(/^monitoring\//, '');
          const rule = monitoring
            ? monitoringRulesByCode.get(code)
            : runtimeRulesByCode.get(code);
          const fingerprint = await cacheDigest([
            'shared-source/1',
            buildCodeSourceQuery(
              (monitoring ? monitoringView : reportingView)!,
              code,
              monitoring
            ).sql,
            fiscalYear,
            code,
            rule,
            runtimeReportingDefinitions.get(code)!.ruleHash,
          ]);
          return [
            taskCode,
            {
              key: `${scope}:${fiscalYear}:${monitoring ? 'monitoring-source' : 'reporting-source'}:${code}:${fingerprint}`,
              scope,
              version: 3,
              code: taskCode,
              fiscalYear,
              fingerprint,
              ruleVersion: fingerprint,
            },
          ] as const;
        })
    )
  );
  const validate = (
    input: unknown[],
    code: string,
    fy: number
  ): CandidateAggregate[] =>
    code.startsWith('monitoring/')
      ? validateMonitoringProjection(input, code, fy)
      : reportingView
        ? validateReportingProjection(input, code, fy)
        : validateCandidateRows(input, code, fy);
  function restore(value: unknown, taskCode: string): CachedStep | null {
    try {
      const descriptor = descriptorMap.get(taskCode)!;
      const entry = value as CacheEntry;
      if (
        !entry ||
        entry.version !== 3 ||
        entry.key !== descriptor.key ||
        entry.scope !== scope ||
        entry.fingerprint !== descriptor.fingerprint ||
        entry.ruleVersion !== descriptor.ruleVersion ||
        entry.code !== taskCode ||
        entry.fiscalYear !== fiscalYear ||
        !Array.isArray(entry.projection) ||
        !Number.isFinite(entry.expiresAt) ||
        entry.expiresAt <= Date.now()
      )
        return null;
      const observed = Date.parse(entry.observedAt);
      if (
        !Number.isFinite(observed) ||
        observed > Date.now() ||
        entry.expiresAt > candidateCacheExpiry(fiscalYear, observed)
      )
        return null;
      return {
        code: taskCode,
        rows: validate(entry.projection, taskCode, fiscalYear).map((row) => ({
          ...row,
          observedAt: entry.observedAt,
        })),
        observedAt: entry.observedAt,
        expiresAt: entry.expiresAt,
      };
    } catch {
      return null;
    }
  }
  const cache: StepCachePort = {
    async read(readSignal) {
      const native = (await nativeCache?.read(readSignal)) ?? [];
      const descriptors = [...descriptorMap.entries()];
      const values = repository.readMany
        ? await repository.readMany(descriptors.map(([, value]) => value.key))
        : await Promise.all(
            descriptors.map(([, value]) => repository.read(value.key))
          );
      if (readSignal.aborted || signal.aborted) return [];
      return [
        ...native,
        ...values.flatMap((value, index) => {
          const row = restore(value, descriptors[index][0]);
          return row ? [row] : [];
        }),
      ];
    },
    async write(taskCode, rows, writeSignal) {
      if (!descriptorMap.has(taskCode))
        return (await nativeCache?.write(taskCode, rows, writeSignal)) ?? null;
      if (signal.aborted || writeSignal.aborted) return null;
      const facts = rows as readonly SharedKpiFact[];
      const observedAt = facts[0]?.observedAt ?? new Date().toISOString();
      const projection = facts.map((row) =>
        taskCode.startsWith('monitoring/') ? row.monitoring! : row.normalized!
      );
      const entry: CacheEntry = {
        ...descriptorMap.get(taskCode)!,
        observedAt,
        expiresAt: candidateCacheExpiry(fiscalYear, Date.parse(observedAt)),
        facts: [],
        projection,
      };
      const restored = restore(entry, taskCode);
      if (!restored) return null;
      const linked = new AbortController();
      const abort = () => linked.abort();
      signal.addEventListener('abort', abort, { once: true });
      writeSignal.addEventListener('abort', abort, { once: true });
      if (signal.aborted || writeSignal.aborted) linked.abort();
      try {
        await repository.write(entry, linked.signal);
      } finally {
        signal.removeEventListener('abort', abort);
        writeSignal.removeEventListener('abort', abort);
      }
      return signal.aborted || writeSignal.aborted ? null : restored;
    },
  };
  const tasks: StepTask[] = taskCodes.map((taskCode) => {
    let latency: number | undefined;
    return {
      code: taskCode,
      queryLatencyMs: () => latency,
      async run(requestSignal) {
        return aggregateQueryLane(runtime).run(requestSignal, async () => {
          const monitoring = taskCode.startsWith('monitoring/');
          const code = taskCode.replace(/^monitoring\//, '');
          const request =
            !monitoring && !reportingView
              ? planFoundationRequests({
                  fiscalYear,
                  chunkSize: 1,
                  codes: [code],
                })[0]
              : null;
          const query = request
            ? {
                ...request.query,
                key: `thipReportCandidate_${code.replace(/\./g, '_')}`,
              }
            : buildCodeSourceQuery(
                (monitoring ? monitoringView : reportingView)!,
                code,
                monitoring
              );
          const parameters = {
            fiscal_year: { value: fiscalYear, value_type: 'integer' as const },
            start_date: {
              value: `${fiscalYear - 1}-10-01`,
              value_type: 'date' as const,
            },
            end_date: {
              value: `${fiscalYear}-10-01`,
              value_type: 'date' as const,
            },
            indicator_code: { value: code, value_type: 'string' as const },
          };
          const params: Record<
            string,
            (typeof parameters)[keyof typeof parameters]
          > = monitoring
            ? {
                fiscal_year: parameters.fiscal_year,
                indicator_code: parameters.indicator_code,
              }
            : request
              ? {
                  start_date: parameters.start_date,
                  end_date: parameters.end_date,
                }
              : parameters;
          const started = performance.now();
          try {
            const response = await executeRegisteredQuery(
              query,
              runtime,
              params,
              runtime.marketplaceToken,
              { signal: requestSignal }
            );
            const rows = response.data ?? response.result;
            if (!Array.isArray(rows))
              throw new BmsRequestError(
                'data',
                'response',
                'Missing aggregate array'
              );
            return rows;
          } finally {
            latency = performance.now() - started;
          }
        });
      },
    };
  });
  if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
  const loader = new ThipStepLoader(
    fiscalYear,
    tasks,
    onProgress,
    1000,
    reportingView ? [] : externalRegisteredCodes,
    cache,
    validate
  );
  signal.addEventListener('abort', () => loader.cancel(), { once: true });
  return loader;
}
