import { getRuleReadiness, thipKpiRulesByCode } from '@/data/thipKpiRules';
import type { Indicator } from '@/types/thip';
import type { BmsDataLoadResult } from './bmsData';

/** Adapters can validate draft aggregates; screens/export only receive approved facts. */
export function publishApprovedThip(result: BmsDataLoadResult): BmsDataLoadResult {
  const indicators: Indicator[] = result.indicators.map((indicator) => {
    const rule = thipKpiRulesByCode.get(indicator.code);
    const approval = rule?.publicationApproval;
    const start = `${indicator.fiscalYear - 1}-10-01`, end = `${indicator.fiscalYear}-10-01`;
    if (rule && getRuleReadiness(rule).ready && approval?.evidence && approval.version === rule.ruleVersion && approval.version === indicator.ruleVersion && approval.from <= start && approval.until >= end) {
      const targetApproval = rule.hospitalTargetApproval;
      if (targetApproval?.source && targetApproval.unit === indicator.unit && targetApproval.from <= start && targetApproval.until >= end) return indicator;
      return { ...indicator, target: null, monthly: indicator.monthly.map((month) => ({ ...month, target: null, status: month.value === null ? 'no-data' : 'unbenchmarked' })), annual: { ...indicator.annual, target: null, status: indicator.annual.value === null ? 'no-data' : 'unbenchmarked' } };
    }
    return { ...indicator, dataSource: 'no-data', pendingReason: `rule-unapproved: ${rule ? [...getRuleReadiness(rule).missing, 'publication approval/version/effective period'].join(', ') : 'missing rule'}`,
      target: null, monthly: indicator.monthly.map((month) => ({ ...month, numerator: null, denominator: null, value: null, target: null, percentile: null, status: 'no-data' })),
      annual: { ...indicator.annual, numerator: null, denominator: null, value: null, target: null, status: 'no-data' },
    };
  });
  const availableCellCount = indicators.reduce((sum, indicator) => sum + indicator.monthly.filter((month) => month.denominator !== null || month.value !== null).length, 0);
  return { ...result, indicators, coverage: { ...result.coverage, availableCellCount, unavailableCellCount: result.coverage.coveredCellCount - availableCellCount, measuredIndicatorCount: indicators.filter((indicator) => indicator.dataSource === 'bms').length } };
}
