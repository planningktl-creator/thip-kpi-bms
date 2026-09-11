import { describe, expect, it, vi } from 'vitest';
import { thipCatalogue } from '@/data/thipCatalogue';
import { getExpectedFiscalMonths } from '@/data/thipReporting';
import { getRuleUnit, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { BmsRequestError } from '@/services/bmsErrors';
import { buildCompletenessAuditQuery, buildDuplicateCheckQuery, buildIndicatorFromRows, buildSourceViewQuery, loadBmsIndicators, quoteSourceView, summarizeCoverage } from '@/services/bmsData';
import { getFiscalMonthPeriods } from '@/utils/fiscal';

describe('BMS KPI data adapter', () => {
  it('maps monthly source facts and calculates a weighted annual result', () => {
    const indicator = buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, numerator: '2', denominator: '10', value: '20', percentile: 71, status: 'on-track' },
      { indicator_code: 'DH0101', fiscal_month: 2, numerator: 1, denominator: 5, value: 20, percentile: 73 },
    ], 2026);

    expect(indicator?.dataSource).toBe('bms');
    expect(indicator?.monthly[0]).toMatchObject({ numerator: 2, denominator: 10, value: 20, percentile: 71 });
    expect(indicator?.monthly[0]?.status).toBe('unbenchmarked');
    expect(indicator?.monthly[2]?.value).toBeNull();
    expect(indicator?.annual).toMatchObject({ numerator: 3, denominator: 15, value: 20 });
  });

  it('normalizes PostgreSQL text-array source table metadata', () => {
    const indicator = buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, numerator: 1, denominator: 2, source_tables: '{ipt,an_stat}' },
    ], 2026);

    expect(indicator?.sourceTables).toEqual(['ipt', 'an_stat']);
  });

  it('uses the KPI formula multiplier for rate values and annual rollups', () => {
    const indicator = buildIndicatorFromRows('AA0101', [
      { indicator_code: 'AA0101', fiscal_month: 1, numerator: 1, denominator: 1000 },
    ], 2026);

    expect(indicator?.formula).toContain('100,000');
    expect(indicator?.monthly[0]?.value).toBe(100);
    expect(indicator?.annual.value).toBe(100);
  });

  it('rejects duplicate indicator-month rows', () => {
    expect(() => buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, numerator: 1, denominator: 2 },
      { indicator_code: 'DH0101', fiscal_month: 1, numerator: 2, denominator: 3 },
    ], 2026)).toThrow(BmsRequestError);
  });

  it('quotes only safe source-view identifiers', () => {
    expect(quoteSourceView('public.thip_kpi_monthly')).toBe('"public"."thip_kpi_monthly"');
    expect(() => quoteSourceView('public.thip_kpi_monthly; DROP TABLE patient')).toThrow();
    expect(buildSourceViewQuery('thip_kpi_monthly').sql).toContain('FROM "thip_kpi_monthly"');
    expect(buildSourceViewQuery('thip_kpi_monthly').sql).toContain('rule_version');
    expect(buildSourceViewQuery('thip_kpi_monthly').sql).toContain('refreshed_at');
  });

  it('builds a completeness audit covering every catalogue code x applicable fiscal period', () => {
    const query = buildCompletenessAuditQuery('thip_kpi_monthly');
    expect(query.key).toBe('thipCompletenessAudit');
    expect(query.sql).toContain('completeness_status');
    expect(query.sql).toContain('"thip_kpi_monthly"');
    expect(query.sql).toContain("('AA0101', 1)");
    expect(query.sql).toContain("('DH0101', 1)");
    expect(query.sql).toContain('zero-denominator');
    expect(query.sql.match(/\('[A-Z0-9.]+', \d{1,2}\)/g) ?? []).toHaveLength(1552);
  });

  it('builds a duplicate check that flags repeated indicator-month rows', () => {
    const query = buildDuplicateCheckQuery('thip_kpi_monthly');
    expect(query.sql).toContain('HAVING COUNT(*) <> 1');
    expect(query.sql).toContain('"thip_kpi_monthly"');
  });

  it('marks a source view complete only when all 232 indicators have every applicable reporting period', () => {
    const rows = thipCatalogue.flatMap((entry) => getExpectedFiscalMonths(entry.code).map((fiscalMonth) => ({
      indicator_code: entry.code,
      fiscal_month: fiscalMonth,
    })));
    const coverage = summarizeCoverage(rows, 2026);

    expect(coverage).toMatchObject({
      expectedIndicatorCount: 232,
      liveIndicatorCount: 232,
      expectedCellCount: 1552,
      coveredCellCount: 1552,
      unexpectedCellCount: 0,
      complete: true,
    });
  });

  it('keeps incomplete BMS responses partial instead of promoting them to live', () => {
    const coverage = summarizeCoverage([
      { indicator_code: 'DH0101', fiscal_month: 1 },
      { indicator_code: 'DH0101', fiscal_month: 2 },
    ], 2026);

    expect(coverage).toMatchObject({ liveIndicatorCount: 1, coveredCellCount: 2, complete: false });
  });

  it('rejects a row outside an indicator cadence from complete coverage', () => {
    const coverage = summarizeCoverage([
      { indicator_code: 'HH0103.3', fiscal_month: 1 },
      { indicator_code: 'HH0103.3', fiscal_month: 2 },
    ], 2026);

    expect(coverage).toMatchObject({
      liveIndicatorCount: 1,
      coveredCellCount: 1,
      unexpectedCellCount: 1,
      complete: false,
    });
  });

  it('does not count a code as live when every returned period is outside its cadence', () => {
    const coverage = summarizeCoverage([
      { indicator_code: 'AA0101', fiscal_month: 2 },
    ], 2026);

    expect(coverage).toMatchObject({ liveIndicatorCount: 0, coveredCellCount: 0, unexpectedCellCount: 1, complete: false });
  });

  it('accepts a complete normalized source view as the 232-indicator live contract', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubEnv('VITE_BMS_KPI_REQUIRE_COMPLETE_SOURCE_VIEW', 'true');
    const periods = getFiscalMonthPeriods(2026);
    const rows = thipCatalogue.flatMap((entry) => getExpectedFiscalMonths(entry.code).map((fiscalMonth) => ({
      indicator_code: entry.code,
      period_start: periods[fiscalMonth - 1]?.periodStart,
      fiscal_year: 2026,
      fiscal_month: fiscalMonth,
      numerator: null,
      denominator: null,
      value: null,
      target_scope: 'monthly',
      indicator_group: entry.group,
      unit: getRuleUnit(thipKpiRulesByCode.get(entry.code)!),
      direction: 'neutral',
      category: 'test category',
      title: entry.title,
      definition: 'test definition',
      formula: thipKpiRulesByCode.get(entry.code)?.formulaScale ?? 'a/b x 100',
      numerator_label: 'test numerator',
      denominator_label: 'test denominator',
      source_tables: ['thip_kpi_monthly'],
      frequency: 'monthly',
      reference: 'test reference',
      rule_version: '2025.1-test',
      refreshed_at: '2026-09-11T08:00:00Z',
    })));
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: rows })),
    }));

    try {
      const result = await loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026);
      expect(result.sourceView).toBe('thip_kpi_monthly');
      expect(result.liveCodes).toHaveLength(232);
      expect(result.indicators).toHaveLength(232);
      expect(result.coverage.complete).toBe(true);
      expect(result.refreshedAt).toBe('2026-09-11T08:00:00Z');
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('fails closed when a required source view is incomplete', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubEnv('VITE_BMS_KPI_REQUIRE_COMPLETE_SOURCE_VIEW', 'true');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 1,
        denominator: 2,
        value: 50,
        target_scope: 'monthly',
        indicator_group: 'D',
        unit: 'percent',
        direction: 'lower-is-better',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/source view thip_kpi_monthly is incomplete/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects an empty configured source view', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/returned no rows/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects normalized source rows that omit required metadata', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 1,
        denominator: 2,
        value: 50,
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toMatchObject({ phase: 'data', failure: 'response' });
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects invalid normalized metadata', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 0,
        denominator: 1,
        value: 0,
        target_scope: 'monthly',
        indicator_group: 'D',
        unit: 'percent',
        direction: 'not-a-direction',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/invalid direction/);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects a source unit that conflicts with the registered formula scale', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'AA0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 1,
        denominator: 1000,
        value: 100,
        target_scope: 'annual',
        indicator_group: 'A',
        unit: 'percent',
        direction: 'neutral',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100,000',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'annual',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/formula requires rate/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects a source formula multiplier that conflicts with the registered rule', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'AA0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 1,
        denominator: 1000,
        value: 100,
        target_scope: 'annual',
        indicator_group: 'A',
        unit: 'rate',
        direction: 'neutral',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/formula multiplier that conflicts/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects a source value that does not match its numerator and denominator', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 1,
        denominator: 4,
        value: 40,
        target_scope: 'monthly',
        indicator_group: 'D',
        unit: 'percent',
        direction: 'lower-is-better',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/value inconsistent with numerator/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects normalized metadata whose group does not match the catalogue code', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 0,
        denominator: 1,
        value: 0,
        target_scope: 'monthly',
        indicator_group: 'C',
        unit: 'percent',
        direction: 'lower-is-better',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/indicator_group that does not match DH0101/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects inconsistent descriptive metadata for the same indicator across periods', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    const baseRow = {
      indicator_code: 'DH0101',
      fiscal_year: 2026,
      numerator: 1,
      denominator: 4,
      value: 25,
      target: 5,
      indicator_group: 'D',
      unit: 'percent',
      direction: 'lower-is-better',
      category: 'test category',
      title: 'test title',
      title_th: 'test title th',
      definition: 'test definition',
      formula: 'a/b x 100',
      numerator_label: 'test numerator',
      denominator_label: 'test denominator',
      source_tables: ['ipt'],
      frequency: 'ทุกเดือน',
      reference: 'test reference',
      rule_version: '2025.1-test',
      refreshed_at: '2026-09-11T08:00:00Z',
    };
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [
        { ...baseRow, fiscal_month: 1, period_start: '2025-10-01', target_scope: 'monthly' },
        { ...baseRow, fiscal_month: 2, period_start: '2025-11-01', target_scope: 'annual' },
      ] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/inconsistent descriptive metadata for DH0101/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects a non-NULL value when a normalized row has a zero denominator', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 0,
        denominator: 0,
        value: 0,
        target_scope: 'monthly',
        indicator_group: 'D',
        unit: 'percent',
        direction: 'lower-is-better',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/NULL value when denominator is zero/);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects a ratio value without a denominator', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: null,
        denominator: null,
        value: 50,
        target_scope: 'monthly',
        indicator_group: 'D',
        unit: 'percent',
        direction: 'lower-is-better',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/value without a denominator/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects a percentile outside the normalized 0-100 range', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        period_start: '2025-10-01',
        fiscal_year: 2026,
        fiscal_month: 1,
        numerator: 1,
        denominator: 4,
        value: 25,
        percentile: 101,
        target_scope: 'monthly',
        indicator_group: 'D',
        unit: 'percent',
        direction: 'lower-is-better',
        category: 'test category',
        title: 'test title',
        definition: 'test definition',
        formula: 'a/b x 100',
        numerator_label: 'test numerator',
        denominator_label: 'test denominator',
        source_tables: ['thip_kpi_monthly'],
        frequency: 'monthly',
        reference: 'test reference',
        rule_version: '2025.1-test',
        refreshed_at: '2026-09-11T08:00:00Z',
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toThrow(/percentile outside 0-100/i);
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('rejects normalized source rows that omit period_start', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW', 'thip_kpi_monthly');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({ data: [{
        indicator_code: 'DH0101',
        fiscal_year: 2026,
        fiscal_month: 1,
      }] })),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toMatchObject({ phase: 'data', failure: 'response' });
    } finally {
      vi.unstubAllEnvs();
      vi.unstubAllGlobals();
    }
  });

  it('fails closed when complete coverage is required without a source view', async () => {
    vi.stubEnv('VITE_BMS_KPI_REQUIRE_COMPLETE_SOURCE_VIEW', 'true');
    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toMatchObject({ phase: 'data', failure: 'config' });
    } finally {
      vi.unstubAllEnvs();
    }
  });

  it('builds average-length-of-stay indicators as ratio units', () => {
    const los = buildIndicatorFromRows('DH0112', [
      { indicator_code: 'DH0112', fiscal_month: 1, numerator: 42, denominator: 6, value: 7 },
    ], 2026);
    expect(los?.unit).toBe('ratio');
    expect(los?.direction).toBe('neutral');
    expect(los?.target).toBeNull();
    expect(los?.monthly[0]).toMatchObject({ numerator: 42, denominator: 6, value: 7 });
  });

  it('keeps direct count values when a count KPI has no denominator', () => {
    const count = buildIndicatorFromRows('SM0201', [
      { indicator_code: 'SM0201', fiscal_month: 1, unit: 'count', numerator: null, denominator: null, value: 12 },
    ], 2026);

    expect(count?.monthly[0]).toMatchObject({ value: 12, numerator: null, denominator: null });
    expect(count?.annual).toMatchObject({ value: 12, numerator: null, denominator: null });
  });

  it('honors an explicit NULL target from the normalized source instead of using a seed target', () => {
    const indicator = buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, target: null, numerator: 1, denominator: 4, value: 25 },
    ], 2026);

    expect(indicator?.target).toBeNull();
    expect(indicator?.monthly[0]?.target).toBeNull();
  });

  it('does not carry a target from another reporting period into an explicit NULL source target', () => {
    const indicator = buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, target: 5, numerator: 1, denominator: 4, value: 25 },
      { indicator_code: 'DH0101', fiscal_month: 2, target: null, numerator: 1, denominator: 4, value: 25 },
    ], 2026);

    expect(indicator?.monthly[0]?.target).toBe(5);
    expect(indicator?.monthly[1]?.target).toBeNull();
  });

  it('does not treat monthly targets as an annual target', () => {
    const indicator = buildIndicatorFromRows('DH0101', [
      { indicator_code: 'DH0101', fiscal_month: 1, target_scope: 'monthly', target: 5, numerator: 1, denominator: 4, value: 25 },
    ], 2026);

    expect(indicator?.target).toBe(5);
    expect(indicator?.annual.target).toBeNull();
    expect(indicator?.annual.status).toBe('unbenchmarked');
  });

  it('keeps an annual target on the annual rollup', () => {
    const indicator = buildIndicatorFromRows('AA0101', [
      { indicator_code: 'AA0101', fiscal_month: 1, target_scope: 'annual', target: 100, numerator: 1, denominator: 1000 },
    ], 2026);

    expect(indicator?.annual.target).toBe(100);
  });

  it('classifies API failures during the KPI load as data failures', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 502,
      text: vi.fn().mockResolvedValue(''),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toMatchObject({ phase: 'data', failure: 'http', status: 502 });
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('surfaces a 401 as a data-phase http failure for session-expiry messaging', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: false,
      status: 401,
      text: vi.fn().mockResolvedValue(''),
    }));

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'expired-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026)).rejects.toMatchObject({ phase: 'data', failure: 'http', status: 401 });
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('maps a hung BMS API request to a timeout failure', async () => {
    vi.stubGlobal('fetch', vi.fn((_url: string, init?: RequestInit) => new Promise<Response>((_resolve, reject) => {
      init?.signal?.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')));
    })));

    const abort = new AbortController();
    setTimeout(() => abort.abort(), 50);

    try {
      await expect(loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
        marketplaceToken: undefined,
      }, 2026, { signal: abort.signal })).rejects.toMatchObject({ phase: 'data', failure: 'timeout' });
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('stamps the load result with a refresh timestamp', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({
        data: [{
          indicator_code: 'DH0101',
          period_start: '2025-10-01',
          fiscal_year: 2026,
          fiscal_month: 1,
          numerator: 1,
          denominator: 4,
          value: 25,
        }],
      })),
    }));

    try {
      const result = await loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026);
      expect(Number.isNaN(Date.parse(result.refreshedAt))).toBe(false);
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('accepts the BMS result response envelope', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({
        result: [{
          indicator_code: 'DH0101',
          period_start: '2025-10-01',
          fiscal_year: 2026,
          fiscal_month: 1,
          numerator: 1,
          denominator: 4,
          value: 25,
        }],
      })),
    }));

    try {
      const result = await loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026);
      expect(result.liveCodes).toEqual(['DH0101']);
      expect(result.coverage.complete).toBe(false);
      expect(result.indicators.find((indicator) => indicator.code === 'DH0101')).toMatchObject({ dataSource: 'bms' });
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('keeps the complete catalogue visible when local foundation data is partial', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      text: vi.fn().mockResolvedValue(JSON.stringify({
        data: [{
          indicator_code: 'DH0101',
          period_start: '2025-10-01',
          fiscal_year: 2026,
          fiscal_month: 1,
          numerator: 1,
          denominator: 4,
          value: 25,
        }],
      })),
    }));

    try {
      const result = await loadBmsIndicators({
        apiUrl: 'https://bms.test',
        bearerToken: 'test-token',
        appIdentifier: 'THIP.KPI.BMS',
      }, 2026);
      expect(result.indicators).toHaveLength(232);
      expect(result.indicators.find((indicator) => indicator.code === 'DH0101')).toMatchObject({ dataSource: 'bms' });
      expect(result.indicators.find((indicator) => indicator.code === 'AA0101')).toMatchObject({ dataSource: 'no-data' });
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
