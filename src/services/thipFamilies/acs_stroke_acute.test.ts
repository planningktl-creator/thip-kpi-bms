import { describe, expect, it } from 'vitest';

import { isExternalBranch } from '@/services/thipFamilyBase';
import {
  ACS_STROKE_ACUTE_APPROXIMATIONS,
  ACS_STROKE_ACUTE_BRANCHES,
} from '@/services/thipFamilies/acs_stroke_acute';

/**
 * Contract checks for the `acs_stroke_acute` batch: exactly one branch per
 * code, the 7-column aggregate projection without PHI, dotless ICD literals,
 * NULLIF-guarded divisions only, external branches matching EXTERNAL_CODES and
 * a non-empty honesty note per code.
 */

const CODES: readonly string[] = [
  'DH0103', 'DH0104', 'DH0105', 'DH0106', 'DH0107', 'DH0108', 'DH0109',
  'DH0110', 'DH0113', 'DH0401', 'DH0402', 'DN0102', 'DN0103', 'DN0104',
  'DN0105', 'DN0106', 'DN0110', 'DN0301', 'DN0303', 'DR0103', 'CE0104',
  'DE1401', 'DE1402', 'DE1403', 'DE1404', 'DE1405',
];

const EXTERNAL_CODES: readonly string[] = [];

const PHI_TOKENS: readonly string[] = [
  'hn', 'an', 'vn', 'cid', 'pname', 'fname', 'lname', 'patient_name',
  'birthday', 'birth_date', 'addrpart', 'moopart', 'bloodgrp', 'nationality',
];

const EXPECTED_ALIASES: readonly string[] = [
  'indicator_code', 'period_start', 'fiscal_month', 'fiscal_year',
  'numerator', 'denominator', 'value',
];

const OUTERMOST_FROM = /\n {6}FROM /;

function branchFor(code: string): string {
  const matches = ACS_STROKE_ACUTE_BRANCHES.filter((sql) =>
    sql.includes(`'${code}' AS indicator_code`),
  );
  expect(matches, `code ${code} must appear in exactly one branch`).toHaveLength(1);
  return matches[0];
}

/** Splits text on top-level commas (paren depth 0, outside string literals). */
function splitTopLevel(text: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let inString = false;
  let current = '';
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (ch === "'") inString = !inString;
    if (!inString) {
      if (ch === '(') depth += 1;
      if (ch === ')') depth -= 1;
      if (ch === ',' && depth === 0) {
        parts.push(current);
        current = '';
        continue;
      }
    }
    current += ch;
  }
  parts.push(current);
  return parts;
}

/** The outer SELECT list of a branch: everything before its outer FROM line. */
function outerProjection(sql: string): string {
  const fromMatch = OUTERMOST_FROM.exec(sql);
  expect(fromMatch, 'branch must contain its outer FROM at 6-space indent').not.toBeNull();
  return sql.slice(0, fromMatch?.index ?? sql.length);
}

function projectedColumns(sql: string): Array<{ expression: string; alias: string }> {
  return splitTopLevel(outerProjection(sql)).map((segment) => {
    const aliasMatch = /\bAS\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*$/.exec(segment);
    expect(aliasMatch, `projection segment without trailing alias: ${segment}`).not.toBeNull();
    const alias = aliasMatch?.[1] ?? '';
    const expression = segment.replace(/\s+AS\s+[a-zA-Z_][a-zA-Z0-9_]*\s*$/, '').trim();
    return { expression, alias };
  });
}

describe('acs_stroke_acute batch shape', () => {
  it('has exactly one branch per assigned code and no extra branches', () => {
    expect(ACS_STROKE_ACUTE_BRANCHES).toHaveLength(CODES.length);
    for (const code of CODES) {
      branchFor(code);
    }
  });

  it('carries a non-empty approximation note for every code', () => {
    for (const code of CODES) {
      const note = ACS_STROKE_ACUTE_APPROXIMATIONS[code];
      expect(typeof note, `approximation for ${code} must be a string`).toBe('string');
      expect((note ?? '').trim().length, `approximation for ${code} must be non-empty`).toBeGreaterThan(0);
    }
  });
});

describe.each(CODES.map((code) => [code] as const))('branch %s contract', (code) => {
  const branch = branchFor(code);

  it('exposes numerator, denominator and value aliases', () => {
    expect(branch).toContain('AS numerator');
    expect(branch).toContain('AS denominator');
    expect(branch).toContain('AS value');
  });

  it('projects exactly the 7 contract columns without PHI', () => {
    const columns = projectedColumns(branch);
    expect(columns.map((c) => c.alias)).toEqual([...EXPECTED_ALIASES]);
    for (const col of columns) {
      for (const phi of PHI_TOKENS) {
        expect(col.alias, `alias ${col.alias} is PHI`).not.toBe(phi);
        const bareColumn = new RegExp(`^(?:[a-zA-Z0-9_]+\\.)?${phi}$`, 'i');
        expect(col.expression, `raw unaggregated PHI ${phi} in ${col.expression}`).not.toMatch(bareColumn);
      }
    }
  });

  it('uses dotless ICD literals only', () => {
    expect(branch).not.toMatch(/\b[A-Z]\d{2}\./);
  });

  it('guards every division with NULLIF', () => {
    for (let i = branch.indexOf('/'); i !== -1; i = branch.indexOf('/', i + 1)) {
      expect(
        branch.slice(i).startsWith('/ NULLIF(') || branch.slice(i).startsWith('/NULLIF('),
        `unguarded division at ${i}: ${branch.slice(Math.max(0, i - 30), i + 40)}`,
      ).toBe(true);
    }
  });

  it('marks external branches exactly as listed', () => {
    expect(isExternalBranch(branch)).toBe(EXTERNAL_CODES.includes(code));
  });
});
