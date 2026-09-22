import { describe, expect, it } from 'vitest';
import { isExternalBranch } from '@/services/thipFamilyBase';
import { NCD_MENTAL_APPROXIMATIONS, NCD_MENTAL_BRANCHES } from '@/services/thipFamilies/ncd_mental';

const CODES = [
  'DC0301', 'DC0302', 'DC0306', 'DC0307', 'DC0308', 'DC0309',
  'DR0202', 'DR0203', 'DR0204', 'DR0205',
  'DC0501', 'DC0502',
  'CP0101', 'CP0201',
  'DM0101', 'DM0102', 'DM0103', 'DM0201', 'DM0202', 'DM0203',
  'DM0301', 'DM0302', 'DM0401', 'DM0402',
  'DS0101', 'DS0201', 'DS0301', 'DS0401',
];

/** Instrument, education-system and addiction follow-up verdicts are staged. */
const EXTERNAL_CODES = ['DM0103', 'DM0203', 'DM0401', 'DM0402', 'DS0101', 'DS0201', 'DS0301'];

const PHI_TOKENS = ['hn', 'an', 'vn', 'cid', 'patient_name', 'birthdate'];

function branchFor(code: string): string {
  const matches = NCD_MENTAL_BRANCHES.filter((branch) => branch.includes(`'${code}' AS indicator_code`));
  expect(matches, `code ${code} must appear in exactly one branch`).toHaveLength(1);
  return matches[0];
}

/**
 * Outer projection = everything the helper emits between its leading SELECT and
 * its base FROM line (`\n      FROM `); correlated subqueries never appear in
 * that region because event logic lives in WHERE and in LATERAL join lines.
 */
function outerProjection(sql: string): string {
  const start = sql.indexOf('SELECT');
  expect(start, 'branch must start from a SELECT').toBeGreaterThanOrEqual(0);
  const end = sql.indexOf('\n      FROM ', start);
  expect(end, 'branch must close its projection with the helper FROM line').toBeGreaterThan(start);
  return sql.slice(start, end);
}

/** Every division must be guarded by NULLIF, as in the repo security suite. */
function assertDivisionsGuarded(sql: string, code: string): number {
  const divRegex = /\s*\/\s*([^,\n\r)]+)/g;
  let match: RegExpExecArray | null;
  let divisionCount = 0;
  while ((match = divRegex.exec(sql)) !== null) {
    divisionCount += 1;
    const denominatorExpr = match[1].trim();
    const context = sql.slice(Math.max(0, match.index - 30), match.index + 100);
    const hasNullif = denominatorExpr.includes('NULLIF') || context.includes('NULLIF');
    expect(hasNullif, `code ${code} division at ${match.index} lacks NULLIF guard: ${context}`).toBe(true);
  }
  return divisionCount;
}

describe('ncd_mental family batch (HIV, TB, CKD, mental and development)', () => {
  it('exports exactly one branch per assigned code', () => {
    expect(NCD_MENTAL_BRANCHES).toHaveLength(CODES.length);
    expect(NCD_MENTAL_BRANCHES).toHaveLength(28);
    for (const code of CODES) {
      expect(branchFor(code), `branch for ${code} must exist`).toBeTruthy();
    }
  });

  for (const code of CODES) {
    const external = EXTERNAL_CODES.includes(code);

    describe(`code ${code}`, () => {
      it('has exactly one indicator_code marker with numerator, denominator and value outputs', () => {
        const branch = branchFor(code);
        expect(branch.split(`'${code}' AS indicator_code`).length - 1).toBe(1);
        if (external) {
          // branchExternal projects the staged aggregate columns directly.
          expect(branch).toContain('numerator,');
          expect(branch).toContain('denominator,');
          expect(branch).toContain('value');
        } else {
          expect(branch).toContain('AS numerator');
          expect(branch).toContain('AS denominator');
          expect(branch).toContain('AS value');
          expect(branch).toContain('AS period_start');
          expect(branch).toContain('AS fiscal_month');
          expect(branch).toContain('AS fiscal_year');
          expect(branch).toMatch(/GROUP BY 2, 3, 4/);
        }
      });

      it('keeps every PHI token out of the outer projection', () => {
        const projection = outerProjection(branchFor(code));
        // The scanned region must span the whole contract projection, so the
        // PHI scan below cannot pass on a truncated slice. Fact branches alias
        // the value expression; branchExternal ends on the staged `value`
        // column.
        expect(projection).toContain('AS indicator_code');
        expect(projection.trimEnd().endsWith(external ? 'value' : 'AS value')).toBe(true);
        for (const phi of PHI_TOKENS) {
          expect(projection, `projection of ${code} must not reference ${phi}`).not.toMatch(
            new RegExp(`\\b${phi}\\b`, 'i'),
          );
        }
      });

      it('uses strictly dotless ICD literals', () => {
        const branch = branchFor(code);
        expect(branch, `code ${code} carries a dotted ICD-10 literal`).not.toMatch(/\b[A-Z]\d{2}\./);
        expect(branch).not.toMatch(/'[A-Z][0-9]{2}\.[0-9]+'/i);
        expect(branch).not.toMatch(/'[0-9]{2}\.[0-9]+'/i);
      });

      it('guards every division with NULLIF', () => {
        assertDivisionsGuarded(branchFor(code), code);
      });

      it('matches the declared external staging list', () => {
        expect(isExternalBranch(branchFor(code)), `code ${code} external flag`).toBe(external);
      });

      it('documents a non-empty approximation entry', () => {
        const note = NCD_MENTAL_APPROXIMATIONS[code];
        expect(typeof note, `approximation for ${code} must be a string`).toBe('string');
        expect(note.trim().length, `approximation for ${code} must be non-empty`).toBeGreaterThan(20);
      });
    });
  }

  it('keeps the approximation map free of gaps and extras', () => {
    expect(Object.keys(NCD_MENTAL_APPROXIMATIONS).sort()).toEqual([...CODES].sort());
  });

  it('runs at least one NULLIF-guarded ratio per computed branch', () => {
    for (const code of CODES.filter((c) => !EXTERNAL_CODES.includes(c))) {
      const divisions = assertDivisionsGuarded(branchFor(code), code);
      expect(divisions, `code ${code} must compute a guarded ratio value`).toBeGreaterThan(0);
    }
  });
});
