import { benchmarkSourceFromTarget, getDictionaryEntry, parseBenchmark } from '@/data/thipDictionary';
import { getExpectedFiscalMonths } from '@/data/thipReporting';
import type { FiscalYear, Indicator, IndicatorGroup, MonthlyResult, TargetScope } from '@/types/thip';
import { getFiscalMonthPeriods } from '@/utils/fiscal';

/** Metadata for indicators returned by the local, evidence-backed foundation query. */
export type FoundationDefinition = {
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
  /** Optional overrides; the THIP KPI dictionary fills these when absent. */
  targetText?: string | null;
  benchmarkSource?: string | null;
  numeratorDefinition?: string | null;
  denominatorDefinition?: string | null;
};

function createLiveMonthly(
  fiscalYear: FiscalYear,
  monthlyTarget: number | null,
  expectedMonths: ReadonlySet<number>,
): MonthlyResult[] {
  return getFiscalMonthPeriods(fiscalYear).map((period) => ({
    periodStart: period.periodStart,
    fiscalYear: period.fiscalYear,
    fiscalMonth: period.fiscalMonth,
    label: period.label,
    numerator: null,
    denominator: null,
    value: null,
    target: monthlyTarget !== null && expectedMonths.has(period.fiscalMonth) ? monthlyTarget : null,
    percentile: null,
    status: 'no-data',
  }));
}

/**
 * Builds a foundation indicator. The THIP KPI dictionary is the source of truth
 * for the printed metadata (definition, formula, a/b labels and definitions,
 * benchmark text, direction); the supplied definition only fills gaps. An
 * explicitly supplied numeric `target` still wins over the parsed benchmark.
 */
export function createFoundationIndicator(definition: FoundationDefinition, fiscalYear: FiscalYear): Indicator {
  const dictionary = getDictionaryEntry(definition.code);
  const targetText = dictionary?.target ?? definition.targetText ?? null;
  const benchmark = parseBenchmark(targetText);
  const target = definition.target ?? benchmark.value;
  const expectedMonths = new Set(getExpectedFiscalMonths(definition.code));
  const monthlyTarget = definition.targetScope === 'monthly' ? target : null;

  return {
    code: definition.code,
    dataSource: 'bms',
    implementationTier: 'registered',
    pendingReason: null,
    fiscalYear,
    group: definition.group,
    category: definition.category,
    title: definition.title,
    titleTh: definition.titleTh,
    unit: definition.unit,
    direction: dictionary?.direction ?? definition.direction,
    target,
    targetScope: definition.targetScope,
    targetText,
    benchmarkSource: benchmarkSourceFromTarget(targetText) ?? definition.benchmarkSource ?? null,
    definition: dictionary?.definition ?? definition.definition,
    formula: dictionary?.formula ?? definition.formula,
    numeratorLabel: dictionary?.numeratorLabel ?? definition.numeratorLabel,
    denominatorLabel: dictionary?.denominatorLabel ?? definition.denominatorLabel,
    numeratorDefinition: dictionary?.numeratorDefinition ?? definition.numeratorDefinition ?? null,
    denominatorDefinition: dictionary?.denominatorDefinition ?? definition.denominatorDefinition ?? null,
    sourceTables: definition.sourceTables,
    frequency: dictionary?.frequency ?? definition.frequency,
    reference: definition.reference,
    monthly: createLiveMonthly(fiscalYear, monthlyTarget, expectedMonths),
    annual: {
      fiscalYear,
      numerator: null,
      denominator: null,
      value: null,
      target: definition.targetScope === 'annual' ? target : null,
      status: 'no-data',
    },
  };
}
