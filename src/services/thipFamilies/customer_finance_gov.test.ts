import { describe, expect, it } from 'vitest';
import { isExternalBranch } from '@/services/thipFamilyBase';
import {
  CUSTOMER_FINANCE_GOV_APPROXIMATIONS as _APPROXIMATIONS,
  CUSTOMER_FINANCE_GOV_BRANCHES,
} from '@/services/thipFamilies/customer_finance_gov';

/** The thirteen assigned codes of the `customer_finance_gov` batch. */
const CODES = [
  'SC0101',
  'SC0102',
  'SC0103',
  'SC0104',
  'SC0105',
  'SC0106',
  'SF0101',
  'SF0102',
  'SF0103',
  'SF0104',
  'SF0105',
  'SF0106',
  'SG0104',
] as const;

/**
 * Every code of this batch reads `reporting.thip_external_facts` (survey
 * instruments and score scales unconfirmable in HOSxP, audited financial
 * statements outside HOSxP, waste weights in the environment office log).
 */
const EXTERNAL_CODES: readonly string[] = [...CODES];

const PHI_TOKENS = ['hn', 'an', 'vn', 'cid', 'patient_name', 'birthdate'];

/** Every `/` must be the division marker of a `X NULLIF(Y, 0)` guard. */
const GUARDED_DIVISION = /\/ NULLIF\([A-Za-z0-9_. ]+, 0\)/g;

function branchesFor(code: string): string[] {
  return CUSTOMER_FINANCE_GOV_BRANCHES.filter((sql) =>
    sql.includes(`'${code}' AS indicator_code`),
  );
}

describe('customer_finance_gov batch coverage', () => {
  it('renders exactly one branch per assigned code and nothing else', () => {
    expect(CUSTOMER_FINANCE_GOV_BRANCHES).toHaveLength(CODES.length);
    let matched = 0;
    for (const code of CODES) {
      const branches = branchesFor(code);
      expect(branches, `code ${code}`).toHaveLength(1);
      matched += branches.length;
    }
    expect(matched).toBe(CODES.length);
    expect(Object.keys(_APPROXIMATIONS).length).toBe(CODES.length);
  });

  it('flags exactly the documented external codes through isExternalBranch', () => {
    for (const code of CODES) {
      const branch = branchesFor(code)[0] ?? '';
      expect(isExternalBranch(branch), `code ${code}`).toBe(
        EXTERNAL_CODES.includes(code),
      );
    }
  });
});

for (const code of CODES) {
  describe(`branch ${code}`, () => {
    const branch = branchesFor(code)[0] ?? '';

    it("contains exactly one 'CODE' AS indicator_code with aliased value columns", () => {
      const occurrences = branch.split(`'${code}' AS indicator_code`).length - 1;
      expect(occurrences).toBe(1);
      expect(branch).toContain('AS numerator');
      expect(branch).toContain('AS denominator');
      expect(branch).toContain('AS value');
    });

    it('keeps the outer projection free of PHI tokens', () => {
      const outer = branch.slice(branch.indexOf('SELECT'), branch.indexOf('FROM'));
      for (const phi of PHI_TOKENS) {
        expect(outer, `token ${phi}`).not.toMatch(new RegExp(`\\b${phi}\\b`, 'i'));
      }
    });

    it('uses no dotted ICD codes', () => {
      expect(branch).not.toMatch(/\b[A-Z]\d{2}\./);
    });

    it('lets every slash be a NULLIF-guarded division', () => {
      const slashCount = (branch.match(/\//g) ?? []).length;
      const guarded = branch.match(GUARDED_DIVISION) ?? [];
      expect(slashCount).toBe(guarded.length);
      const withoutGuarded = branch.replace(GUARDED_DIVISION, '');
      expect(withoutGuarded).not.toContain('/');
    });

    it('matches the batch external list via isExternalBranch', () => {
      expect(isExternalBranch(branch)).toBe(EXTERNAL_CODES.includes(code));
    });

    it('carries a non-empty _APPROXIMATIONS entry with the staging contract', () => {
      const entry = (_APPROXIMATIONS[code] ?? '').trim();
      expect(entry.length).toBeGreaterThan(0);
      if (EXTERNAL_CODES.includes(code)) {
        expect(entry).toContain('reporting.thip_external_facts');
        expect(entry).toContain('source_system');
        expect(entry).toContain('period_start');
      }
    });
  });
}
