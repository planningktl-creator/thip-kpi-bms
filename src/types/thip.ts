export type IndicatorGroup = 'D' | 'C' | 'S' | 'H' | 'A';

export type IndicatorUnit = 'percent' | 'rate' | 'ratio' | 'count';

export type IndicatorDirection =
  | 'higher-is-better'
  | 'lower-is-better'
  | 'neutral';

export type IndicatorStatus = 'on-track' | 'watch' | 'action' | 'no-data';

export type MonthlyResult = {
  fiscalMonth: number;
  label: string;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  target: number | null;
  percentile: number | null;
  status: IndicatorStatus;
};

export type Indicator = {
  code: string;
  group: IndicatorGroup;
  category: string;
  title: string;
  titleTh: string;
  unit: IndicatorUnit;
  direction: IndicatorDirection;
  target: number | null;
  definition: string;
  formula: string;
  numeratorLabel: string;
  denominatorLabel: string;
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
  | 'demo'
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
