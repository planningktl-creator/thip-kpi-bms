import { createNoDataIndicator, thipCatalogueByCode } from '@/data/thipCatalogue';
import { createLiveIndicator, type LiveDefinition } from '@/data/liveDefinitions';
import { BmsRequestError } from '@/services/bmsErrors';
import {
  executeRegisteredQuery,
  queryRegistry,
  type BmsParam,
  type BmsSqlResponse,
  type RegisteredQuery,
} from '@/services/queryRegistry';
import type {
  AnnualResult,
  FiscalYear,
  Indicator,
  IndicatorDirection,
  IndicatorGroup,
  IndicatorStatus,
  IndicatorUnit,
  MonthlyResult,
  TargetScope,
} from '@/types/thip';
import { getFiscalMonthPeriods } from '@/utils/fiscal';

export const foundationIndicatorCodes = ['DH0101', 'DN0101', 'DR0101', 'CE0101', 'CI0101', 'DH0102'] as const;

const liveSeeds: Record<string, Omit<LiveDefinition, 'code'>> = {
  DH0101: {
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน',
    unit: 'percent',
    direction: 'lower-is-better',
    target: 3.5,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis เป็น Acute coronary syndrome และเสียชีวิตจากทุกสาเหตุ',
    formula: '(จำนวนผู้ป่วย ACS ที่เสียชีวิต ÷ จำนวนผู้ป่วย ACS ที่จำหน่ายทุกสถานะ) × 100',
    numeratorLabel: 'จำหน่ายด้วยการเสียชีวิต',
    denominatorLabel: 'ผู้ป่วย ACS ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 39',
  },
  DN0101: {
    group: 'D',
    category: 'Neurovascular disease · Stroke',
    title: 'Stroke: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย Stroke',
    unit: 'percent',
    direction: 'lower-is-better',
    target: 5,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis หรือโรคร่วมตามกลุ่มรหัส Stroke และจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Stroke ที่เสียชีวิต ÷ จำนวนผู้ป่วย Stroke ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Stroke ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Stroke ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 67',
  },
  DR0101: {
    group: 'D',
    category: 'Respiratory disease · Pneumonia',
    title: 'Pneumonia: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วยปอดบวม',
    unit: 'percent',
    direction: 'lower-is-better',
    target: 8,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่เข้าเกณฑ์ Pneumonia ตามนิยามและจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Pneumonia ที่เสียชีวิต ÷ จำนวนผู้ป่วย Pneumonia ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Pneumonia ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Pneumonia ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 79',
  },
  CE0101: {
    group: 'C',
    category: 'Sepsis care process',
    title: 'Sepsis: Percent of broad-spectrum antibiotic receiving within 3 hours',
    titleTh: 'ร้อยละผู้ป่วย Sepsis ที่ได้รับยาปฏิชีวนะ broad-spectrum ภายใน 3 ชั่วโมง',
    unit: 'percent',
    direction: 'higher-is-better',
    target: 80,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis หรือโรคร่วมเป็น Sepsis และได้รับยาปฏิชีวนะ broad-spectrum ภายใน 3 ชั่วโมง',
    formula: '(จำนวนผู้ป่วย Sepsis ที่ได้รับยาปฏิชีวนะ broad-spectrum ภายใน 3 ชั่วโมง ÷ จำนวนผู้ป่วย Sepsis ทั้งหมด) × 100',
    numeratorLabel: 'ได้รับ broad-spectrum antibiotic ภายใน 3 ชั่วโมง',
    denominatorLabel: 'ผู้ป่วย Sepsis ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'opitemrece', 'drugitems'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 65',
  },
  CI0101: {
    group: 'C',
    category: 'Sepsis care process',
    title: 'Sepsis: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย Sepsis',
    unit: 'percent',
    direction: 'lower-is-better',
    target: 15,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis หรือโรคร่วมเป็น Sepsis และจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Sepsis ที่เสียชีวิต ÷ จำนวนผู้ป่วย Sepsis ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Sepsis ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Sepsis ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 105',
  },
  DH0102: {
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome: Aspirin within 24 hours',
    titleTh: 'ร้อยละผู้ป่วย ACS ที่ได้รับ Aspirin ภายใน 24 ชั่วโมง',
    unit: 'percent',
    direction: 'higher-is-better',
    target: 90,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis เป็น Acute coronary syndrome และได้รับ Aspirin ภายใน 24 ชั่วโมง',
    formula: '(จำนวนผู้ป่วย ACS ที่ได้รับ Aspirin ภายใน 24 ชั่วโมง ÷ จำนวนผู้ป่วย ACS ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ได้รับ Aspirin ภายใน 24 ชั่วโมง',
    denominatorLabel: 'ผู้ป่วย ACS ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'opitemrece', 'drugitems'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 42',
  },
};

export type RawKpiRow = Record<string, unknown>;

export type BmsDataLoadResult = {
  indicators: Indicator[];
  rowCount: number;
  sourceView: string | null;
  liveCodes: string[];
  /** ISO timestamp captured when the BMS response was accepted. */
  refreshedAt: string;
};

const identifierPart = /^[A-Za-z_][A-Za-z0-9_]*$/;
const validUnits = new Set<IndicatorUnit>(['percent', 'rate', 'ratio', 'count']);
const validDirections = new Set<IndicatorDirection>(['higher-is-better', 'lower-is-better', 'neutral']);
const validTargetScopes = new Set<TargetScope>(['monthly', 'annual']);
const validStatuses = new Set<IndicatorStatus>(['on-track', 'watch', 'action', 'no-data']);

function configuredSourceView(): string | null {
  const value = String(import.meta.env.VITE_BMS_KPI_SOURCE_VIEW ?? '').trim();
  return value || null;
}

export function quoteSourceView(value: string): string {
  const parts = value.trim().split('.');
  if (parts.length < 1 || parts.length > 3 || parts.some((part) => !identifierPart.test(part))) {
    throw new Error('VITE_BMS_KPI_SOURCE_VIEW ต้องเป็นชื่อ table/view ที่ไม่มีอักขระพิเศษ');
  }
  return parts.map((part) => `"${part}"`).join('.');
}

export function buildSourceViewQuery(sourceView: string): RegisteredQuery {
  const quotedView = quoteSourceView(sourceView);
  return {
    key: 'thipMonthlySourceView',
    description: `ผลลัพธ์ THIP รายเดือนจาก source view ${sourceView}`,
    sql: `
      SELECT
        indicator_code,
        period_start,
        fiscal_year,
        fiscal_month,
        numerator,
        denominator,
        value,
        target,
        target_scope,
        percentile,
        indicator_group,
        unit,
        direction,
        category,
        title,
        title_th,
        definition,
        formula,
        numerator_label,
        denominator_label,
        source_tables,
        frequency,
        reference
      FROM ${quotedView}
      WHERE period_start >= :start_date
        AND period_start < :end_date
        AND fiscal_year = :fiscal_year
      ORDER BY indicator_code, fiscal_month
    `.trim(),
  };
}

function getValue(row: RawKpiRow, key: string): unknown {
  const found = Object.keys(row).find((candidate) => candidate.toLowerCase() === key.toLowerCase());
  return found ? row[found] : undefined;
}

function asString(value: unknown): string | null {
  if (typeof value !== 'string' && typeof value !== 'number') return null;
  const text = String(value).trim();
  return text || null;
}

function asNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  const number = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

function asInteger(value: unknown): number | null {
  const number = asNumber(value);
  return number === null ? null : Math.trunc(number);
}

function asUnit(value: unknown, fallback: IndicatorUnit): IndicatorUnit {
  const unit = asString(value) as IndicatorUnit | null;
  return unit && validUnits.has(unit) ? unit : fallback;
}

function asDirection(value: unknown, fallback: IndicatorDirection): IndicatorDirection {
  const direction = asString(value) as IndicatorDirection | null;
  return direction && validDirections.has(direction) ? direction : fallback;
}

function asTargetScope(value: unknown, fallback: TargetScope): TargetScope {
  const targetScope = asString(value) as TargetScope | null;
  return targetScope && validTargetScopes.has(targetScope) ? targetScope : fallback;
}

function asStatus(value: unknown): IndicatorStatus | null {
  const status = asString(value) as IndicatorStatus | null;
  return status && validStatuses.has(status) ? status : null;
}

function getStatus(value: number | null, target: number | null, direction: IndicatorDirection): IndicatorStatus {
  if (value === null) return 'no-data';
  if (target === null || direction === 'neutral') return 'on-track';
  const margin = Math.max(Math.abs(target) * 0.08, 0.02);
  if (direction === 'higher-is-better') {
    if (value >= target) return 'on-track';
    if (value >= target - margin) return 'watch';
    return 'action';
  }
  if (value <= target) return 'on-track';
  if (value <= target + margin) return 'watch';
  return 'action';
}

function asSourceTables(value: unknown, fallback: string[]): string[] {
  if (Array.isArray(value)) return value.map(asString).filter((item): item is string => Boolean(item));
  const text = asString(value);
  return text ? text.split(',').map((item) => item.trim()).filter(Boolean) : fallback;
}

function rowPeriod(row: RawKpiRow, periods: ReturnType<typeof getFiscalMonthPeriods>): number | null {
  const fiscalMonth = asInteger(getValue(row, 'fiscal_month'));
  if (fiscalMonth && fiscalMonth >= 1 && fiscalMonth <= 12) return fiscalMonth;
  const periodStart = asString(getValue(row, 'period_start'));
  const match = periods.find((period) => period.periodStart === periodStart);
  return match?.fiscalMonth ?? null;
}

function makeAnnual(
  monthly: MonthlyResult[],
  fiscalYear: FiscalYear,
  unit: IndicatorUnit,
  target: number | null,
  direction: IndicatorDirection,
): AnnualResult {
  const rows = monthly.filter((month) => month.numerator !== null && month.denominator !== null);
  const numerator = rows.length ? rows.reduce((sum, month) => sum + (month.numerator ?? 0), 0) : null;
  const denominator = rows.length ? rows.reduce((sum, month) => sum + (month.denominator ?? 0), 0) : null;
  const scale = unit === 'percent' || unit === 'rate' ? 100 : 1;
  const value = unit === 'count'
    ? (rows.length ? Number(rows.reduce((sum, month) => sum + (month.value ?? 0), 0).toFixed(2)) : null)
    : numerator !== null && denominator
      ? Number(((numerator / denominator) * scale).toFixed(2))
      : null;

  return {
    fiscalYear,
    numerator,
    denominator,
    value,
    target,
    status: getStatus(value, target, direction),
  };
}

function getBaseIndicator(code: string, fiscalYear: FiscalYear): Indicator | null {
  const liveSeed = liveSeeds[code];
  if (liveSeed) return createLiveIndicator({ code, ...liveSeed }, fiscalYear);
  const catalogueEntry = thipCatalogueByCode.get(code);
  return catalogueEntry ? createNoDataIndicator(catalogueEntry, fiscalYear) : null;
}

export function buildIndicatorFromRows(
  code: string,
  rows: RawKpiRow[],
  fiscalYear: FiscalYear,
): Indicator | null {
  const base = getBaseIndicator(code, fiscalYear);
  if (!base) return null;
  const periods = getFiscalMonthPeriods(fiscalYear);
  const firstRow = rows[0];
  const unit = asUnit(getValue(firstRow ?? {}, 'unit'), base.unit);
  const direction = asDirection(getValue(firstRow ?? {}, 'direction'), base.direction);
  const targetScope = asTargetScope(getValue(firstRow ?? {}, 'target_scope'), base.targetScope);
  const targetFromRows = rows.map((row) => asNumber(getValue(row, 'target'))).find((value) => value !== null) ?? base.target;
  const rowsByMonth = new Map<number, RawKpiRow>();

  for (const row of rows) {
    const month = rowPeriod(row, periods);
    if (!month) continue;
    if (rowsByMonth.has(month)) {
      throw new BmsRequestError('data', 'response', `BMS KPI source has duplicate rows for ${code} month ${month}`);
    }
    rowsByMonth.set(month, row);
  }

  const monthly = periods.map((period) => {
    const row = rowsByMonth.get(period.fiscalMonth);
    const numerator = asNumber(getValue(row ?? {}, 'numerator'));
    const denominator = asNumber(getValue(row ?? {}, 'denominator'));
    const sourceValue = asNumber(getValue(row ?? {}, 'value'));
    const scale = unit === 'percent' || unit === 'rate' ? 100 : 1;
    const value = denominator === null || denominator === 0
      ? null
      : sourceValue ?? (numerator === null ? null : Number(((numerator / denominator) * scale).toFixed(2)));
    const target = targetScope === 'monthly'
      ? asNumber(getValue(row ?? {}, 'target')) ?? targetFromRows
      : null;

    return {
      periodStart: period.periodStart,
      fiscalYear,
      fiscalMonth: period.fiscalMonth,
      label: period.label,
      numerator,
      denominator,
      value,
      target,
      percentile: asNumber(getValue(row ?? {}, 'percentile')),
      status: asStatus(getValue(row ?? {}, 'status')) ?? getStatus(value, target, direction),
    } satisfies MonthlyResult;
  });

  const rowText = (key: string, fallback: string): string => asString(getValue(firstRow ?? {}, key)) ?? fallback;
  const group = (rowText('indicator_group', rowText('group', base.group)) as IndicatorGroup);
  const next: Indicator = {
    ...base,
    code,
    dataSource: rowsByMonth.size ? 'bms' : 'no-data',
    fiscalYear,
    group: ['D', 'C', 'S', 'H', 'A'].includes(group) ? group : base.group,
    category: rowText('category', base.category),
    title: rowText('title', base.title),
    titleTh: rowText('title_th', base.titleTh),
    unit,
    direction,
    target: targetFromRows,
    targetScope,
    definition: rowText('definition', base.definition),
    formula: rowText('formula', base.formula),
    numeratorLabel: rowText('numerator_label', base.numeratorLabel),
    denominatorLabel: rowText('denominator_label', base.denominatorLabel),
    sourceTables: asSourceTables(getValue(firstRow ?? {}, 'source_tables'), base.sourceTables),
    frequency: rowText('frequency', base.frequency),
    reference: rowText('reference', base.reference),
    monthly,
    annual: makeAnnual(monthly, fiscalYear, unit, targetFromRows, direction),
  };
  return next;
}

function paramsForFiscalYear(fiscalYear: FiscalYear, includeFiscalYear: boolean): Record<string, BmsParam> {
  const periods = getFiscalMonthPeriods(fiscalYear);
  const params: Record<string, BmsParam> = {
    start_date: { value: periods[0].periodStart, value_type: 'date' },
    end_date: { value: `${fiscalYear}-10-01`, value_type: 'date' },
  };
  if (includeFiscalYear) params.fiscal_year = { value: fiscalYear, value_type: 'integer' };
  return params;
}

function responseRows(response: BmsSqlResponse): RawKpiRow[] {
  const rows = response.data ?? response.result;
  return Array.isArray(rows) ? rows.filter((row): row is RawKpiRow => Boolean(row && typeof row === 'object')) : [];
}

function asDataError(error: unknown): unknown {
  if (!(error instanceof BmsRequestError) || error.phase !== 'api') return error;
  return new BmsRequestError('data', error.failure, error.message, error.status, { cause: error });
}

function assertNoUnknownCodes(rows: RawKpiRow[]): void {
  for (const row of rows) {
    const code = asString(getValue(row, 'indicator_code'));
    if (!code) {
      throw new BmsRequestError('data', 'response', 'BMS KPI source row is missing indicator_code');
    }
    if (!thipCatalogueByCode.has(code)) {
      throw new BmsRequestError('data', 'response', `BMS KPI source returned unknown indicator ${code}`);
    }
  }
}

export async function loadBmsIndicators(
  runtime: { apiUrl: string; bearerToken: string; appIdentifier: string; marketplaceToken?: string },
  fiscalYear: FiscalYear,
  options?: { signal?: AbortSignal; timeoutMs?: number },
): Promise<BmsDataLoadResult> {
  const sourceView = configuredSourceView();
  const query = sourceView ? buildSourceViewQuery(sourceView) : queryRegistry.thipIpdFoundation;
  let response: BmsSqlResponse;
  try {
    response = await executeRegisteredQuery(query, runtime, paramsForFiscalYear(fiscalYear, Boolean(sourceView)), runtime.marketplaceToken, { signal: options?.signal, timeoutMs: options?.timeoutMs });
  } catch (error) {
    throw asDataError(error);
  }
  const rows = responseRows(response);
  assertNoUnknownCodes(rows);

  if (sourceView) {
    const codes = new Set<string>([
      ...thipCatalogueByCode.keys(),
      ...rows.map((row) => asString(getValue(row, 'indicator_code'))).filter((code): code is string => Boolean(code)),
    ]);
    const indicators = Array.from(codes)
      .map((code) => buildIndicatorFromRows(code, rows.filter((row) => asString(getValue(row, 'indicator_code')) === code), fiscalYear))
      .filter((indicator): indicator is Indicator => Boolean(indicator));
    return { indicators, rowCount: rows.length, sourceView, liveCodes: rows.map((row) => asString(getValue(row, 'indicator_code'))).filter((code): code is string => Boolean(code)), refreshedAt: new Date().toISOString() };
  }

  const byCode = new Map<string, RawKpiRow[]>();
  for (const row of rows) {
    const code = asString(getValue(row, 'indicator_code'));
    if (!code) continue;
    byCode.set(code, [...(byCode.get(code) ?? []), row]);
  }
  const indicators = foundationIndicatorCodes
    .map((code) => buildIndicatorFromRows(code, byCode.get(code) ?? [], fiscalYear))
    .filter((indicator): indicator is Indicator => Boolean(indicator));
  return {
    indicators,
    rowCount: rows.length,
    sourceView: null,
    liveCodes: foundationIndicatorCodes.filter((code) => byCode.has(code)),
    refreshedAt: new Date().toISOString(),
  };
}
