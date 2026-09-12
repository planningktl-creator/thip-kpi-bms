import { describe, expect, it } from 'vitest';
import { foundationRuleCodes, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { assertRegisteredReadOnlyQuery, foundationFamilyQueries, queryRegistry } from '@/services/queryRegistry';
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

  it('exposes one read-only foundation query per family', () => {
    const families = Object.keys(foundationFamilyQueries);
    expect(families.length).toBeGreaterThan(1);
    for (const [family, query] of Object.entries(foundationFamilyQueries)) {
      expect(() => assertRegisteredReadOnlyQuery(query), family).not.toThrow();


      expect(query.key).toMatch(/^thip[A-Za-z]+Foundation$/);
      expect(query.sql).toContain('expected_codes(indicator_code)');
      expect(query.sql).toContain('generate_series(');
    }
  });

  it('covers every foundation manifest code across the family queries', () => {
    const familySql = Object.values(foundationFamilyQueries).map((query) => query.sql).join('\n');
    for (const code of foundationRuleCodes) {
      expect(familySql, code).toContain(`'${code}' AS indicator_code`);
      expect(thipKpiRulesByCode.get(code)?.queryKey, code).toBe('thipIpdFoundation');
    }
  });

  it('keeps each family query scoped to its own codes', () => {
    const sepsis = foundationFamilyQueries.SEPSIS_ER!.sql;
    expect(sepsis).toContain("'CE0101' AS indicator_code");
    expect(sepsis).toContain("'CI0101' AS indicator_code");
    expect(sepsis).not.toContain("'DH0101' AS indicator_code");
  });

  it('preserves all 24 existing registered queries without regression', () => {
    const existing24 = [
      'DH0101', 'DH0101.1', 'DH0101.2', 'DH0102', 'DH0112',
      'DN0101', 'DN0107', 'DN0109', 'DN0302',
      'DR0101', 'DR0102', 'DR0403',
      'CE0101', 'CI0101',
      'DG0102', 'DG0202',
      'DC0401', 'DR0201', 'DG0201', 'DH0111', 'DR0301', 'DR0401', 'DG0101', 'CM0105',
    ];
    const allSql = Object.values(queryRegistry).map((q) => q.sql).join('\n');
    for (const code of existing24) {
      expect(allSql, `Indicator ${code} must remain present`).toContain(`'${code}' AS indicator_code`);
    }
  });

  it('enforces strictly dotless ICD-10 and ICD-9-CM codes across all registered queries', () => {
    const allQueries = [
      ...Object.values(queryRegistry),
      ...Object.values(foundationFamilyQueries),
    ];
    for (const query of allQueries) {
      // Dotted ICD-10 regex: e.g. 'I21.0', 'I50.9', 'J44.1', 'O82.0', 'E11.9', 'M16.1'
      expect(query.sql, `Query ${query.key} has dotted ICD-10`).not.toMatch(/'[A-Z][0-9]{2}\.[0-9]+'/i);
      // Dotted ICD-9-CM regex: e.g. '36.10', '81.51', '81.54', '68.3'
      expect(query.sql, `Query ${query.key} has dotted ICD-9`).not.toMatch(/'[0-9]{2}\.[0-9]+'/i);
    }
  });

  it('enforces zero PHI leakage in the outer projection of all registered queries', () => {
    const prohibitedPhi = ['hn', 'cid', 'patient_name', 'pname', 'fname', 'lname', 'birthday', 'addrpart'];
    for (const [key, query] of Object.entries(queryRegistry)) {
      if (key === 'versionProbe') continue;
      // Extract the final SELECT clause
      const lastSelectIndex = query.sql.lastIndexOf('SELECT');
      const outerProjection = query.sql.slice(lastSelectIndex);
      for (const phi of prohibitedPhi) {
        expect(outerProjection, `Query ${key} leaks PHI column ${phi}`).not.toMatch(new RegExp(`\\b${phi}\\b`, 'i'));
      }
    }
  });

  it('validates that every family foundation query passes read-only assertion', () => {
    for (const [family, query] of Object.entries(foundationFamilyQueries)) {
      expect(() => assertRegisteredReadOnlyQuery(query), `Family ${family} must be read-only`).not.toThrow();
      expect(query.sql).toMatch(/^(SELECT|WITH)\b/i);
      expect(query.sql).not.toMatch(/\b(insert|update|delete|drop|alter|truncate|create|grant|revoke)\b/i);
    }
  });

  describe('Milestone 1 clinical family query coverage', () => {
    it('covers Heart Failure indicators (DH0301, DH0302)', () => {
      const hf = foundationFamilyQueries.HEART_FAILURE;
      expect(hf, 'HEART_FAILURE foundation query must be defined').toBeDefined();
      expect(hf.sql).toContain("'DH0301' AS indicator_code");
      expect(hf.sql).toContain("'DH0302' AS indicator_code");
      expect(hf.sql).toContain('I50');
      expect(hf.sql).toContain('enalapril');
      expect(hf.sql).toContain('Z716');
    });

    it('covers CABG indicators (DH0201, DH0202, DH0203, DH0204)', () => {
      const cabg = foundationFamilyQueries.CABG;
      expect(cabg, 'CABG foundation query must be defined').toBeDefined();
      expect(cabg.sql).toContain("'DH0201' AS indicator_code");
      expect(cabg.sql).toContain("'DH0202' AS indicator_code");
      expect(cabg.sql).toContain("'DH0203' AS indicator_code");
      expect(cabg.sql).toContain("'DH0204' AS indicator_code");
      expect(cabg.sql).toContain('3610');
      expect(cabg.sql).toContain('T814');
      expect(cabg.sql).toContain('T826');
      expect(cabg.sql).toContain('BETWEEN 0 AND 3600');
    });

    it('covers Arthroplasty indicators (DO0202, DO0204, DO0205, DO0302, DO0303, DO0304)', () => {
      const arthro = foundationFamilyQueries.ARTHROPLASTY;
      expect(arthro, 'ARTHROPLASTY foundation query must be defined').toBeDefined();
      for (const code of ['DO0202', 'DO0204', 'DO0205', 'DO0302', 'DO0303', 'DO0304']) {
        expect(arthro.sql).toContain(`'${code}' AS indicator_code`);
      }
      expect(arthro.sql).toContain('8151');
      expect(arthro.sql).toContain('8154');
      expect(arthro.sql).toContain('T845');
      expect(arthro.sql).toContain("INTERVAL '90 days'");
      expect(arthro.sql).toContain("INTERVAL '365 days'");
    });

    it('covers Asthma & COPD expanded indicators (DR0302, DR0404, DR0403 with age_y >= 18)', () => {
      const copd = foundationFamilyQueries.ASTHMA_COPD;
      expect(copd.sql).toContain("'DR0302' AS indicator_code");
      expect(copd.sql).toContain("'DR0404' AS indicator_code");
      expect(copd.sql).toContain("'DR0301' AS indicator_code");
      expect(copd.sql).toContain("'DR0401' AS indicator_code");
      expect(copd.sql).toContain("'DR0403' AS indicator_code");
      expect(copd.sql).toContain("age_y >= 18 AND LEFT(pdx, 3) = 'J44'");
    });

    it('covers Maternal & Child indicators (CM0101, CM0104, CM0107, CM0109, CM0110, CM0116, CM0117, CM0118, CM0119, CM0201-CM0209, DE1601)', () => {
      const mc = foundationFamilyQueries.MATERNAL_CHILD;
      expect(mc, 'MATERNAL_CHILD foundation query must be defined').toBeDefined();
      const expectedCodes = [
        'CM0101', 'CM0104', 'CM0105', 'CM0107', 'CM0109', 'CM0110',
        'CM0116', 'CM0117', 'CM0118', 'CM0119',
        'CM0201', 'CM0202', 'CM0203', 'CM0204', 'CM0205', 'CM0206', 'CM0207', 'CM0208', 'CM0209',
        'DE1601',
      ];
      for (const code of expectedCodes) {
        expect(mc.sql).toContain(`'${code}' AS indicator_code`);
      }
      expect(mc.sql).toContain('O72');
      expect(mc.sql).toContain('O15');
      expect(mc.sql).toContain('O244');
      expect(mc.sql).toContain('683');
      expect(mc.sql).toContain('O342');
      expect(mc.sql).toContain('P210');
      expect(mc.sql).toContain('9541');
      expect(mc.sql).toContain('100000.0');
    });

    it('covers Diabetes & Hypertension indicators (DC0103, DC0107, DC0108, DC0108.1, DC0108.2, DC0201, DC0201.1, DC0201.2, DP0101, AA0104, AA0105)', () => {
      const dmHt = foundationFamilyQueries.DM_HT;
      expect(dmHt, 'DM_HT foundation query must be defined').toBeDefined();
      const expectedCodes = [
        'DC0103', 'DC0107', 'DC0108', 'DC0108.1', 'DC0108.2',
        'DC0201', 'DC0201.1', 'DC0201.2', 'DP0101', 'AA0104', 'AA0105',
      ];
      for (const code of expectedCodes) {
        expect(dmHt.sql).toContain(`'${code}' AS indicator_code`);
      }
      expect(dmHt.sql).toContain('8410');
      expect(dmHt.sql).toContain('hba1c');
      expect(dmHt.sql).toContain('bps <= 130');
      expect(dmHt.sql).toContain('bps <= 140');
      expect(dmHt.sql).toContain('100000.0');
    });

    it('keeps each family query strictly scoped to its own clinical indicators', () => {
      expect(foundationFamilyQueries.HEART_FAILURE.sql).not.toContain("'DH0201' AS indicator_code");
      expect(foundationFamilyQueries.CABG.sql).not.toContain("'DH0301' AS indicator_code");
      expect(foundationFamilyQueries.ARTHROPLASTY.sql).not.toContain("'DC0108' AS indicator_code");
    });
  });
});
