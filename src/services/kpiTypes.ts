import type {
  CandidateAggregate,
  StepSnapshot,
  StepResult,
} from './thipStepLoader';
import type {
  MonthlyMonitoringResult,
  MonitoringTarget,
  MonitoringAssessment,
  MonitoringCumulative,
  MonitoringUnit,
} from '@/monitoring/types';
import type { Indicator } from '@/types/thip';

export type KpiMode = 'review' | 'approved';
export type KpiSeries = 'thip-report' | 'monthly-monitoring';
export type KpiResultView = 'period' | 'cumulative';
export type KpiAvailability =
  | 'pending'
  | 'loading'
  | 'measured'
  | 'zero-cohort'
  | 'missing-source'
  | 'failed'
  | 'future'
  | 'rule-unapproved'
  | 'not-applicable'
  | 'expired';
export type SharedKpiFact = CandidateAggregate & {
  monitoring?: MonthlyMonitoringResult;
  normalized?: Record<string, unknown>;
};
export type KpiCellViewModel = Readonly<{
  code: string;
  fiscalYear: number;
  fiscalMonth: number;
  series: KpiSeries;
  periodStart: string;
  periodEnd: string;
  label: string;
  value: number | null;
  numerator: number | null;
  denominator: number | null;
  derivedValue: number | null;
  unit: MonitoringUnit;
  status: KpiAvailability;
  approval: 'unapproved' | 'approved';
  assessment: MonitoringAssessment;
  target: MonitoringTarget | null;
  cumulative: MonitoringCumulative;
  cumulativeBasis: 'source' | 'period-facts' | null;
  cumulativeReason: string;
  discrepancy: boolean;
  reason: string;
  ruleVersion: string;
  lineage: string;
  formula: string;
  method: string;
  accumulation: string;
  observedAt: string | null;
  refreshedAt: string | null;
  dataThrough: string | null;
  origin: 'cache' | 'query' | null;
  expiresAt: number | null;
}>;
export type KpiGridRow = Readonly<{
  code: string;
  cells: readonly KpiCellViewModel[];
}>;
export type KpiDataSnapshot = Readonly<{
  fiscalYear: number;
  owner: object | null;
  progress: StepSnapshot | null;
  cacheUnavailable: boolean;
  preparing: boolean;
  error: string | null;
  stopped: boolean;
  clearIncomplete: boolean;
  blockedBySession: boolean;
  retryAt: number;
}>;
export type KpiQueuePort = {
  start(): Promise<void>;
  pause(): void;
  resume(): Promise<void>;
  cancel(): void;
  retryFailed(code?: string): Promise<void>;
  holdSource(error: import('./bmsErrors').BmsRequestError): void;
};
export type KpiDataPort = {
  snapshot(): KpiDataSnapshot;
  subscribe(listener: () => void): () => void;
  grid(series: KpiSeries, mode: KpiMode): readonly KpiGridRow[];
  reportingSteps(): readonly Readonly<StepResult>[];
  officialIndicator(code: string): Indicator | null;
};
