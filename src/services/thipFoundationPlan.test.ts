import { describe, expect, it } from 'vitest';
import { getReportingCadence } from '@/data/thipReporting';
import { extendedBaseCte } from '@/services/thipFamilyBase';
import { hosxpRegisteredCodes } from '@/services/queryRegistry';
import {
  FOUNDATION_CHUNK_SIZE,
  planFoundationChunks,
  planFoundationRequests,
  plannedCodeCount,
  registeredCodeBranchPairs,
  splitFoundationChunk,
  splitFoundationRequestByWindow,
} from '@/services/thipFoundationPlan';

/** First registered code that reports on the given cadence, for splitter tests. */
function firstCodeWithCadence(cadence: ReturnType<typeof getReportingCadence>): string {
  const code = hosxpRegisteredCodes.find((candidate) => getReportingCadence(candidate) === cadence);
  if (!code) throw new Error(`no registered code with ${cadence} cadence`);
  return code;
}

describe('foundation fan-out plan', () => {
  it('covers every HOSxP registered code exactly once', () => {
    const chunks = planFoundationChunks();
    const pairs = registeredCodeBranchPairs();
    expect(pairs).toHaveLength(hosxpRegisteredCodes.length);
    expect(plannedCodeCount(chunks)).toBe(hosxpRegisteredCodes.length);
    // Every code appears once: sum of per-chunk code counts equals the contract.
    const perChunk = chunks.map((chunk) => chunk.sql.match(/'[A-Z]{2}\d{4}(?:\.\d)?' AS indicator_code/g)?.length ?? 0);
    expect(perChunk.reduce((total, value) => total + value, 0)).toBe(hosxpRegisteredCodes.length);
  });

  it('keeps chunks bounded by the configured size', () => {
    const chunks = planFoundationChunks({ chunkSize: 5 });
    for (const chunk of chunks) {
      const count = chunk.sql.match(/'[A-Z]{2}\d{4}(?:\.\d)?' AS indicator_code/g)?.length ?? 0;
      expect(count).toBeGreaterThan(0);
      expect(count).toBeLessThanOrEqual(5);
    }
  });

  it('declares every base CTE its branches reference, whatever codes share a chunk', () => {
    // Regression guard: a chunk that mixes IPD codes with OPD/chronic/etc. branches must
    // still declare `opd_periodized` and friends, otherwise HOSxP answers
    // `relation "opd_periodized" does not exist`.
    const declared = new Set(['ipd', 'periodized', ...Array.from(extendedBaseCte(false).matchAll(/^\s*([a-z_0-9]+) AS \(/gm), (match) => match[1]!)]);
    for (const chunk of planFoundationChunks()) {
      const referenced = new Set<string>();
      for (const match of chunk.sql.matchAll(/\bFROM\s+([a-z_0-9]+_periodized)\b/gi)) referenced.add(match[1]!.toLowerCase());
      for (const match of chunk.sql.matchAll(/\bJOIN\s+([a-z_0-9]+_periodized)\b/gi)) referenced.add(match[1]!.toLowerCase());
      for (const name of referenced) expect(declared.has(name), `${chunk.key} references undeclared ${name}`).toBe(true);
    }
  });

  it('executes the whole fiscal year in every chunk', () => {
    for (const chunk of planFoundationChunks()) {
      expect(chunk.sql).toContain('CAST(:start_date AS date)');
      expect(chunk.sql).toContain('CAST(:end_date AS date)');
      // Never hard-code an ISO year: the app passes the current fiscal-year window.
      expect(chunk.sql).not.toMatch(/'20\d\d-\d\d-\d\d'/);
    }
  });

  it('splits out codes that measured close to the request ceiling', () => {
    const pairs = registeredCodeBranchPairs();
    const heavy = pairs[0]![0];
    const chunks = planFoundationChunks({ chunkSize: FOUNDATION_CHUNK_SIZE, observedMs: { [heavy]: 9_500 } });
    const heavyChunk = chunks.find((chunk) => chunk.sql.includes(`'${heavy}' AS indicator_code`))!;
    expect(heavyChunk.sql.match(/'[A-Z]{2}\d{4}(?:\.\d)?' AS indicator_code/g)).toHaveLength(1);
    expect(plannedCodeCount(chunks)).toBe(hosxpRegisteredCodes.length);
  });

  it('produces smaller chunks for codes with no measurement yet', () => {
    const halved = planFoundationChunks({ chunkSize: 10, observedMs: {} });
    for (const chunk of halved) {
      const count = chunk.sql.match(/'[A-Z]{2}\d{4}(?:\.\d)?' AS indicator_code/g)?.length ?? 0;
      expect(count).toBeLessThanOrEqual(5);
    }
  });

  it('bisects a refused chunk into halves that still cover the same codes', () => {
    const chunk = planFoundationChunks({ chunkSize: 8 })[0]!;
    const parts = splitFoundationChunk(chunk);
    expect(parts).toHaveLength(2);
    expect(parts[0]!.key).toBe(`${chunk.key}.1`);
    expect(plannedCodeCount(chunk ? [chunk] : [])).toBe(plannedCodeCount(parts));
    // A single-code chunk cannot be bisected further; that code is unmeasurable alone.
    const single = planFoundationChunks({ chunkSize: 1 })[0]!;
    expect(splitFoundationChunk(single)).toHaveLength(0);
  });

  it('plans every request over the full fiscal-year window', () => {
    const requests = planFoundationRequests({ fiscalYear: 2026 });
    expect(requests.length).toBe(planFoundationChunks().length);
    for (const request of requests) {
      expect(request.start).toBe('2025-10-01');
      expect(request.end).toBe('2026-10-01');
    }
    // A different fiscal year moves the window with it: nothing is hard-coded.
    for (const request of planFoundationRequests({ fiscalYear: 2025 })) {
      expect(request.start).toBe('2024-10-01');
      expect(request.end).toBe('2025-10-01');
    }
  });

  it('halves a window for cadences that bucket into months, quarters or half-years', () => {
    const monthly = planFoundationRequests({ fiscalYear: 2026, codes: [firstCodeWithCadence('monthly')] })[0]!;
    const halves = splitFoundationRequestByWindow(monthly);
    expect(halves).toHaveLength(2);
    expect(halves[0]!.start).toBe('2025-10-01');
    expect(halves[0]!.end).toBe('2026-04-01');
    expect(halves[1]!.start).toBe('2026-04-01');
    expect(halves[1]!.end).toBe('2026-10-01');
  });

  it('never halves an annual window, because a year is one bucket', () => {
    const annual = planFoundationRequests({ fiscalYear: 2026, codes: [firstCodeWithCadence('annual')] })[0]!;
    expect(splitFoundationRequestByWindow(annual)).toHaveLength(0);
  });
});
