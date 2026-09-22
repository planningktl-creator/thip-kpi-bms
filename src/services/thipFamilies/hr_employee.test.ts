import { describe, expect, it } from 'vitest';
import { isExternalBranch } from '@/services/thipFamilyBase';
import {
  HR_EMPLOYEE_APPROXIMATIONS as _APPROXIMATIONS,
  HR_EMPLOYEE_BRANCHES,
} from '@/services/thipFamilies/hr_employee';

/** The thirty-four assigned codes of the `hr_employee` batch, in task order. */
const CODES = [
  'HE0101', 'HE0102', 'HE0103', 'HE0104', 'HE0105', 'HE0106',
  'SH0101', 'SH0102', 'SH0103', 'SH0104', 'SH0105', 'SH0106', 'SH0107',
  'SH0201', 'SH0202', 'SH0203', 'SH0204', 'SH0205', 'SH0206', 'SH0207',
  'SH0208', 'SH0209', 'SH0210', 'SH0211', 'SH0212', 'SH0213', 'SH0214',
  'SH0215', 'SH0216', 'SH0301', 'SH0302', 'SH0303', 'SH0306', 'SH0307',
] as const;

/**
 * Satisfaction-instrument and training-hour codes have no HOSxP source and
 * read `reporting.thip_external_facts`; everything else is HOSxP.
 */
const EXTERNAL_CODES: readonly string[] = [
  'SH0201', 'SH0202', 'SH0203', 'SH0204', 'SH0205', 'SH0206', 'SH0207',
  'SH0208', 'SH0209', 'SH0210', 'SH0211', 'SH0212', 'SH0213', 'SH0214',
  'SH0215', 'SH0216',
];

const PHI_TOKENS = ['hn', 'an', 'vn', 'cid', 'patient_name', 'birthdate', 'emp_id'];

/** Every `/` must be the division marker of a `X NULLIF(Y, 0)` guard. */
const GUARDED_DIVISION = /\/ NULLIF\(/g;

function branchesFor(code: string): string[] {
  return HR_EMPLOYEE_BRANCHES.filter((sql) =>
    sql.includes(`'${code}' AS indicator_code`),
  );
}

/**
 * Outer projection of a branch: the text between the outer SELECT and the
 * helper's FROM marker (six-space indent). Inner subqueries are indented past
 * that marker, so they never leak into the projection slice.
 */
function outerProjection(branch: string): string {
  const fromIdx = branch.indexOf('\n      FROM ');
  expect(fromIdx, 'branch has no helper FROM marker').toBeGreaterThan(0);
  return branch.slice(branch.indexOf('SELECT'), fromIdx);
}

describe('hr_employee batch coverage', () => {
  it('renders exactly one branch per assigned code and nothing else', () => {
    expect(HR_EMPLOYEE_BRANCHES).toHaveLength(CODES.length);
    let matched = 0;
    for (const code of CODES) {
      const branches = branchesFor(code);
      expect(branches, `code ${code}`).toHaveLength(1);
      matched += branches.length;
    }
    expect(matched).toBe(CODES.length);
  });

  it('flags exactly the documented external codes through isExternalBranch', () => {
    for (const code of CODES) {
      const branch = branchesFor(code)[0] ?? '';
      expect(isExternalBranch(branch), `code ${code}`).toBe(
        EXTERNAL_CODES.includes(code),
      );
    }
  });

  it('keeps the exact assigned code list in branch order', () => {
    expect(HR_EMPLOYEE_BRANCHES.map((sql, index) => {
      const code = CODES[index];
      return sql.includes(`'${code}' AS indicator_code`);
    })).toEqual(CODES.map(() => true));
  });

  it('carries one _APPROXIMATIONS entry per assigned code', () => {
    expect(Object.keys(_APPROXIMATIONS).sort()).toEqual([...CODES].sort());
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
      const outer = outerProjection(branch);
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

    it('keeps parentheses balanced in the generated SQL', () => {
      const opens = (branch.match(/\(/g) ?? []).length;
      const closes = (branch.match(/\)/g) ?? []).length;
      expect(opens).toBe(closes);
      let depth = 0;
      let minDepth = 0;
      for (const char of branch) {
        if (char === '(') depth += 1;
        if (char === ')') depth -= 1;
        if (depth < minDepth) minDepth = depth;
      }
      expect(minDepth, 'parenthesis closed before it was opened').toBeGreaterThanOrEqual(0);
      expect(depth).toBe(0);
    });

    it('matches the batch external list via isExternalBranch', () => {
      expect(isExternalBranch(branch)).toBe(EXTERNAL_CODES.includes(code));
    });

    it('carries a non-empty _APPROXIMATIONS entry', () => {
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
