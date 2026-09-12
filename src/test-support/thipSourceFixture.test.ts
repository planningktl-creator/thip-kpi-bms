import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { thipCatalogue } from '@/data/thipCatalogue';
import { loadBmsIndicators } from '@/services/bmsData';
import {
  FIXTURE_FISCAL_YEAR,
  FIXTURE_REFRESHED_AT,
  buildCompleteSourceFixture,
  invalidFixtureMutations,
  type InvalidFixtureName,
} from '@/test-support/thipSourceFixture';

const fixturePath = resolve(
  fileURLToPath(new URL('.', import.meta.url)),
  '../../test-fixtures/thip-kpi-complete-2026.json',
);

const runtime = { apiUrl: 'https://bms.test', bearerToken: 'test-token', appIdentifier: 'THIP.KPI.BMS' };

function stubCompleteSourceView(rows: unknown): void {
  vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
  vi.stubEnv('VITE_BMS_KPI_REQUIRE_COMPLETE_SOURCE_VIEW', 'true');
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
    ok: true,
    status: 200,
    text: vi.fn().mockResolvedValue(JSON.stringify({ data: rows })),
  }));
}

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe('THIP aggregate source fixture', () => {
  it('generates every cadence-aware cell for all 232 catalogue codes', () => {
    const rows = buildCompleteSourceFixture();
    expect(thipCatalogue).toHaveLength(232);
    expect(rows).toHaveLength(1552);
    expect(new Set(rows.map((row) => row.indicator_code)).size).toBe(232);
    expect(new Set(rows.map((row) => `${row.indicator_code}:${row.fiscal_month}`)).size).toBe(1552);
  });

  it('keeps the committed fixture in sync with the repository manifests', () => {
    const committed = JSON.parse(readFileSync(fixturePath, 'utf8')) as unknown;
    expect(committed).toEqual(buildCompleteSourceFixture());
  });

  it('loads the complete fixture as the 232-indicator live contract', async () => {
    stubCompleteSourceView(buildCompleteSourceFixture());
    const result = await loadBmsIndicators(runtime, FIXTURE_FISCAL_YEAR);

    expect(result.coverage).toMatchObject({
      expectedIndicatorCount: 232,
      liveIndicatorCount: 232,
      expectedCellCount: 1552,
      coveredCellCount: 1552,
      unexpectedCellCount: 0,
      complete: true,
    });
    // Registered codes carry measured cells; pending-local-source codes carry
    // explicit unavailable cells, and the two must add up to the full grid.
    expect(result.coverage.availableCellCount).toBeGreaterThan(0);
    expect(result.coverage.unavailableCellCount).toBeGreaterThan(0);
    expect(result.coverage.availableCellCount + result.coverage.unavailableCellCount).toBe(1552);
    expect(result.indicators).toHaveLength(232);
    expect(result.refreshedAt).toBe(FIXTURE_REFRESHED_AT);
  });

  it.each(Object.keys(invalidFixtureMutations) as InvalidFixtureName[])(
    'rejects the %s invalid fixture through the adapter',
    async (name) => {
      const rows = invalidFixtureMutations[name](buildCompleteSourceFixture());
      stubCompleteSourceView(rows);
      await expect(loadBmsIndicators(runtime, FIXTURE_FISCAL_YEAR)).rejects.toThrow();
    },
  );

  it('verifies newly promoted Milestone 2 indicators have measured values and null pending reason', () => {
    const promotedM2Codes = [
      'DH0301', 'DH0302',
      'DH0201', 'DH0202', 'DH0203', 'DH0204',
      'DO0202', 'DO0204', 'DO0205', 'DO0302', 'DO0303', 'DO0304',
      'DR0302', 'DR0404',
      'CM0104', 'CM0107', 'CM0109', 'CM0110', 'CM0116', 'CM0117', 'CM0118', 'CM0119',
      'CM0204', 'CM0205', 'CM0206', 'CM0207', 'CM0208', 'CM0209',
      'DC0103', 'DC0107', 'DC0108', 'DC0108.1', 'DC0108.2', 'DC0201', 'DC0201.1', 'DC0201.2', 'DP0101',
    ];
    const rows = buildCompleteSourceFixture();
    for (const code of promotedM2Codes) {
      const codeRows = rows.filter((r) => r.indicator_code === code);
      expect(codeRows.length).toBeGreaterThan(0);
      for (const r of codeRows) {
        expect(r.value, `${code} value should not be null`).not.toBeNull();
        expect(r.pending_reason, `${code} pending_reason should be null`).toBeNull();
        if (r.unit !== 'count') {
          expect(r.denominator, `${code} denominator`).not.toBeNull();
          expect(r.numerator, `${code} numerator`).not.toBeNull();
        }
      }
    }
  });

  it('verifies all pending-local-source indicators have null values and explicit non-empty pending reasons', () => {
    const rows = buildCompleteSourceFixture();
    const pendingRows = rows.filter((r) => r.pending_reason !== null);
    expect(pendingRows.length).toBeGreaterThan(0);
    for (const r of pendingRows) {
      expect(r.numerator, `${r.indicator_code} numerator`).toBeNull();
      expect(r.denominator, `${r.indicator_code} denominator`).toBeNull();
      expect(r.value, `${r.indicator_code} value`).toBeNull();
      expect(typeof r.pending_reason).toBe('string');
      expect((r.pending_reason as string).trim().length).toBeGreaterThan(5);
    }
  });

  it('enforces zero PHI across all generated fixture rows', () => {
    const rows = buildCompleteSourceFixture();
    const phiKeys = ['hn', 'an', 'vn', 'cid', 'patient_name', 'citizen_id', 'id_card'];
    for (const row of rows) {
      for (const key of phiKeys) {
        expect(row).not.toHaveProperty(key);
      }
      // Check that string values don't contain 13-digit Thai national ID pattern
      for (const val of Object.values(row)) {
        if (typeof val === 'string') {
          expect(val).not.toMatch(/\b\d{13}\b/);
        }
      }
    }
  });
});

