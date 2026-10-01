import { describe, expect, it, vi, afterEach } from 'vitest';
import { buildIndicatorFromRows, loadBmsIndicators, summarizeCoverage } from './bmsData';
import { publishApprovedThip } from './publication';
import { buildCompleteSourceFixture } from '@/test-support/thipSourceFixture';
import { createNoDataIndicator, thipCatalogue } from '@/data/thipCatalogue';
import { rollupQuarters } from '@/utils/rollup';
import { buildControlChart } from '@/utils/controlChart';
afterEach(() => { vi.unstubAllEnvs(); vi.unstubAllGlobals(); });
describe('audit correctness regressions', () => {
  it('keeps the 1552 delivered reporting cells while withholding every unapproved fact', () => {
    const rows = buildCompleteSourceFixture();
    const indicators = thipCatalogue.map((entry) => buildIndicatorFromRows(entry.code, rows.filter((row) => row.indicator_code === entry.code),2026)!);
    const published = publishApprovedThip({ indicators, rowCount:1552,sourceView:'reporting.synthetic',liveCodes:thipCatalogue.map((entry)=>entry.code),coverage:summarizeCoverage(rows,2026),refreshedAt:'2026-10-01T00:00:00Z' });
    expect(published.coverage).toMatchObject({complete:true,coveredCellCount:1552,availableCellCount:0,unavailableCellCount:1552});
    expect(published.indicators.every((indicator)=>indicator.monthly.every((month)=>month.value===null && month.numerator===null))).toBe(true);
    expect(published.indicators.every((indicator)=>indicator.pendingReason?.startsWith('rule-unapproved'))).toBe(true);
  });
  it('reports budget exhaustion with a reason without shrinking any observation window', async () => {
    vi.stubEnv('VITE_BMS_KPI_SOURCE_VIEW',''); vi.stubEnv('VITE_BMS_KPI_REQUIRE_COMPLETE_SOURCE_VIEW','false');
    const windows: string[] = [];
    vi.stubGlobal('fetch',vi.fn(async (_url,init:RequestInit) => {
      const body = JSON.parse(String(init.body)); windows.push(`${body.params.start_date.value}/${body.params.end_date.value}`);
      return {ok:false,status:504,text:async()=>''};
    }));
    const result = await loadBmsIndicators({apiUrl:'https://synthetic.test',bearerToken:'synthetic',appIdentifier:'test'},2026,{concurrency:6});
    expect(new Set(windows)).toEqual(new Set(['2025-10-01/2026-10-01']));
    expect(result.coverage.availableCellCount).toBe(0);
    expect(result.indicators.find((indicator)=>indicator.code==='DH0101')!.pendingReason).toContain('query-budget-exceeded');
  });
  it('compares quarters only with targets valid consistently inside that quarter', () => {
    const indicator = createNoDataIndicator(thipCatalogue.find((entry)=>entry.code==='DH0101')!,2026);
    indicator.monthly = indicator.monthly.map((month)=>({...month,target:month.fiscalMonth<=3?5:10,numerator:1,denominator:100,value:1}));
    expect(rollupQuarters(indicator).map((quarter)=>quarter.target)).toEqual([5,10,10,10]);
    indicator.monthly[1].target=6;
    expect(rollupQuarters(indicator)[0].target).toBeNull();
    indicator.targetScope='annual'; indicator.annual.target=5;
    expect(rollupQuarters(indicator).every((quarter)=>quarter.target===null)).toBe(true);
  });
  it('does not report a run of points lying exactly on the center line', () => {
    const indicator = createNoDataIndicator(thipCatalogue.find((entry)=>entry.code==='DH0101')!,2026);
    indicator.monthly = indicator.monthly.map((month)=>({...month,numerator:5,denominator:100,value:5}));
    const chart=buildControlChart(indicator);
    expect(chart.runSignalCount).toBe(0); expect(chart.points.every((point)=>point.signal==='none')).toBe(true);
    indicator.unit='ratio';
    expect(buildControlChart(indicator).kind).toBe('individuals');
  });
});
