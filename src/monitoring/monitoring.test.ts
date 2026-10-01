import { afterEach, describe, expect, it, vi } from 'vitest';
import { createPreviewProvider } from '@/dev/monitoringPreview';
import { emptyMonitoring, loadMonitoring, unavailableCell, validateMonitoringRow } from './contract';
import { monitoringRules, monitoringRulesByCode } from './rules';
import { accumulateMonitoring, assessMonitoring } from './calculation';
import { monitoringCsv } from './export';
import { buildMonitoringQuery } from './provider';
import { assertRegisteredReadOnlyQuery } from '@/services/queryRegistry';
import { bangkokDate, getCurrentFiscalYear } from '@/utils/fiscal';
import { escapeCsv } from '@/utils/export';
import { getExpectedFiscalMonths } from '@/data/thipReporting';
import type { MonitoringRule, MonthlyMonitoringResult } from './types';

const now = new Date('2026-10-01T00:00:00Z');
const approvedRule: MonitoringRule = { ...monitoringRulesByCode.get('DH0101')!, approval: 'approved', approvalEvidence: 'synthetic-test-owner-signoff', effectiveFrom: '2025-10-01', effectiveTo: '2026-10-01' };
function measured(month = 1, numerator = 10, denominator = 100): MonthlyMonitoringResult {
  const row = unavailableCell(approvedRule, 2026, month, now);
  return { ...row, numerator, denominator, value: numerator / denominator * 100, dataStatus: 'measured', reason: null, dataThrough: row.periodStart, refreshedAt: now.toISOString(), assessment: 'no-target' };
}
afterEach(() => vi.unstubAllEnvs());
describe('independent monthly monitoring contract', () => {
  it('covers all 232 codes × 12 without changing the 1552 THIP cadence cells', () => {
    const snapshot = emptyMonitoring(2026, now);
    expect(snapshot.rows).toHaveLength(2784); expect(snapshot.measuredCells).toBe(0);
    expect(monitoringRules.reduce((sum, rule) => sum + getExpectedFiscalMonths(rule.code).length, 0)).toBe(1552);
    const counts = Object.fromEntries([...new Set(monitoringRules.map((rule) => rule.capability))].map((path) => [path, monitoringRules.filter((rule) => rule.capability === path).length]));
    expect(Object.values(counts).sort((a,b) => a-b)).toEqual([5,55,71,101]);
    expect(snapshot.rows.every((row) => row.reason && row.value === null && row.target === null)).toBe(true);
  });
  it('uses Bangkok fiscal boundaries even when UTC is still September', () => {
    expect(bangkokDate(new Date('2026-09-30T17:01:00Z'))).toBe('2026-10-01');
    expect(getCurrentFiscalYear(new Date('2026-09-30T16:59:59Z'))).toBe(2026);
    expect(getCurrentFiscalYear(new Date('2026-09-30T17:00:00Z'))).toBe(2027);
    const rows = emptyMonitoring(2027, now).rows.filter((row) => row.code === 'DH0101');
    expect(rows[0].dataStatus).toBe('rule-unapproved'); expect(rows[1].dataStatus).toBe('future');
    expect(rows[11].periodEnd).toBe('2027-10-01');
  });
  it('publishes no draft rule even when the source has measured facts', () => {
    const row = validateMonitoringRow(measured(), 2026, monitoringRulesByCode, false, now);
    expect(row).toMatchObject({ value: null, numerator: null, dataStatus: 'rule-unapproved' });
  });
  it('requires approval evidence and an effective rule for the selected month', () => {
    for (const rule of [{ ...approvedRule, approvalEvidence: null }, { ...approvedRule, effectiveFrom: '2026-01-01' }]) {
      expect(validateMonitoringRow(measured(), 2026, new Map([[rule.code, rule]]), false, now)).toMatchObject({value: null, dataStatus: 'rule-unapproved', reason: expect.stringContaining('effective period')});
    }
    expect(validateMonitoringRow(measured(), 2026, new Map([[approvedRule.code, approvedRule]]), false, now).value).toBe(10);
  });
  it.each(['minute','day','month','hour-per-person'])('preserves %s unit metadata independently of the legacy ratio unit', (unit) => {
    expect(monitoringRules.some((rule) => rule.unit === unit)).toBe(true);
  });
  it('rejects duplicate cells, PHI fields and malformed periods', async () => {
    const provider = createPreviewProvider(now); const data = await provider.load(2026, new AbortController().signal);
    await expect(loadMonitoring({ ...provider, load: async () => [data[0], data[0]] }, 2026, new AbortController().signal, now)).rejects.toThrow('Duplicate');
    expect(() => validateMonitoringRow({ ...measured(), hn: 'synthetic-prohibited-field' }, 2026)).toThrow('fields');
    expect(() => validateMonitoringRow({ ...measured(), fiscalMonth: 2 }, 2026)).toThrow('period');
    expect(() => validateMonitoringRow({ ...measured(), periodEnd: '2025-11-31' }, 2026)).toThrow('ISO');
  });
  it('rejects invalid status, unit, version, NaN and zero-denominator rates', () => {
    for (const patch of [{ dataStatus: 'missing' }, { unit: 'minute' }, { ruleVersion: 'wrong' }, { value: NaN }, { denominator: 0 }, { dataThrough: '2026-10-02' }, { synthetic: true }]) {
      expect(() => validateMonitoringRow({ ...measured(), ...patch }, 2026, new Map([[approvedRule.code, approvedRule]]), false, now)).toThrow();
    }
  });
  it('allows observation coverage across a month/year while retaining its original cohort month', () => {
    const row = { ...measured(3), dataThrough: '2026-01-30' };
    expect(validateMonitoringRow(row, 2026, new Map([[approvedRule.code, approvedRule]]), false, now).periodStart).toBe('2025-12-01');
  });
  it('keeps zero cohort separate from missing source and target-only data', () => {
    const ruleMap = new Map([[approvedRule.code, approvedRule]]);
    const zero = { ...measured(), numerator: 0, denominator: 0, value: null, dataStatus: 'zero-cohort' as const };
    expect(validateMonitoringRow(zero, 2026, ruleMap, false, now).assessment).toBe('not-assessable');
    expect(() => validateMonitoringRow({ ...zero, value: 0 }, 2026, ruleMap, false, now)).toThrow('Zero cohort');
    expect(emptyMonitoring(2026, now).measuredCells).toBe(0);
  });
  it('loads labelled synthetic scenarios for all representative codes', async () => {
    const result = await loadMonitoring(createPreviewProvider(now), 2026, new AbortController().signal, now);
    expect(result.preview).toBe(true); expect(result.rows).toHaveLength(2784); expect(result.measuredCells).toBe(70);
    for (const code of ['DH0101','DH0112','CE0102','HH0102','SH0101','SM0201','DE1601']) {
      expect(result.rows.find((row) => row.code === code && row.fiscalMonth === 1)?.dataStatus).toBe('measured');
    }
    expect(result.rows.find((row) => row.code === 'SH0101')!.formula).toContain('PREVIEW ONLY');
    expect(monitoringRulesByCode.get('SH0101')!.formula).toContain('ห้ามแบ่ง');
  });
  it('rejects preview in production and any production rule override', async () => {
    vi.stubEnv('DEV', false);
    await expect(loadMonitoring(createPreviewProvider(now), 2026, new AbortController().signal)).rejects.toThrow('prohibited');
    await expect(loadMonitoring({ preview: false, rules: new Map(), load: async () => [] }, 2026, new AbortController().signal)).rejects.toThrow('manifest');
  });
  it('cancels a stale provider response before assembling its snapshot', async () => {
    const controller = new AbortController();
    await expect(loadMonitoring({ preview: false, load: async () => { controller.abort(); return []; } }, 2026, controller.signal)).rejects.toMatchObject({ name: 'AbortError' });
  });
  it('registers only explicit aggregate columns with safe source identifiers', () => {
    expect(() => buildMonitoringQuery('reporting.view;drop table')).toThrow();
    expect(() => assertRegisteredReadOnlyQuery(buildMonitoringQuery('reporting.thip_monthly_monitoring'))).not.toThrow();
    expect(buildMonitoringQuery('reporting.thip_monthly_monitoring').sql).not.toContain('SELECT *');
  });
});
describe('monitoring accumulation and targets', () => {
  it('weights ratios instead of averaging percentages and preserves incomplete YTD', () => {
    const rows = [measured(1,10,100), measured(2,10,20)];
    expect(accumulateMonitoring(rows, approvedRule).value).toBeCloseTo(16.6667);
    expect(accumulateMonitoring([...rows, unavailableCell(approvedRule,2026,3,now)], approvedRule).value).toBeNull();
  });
  it('uses fixed denominator once and fails closed if it changes', () => {
    const rule = { ...approvedRule, accumulation: 'fixed-denominator' as const };
    expect(accumulateMonitoring([measured(1,10,100),measured(2,20,100)],rule).value).toBe(30);
    expect(accumulateMonitoring([measured(1,10,100),measured(2,20,200)],rule).value).toBeNull();
  });
  it('sums counts, takes snapshots and uses database distinct/custom aggregates', () => {
    const rows = [measured(1,10,100),measured(2,20,100)];
    expect(accumulateMonitoring(rows,{...approvedRule,accumulation:'count'}).value).toBe(30);
    expect(accumulateMonitoring(rows,{...approvedRule,accumulation:'snapshot'}).value).toBe(20);
    rows[1].cumulative = { numerator: 25, denominator: 120, value: 25/120*100, through: rows[1].dataThrough, complete: true };
    expect(accumulateMonitoring(rows,{...approvedRule,accumulation:'distinct-cohort'})).toEqual(rows[1].cumulative);
    expect(accumulateMonitoring(rows,{...approvedRule,accumulation:'custom'})).toEqual(rows[1].cumulative);
  });
  it('handles zero targets, high/low, range watch only when configured, and NULL targets', () => {
    const row = measured(); row.target = { value: 0, lower: 8, upper: 9, unit: row.unit, source: 'synthetic-test-target', kind: 'hospital', validFrom: row.periodStart, validTo: row.periodEnd, mappingConfirmed: true };
    expect(assessMonitoring(row, { ...approvedRule, direction:'higher-is-better' })).toBe('on-track');
    expect(assessMonitoring(row, { ...approvedRule, direction:'lower-is-better' })).toBe('action');
    expect(assessMonitoring(row, { ...approvedRule, direction:'range',watchMargin:null })).toBe('action');
    expect(assessMonitoring(row, { ...approvedRule, direction:'range',watchMargin:2 })).toBe('watch');
    row.target = null; expect(assessMonitoring(row, approvedRule)).toBe('no-target');
  });
  it('rejects unconfirmed, mismatched-unit and expired targets', () => {
    const row = measured(); const target = { value: 5, lower: null, upper: null, unit: 'percent', source: 'synthetic-test', kind: 'hospital', validFrom: row.periodStart, validTo: row.periodEnd, mappingConfirmed: true };
    for (const patch of [{ mappingConfirmed: false },{ unit: 'day' },{ source: '' },{validTo: row.periodStart}]) {
      expect(() => validateMonitoringRow({...row,target:{...target,...patch}},2026,new Map([[approvedRule.code,approvedRule]]),false,now)).toThrow('hospital target');
    }
  });
  it('exports all twelve filtered months, reasons and series with a preview filename marker payload', async () => {
    const snapshot = await loadMonitoring(createPreviewProvider(now),2026,new AbortController().signal,now);
    const rows = snapshot.rows.filter((row) => row.code === 'DH0101');
    const csv = monitoringCsv(snapshot,rows,2026);
    expect(csv.split('\r\n')).toHaveLength(13); expect(csv).toContain('SYNTHETIC DEVELOPMENT PREVIEW');
    expect(csv).toContain('missing-source'); expect(csv).toContain('period_end_exclusive');
    const lines = csv.replace(/^\uFEFF/, '').split('\r\n').map((line) => line.split(','));
    const column = (name: string) => lines[1][lines[0].indexOf(name)];
    expect(column('period_start')).toBe('2025-10-01');
    expect(column('period_start_be')).toBe('1 ต.ค. พ.ศ. 2568');
    expect(column('period_end_exclusive_be')).toBe('1 พ.ย. พ.ศ. 2568');
    expect(column('refreshed_at_be')).toContain('พ.ศ. 2569');
    expect(() => monitoringCsv(snapshot,rows,2025)).toThrow('year mismatch');
    expect(escapeCsv('=HYPERLINK("synthetic")')).toContain("'=HYPERLINK");
    expect(escapeCsv('  @synthetic')).toBe("'  @synthetic"); expect(escapeCsv(-1)).toBe('-1');
  });
});
