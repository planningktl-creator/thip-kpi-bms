import { describe, expect, it } from 'vitest';
import { parseCtes, requiredCtes } from './thipCtePlan';
import { ThipStepLoader, planThipSteps } from './thipStepLoader';
import { runtimeRulesByCode, runtimeSignatures, runtimeMonitoringRules } from '@/data/thipRuntime';
import { thipKpiRulesByCode } from '@/data/thipKpiRules';
import { getRuleReadiness } from '@/data/thipRuleLogic';
import { monitoringRules } from '@/monitoring/ruleSource';
import { createHash } from 'node:crypto';
import { MemoryCacheRepository, type CacheEntry } from './thipStepCache';
import { recordAppPerformance, getAppPerformance, clearAppPerformance } from './appPerformance';

describe('performance boundaries preserve data truth', () => {
  it('prunes only unreachable CTEs and ignores relation words in literals/comments', () => {
    const ctes = parseCtes("WITH base AS (SELECT 1 n), keep AS (SELECT * FROM base), unused AS (SELECT 'FROM keep, (x)' value), fiscal_periods AS (SELECT 1 m)");
    expect(requiredCtes(ctes, ['SELECT * FROM keep /* JOIN unused */']).map(cte => cte.name)).toEqual(['base', 'keep', 'fiscal_periods']);
    expect(requiredCtes(ctes, ["SELECT 'FROM unused' FROM keep"]).map(cte => cte.name)).toEqual(['base', 'keep', 'fiscal_periods']);
    expect(() => parseCtes('WITH bad AS (SELECT 1')).toThrow();
  });
  it('runtime rules retain every readiness/publication field and hash full evidence', () => {
    expect(runtimeRulesByCode.size).toBe(232);
    expect(runtimeMonitoringRules).toEqual(monitoringRules);
    for (const [code, rule] of thipKpiRulesByCode) {
      const { cohortDefinition, ...compact } = rule;
      expect(runtimeRulesByCode.get(code)).toEqual(compact);
      expect(getRuleReadiness(runtimeRulesByCode.get(code)!)).toEqual(getRuleReadiness(rule));
    }
    const digest = (value: string) => createHash('sha256').update(value).digest('hex');
    for (const plan of planThipSteps(2026)) {
      const signature = runtimeSignatures.find(entry => entry.code === plan.code)!;
      expect(signature.sqlHash).toBe(digest(plan.query.sql));
      expect(signature.ruleHash).toBe(digest(JSON.stringify(thipKpiRulesByCode.get(plan.code))));
      expect(plan.start).toBe('2025-10-01'); expect(plan.end).toBe('2026-10-01');
      expect(plan.query.sql).not.toMatch(/^WITH\s*,/);
    }
  });
  it('shares unchanged progress rows and prevents mutation of emitted facts', async () => {
    const loader = new ThipStepLoader(2026, [{ code: 'DH0101', run: async () => [{ indicator_code: 'DH0101', fiscal_year: 2026, fiscal_month: 1, period_start: '2025-10-01', numerator: 1, denominator: 10, value: 10 }] }], () => {}, 0, ['DE1601']);
    const before = loader.snapshot(); await loader.start(); const after = loader.snapshot();
    expect(before.steps[1]).toBe(after.steps[1]); expect(before.steps[0]).not.toBe(after.steps[0]);
    expect(Object.isFrozen(after.steps[0].rows[0])).toBe(true);
    expect(loader.snapshot().steps[0]).toBe(after.steps[0]);
  });
  it('bulk cache reads preserve requested order and cannot mutate repository state', async () => {
    const repository = new MemoryCacheRepository();
    const entry: CacheEntry = { key: 'first', scope: 'context', version: 2, fiscalYear: 2026, code: 'DH0101', fingerprint: 'digest', ruleVersion: 'unapproved', observedAt: '2026-10-01T00:00:00Z', expiresAt: 0, facts: [] };
    const signal = new AbortController().signal;
    await repository.write(entry, signal);
    await repository.write({ ...entry, key: 'second', code: 'DH0112' }, signal);
    const results = await repository.readMany(['second', 'missing', 'first']);
    expect(results).toEqual([{ ...entry, key: 'second', code: 'DH0112' }, undefined, entry]);
    results[0]!.code = 'CHANGED';
    expect((await repository.read('second'))?.code).toBe('DH0112');
  });
  it('bounds diagnostics and rejects identifiers/URLs outside the allowlist', () => {
    clearAppPerformance();
    recordAppPerformance({ phase: 'query', key: 'https://unsafe/?token=secret', durationMs: 1, success: false });
    expect(getAppPerformance()).toHaveLength(0);
    for (let index = 0; index < 300; index++) recordAppPerformance({ phase: 'cache-read', key: 'thip-report', durationMs: index, success: true });
    expect(getAppPerformance()).toHaveLength(256); clearAppPerformance();
  });
});
