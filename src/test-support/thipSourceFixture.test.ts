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
});
