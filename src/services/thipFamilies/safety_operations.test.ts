import { describe, expect, it } from 'vitest';
import { isExternalBranch } from '@/services/thipFamilyBase';
import {
  SAFETY_OPERATIONS_APPROXIMATIONS,
  SAFETY_OPERATIONS_BRANCHES,
} from '@/services/thipFamilies/safety_operations';

const CODES: readonly string[] = [
  'CA0101', 'CA0102', 'CA0103', 'CA0104', 'CA0105',
  'CG0101', 'CG0102', 'CG0103', 'CG0104',
  'CO0101', 'CO0105', 'CO0107',
  'SI0101', 'SI0102', 'SI0103', 'SI0201', 'SI0202', 'SI0203', 'SI0301', 'SI0302', 'SI0303',
  'SL0101',
  'SS0101', 'SS0102', 'SS0103',
];

const EXTERNAL_CODES: readonly string[] = [
  'CG0103', 'CG0104',
  'SI0101', 'SI0102', 'SI0103', 'SI0201', 'SI0202', 'SI0203', 'SI0301', 'SI0302', 'SI0303',
  'SS0101',
];

const PHI_TOKENS = ['hn', 'an', 'vn', 'cid', 'patient_name', 'birthdate'];
const CONTRACT_COLUMNS = [
  'indicator_code',
  'period_start',
  'fiscal_month',
  'fiscal_year',
  'numerator',
  'denominator',
  'value',
];

/** The single branch of a code (fails when zero or several branches claim the code). */
function branchFor(code: string): string {
  const matches = SAFETY_OPERATIONS_BRANCHES.filter((branch) =>
    branch.includes(`'${code}' AS indicator_code`),
  );
  expect(matches, `expected exactly one branch for ${code}`).toHaveLength(1);
  return matches[0];
}

/**
 * Outer select list of a branch: text between the leading SELECT and the first
 * FROM keyword at paren depth 0 (subquery FROMs live inside parentheses).
 */
function outerSelectList(sql: string): string {
  const start = sql.indexOf('SELECT');
  expect(start, 'branch must start with a SELECT').toBeGreaterThanOrEqual(0);
  const body = start + 'SELECT'.length;
  let depth = 0;
  for (let i = body; i < sql.length; i += 1) {
    const ch = sql[i];
    if (ch === '(') depth += 1;
    else if (ch === ')') depth -= 1;
    else if (
      depth === 0 &&
      (i === 0 || /\W/.test(sql[i - 1])) &&
      /^from\b/i.test(sql.slice(i))
    ) {
      return sql.slice(body, i);
    }
  }
  return sql.slice(body);
}

function stripParenthesized(text: string): string {
  let depth = 0;
  let out = '';
  for (const ch of text) {
    if (ch === '(') {
      depth += 1;
      continue;
    }
    if (ch === ')') {
      depth = Math.max(0, depth - 1);
      continue;
    }
    if (depth === 0) out += ch;
  }
  return out;
}

function topLevelColumnAliases(selectList: string): string[] {
  const parts: string[] = [];
  let current = '';
  let depth = 0;
  for (const ch of selectList) {
    if (ch === '(') depth += 1;
    else if (ch === ')') depth -= 1;
    if (ch === ',' && depth === 0) {
      parts.push(current);
      current = '';
    } else {
      current += ch;
    }
  }
  if (current.trim()) parts.push(current);
  return parts.map((raw) => {
    const asMatch = raw.match(/(?:AS\s+)?([a-zA-Z0-9_]+)\s*$/i);
    return asMatch ? asMatch[1].toLowerCase() : raw.trim().toLowerCase();
  });
}

function topLevelColumnExpressions(selectList: string): string[] {
  const parts: string[] = [];
  let current = '';
  let depth = 0;
  for (const ch of selectList) {
    if (ch === '(') depth += 1;
    else if (ch === ')') depth -= 1;
    if (ch === ',' && depth === 0) {
      parts.push(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  if (current.trim()) parts.push(current.trim());
  return parts;
}

describe('safety_operations family batch', () => {
  it('exports one branch per assigned code and approximations for all of them', () => {
    expect(SAFETY_OPERATIONS_BRANCHES).toHaveLength(CODES.length);
    for (const code of CODES) {
      expect(SAFETY_OPERATIONS_APPROXIMATIONS[code]?.trim().length ?? 0).toBeGreaterThan(0);
    }
    expect(Object.keys(SAFETY_OPERATIONS_APPROXIMATIONS).sort()).toEqual([...CODES].sort());
    for (const branch of SAFETY_OPERATIONS_BRANCHES) {
      expect(branch.trim().length).toBeGreaterThan(0);
      expect(branch).toMatch(/\bperiod_start\b/);
    }
  });

  for (const code of CODES) {
    it(`${code}: single branch, contract projection, PHI-free, dotless, NULLIF-guarded`, () => {
      // 1. Exactly one branch contains '<CODE>' AS indicator_code.
      const branch = branchFor(code);

      // 2. The branch projects AS numerator, AS denominator, AS value.
      expect(branch).toContain('AS numerator');
      expect(branch).toContain('AS denominator');
      expect(branch).toContain('AS value');

      // 3. Outer projection is free of PHI tokens and strictly the contract columns.
      const selectList = outerSelectList(branch);
      expect(topLevelColumnAliases(selectList)).toEqual(CONTRACT_COLUMNS);
      const bareProjection = stripParenthesized(selectList);
      for (const phi of PHI_TOKENS) {
        expect(bareProjection).not.toMatch(new RegExp(`\\b${phi}\\b`, 'i'));
      }
      for (const expression of topLevelColumnExpressions(selectList)) {
        for (const phi of PHI_TOKENS) {
          expect(expression).not.toMatch(new RegExp(`^(?:[a-zA-Z0-9_]+\\.)?${phi}$`, 'i'));
        }
      }

      // 4. No dotted ICD codes anywhere in the branch.
      expect(branch).not.toMatch(/\b[A-Z]\d{2}\./);

      // 5. Every forward slash is a NULLIF-guarded division.
      expect(branch.replace(/\/\s*NULLIF\s*\(/gi, '')).not.toContain('/');

      // 6. isExternalBranch matches the batch external list.
      expect(isExternalBranch(branch)).toBe(EXTERNAL_CODES.includes(code));

      // 7. The approximations entry is non-empty.
      expect(SAFETY_OPERATIONS_APPROXIMATIONS[code].trim().length).toBeGreaterThan(0);
    });
  }
});
