import type { FiscalYear, Indicator, IndicatorGroup, MonthlyResult, TargetScope } from '@/types/thip';
import { getFiscalMonthPeriods } from '@/utils/fiscal';

export type LiveDefinition = {
  code: string;
  group: IndicatorGroup;
  category: string;
  title: string;
  titleTh: string;
  unit: Indicator['unit'];
  direction: Indicator['direction'];
  target: number | null;
  targetScope: TargetScope;
  definition: string;
  formula: string;
  numeratorLabel: string;
  denominatorLabel: string;
  sourceTables: string[];
  frequency: string;
  reference: string;
};

function createLiveMonthly(fiscalYear: FiscalYear): MonthlyResult[] {
  return getFiscalMonthPeriods(fiscalYear).map((period) => ({
    periodStart: period.periodStart,
    fiscalYear: period.fiscalYear,
    fiscalMonth: period.fiscalMonth,
    label: period.label,
    numerator: null,
    denominator: null,
    value: null,
    target: null,
    percentile: null,
    status: 'no-data',
  }));
}

export function createLiveIndicator(definition: LiveDefinition, fiscalYear: FiscalYear): Indicator {
  return {
    code: definition.code,
    dataSource: 'bms',
    fiscalYear,
    group: definition.group,
    category: definition.category,
    title: definition.title,
    titleTh: definition.titleTh,
    unit: definition.unit,
    direction: definition.direction,
    target: definition.target,
    targetScope: definition.targetScope,
    definition: definition.definition,
    formula: definition.formula,
    numeratorLabel: definition.numeratorLabel,
    denominatorLabel: definition.denominatorLabel,
    sourceTables: definition.sourceTables,
    frequency: definition.frequency,
    reference: definition.reference,
    monthly: createLiveMonthly(fiscalYear),
    annual: {
      fiscalYear,
      numerator: null,
      denominator: null,
      value: null,
      target: definition.target,
      status: 'no-data',
    },
  };
}
