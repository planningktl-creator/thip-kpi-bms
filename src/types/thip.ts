export type IndicatorGroup = 'D' | 'C' | 'S' | 'H' | 'A';

export type IndicatorUnit = 'percent' | 'rate' | 'ratio' | 'count';

export type IndicatorDirection =
  | 'higher-is-better'
  | 'lower-is-better'
  | 'neutral';

export type IndicatorStatus = 'on-track' | 'watch' | 'action' | 'no-data' | 'unbenchmarked';

export type IndicatorDataSource = 'bms' | 'no-data';

/**
 * The app keeps the Gregorian end year as the stable ISO-side fiscal-year key.
 * For example, fiscalYear 2026 is displayed as ปีงบประมาณ 2569.
 */
export type FiscalYear = number;

export type TargetScope = 'monthly' | 'annual';

export type MonthlyResult = {
  /** ISO date for the first day of the source reporting period, e.g. 2025-10-01. */
  periodStart: string;
  fiscalYear: FiscalYear;
  fiscalMonth: number;
  label: string;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  percentile: number | null;
  status: IndicatorStatus;
};

export type AnnualResult = {
  fiscalYear: FiscalYear;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  status: IndicatorStatus;
};

export type Indicator = {
  code: string;
  dataSource?: IndicatorDataSource;
  /** Whether the code has a registered read-only query or still needs a local source. */
  implementationTier: 'registered' | 'pending-local-source';
  /** Explicit reason when the code cannot be measured yet; never a fabricated zero. */
  pendingReason: string | null;
  fiscalYear: FiscalYear;
  group: IndicatorGroup;
  category: string;
  title: string;
  titleTh: string;
  unit: IndicatorUnit;
  direction: IndicatorDirection;
  target: number | null;
  targetScope: TargetScope;
  annual: AnnualResult;
  definition: string;
  formula: string;
  numeratorLabel: string;
  denominatorLabel: string;
  /** Printed `a = ...` line from the THIP KPI dictionary, verbatim. */
  numeratorDefinition: string | null;
  /** Printed `b = ...` line from the THIP KPI dictionary, verbatim. */
  denominatorDefinition: string | null;
  /** Verbatim benchmark/เป้าหมาย text from the dictionary (null when the PDF printed none). */
  targetText: string | null;
  /** Benchmark citation source from the PDF (e.g. `U.S.A. National Median`), or the full printed string. */
  benchmarkSource: string | null;
  sourceTables: string[];
  frequency: string;
  reference: string;
  monthly: MonthlyResult[];
};

export type GroupMeta = {
  key: IndicatorGroup;
  label: string;
  shortLabel: string;
  description: string;
  color: string;
};

export type BmsConnectionStatus =
  | 'idle'
  | 'connecting'
  | 'connected'
  | 'unsupported'
  | 'error';

export type BmsConnection = {
  status: BmsConnectionStatus;
  hospitalCode?: string;
  userName?: string;
  apiUrl?: string;
  databaseType?: string;
  message?: string;
};

/** ISO timestamp of the last successful data refresh, e.g. 2026-09-10T08:45:00Z. */
export type RefreshedAt = string;
