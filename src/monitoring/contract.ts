import { bangkokDate, fiscalPeriodEnd, getFiscalMonthPeriods } from '@/utils/fiscal';
import { monitoringRulesByCode } from './rules';
import { assessMonitoring } from './calculation';
import type { MonitoringLoadResult, MonitoringProvider, MonitoringRule, MonthlyMonitoringResult } from './types';

const fields = ['code', 'fiscalYear', 'fiscalMonth', 'periodStart', 'periodEnd', 'dataThrough', 'numerator', 'denominator', 'value', 'unit', 'target', 'cumulative', 'accumulation', 'formula', 'method', 'dataStatus', 'assessment', 'reason', 'ruleVersion', 'refreshedAt', 'synthetic'];
const dataStatuses = ['measured', 'zero-cohort', 'missing-source', 'rule-unapproved', 'future'];
const assessments = ['on-track', 'watch', 'action', 'no-target', 'not-assessable'];
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Monitoring row must be an aggregate object');
  return value as Record<string, unknown>;
}
function exact(value: Record<string, unknown>, keys: string[]): void {
  if (Object.keys(value).some((key) => !keys.includes(key)) || keys.some((key) => !(key in value))) throw new Error('Monitoring contract fields mismatch; patient rows are prohibited');
}
function numberOrNull(value: unknown): void {
  if (value !== null && (typeof value !== 'number' || !Number.isFinite(value))) throw new Error('Monitoring numbers must be finite or NULL');
}
function date(value: unknown): void {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) || Number.isNaN(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value) throw new Error('Monitoring date must be a valid ISO date');
}
export function unavailableCell(rule: MonitoringRule, fiscalYear: number, month: number, now = new Date(), preview = false): MonthlyMonitoringResult {
  const period = getFiscalMonthPeriods(fiscalYear)[month - 1];
  const future = period.periodStart.slice(0, 7) > bangkokDate(now).slice(0, 7);
  return {
    code: rule.code, fiscalYear, fiscalMonth: month, periodStart: period.periodStart, periodEnd: fiscalPeriodEnd(fiscalYear, month),
    dataThrough: null, numerator: null, denominator: null, value: null, unit: rule.unit, target: null,
    cumulative: { numerator: null, denominator: null, value: null, through: null, complete: false },
    accumulation: rule.accumulation, formula: rule.formula, method: rule.method,
    dataStatus: future ? 'future' : rule.approval === 'unapproved' ? 'rule-unapproved' : 'missing-source',
    assessment: 'not-assessable', reason: future ? 'เดือนอนาคตตามเวลา Asia/Bangkok' : rule.approval === 'unapproved' ? rule.reason : 'missing-source: ยังไม่มี aggregate ที่รับรองสำหรับเดือนนี้',
    ruleVersion: rule.version, refreshedAt: null, synthetic: preview,
  };
}
export function validateMonitoringRow(input: unknown, fiscalYear: number, rules = monitoringRulesByCode, preview = false, now = new Date()): MonthlyMonitoringResult {
  const raw = object(input); exact(raw, fields);
  const rule = rules.get(String(raw.code));
  if (!rule || raw.fiscalYear !== fiscalYear || !Number.isInteger(raw.fiscalMonth) || Number(raw.fiscalMonth) < 1 || Number(raw.fiscalMonth) > 12) throw new Error('Unknown monitoring code/year/month');
  const row = raw as unknown as MonthlyMonitoringResult;
  date(row.periodStart); date(row.periodEnd);
  if (row.periodStart !== getFiscalMonthPeriods(fiscalYear)[row.fiscalMonth - 1].periodStart || row.periodEnd !== fiscalPeriodEnd(fiscalYear, row.fiscalMonth)) throw new Error('Monitoring period must be the exact fiscal month, with exclusive end');
  if (row.ruleVersion !== rule.version || row.unit !== rule.unit || row.accumulation !== rule.accumulation || row.formula !== rule.formula || row.method !== rule.method) throw new Error('Monitoring rule version/unit/method mismatch');
  if (!dataStatuses.includes(row.dataStatus) || !assessments.includes(row.assessment) || row.synthetic !== preview) throw new Error('Invalid monitoring state or preview marker');
  for (const field of ['numerator', 'denominator', 'value'] as const) numberOrNull(row[field]);
  if (row.numerator !== null && row.numerator < 0 || row.denominator !== null && row.denominator < 0) throw new Error('Negative monitoring cohort');
  if (row.dataThrough !== null) { date(row.dataThrough); if (row.dataThrough < row.periodStart || row.dataThrough > bangkokDate(now)) throw new Error('Invalid data coverage date'); }
  if (row.refreshedAt !== null && (typeof row.refreshedAt !== 'string' || !/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(row.refreshedAt) || Number.isNaN(Date.parse(row.refreshedAt)))) throw new Error('Invalid refresh timestamp');
  const cumulative = object(row.cumulative); exact(cumulative, ['numerator', 'denominator', 'value', 'through', 'complete']);
  for (const field of ['numerator', 'denominator', 'value']) numberOrNull(cumulative[field]);
  if (typeof cumulative.complete !== 'boolean' || cumulative.complete && (cumulative.value === null || cumulative.through === null)) throw new Error('Invalid cumulative completeness');
  if (cumulative.value !== null && row.unit !== 'count' && (cumulative.numerator === null || cumulative.denominator === null || Number(cumulative.denominator) <= 0)) throw new Error('Cumulative rate requires nonzero aggregate denominator');
  if (cumulative.through !== null) { date(cumulative.through); if (row.dataThrough === null || String(cumulative.through) > row.dataThrough) throw new Error('Cumulative coverage exceeds source coverage'); }
  if (row.target !== null) {
    const target = object(row.target); exact(target, ['value', 'lower', 'upper', 'unit', 'source', 'kind', 'validFrom', 'validTo', 'mappingConfirmed']);
    for (const field of ['value', 'lower', 'upper']) numberOrNull(target[field]);
    date(target.validFrom); date(target.validTo);
    if (target.kind !== 'hospital' || target.mappingConfirmed !== true || typeof target.source !== 'string' || !target.source.trim() || target.unit !== row.unit || String(target.validFrom) > row.periodStart || String(target.validTo) < row.periodEnd || target.lower !== null && target.upper !== null && Number(target.lower) > Number(target.upper)) throw new Error('Unconfirmed, expired or incompatible hospital target');
  }
  if (row.dataStatus === 'measured' && (row.value === null || row.dataThrough === null || row.refreshedAt === null || row.unit !== 'count' && (row.numerator === null || row.denominator === null || row.denominator <= 0))) throw new Error('Measured monitoring result requires actual aggregate facts and coverage');
  if (row.dataStatus === 'zero-cohort' && (row.denominator !== 0 || row.numerator !== 0 || row.value !== null || row.dataThrough === null)) throw new Error('Zero cohort must be 0/0 with NULL value');
  if (!['measured', 'zero-cohort'].includes(row.dataStatus) && (row.value !== null || row.numerator !== null || row.denominator !== null || row.cumulative.value !== null || row.cumulative.numerator !== null || row.cumulative.denominator !== null || row.cumulative.complete)) throw new Error('Unavailable monitoring cells cannot contain measured values');
  if (!['measured', 'zero-cohort'].includes(row.dataStatus) && (typeof row.reason !== 'string' || !row.reason.trim())) throw new Error('Unavailable monitoring cells require a reason');
  // Publication is independent of SQL registration and transport state.
  const approved = rule.approval === 'approved' && Boolean(rule.approvalEvidence) && rule.effectiveFrom !== null && rule.effectiveFrom <= row.periodStart && (rule.effectiveTo === null || rule.effectiveTo >= row.periodEnd);
  const syntheticApproval = preview && rule.approval === 'synthetic';
  if (row.periodStart.slice(0, 7) > bangkokDate(now).slice(0, 7)) return unavailableCell(rule, fiscalYear, row.fiscalMonth, now, preview);
  if (!(approved || syntheticApproval)) return { ...unavailableCell(rule, fiscalYear, row.fiscalMonth, now, preview), dataStatus: 'rule-unapproved', reason: rule.approval === 'unapproved' ? rule.reason : 'rule-unapproved: approval evidence/effective period does not cover this month' };
  return { ...row, assessment: assessMonitoring(row, rule) };
}
export function emptyMonitoring(fiscalYear: number, now = new Date(), preview = false, error: string | null = null, rules = monitoringRulesByCode): MonitoringLoadResult {
  return { fiscalYear, series: 'monthly-monitoring', preview, rows: [...rules.values()].flatMap((rule) => Array.from({ length: 12 }, (_, index) => unavailableCell(rule, fiscalYear, index + 1, now, preview))), refreshedAt: null, totalCells: 2784, measuredCells: 0, error };
}
export async function loadMonitoring(provider: MonitoringProvider, fiscalYear: number, signal: AbortSignal, now = new Date()): Promise<MonitoringLoadResult> {
  if (provider.preview && !import.meta.env.DEV) throw new Error('Synthetic preview is prohibited in production');
  if (!provider.preview && provider.rules) throw new Error('Production rules must come from the publication manifest');
  const rules = provider.rules ?? monitoringRulesByCode;
  const inputs = await provider.load(fiscalYear, signal);
  if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
  const seen = new Map<string, MonthlyMonitoringResult>();
  for (const input of inputs) {
    const row = validateMonitoringRow(input, fiscalYear, rules, provider.preview, now);
    const key = `${row.code}:${row.fiscalMonth}`;
    if (seen.has(key)) throw new Error(`Duplicate monitoring cell ${key}`);
    seen.set(key, row);
  }
  const snapshot = emptyMonitoring(fiscalYear, now, provider.preview, null, rules);
  snapshot.rows = snapshot.rows.map((row) => seen.get(`${row.code}:${row.fiscalMonth}`) ?? row);
  snapshot.measuredCells = snapshot.rows.filter((row) => row.dataStatus === 'measured').length;
  snapshot.refreshedAt = snapshot.rows.map((row) => row.refreshedAt).filter((value): value is string => value !== null).sort().at(-1) ?? null;
  return snapshot;
}
