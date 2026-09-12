import { describe, expect, it } from 'vitest';
import { queryRegistry, foundationFamilyQueries, RegisteredQuery } from '@/services/queryRegistry';
import { registeredRuleCodes, thipImplementationByCode } from '@/data/thipImplementation';
import { thipKpiRulesByCode } from '@/data/thipKpiRules';

function splitTopLevel(str: string, delimiter = ','): string[] {
  const parts: string[] = [];
  let current = '';
  let depth = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    if (char === '(') depth++;
    else if (char === ')') depth--;
    if (char === delimiter && depth === 0) {
      parts.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  if (current.trim()) parts.push(current.trim());
  return parts;
}

function getOuterProjectedColumns(sql: string): { expression: string; alias: string }[] {
  const lastSelectIdx = sql.lastIndexOf('SELECT');
  if (lastSelectIdx === -1) return [];
  const outer = sql.slice(lastSelectIdx);
  const fromMatch = outer.match(/SELECT([\s\S]+?)(?:\bFROM\b|$)/i);
  if (!fromMatch) return [];
  const rawCols = splitTopLevel(fromMatch[1]);
  return rawCols.map((raw) => {
    const asMatch = raw.match(/(?:AS\s+)?([a-zA-Z0-9_]+)$/i);
    const alias = asMatch ? asMatch[1].toLowerCase() : raw.toLowerCase();
    const cleanAlias = alias.includes('.') ? alias.split('.').pop()! : alias;
    return { expression: raw.trim(), alias: cleanAlias };
  });
}

describe('EMPIRICAL CHALLENGER: Milestone 1 Security & Boundary Invariants', () => {
  const allQueries: Record<string, RegisteredQuery> = {
    ...queryRegistry,
    ...foundationFamilyQueries,
  };

  // ----------------------------------------------------
  // Invariant 1: Outer SELECT Projections & Zero PHI Emission
  // ----------------------------------------------------
  describe('Invariant 1: Outer SELECT Projections & Zero PHI Emission', () => {
    const forbiddenPhiIdentifiers = [
      'hn', 'an', 'vn', 'cid', 'pname', 'fname', 'lname', 'patient_name',
      'birthday', 'birth_date', 'addrpart', 'moopart', 'bloodgrp', 'nationality'
    ];

    const allowedFoundationColumns = new Set([
      'indicator_code',
      'period_start',
      'fiscal_month',
      'fiscal_year',
      'numerator',
      'denominator',
      'value',
    ]);

    for (const [key, q] of Object.entries(allQueries)) {
      it(`Query "${key}" projects strictly NO PHI aliases or raw identifiers in outer SELECT`, () => {
        const columns = getOuterProjectedColumns(q.sql);
        expect(columns.length, `Query ${key} has no projected columns`).toBeGreaterThan(0);

        for (const col of columns) {
          // 1. Alias must not be a PHI identifier
          for (const phi of forbiddenPhiIdentifiers) {
            expect(col.alias, `Query ${key} emitted PHI column alias "${col.alias}"`).not.toBe(phi);
          }

          // 2. Expression must not emit a raw unaggregated PHI column
          for (const phi of forbiddenPhiIdentifiers) {
            const rawColPattern = new RegExp(`^(?:[a-zA-Z0-9_]+\\.)?${phi}$`, 'i');
            expect(col.expression, `Query ${key} projects raw unaggregated PHI: "${col.expression}"`).not.toMatch(rawColPattern);
          }
        }
      });

      if (key !== 'versionProbe' && key !== 'ipdMonthlyFoundation') {
        it(`Foundation query "${key}" projects EXACTLY the contract columns in outer SELECT`, () => {
          const columns = getOuterProjectedColumns(q.sql);
          const aliases = columns.map((c) => c.alias);

          // 1. Verify NO unexpected extra columns
          for (const alias of aliases) {
            expect(allowedFoundationColumns.has(alias), `Query ${key} projected unexpected column: ${alias}`).toBe(true);
          }

          // 2. Verify ALL required foundation columns are present
          for (const required of allowedFoundationColumns) {
            expect(aliases, `Query ${key} is missing required column: ${required}`).toContain(required);
          }

          // 3. Exactly 7 contract columns: indicator_code, period_start, fiscal_month, fiscal_year, numerator, denominator, value
          expect(aliases.length, `Query ${key} should project exactly 7 contract columns`).toBe(7);
        });
      }
    }
  });

  // ----------------------------------------------------
  // Invariant 2: Division-by-Zero Protection & Zero Cohort Handling
  // ----------------------------------------------------
  describe('Invariant 2: Division-by-Zero & Zero-Cohort Handling', () => {
    it('all division operations in foundation queries are guarded by NULLIF(..., 0)', () => {
      let divisionCount = 0;
      for (const [key, q] of Object.entries(allQueries)) {
        if (key === 'versionProbe' || key === 'ipdMonthlyFoundation') continue;
        const sql = q.sql;
        const divRegex = /\s*\/\s*([^,\n\r)]+)/g;
        let match;
        while ((match = divRegex.exec(sql)) !== null) {
          divisionCount++;
          const denominatorExpr = match[1].trim();
          const context = sql.slice(Math.max(0, match.index - 30), match.index + 100);
          const hasNullif = denominatorExpr.includes('NULLIF') || context.includes('NULLIF');
          expect(hasNullif, `Query ${key} division at index ${match.index} lacks NULLIF guard: ${context}`).toBe(true);
        }
      }
      expect(divisionCount, 'Should have verified multiple division operations').toBeGreaterThan(20);
    });

    it('buildFoundationQuery ensures zero-cohort preservation and correct 0 facts / NULL rate', () => {
      const sql = queryRegistry.thipIpdFoundation.sql;

      // CROSS JOIN ensures complete matrix of expected_codes x fiscal_periods
      expect(sql).toContain('expected_codes\n      CROSS JOIN fiscal_periods');

      // LEFT JOIN facts ensures zero-cohort periods have rows
      expect(sql).toContain('LEFT JOIN facts');

      // Numerator & denominator coalesce to 0
      expect(sql).toContain('COALESCE(facts.numerator, 0) AS numerator');
      expect(sql).toContain('COALESCE(facts.denominator, 0) AS denominator');

      // facts.value is NOT coalesced to 0 (must remain NULL when 0/0)
      expect(sql).toMatch(/facts\.value\s+FROM expected_codes/);
    });
  });

  // ----------------------------------------------------
  // Invariant 3: Backward Compatibility of 24 Original Indicators
  // ----------------------------------------------------
  describe('Invariant 3: Backward Compatibility of Original 24 Indicators', () => {
    const original24Codes = [
      'DH0101', 'DH0101.1', 'DH0101.2', 'DH0102', 'DH0112',
      'DN0101', 'DN0107', 'DN0109', 'DN0302',
      'DR0101', 'DR0102', 'DR0403',
      'CE0101', 'CI0101',
      'DG0102', 'DG0202',
      'DC0401', 'DR0201', 'DG0201', 'DH0111', 'DR0301', 'DR0401', 'DG0101', 'CM0105',
    ];

    it('all 24 original indicator codes remain registered in implementation manifest', () => {
      for (const code of original24Codes) {
        expect(registeredRuleCodes, `Indicator ${code} must be in registeredRuleCodes`).toContain(code);
        const impl = thipImplementationByCode.get(code);
        expect(impl, `Implementation entry for ${code} must exist`).toBeDefined();
        expect(impl?.tier, `Indicator ${code} tier must be registered`).toBe('registered');
      }
    });

    it('all 24 original indicators are present in thipIpdFoundation SQL', () => {
      const sql = queryRegistry.thipIpdFoundation.sql;
      for (const code of original24Codes) {
        expect(sql, `Indicator ${code} must have SQL branch in thipIpdFoundation`).toContain(`'${code}' AS indicator_code`);
      }
    });

    it('all 24 original indicators have valid rule definition in thipKpiRulesByCode', () => {
      for (const code of original24Codes) {
        const rule = thipKpiRulesByCode.get(code);
        expect(rule, `Rule for ${code} must exist`).toBeDefined();
        expect(rule?.code).toBe(code);
      }
    });

    it('thipIpdDrgResultFoundation preserves all 14 pdx-only original indicators', () => {
      const drgSql = queryRegistry.thipIpdDrgResultFoundation.sql;
      const expectedDrgCodes = [
        'DH0101', 'DH0101.1', 'DH0101.2', 'DN0101', 'DR0101', 'DR0403',
        'DR0201', 'DG0202', 'DN0302', 'DC0401', 'CI0101', 'DN0107', 'DR0102', 'DG0101'
      ];
      for (const code of expectedDrgCodes) {
        expect(drgSql, `DRG variant must include ${code}`).toContain(`'${code}' AS indicator_code`);
      }
    });
  });

  // ----------------------------------------------------
  // Invariant 4: Dotless Code Invariant
  // ----------------------------------------------------
  describe('Invariant 4: Strictly Dotless ICD-10 and ICD-9 Codes', () => {
    for (const [key, q] of Object.entries(allQueries)) {
      it(`Query "${key}" has strictly NO dotted ICD-10 or ICD-9 codes`, () => {
        expect(q.sql, `Query ${key} contains dotted ICD-10`).not.toMatch(/'[A-Z][0-9]{2}\.[0-9]+'/i);
        expect(q.sql, `Query ${key} contains dotted ICD-9`).not.toMatch(/'[0-9]{2}\.[0-9]+'/i);
      });
    }
  });
});
