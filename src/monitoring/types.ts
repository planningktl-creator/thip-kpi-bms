import type { IndicatorDirection, IndicatorGroup } from '@/types/thip';

export type MonitoringUnit = 'percent' | 'rate' | 'count' | 'ratio' | 'minute' | 'day' | 'month' | 'hour-per-person';
export type MonitoringDataStatus = 'measured' | 'zero-cohort' | 'missing-source' | 'rule-unapproved' | 'future';
export type MonitoringAssessment = 'on-track' | 'watch' | 'action' | 'no-target' | 'not-assessable';
export type AccumulationMethod = 'sum' | 'count' | 'weighted-ratio' | 'fixed-denominator' | 'snapshot' | 'distinct-cohort' | 'custom';
export type MonitoringRule = {
  code: string; group: IndicatorGroup; title: string; version: string;
  approval: 'unapproved' | 'approved' | 'synthetic';
  approvalEvidence: string | null; effectiveFrom: string | null; effectiveTo: string | null;
  unit: MonitoringUnit; precision: number; scale: number;
  direction: IndicatorDirection | 'range'; watchMargin: number | null;
  accumulation: AccumulationMethod; formula: string; method: string;
  capability: string; reason: string; dictionaryBenchmark: string | null; reference: string;
};
export type MonitoringTarget = {
  value: number | null; lower: number | null; upper: number | null;
  unit: MonitoringUnit; source: string; kind: 'hospital';
  validFrom: string; validTo: string; mappingConfirmed: true;
};
export type MonitoringCumulative = {
  numerator: number | null; denominator: number | null; value: number | null;
  through: string | null; complete: boolean;
};
export type MonthlyMonitoringResult = {
  code: string; fiscalYear: number; fiscalMonth: number;
  periodStart: string; periodEnd: string; dataThrough: string | null;
  numerator: number | null; denominator: number | null; value: number | null;
  unit: MonitoringUnit; target: MonitoringTarget | null;
  cumulative: MonitoringCumulative; accumulation: AccumulationMethod;
  formula: string; method: string; dataStatus: MonitoringDataStatus;
  assessment: MonitoringAssessment; reason: string | null;
  ruleVersion: string; refreshedAt: string | null; synthetic: boolean;
};
export type MonitoringLoadResult = {
  fiscalYear: number; series: 'monthly-monitoring'; preview: boolean;
  rows: MonthlyMonitoringResult[]; refreshedAt: string | null;
  measuredCells: number; totalCells: number; error: string | null;
};
export type MonitoringProvider = {
  preview: boolean;
  rules?: ReadonlyMap<string, MonitoringRule>;
  load(fiscalYear: number, signal: AbortSignal): Promise<unknown[]>;
};
