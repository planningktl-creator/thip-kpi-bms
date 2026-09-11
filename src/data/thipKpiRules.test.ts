import { describe, expect, it } from 'vitest';
import {
  assertRuleReadiness,
  foundationRuleCodes,
  getFormulaScale,
  getRuleReadiness,
  getRuleUnit,
  readyRuleCodes,
  thipKpiRules,
  thipKpiRulesByCode,
  thipKpiRulesWithEvidence,
} from '@/data/thipKpiRules';

describe('THIP KPI rule manifest', () => {
  it('contains one rule for every dictionary indicator', () => {
    expect(thipKpiRules).toHaveLength(232);
    expect(new Set(thipKpiRules.map((rule) => rule.code)).size).toBe(232);
    expect(thipKpiRulesByCode.get('AA0101')?.status).toBe('needs-local-mapping');
    expect(thipKpiRulesByCode.get('DH0101')?.status).toBe('foundation');
  });

  it('keeps the executable foundation list aligned with the manifest', () => {
    expect(foundationRuleCodes).toHaveLength(16);
    expect(foundationRuleCodes).toEqual(expect.arrayContaining([
      'DH0101', 'DH0101.1', 'DH0101.2', 'DN0101', 'DR0101', 'CE0101', 'CI0101', 'DH0102',
      'DG0102', 'DG0202', 'DR0403', 'DR0102', 'DN0107', 'DH0112', 'DN0109', 'DN0302',
    ]));
  });

  it('derives display units from formula scale without deriving values', () => {
    expect(getRuleUnit({ formulaScale: 'a/b x 100,000' })).toBe('rate');
    expect(getRuleUnit({ formulaScale: 'a/b x 100' })).toBe('percent');
    expect(getRuleUnit({ formulaScale: 'a/b' })).toBe('ratio');
  });

  it('preserves the formula multiplier for rate calculations', () => {
    expect(getFormulaScale('a/b x 100')).toBe(100);
    expect(getFormulaScale('a/b × 1,000')).toBe(1000);
    expect(getFormulaScale('a/b x 100,000')).toBe(100000);
    expect(getFormulaScale('a/b')).toBe(1);
  });

  it('attaches curated evidence to every foundation rule', () => {
    for (const code of foundationRuleCodes) {
      const rule = thipKpiRulesByCode.get(code)!;
      expect(rule.episodeGrain, code).toBeTruthy();
      expect(rule.periodField, code).toBeTruthy();
      expect(rule.codeSetVersion, code).toBeTruthy();
      expect(rule.ruleVersion, code).toBeTruthy();
      expect(rule.evidence?.length, code).toBeGreaterThan(0);
    }
  });

  it('does not publish any rule as ready without complete evidence', () => {
    expect(readyRuleCodes).toHaveLength(0);
    for (const rule of thipKpiRulesWithEvidence) {
      expect(() => assertRuleReadiness(rule), rule.code).not.toThrow();
      if (rule.status === 'ready') {
        expect(getRuleReadiness(rule).ready, rule.code).toBe(true);
      }
    }
  });

  it('reports missing evidence fields for a not-yet-ready rule', () => {
    const readiness = getRuleReadiness(thipKpiRulesByCode.get('DH0101')!);
    expect(readiness.ready).toBe(false);
    expect(readiness.missing).toContain('owner');
  });
});
