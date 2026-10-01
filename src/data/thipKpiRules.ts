import { thipRuleEvidenceByCode } from './thipRuleEvidence';
import { getRuleReadiness, type ThipKpiRule } from './thipRuleLogic';
import { thipKpiRules } from './thipRuleSource';
export { thipKpiRules } from './thipRuleSource';
export * from './thipRuleLogic';
/**
 * Merges curated evidence into the raw manifest. The manifest rows keep their
 * dictionary facts; evidence is attached by code so a rule cannot claim
 * readiness without a traceable source.
 */
export const thipKpiRulesWithEvidence: readonly ThipKpiRule[] = thipKpiRules.map((rule) => ({
  ...rule,
  ...thipRuleEvidenceByCode[rule.code],
}));

export const thipKpiRulesByCode = new Map(thipKpiRulesWithEvidence.map((rule) => [rule.code, rule]));

export const foundationRuleCodes = thipKpiRulesWithEvidence
  .filter((rule) => rule.status === 'foundation')
  .map((rule) => rule.code);

export const readyRuleCodes = thipKpiRulesWithEvidence
  .filter((rule) => getRuleReadiness(rule).ready)
  .map((rule) => rule.code);
