import { describe, expect, it } from 'vitest';
import { foundationRuleCodes } from '@/data/thipKpiRules';
import { assertRegisteredReadOnlyQuery, queryRegistry } from '@/services/queryRegistry';
import { buildCompletenessAuditQuery, buildDuplicateCheckQuery } from '@/services/bmsData';

describe('BMS query registry', () => {
  it('accepts the registered read-only probes', () => {
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.versionProbe)).not.toThrow();
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.ipdMonthlyFoundation)).not.toThrow();
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.thipIpdFoundation)).not.toThrow();
    const sql = queryRegistry.thipIpdFoundation.sql;
    expect(sql).toContain('has_acs_sdx');
    expect(sql).toContain('died_from_acs');
    expect(sql).toContain('has_stemi_sdx');
    expect(sql).toContain('died_from_stemi');
    expect(sql).toContain('has_nste_sdx');
    expect(sql).toContain('died_from_nste');
    expect(sql).toContain('died_within_48h');
    expect(sql).toContain('has_ce0101_sepsis');
    expect(sql).toContain('has_ci0101_sepsis');
    expect(sql).toContain('i.regdate');
    expect(sql).toContain('i.regtime');
    expect(sql).toContain('CE0101');
    expect(sql).toContain('CI0101');
    expect(sql).toContain('DH0102');
    expect(sql).toContain('DH0101.1');
    expect(sql).toContain('DH0101.2');
    expect(sql).toContain("'DG0102' AS indicator_code");
    expect(sql).toContain('DG0202');
    expect(sql).toContain('DR0403');
    expect(sql).toContain('DR0102');
    expect(sql).toContain('DN0107');
    expect(sql).toContain('DH0112');
    expect(sql).toContain('DN0109');
    expect(sql).toContain("'DN0302' AS indicator_code");
    expect(sql).toContain('expected_codes(indicator_code)');
    expect(sql).toContain('generate_series(');
    expect(sql).toContain('COALESCE(facts.denominator, 0)');
  });

  it('normalizes ICD-10 to dotless codes so dotted or dotless database values match', () => {
    const sql = queryRegistry.thipIpdFoundation.sql;
    expect(sql).toContain("REPLACE(UPPER(TRIM(s.pdx)), '.', '') AS pdx");
    expect(sql).toContain("'I210'");
    expect(sql).toContain("'J100'");
    expect(sql).toContain("'A400'");
    expect(sql).toContain("'R572'");
    expect(sql).not.toContain("'I21.0'");
    expect(sql).not.toContain("'J10.0'");
  });

  it('uses the PDF-token sepsis code sets for CE0101 and CI0101 separately', () => {
    const sql = queryRegistry.thipIpdFoundation.sql;
    expect(sql).toContain("'A400', 'A419', 'R572', 'R651'");
    expect(sql).toContain("'A400', 'A409', 'A410', 'A419', 'R572', 'R651'");
  });

  it('keeps STEMI and NSTE-ACS mortality cohorts separate', () => {
    const sql = queryRegistry.thipIpdFoundation.sql;
    expect(sql).toContain("'DH0101.1' AS indicator_code");
    expect(sql).toContain("'DH0101.2' AS indicator_code");
    expect(sql).toContain("pdx IN ('I210', 'I211', 'I212', 'I213')");
    expect(sql).toContain("pdx IN ('I214', 'I219')");
    expect(sql).toContain("pdx IN ('I210', 'I211', 'I212', 'I213') OR has_stemi_sdx");
    expect(sql).toContain("pdx IN ('I214', 'I219') OR has_nste_sdx");
    expect(sql).toContain("pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') OR has_acs_sdx");
  });

  it('uses admission and death timestamps for head-injury mortality within 48 hours', () => {
    const sql = queryRegistry.thipIpdFoundation.sql;
    expect(sql).toContain("'DN0302' AS indicator_code");
    expect(sql).toContain("pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')");
    expect(sql).toContain("INTERVAL '48 hours'");
  });

  it('keeps every foundation manifest code backed by a SQL branch', () => {
    const sql = queryRegistry.thipIpdFoundation.sql;
    for (const code of foundationRuleCodes) {
      expect(sql).toContain(`'${code}' AS indicator_code`);
    }
  });

  it('accepts the registered source-view audit queries as read-only', () => {
    const completeness = buildCompletenessAuditQuery('thip_kpi_monthly');
    const duplicates = buildDuplicateCheckQuery('thip_kpi_monthly');
    expect(() => assertRegisteredReadOnlyQuery(completeness)).not.toThrow();
    expect(() => assertRegisteredReadOnlyQuery(duplicates)).not.toThrow();
    expect(completeness.sql).toContain('completeness_status');
    expect(completeness.sql).toContain('"thip_kpi_monthly"');
    expect(duplicates.sql).toContain('HAVING COUNT(*) <> 1');
  });

  it('rejects write statements even if someone adds one to a query object', () => {
    expect(() => assertRegisteredReadOnlyQuery({
      key: 'bad',
      description: 'test',
      sql: 'UPDATE ipt SET drg = :drg',
    })).toThrow(/read-only/);
  });
});
