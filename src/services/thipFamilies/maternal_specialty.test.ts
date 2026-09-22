import { describe, expect, it } from 'vitest';
import { isExternalBranch } from '@/services/thipFamilyBase';
import {
  MATERNAL_SPECIALTY_APPROXIMATIONS,
  MATERNAL_SPECIALTY_BRANCHES,
} from '@/services/thipFamilies/maternal_specialty';

/** The 19 assigned codes in batch order. */
const CODES = [
  'CM0101',
  'CM0201',
  'CM0202',
  'CM0203',
  'DE1601',
  'DE0101',
  'DE0103',
  'DC0402',
  'DC0403',
  'DE0501',
  'DE0801',
  'DE1201',
  'DE1202',
  'DE1301',
  'DE1302',
  'DE1303',
  'DE1304',
  'DE1305',
  'DE1306',
] as const;

/** Codes whose fact rows are hospital-loaded staging aggregates. */
const EXTERNAL_CODES = ['DE1601', 'DE1301', 'DE1302', 'DE1303', 'DE1304', 'DE1305', 'DE1306'];

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

/**
 * Outer projection text of a fact branch: between the outer SELECT and the
 * outer FROM (which the helpers always render at six space indent; inline
 * subqueries are indented deeper and never match).
 */
function outerProjection(sql: string): string {
  const start = sql.indexOf('SELECT');
  expect(start, 'branch must start with an outer SELECT').toBeGreaterThanOrEqual(0);
  const end = sql.indexOf('\n      FROM ');
  expect(end, 'branch must contain the outer FROM at helper indent').toBeGreaterThan(start);
  return sql.slice(start + 'SELECT'.length, end);
}

function projectedColumns(sql: string): { alias: string; expression: string }[] {
  return splitTopLevel(outerProjection(sql)).map((raw) => {
    const asMatch = raw.match(/(?:AS\s+)?([a-zA-Z0-9_]+)$/i);
    const alias = asMatch ? asMatch[1]! : raw;
    const clean = alias.includes('.') ? alias.split('.').pop()! : alias;
    return { alias: clean.toLowerCase(), expression: raw.trim() };
  });
}

function branchesFor(code: string): string[] {
  return MATERNAL_SPECIALTY_BRANCHES.filter((sql) => sql.includes(`'${code}' AS indicator_code`));
}

describe('maternal_specialty family batch', () => {
  it('holds exactly one branch per assigned code and no extra codes', () => {
    expect(MATERNAL_SPECIALTY_BRANCHES).toHaveLength(CODES.length);
    const seen = MATERNAL_SPECIALTY_BRANCHES.map((sql) => {
      const match = sql.match(/'([A-Z0-9.]+)' AS indicator_code/);
      expect(match, 'every branch must project its indicator code').not.toBeNull();
      return match![1]!;
    });
    expect([...seen].sort()).toEqual([...CODES].sort());
    for (const code of CODES) {
      // Requirement 1: exactly one branch contains 'CODE' AS indicator_code.
      expect(branchesFor(code), `code ${code} must have exactly one branch`).toHaveLength(1);
    }
  });

  for (const code of CODES) {
    it(`${code} satisfies the branch contract`, () => {
      const matches = branchesFor(code);
      expect(matches).toHaveLength(1);
      const branch = matches[0]!;

      // Requirement 2: numerator, denominator and value columns.
      const columns = projectedColumns(branch);
      expect(columns.map((c) => c.alias)).toEqual(CONTRACT_COLUMNS);
      if (isExternalBranch(branch)) {
        // branchExternal projects the bare staging columns (thipFamilyBase).
        expect(outerProjection(branch)).toMatch(/\bnumerator\b/);
        expect(outerProjection(branch)).toMatch(/\bdenominator\b/);
        expect(outerProjection(branch)).toMatch(/\bvalue\b/);
      } else {
        expect(branch).toContain('AS numerator');
        expect(branch).toContain('AS denominator');
        expect(branch).toContain('AS value');
      }

      // Requirement 3: outer projection free of PHI tokens.
      for (const col of columns) {
        for (const phi of PHI_TOKENS) {
          expect(col.alias, `alias ${col.alias} is a PHI token`).not.toBe(phi);
          expect(
            col.expression,
            `projection ${col.expression} emits a raw unaggregated PHI column`,
          ).not.toMatch(new RegExp(`^(?:[a-zA-Z0-9_]+\\.)?${phi}$`, 'i'));
        }
      }

      // Requirement 4: no dotted ICD codes.
      expect(branch, 'dotted ICD code found').not.toMatch(/\b[A-Z]\d{2}\./);

      // Requirement 5: every slash is a NULLIF-guarded division.
      for (const match of branch.matchAll(/\//g)) {
        expect(
          branch.slice(match.index),
          `division at ${match.index} is not NULLIF-guarded`,
        ).toMatch(/^\/\s*NULLIF\(/);
      }

      // Requirement 6: external-ness matches the declared external list.
      expect(isExternalBranch(branch)).toBe(EXTERNAL_CODES.includes(code));

      // Requirement 7: every code documents a non-empty approximation entry.
      const note = MATERNAL_SPECIALTY_APPROXIMATIONS[code];
      expect(typeof note).toBe('string');
      expect((note ?? '').trim().length).toBeGreaterThan(0);
    });
  }

  it('keeps the shared helpers default grouping and contract columns', () => {
    for (const branch of MATERNAL_SPECIALTY_BRANCHES) {
      if (isExternalBranch(branch)) continue;
      expect(branch).toMatch(/GROUP BY 2, 3, 4/);
      expect(branch).toContain('AS period_start');
      expect(branch).toContain('AS fiscal_month');
      expect(branch).toContain('AS fiscal_year');
    }
  });

  it('documents every assigned code exactly once in the approximations map', () => {
    expect(Object.keys(MATERNAL_SPECIALTY_APPROXIMATIONS).sort()).toEqual([...CODES].sort());
  });
});
