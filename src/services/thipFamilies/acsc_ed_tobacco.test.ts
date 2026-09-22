import { describe, expect, it } from 'vitest';
import { isExternalBranch } from '@/services/thipFamilyBase';
import {
  ACSC_ED_TOBACCO_APPROXIMATIONS,
  ACSC_ED_TOBACCO_BRANCHES,
} from '@/services/thipFamilies/acsc_ed_tobacco';

const CODES: readonly string[] = [
  'AA0101', 'AA0102', 'AA0103', 'AA0104', 'AA0105',
  'CE0102', 'CE0103',
  'HC0101', 'HC0102',
  'SM0102', 'SM0103', 'SM0201',
  'HH0101.1', 'HH0101.2', 'HH0102',
  'HH0103.1', 'HH0103.2', 'HH0103.3', 'HH0103.4', 'HH0103.5', 'HH0103.6',
  'HH0104.1', 'HH0104.2', 'HH0104.3', 'HH0104.4', 'HH0104.5',
];

/** Codes implemented through `branchExternal` (reporting.thip_external_facts). None in this batch. */
const EXTERNAL_CODES: readonly string[] = [];

const PHI_TOKENS = [
  'hn', 'an', 'vn', 'cid', 'pname', 'fname', 'lname', 'patient_name',
  'birthday', 'birth_date', 'birthdate',
];

const CONTRACT_COLUMNS = [
  'indicator_code', 'period_start', 'fiscal_month', 'fiscal_year',
  'numerator', 'denominator', 'value',
];

function branchesFor(code: string): string[] {
  // The closing quote before ` AS indicator_code` keeps HH0101 from matching HH0101.1.
  return ACSC_ED_TOBACCO_BRANCHES.filter((sql) => sql.includes(`'${code}' AS indicator_code`));
}

function branchFor(code: string): string {
  const branches = branchesFor(code);
  expect(branches, `code ${code} must have exactly one branch`).toHaveLength(1);
  return branches[0]!;
}

/** Removes balanced (...) blocks whose content matches `isRemovable` (recursing into kept blocks). */
function removeBlocks(sql: string, isRemovable: (inner: string) => boolean): string {
  let result = '';
  let i = 0;
  while (i < sql.length) {
    if (sql[i] === '(') {
      let depth = 0;
      let j = i;
      for (; j < sql.length; j++) {
        if (sql[j] === '(') depth += 1;
        else if (sql[j] === ')') {
          depth -= 1;
          if (depth === 0) break;
        }
      }
      const inner = sql.slice(i + 1, j);
      if (isRemovable(inner)) {
        i = j + 1;
        continue;
      }
      result += `(${removeBlocks(inner, isRemovable)})`;
      i = j + 1;
    } else {
      result += sql[i];
      i += 1;
    }
  }
  return result;
}

/** Outer projection text between the outer SELECT and its depth-0 FROM. */
function outerProjection(sql: string): string {
  const selectIdx = sql.toUpperCase().indexOf('SELECT');
  expect(selectIdx, 'branch must start with a SELECT projection').toBeGreaterThanOrEqual(0);
  let depth = 0;
  for (let i = selectIdx; i < sql.length; i++) {
    const ch = sql[i];
    if (ch === '(') depth += 1;
    else if (ch === ')') depth -= 1;
    else if (depth === 0 && /^FROM\b/i.test(sql.slice(i))) {
      return sql.slice(selectIdx + 'SELECT'.length, i);
    }
  }
  throw new Error('branch projection has no depth-0 FROM');
}

function splitTopLevel(str: string, delimiter = ','): string[] {
  const parts: string[] = [];
  let current = '';
  let depth = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str[i];
    if (char === '(') depth += 1;
    else if (char === ')') depth -= 1;
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

function projectionAliases(projection: string): string[] {
  return splitTopLevel(projection).map((item) => {
    const match = /AS\s+([a-zA-Z0-9_]+)\s*$/i.exec(item);
    return (match ? match[1]! : item).toLowerCase();
  });
}

describe('acsc_ed_tobacco family batch', () => {
  it('exposes exactly the 26 assigned codes, one branch per code', () => {
    expect(ACSC_ED_TOBACCO_BRANCHES).toHaveLength(26);
    const seen = new Set<string>();
    for (const code of CODES) {
      const branches = branchesFor(code);
      expect(branches, `code ${code} must have exactly one branch`).toHaveLength(1);
      seen.add(code);
    }
    expect(seen.size).toBe(26);
    // No branch for any code outside the batch.
    for (const sql of ACSC_ED_TOBACCO_BRANCHES) {
      const match = /'([A-Z]{2}[0-9]{4}(?:\.[0-9]+)?)' AS indicator_code/.exec(sql);
      expect(match, 'every branch must carry one code literal').not.toBeNull();
      expect(CODES, `unexpected branch code ${match?.[1]}`).toContain(match?.[1]);
    }
  });

  it('keeps the outer projection on the seven contract columns', () => {
    for (const code of CODES) {
      const aliases = projectionAliases(outerProjection(branchFor(code)));
      expect(aliases, `branch ${code} projection columns`).toEqual(CONTRACT_COLUMNS);
    }
  });

  describe.each(CODES)('code %s', (code) => {
    const branch = branchFor(code);

    it('has exactly one indicator_code marker plus numerator, denominator and value', () => {
      expect(branchesFor(code)).toHaveLength(1);
      expect(branch).toContain('AS numerator');
      expect(branch).toContain('AS denominator');
      expect(branch).toContain('AS value');
    });

    it('projects no PHI token outside aggregate grain keys and correlated subqueries', () => {
      let projection = outerProjection(branch);
      // Correlated scalar subqueries never project a row value out of the branch.
      projection = removeBlocks(projection, (inner) => /^\s*SELECT\b/i.test(inner));
      // COUNT(DISTINCT key) is the sanctioned one-row-per-episode grain key.
      projection = removeBlocks(projection, (inner) => /^\s*DISTINCT\b/i.test(inner));
      expect(projection).not.toMatch(new RegExp(`\\b(${PHI_TOKENS.join('|')})\\b`, 'i'));
    });

    it('never projects a raw unaggregated PHI column', () => {
      for (const item of splitTopLevel(outerProjection(branch))) {
        for (const phi of PHI_TOKENS) {
          expect(item, `branch ${code} projects raw PHI ${phi}`).not.toMatch(
            new RegExp(`^(?:[a-zA-Z0-9_]+\\.)?${phi}$`, 'i'),
          );
        }
      }
    });

    it('uses dotless ICD literals only', () => {
      expect(branch, `branch ${code} contains a dotted ICD code`).not.toMatch(/\b[A-Z]\d{2}\./);
    });

    it('keeps parentheses balanced across the whole branch', () => {
      let depth = 0;
      let minDepth = 0;
      for (const ch of branch) {
        if (ch === '(') depth += 1;
        else if (ch === ')') depth -= 1;
        minDepth = Math.min(minDepth, depth);
      }
      expect(minDepth, `branch ${code} closes more parens than it opens`).toBeGreaterThanOrEqual(0);
      expect(depth, `branch ${code} leaves ${depth} unclosed paren(s)`).toBe(0);
    });

    it('guards every division with NULLIF', () => {
      for (const match of branch.matchAll(/\//g)) {
        expect(
          branch.slice(match.index!),
          `branch ${code} division at ${match.index} is not a NULLIF-guarded division`,
        ).toMatch(/^\/\s*NULLIF\(/);
      }
    });

    it('classifies external branches exactly like the batch external list', () => {
      expect(isExternalBranch(branch)).toBe(EXTERNAL_CODES.includes(code));
    });

    it('records a non-empty approximation entry', () => {
      const note = ACSC_ED_TOBACCO_APPROXIMATIONS[code];
      expect(note, `branch ${code} needs an approximation entry`).toBeTypeOf('string');
      expect((note ?? '').trim().length).toBeGreaterThan(40);
    });
  });
});
