import { describe, expect, it } from 'vitest';
import {
  branchExternal,
  branchFact,
  branchIpd,
  extendedBaseCte,
  isExternalBranch,
} from '@/services/thipFamilyBase';

describe('THIP family SQL plumbing', () => {
  it('buckets monthly facts to calendar months with the contract columns', () => {
    const sql = branchIpd('DH0101', 'COUNT(*)', 'COUNT(*)', 'ROUND(COUNT(*) * 100.0 / NULLIF(COUNT(*), 0), 2)', 'TRUE');
    expect(sql).toContain("'DH0101' AS indicator_code");
    expect(sql).toContain('AS period_start');
    expect(sql).toContain('AS fiscal_month');
    expect(sql).toContain('AS fiscal_year');
    expect(sql).toContain('AS numerator');
    expect(sql).toContain('AS denominator');
    expect(sql).toContain('AS value');
    expect(sql).toContain('FROM periodized');
    expect(sql).toMatch(/GROUP BY 2, 3, 4/);
    // Monthly anchor: no quarter collapsing.
    expect(sql).not.toContain('/ 3');
  });

  it('buckets quarterly facts to anchors 1/4/7/10 and starts of the quarter', () => {
    // DH0110 is a quarterly code per the reporting cadence registry.
    const sql = branchFact('DH0110', 'COUNT(*)', 'COUNT(*)', 'COUNT(*)', 'TRUE');
    // Division-free anchor mapping keeps every SQL division NULLIF-guarded.
    expect(sql).toMatch(/CASE WHEN \(.+\) <= 3 THEN 1 WHEN \(.+\) <= 6 THEN 4 WHEN \(.+\) <= 9 THEN 7 ELSE 10 END/);
    expect(sql).not.toMatch(/\/\s*\d/);
    expect(sql).toContain('MAKE_INTERVAL(months =>');
  });

  it('buckets semiannual facts to anchors 1/7 and annual facts to anchor 1', () => {
    const semiannual = branchFact('DC0108', 'COUNT(*)', 'COUNT(*)', 'COUNT(*)', 'TRUE');
    expect(semiannual).toMatch(/CASE WHEN \(.+\) <= 6 THEN 1 ELSE 7 END/);

    const annual = branchFact('AA0101', 'COUNT(*)', 'COUNT(*)', 'COUNT(*)', 'TRUE');
    expect(annual).toMatch(/AS period_start,\s+1 AS fiscal_month/);
    expect(annual).toContain('MAKE_INTERVAL(months =>');
  });

  it('renders external-fact branches from the staging contract without bucketing', () => {
    const sql = branchExternal('SF0101');
    expect(sql).toContain("'SF0101' AS indicator_code");
    expect(sql).toContain('FROM external_facts');
    expect(sql).toContain('WHERE indicator_code = \'SF0101\'');
    expect(isExternalBranch(sql)).toBe(true);
    expect(isExternalBranch(branchIpd('DH0101', 'COUNT(*)', 'COUNT(*)', 'COUNT(*)', 'TRUE'))).toBe(false);
  });

  it('keeps raw patient identifiers out of every branch projection', () => {
    const sql = branchFact('DR0101', 'COUNT(*)', 'COUNT(*)', 'COUNT(*)', 'TRUE', { source: 'opd_periodized' });
    const outer = sql.slice(sql.indexOf('SELECT'), sql.indexOf('FROM'));
    for (const phi of ['hn', 'an', 'vn', 'cid', 'patient_name', 'birthdate']) {
      expect(outer).not.toMatch(new RegExp(`\\b${phi}\\b`, 'i'));
    }
  });

  it('includes hospital-loaded external facts only when requested', () => {
    expect(extendedBaseCte(false)).not.toContain('external_facts');
    const withExternal = extendedBaseCte(true);
    expect(withExternal).toContain('external_facts AS (');
    expect(withExternal).toContain('reporting.thip_external_facts');
    // The shared bases expose period anchors for cadence bucketing.
    for (const base of ['opd_periodized', 'chronic_periodized', 'delivery_periodized', 'newborn_periodized', 'emp_periodized']) {
      expect(withExternal).toContain(`${base} AS (`);
    }
  });

  it('accepts extra join lines and custom sources', () => {
    const sql = branchFact('SM0102', 'COUNT(*)', 'COUNT(*)', 'COUNT(*)', 'TRUE', {
      source: 'opd_periodized',
      join: 'JOIN stock_trancation st ON st.vn = opd_periodized.vn',
    });
    expect(sql).toContain('FROM opd_periodized');
    expect(sql).toContain('JOIN stock_trancation st ON st.vn = opd_periodized.vn');
  });
});
