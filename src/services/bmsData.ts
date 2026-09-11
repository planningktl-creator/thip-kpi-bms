import { createNoDataIndicator, thipCatalogue, thipCatalogueByCode } from '@/data/thipCatalogue';
import { createFoundationIndicator, type FoundationDefinition } from '@/data/liveDefinitions';
import { foundationRuleCodes, getFormulaScale, getRuleUnit, thipKpiRulesByCode } from '@/data/thipKpiRules';
import { getExpectedFiscalMonths } from '@/data/thipReporting';
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

export const foundationIndicatorCodes = foundationRuleCodes;

const foundationDefinitions: Record<string, Omit<FoundationDefinition, 'code'>> = {
  DH0101: {
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis หรือ qualifying secondary diagnosis เป็น Acute coronary syndrome และเสียชีวิตตามนิยาม THIP',
    formula: '(จำนวนผู้ป่วย ACS ที่เสียชีวิต ÷ จำนวนผู้ป่วย ACS ที่จำหน่ายทุกสถานะ) × 100',
    numeratorLabel: 'จำหน่ายด้วยการเสียชีวิต',
    denominatorLabel: 'ผู้ป่วย ACS ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'death'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 39',
  },
  'DH0101.1': {
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome (STEMI): Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย STEMI',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis หรือ qualifying secondary diagnosis เป็น STEMI ตามรหัส I21.0-I21.3 และเสียชีวิตตามนิยาม THIP',
    formula: '(จำนวนผู้ป่วย STEMI ที่เสียชีวิต ÷ จำนวนผู้ป่วย STEMI ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย STEMI ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย STEMI ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat', 'iptdiag', 'death'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 40',
  },
  'DH0101.2': {
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome (NSTE-ACS): Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย NSTE-ACS',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis หรือ qualifying secondary diagnosis เป็น NSTE-ACS ตามรหัส I21.4/I21.9 และเสียชีวิตตามนิยาม THIP',
    formula: '(จำนวนผู้ป่วย NSTE-ACS ที่เสียชีวิต ÷ จำนวนผู้ป่วย NSTE-ACS ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย NSTE-ACS ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย NSTE-ACS ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat', 'iptdiag', 'death'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 41',
  },
  DN0101: {
    group: 'D',
    category: 'Neurovascular disease · Stroke',
    title: 'Stroke: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย Stroke',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis ตามกลุ่มรหัส Stroke และจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Stroke ที่เสียชีวิต ÷ จำนวนผู้ป่วย Stroke ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Stroke ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Stroke ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'death'],
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
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่เข้าเกณฑ์ Pneumonia ตามนิยามและจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Pneumonia ที่เสียชีวิต ÷ จำนวนผู้ป่วย Pneumonia ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Pneumonia ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Pneumonia ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'death'],
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
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis หรือโรคร่วมเป็น Sepsis และได้รับยาปฏิชีวนะ broad-spectrum ภายใน 3 ชั่วโมง',
    formula: '(จำนวนผู้ป่วย Sepsis ที่ได้รับยาปฏิชีวนะ broad-spectrum ภายใน 3 ชั่วโมง ÷ จำนวนผู้ป่วย Sepsis ทั้งหมด) × 100',
    numeratorLabel: 'ได้รับ broad-spectrum antibiotic ภายใน 3 ชั่วโมง',
    denominatorLabel: 'ผู้ป่วย Sepsis ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'opitemrece', 'drugitems'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 194',
  },
  CI0101: {
    group: 'C',
    category: 'Sepsis care process',
    title: 'Sepsis: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย Sepsis',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis หรือโรคร่วมเป็น Sepsis และจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย Sepsis ที่เสียชีวิต ÷ จำนวนผู้ป่วย Sepsis ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Sepsis ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Sepsis ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'death'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 199',
  },
  DH0102: {
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome: Aspirin within 24 hours',
    titleTh: 'ร้อยละผู้ป่วย ACS ที่ได้รับ Aspirin ภายใน 24 ชั่วโมง',
    unit: 'percent',
    direction: 'higher-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis เป็น Acute coronary syndrome และได้รับ Aspirin ภายใน 24 ชั่วโมง',
    formula: '(จำนวนผู้ป่วย ACS ที่ได้รับ Aspirin ภายใน 24 ชั่วโมง ÷ จำนวนผู้ป่วย ACS ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ได้รับ Aspirin ภายใน 24 ชั่วโมง',
    denominatorLabel: 'ผู้ป่วย ACS ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'iptdiag', 'an_stat', 'opitemrece', 'drugitems'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 42',
  },
  DG0202: {
    group: 'D',
    category: 'Appendicitis · Acute appendicitis',
    title: 'Acute Appendicitis: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วยไส้ติ่งอักเสบเฉียบพลัน',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis เป็น Acute appendicitis และจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วยไส้ติ่งอักเสบที่เสียชีวิต ÷ จำนวนผู้ป่วยไส้ติ่งอักเสบที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Acute appendicitis ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย Acute appendicitis ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat', 'death'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 123',
  },
  DG0102: {
    group: 'D',
    category: 'Gastrointestinal disease · Upper gastrointestinal hemorrhage',
    title: 'Upper gastrointestinal hemorrhage (UGIH): Average length of stay',
    titleTh: 'ระยะเวลาวันนอนเฉลี่ยของผู้ป่วย Upper GI hemorrhage',
    unit: 'ratio',
    direction: 'neutral',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis เป็น Upper gastrointestinal hemorrhage ตามกลุ่มรหัส THIP และมีวันนอนตั้งแต่ 4 ชั่วโมงขึ้นไป',
    formula: 'ผลรวมจำนวนวันนอนของผู้ป่วย UGIH ÷ จำนวนผู้ป่วย UGIH ที่จำหน่าย',
    numeratorLabel: 'ผลรวมจำนวนวันนอน',
    denominatorLabel: 'ผู้ป่วย UGIH ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 121',
  },
  DR0403: {
    group: 'D',
    category: 'Respiratory disease · COPD',
    title: 'COPD: Percent of mortality',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วย COPD',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis เป็น COPD และจำหน่ายด้วยการเสียชีวิต',
    formula: '(จำนวนผู้ป่วย COPD ที่เสียชีวิต ÷ จำนวนผู้ป่วย COPD ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย COPD ที่เสียชีวิต',
    denominatorLabel: 'ผู้ป่วย COPD ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat', 'death'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 90',
  },
  DR0102: {
    group: 'D',
    category: 'Respiratory disease · Pneumonia',
    title: 'Pneumonia: Percent of unplanned re-admission within 28 days after last discharge',
    titleTh: 'ร้อยละการรับเข้ารักษาซ้ำของผู้ป่วยปอดบวมภายใน 28 วันหลังจำหน่าย',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่เข้าเกณฑ์ Pneumonia ตามนิยาม และถูกรับเข้ารักษาซ้ำภายใน 28 วันหลังจำหน่าย (ไม่รวมผู้เสียชีวิตระหว่างนอน; การแยก re-admission แบบ unplanned เป็นการประมาณเบื้องต้น)',
    formula: '(จำนวนผู้ป่วย Pneumonia ที่รับเข้ารักษาซ้ำภายใน 28 วัน ÷ จำนวนผู้ป่วย Pneumonia ที่จำหน่ายโดยไม่เสียชีวิต) × 100',
    numeratorLabel: 'ผู้ป่วย Pneumonia ที่รับเข้ารักษาซ้ำภายใน 28 วัน',
    denominatorLabel: 'ผู้ป่วย Pneumonia ที่จำหน่ายโดยไม่เสียชีวิต',
    sourceTables: ['ipt', 'an_stat', 'iptdiag'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 80',
  },
  DN0107: {
    group: 'D',
    category: 'Neurovascular disease · Stroke',
    title: 'Stroke: Percent of unplanned re-admission of stroke within 28 days',
    titleTh: 'ร้อยละการรับเข้ารักษาซ้ำของผู้ป่วย Stroke ภายใน 28 วัน',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis เป็น Stroke ตามกลุ่มรหัส และถูกรับเข้ารักษาซ้ำภายใน 28 วันหลังจำหน่าย (ไม่รวมผู้เสียชีวิตระหว่างนอน; การแยก re-admission แบบ unplanned เป็นการประมาณเบื้องต้น)',
    formula: '(จำนวนผู้ป่วย Stroke ที่รับเข้ารักษาซ้ำภายใน 28 วัน ÷ จำนวนผู้ป่วย Stroke ที่จำหน่ายโดยไม่เสียชีวิต) × 100',
    numeratorLabel: 'ผู้ป่วย Stroke ที่รับเข้ารักษาซ้ำภายใน 28 วัน',
    denominatorLabel: 'ผู้ป่วย Stroke ที่จำหน่ายโดยไม่เสียชีวิต',
    sourceTables: ['ipt', 'an_stat', 'iptdiag'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 73',
  },
  DH0112: {
    group: 'D',
    category: 'Cardiovascular disease · Acute coronary syndrome',
    title: 'Acute coronary syndrome: Average length of stay',
    titleTh: 'จำนวนวันนอนเฉลี่ยของผู้ป่วย ACS',
    unit: 'ratio',
    direction: 'neutral',
    target: null,
    targetScope: 'monthly',
    definition: 'ค่าเฉลี่ยจำนวนวันนอนของผู้ป่วยในอายุ 18 ปีขึ้นไปที่มี Principal diagnosis เป็น Acute coronary syndrome',
    formula: 'ผลรวมจำนวนวันนอนของผู้ป่วย ACS ÷ จำนวนผู้ป่วย ACS ที่จำหน่าย',
    numeratorLabel: 'ผลรวมจำนวนวันนอน',
    denominatorLabel: 'ผู้ป่วย ACS ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 54',
  },
  DN0109: {
    group: 'D',
    category: 'Neurovascular disease · Stroke',
    title: 'Stroke: Average length of stay',
    titleTh: 'จำนวนวันนอนเฉลี่ยของผู้ป่วย Stroke',
    unit: 'ratio',
    direction: 'neutral',
    target: null,
    targetScope: 'monthly',
    definition: 'ค่าเฉลี่ยจำนวนวันนอนของผู้ป่วยในที่มี Principal diagnosis เป็น Stroke ตามกลุ่มรหัส',
    formula: 'ผลรวมจำนวนวันนอนของผู้ป่วย Stroke ÷ จำนวนผู้ป่วย Stroke ที่จำหน่าย',
    numeratorLabel: 'ผลรวมจำนวนวันนอน',
    denominatorLabel: 'ผู้ป่วย Stroke ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 74',
  },
  DN0302: {
    group: 'D',
    category: 'Neurovascular disease · Head injury',
    title: 'Head injury: Percent of mortality within 48 hours',
    titleTh: 'ร้อยละการเสียชีวิตของผู้ป่วยบาดเจ็บที่ศีรษะภายใน 48 ชั่วโมง',
    unit: 'percent',
    direction: 'lower-is-better',
    target: null,
    targetScope: 'monthly',
    definition: 'ผู้ป่วยในที่มี Principal diagnosis เป็น Head injury ตามรหัส S06.0-S06.9 และเสียชีวิตภายใน 48 ชั่วโมงนับจากเวลา admit โดยนับเฉพาะการนอนโรงพยาบาลตั้งแต่ 4 ชั่วโมงขึ้นไป',
    formula: '(จำนวนผู้ป่วย Head injury ที่เสียชีวิตภายใน 48 ชั่วโมงหลัง admit ÷ จำนวนผู้ป่วย Head injury ที่จำหน่ายทั้งหมด) × 100',
    numeratorLabel: 'ผู้ป่วย Head injury ที่เสียชีวิตภายใน 48 ชั่วโมงหลัง admit',
    denominatorLabel: 'ผู้ป่วย Head injury ที่จำหน่ายทั้งหมด',
    sourceTables: ['ipt', 'an_stat', 'death'],
    frequency: 'ทุกเดือน',
    reference: 'THIP KPI Dictionary 2025 · หน้า 77',
  },
};

export type RawKpiRow = Record<string, unknown>;

export type BmsCoverage = {
  expectedIndicatorCount: number;
  liveIndicatorCount: number;
  expectedCellCount: number;
  coveredCellCount: number;
  unexpectedCellCount: number;
  complete: boolean;
  liveCodes: string[];
};

export type BmsDataLoadResult = {
  indicators: Indicator[];
  rowCount: number;
  sourceView: string | null;
  liveCodes: string[];
  coverage: BmsCoverage;
  /** ISO timestamp captured when the BMS response was accepted. */
  refreshedAt: string;
};

const identifierPart = /^[A-Za-z_][A-Za-z0-9_]*$/;
const validUnits = new Set<IndicatorUnit>(['percent', 'rate', 'ratio', 'count']);
const validDirections = new Set<IndicatorDirection>(['higher-is-better', 'lower-is-better', 'neutral']);
const validTargetScopes = new Set<TargetScope>(['monthly', 'annual']);
const normalizedSourceMetadataFields = [
  'indicator_group',
  'unit',
  'direction',
  'target_scope',
  'category',
  'title',
  'definition',
  'formula',
  'numerator_label',
  'denominator_label',
  'source_tables',
  'frequency',
  'reference',
  'rule_version',
  'refreshed_at',
] as const;
const stableSourceMetadataFields = [
  'indicator_group',
  'unit',
  'direction',
  'target_scope',
  'category',
  'title',
  'title_th',
  'definition',
  'formula',
  'numerator_label',
  'denominator_label',
  'source_tables',
  'frequency',
  'reference',
  'rule_version',
] as const;

function configuredSourceView(): string | null {
  const value = String(import.meta.env.VITE_BMS_KPI_SOURCE_VIEW ?? '').trim();
  return value || null;
}

function requiresCompleteSourceView(): boolean {
  const configured = String(import.meta.env.VITE_BMS_KPI_REQUIRE_COMPLETE_SOURCE_VIEW ?? '').trim().toLowerCase();
  return import.meta.env.PROD || ['1', 'true', 'yes', 'on'].includes(configured);
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
    description: `ผลลัพธ์ THIP ตามรอบรายงานจาก source view ${sourceView}`,
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
        reference,
        rule_version,
        refreshed_at
      FROM ${quotedView}
      WHERE period_start >= :start_date
        AND period_start < :end_date
        AND fiscal_year = :fiscal_year
      ORDER BY indicator_code, fiscal_month
    `.trim(),
  };
}

/**
 * Builds a registered read-only completeness audit for a normalized source view.
 * Returns one row per indicator x applicable reporting period (expected 1,552 rows)
 * labelled missing / unavailable / zero-denominator / ok. Never returns patient rows.
 */
export function buildCompletenessAuditQuery(sourceView: string): RegisteredQuery {
  const quotedView = quoteSourceView(sourceView);
  const expectedCells = (thipCatalogueByCode ? Array.from(thipCatalogueByCode.keys()).sort() : [])
    .flatMap((code) => getExpectedFiscalMonths(code).map((fiscalMonth) => `('${code}', ${fiscalMonth})`));
  const values = expectedCells.join(',\n          ');
  return {
    key: 'thipCompletenessAudit',
    description: `ตรวจความครบตามรอบรายงานของ 232 ตัวชี้วัดใน source view ${sourceView}`,
    sql: `
      WITH params AS (
        SELECT
          CAST(:start_date AS date) AS start_date,
          CAST(:end_date AS date) AS end_date,
          CAST(:fiscal_year AS integer) AS fiscal_year
      ),
      expected(indicator_code, fiscal_month) AS (
        VALUES
          ${values}
      ),
      expected_cells AS (
        SELECT
          e.indicator_code,
          (p.start_date + ((e.fiscal_month - 1) * INTERVAL '1 month'))::date AS period_start,
          p.fiscal_year,
          e.fiscal_month
        FROM expected e
        CROSS JOIN params p
      )
      SELECT
        e.indicator_code,
        e.period_start,
        e.fiscal_year,
        e.fiscal_month,
        s.numerator,
        s.denominator,
        s.value,
        CASE
          WHEN s.indicator_code IS NULL THEN 'missing'
          WHEN s.denominator IS NULL THEN 'unavailable'
          WHEN s.denominator = 0 THEN 'zero-denominator'
          ELSE 'ok'
        END AS completeness_status
      FROM expected_cells e
      LEFT JOIN ${quotedView} s
        ON s.indicator_code = e.indicator_code
       AND s.period_start = e.period_start
       AND s.fiscal_year = e.fiscal_year
       AND s.fiscal_month = e.fiscal_month
      ORDER BY e.indicator_code, e.fiscal_month
    `.trim(),
  };
}

/** Builds a registered read-only duplicate check for a normalized source view. */
export function buildDuplicateCheckQuery(sourceView: string): RegisteredQuery {
  const quotedView = quoteSourceView(sourceView);
  return {
    key: 'thipDuplicateCheck',
    description: `ตรวจ duplicate indicator x reporting period ของ source view ${sourceView}`,
    sql: `
      SELECT
        indicator_code,
        period_start,
        fiscal_year,
        fiscal_month,
        COUNT(*) AS row_count
      FROM ${quotedView}
      WHERE period_start >= :start_date
        AND period_start < :end_date
        AND fiscal_year = :fiscal_year
      GROUP BY indicator_code, period_start, fiscal_year, fiscal_month
      HAVING COUNT(*) <> 1
      ORDER BY indicator_code, period_start
    `.trim(),
  };
}

function getValue(row: RawKpiRow, key: string): unknown {
  const found = Object.keys(row).find((candidate) => candidate.toLowerCase() === key.toLowerCase());
  return found ? row[found] : undefined;
}

function hasField(row: RawKpiRow, key: string): boolean {
  return Object.keys(row).some((candidate) => candidate.toLowerCase() === key.toLowerCase());
}

function asString(value: unknown): string | null {
  if (typeof value !== 'string' && typeof value !== 'number') return null;
  const text = String(value).trim();
  return text || null;
}

function asNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value !== 'number' && typeof value !== 'string') return null;
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

function getStatus(value: number | null, target: number | null, direction: IndicatorDirection): IndicatorStatus {
  if (value === null) return 'no-data';
  if (target === null || direction === 'neutral') return 'unbenchmarked';
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
  if (!text) return fallback;
  const postgresArray = text.startsWith('{') && text.endsWith('}')
    ? text.slice(1, -1)
    : text;
  return postgresArray
    .split(',')
    .map((item) => item.trim().replace(/^"|"$/g, '').replace(/\\"/g, '"'))
    .filter(Boolean);
}

function rowPeriod(row: RawKpiRow, periods: ReturnType<typeof getFiscalMonthPeriods>, fiscalYear: FiscalYear): number | null {
  const rowFiscalYear = asInteger(getValue(row, 'fiscal_year'));
  if (rowFiscalYear !== null && rowFiscalYear !== fiscalYear) return null;
  const fiscalMonth = asInteger(getValue(row, 'fiscal_month'));
  const periodStart = asString(getValue(row, 'period_start'));
  if (fiscalMonth && fiscalMonth >= 1 && fiscalMonth <= 12) {
    const expectedPeriod = periods[fiscalMonth - 1]?.periodStart;
    if (periodStart && expectedPeriod && periodStart.slice(0, 10) !== expectedPeriod) return null;
    return fiscalMonth;
  }
  const match = periods.find((period) => period.periodStart === periodStart);
  return match?.fiscalMonth ?? null;
}

export function summarizeCoverage(rows: RawKpiRow[], fiscalYear: FiscalYear): BmsCoverage {
  const periods = getFiscalMonthPeriods(fiscalYear);
  const expectedCells = new Set<string>(thipCatalogue.flatMap((entry) => getExpectedFiscalMonths(entry.code).map((month) => `${entry.code}:${month}`)));
  const cells = new Set<string>();
  const unexpectedCells = new Set<string>();
  const monthsByCode = new Map<string, Set<number>>();

  for (const row of rows) {
    const code = asString(getValue(row, 'indicator_code'));
    const month = rowPeriod(row, periods, fiscalYear);
    if (!code || !month || !thipCatalogueByCode.has(code)) continue;
    const cell = `${code}:${month}`;
    if (!expectedCells.has(cell)) {
      unexpectedCells.add(cell);
      continue;
    }
    cells.add(cell);
    const months = monthsByCode.get(code) ?? new Set<number>();
    months.add(month);
    monthsByCode.set(code, months);
  }

  const liveCodes = Array.from(thipCatalogueByCode.keys()).filter((code) => monthsByCode.has(code));
  const expectedIndicatorCount = thipCatalogue.length;
  const expectedCellCount = expectedCells.size;

  return {
    expectedIndicatorCount,
    liveIndicatorCount: liveCodes.length,
    expectedCellCount,
    coveredCellCount: cells.size,
    unexpectedCellCount: unexpectedCells.size,
    complete: liveCodes.length === expectedIndicatorCount && cells.size === expectedCellCount && unexpectedCells.size === 0,
    liveCodes,
  };
}

function makeAnnual(
  monthly: MonthlyResult[],
  fiscalYear: FiscalYear,
  unit: IndicatorUnit,
  target: number | null,
  direction: IndicatorDirection,
  formulaScale: number,
): AnnualResult {
  const rows = unit === 'count'
    ? monthly.filter((month) => month.value !== null)
    : monthly.filter((month) => month.value !== null && month.numerator !== null && month.denominator !== null && month.denominator !== 0);
  const numeratorRows = rows.filter((month) => month.numerator !== null);
  const denominatorRows = rows.filter((month) => month.denominator !== null);
  const numerator = numeratorRows.length === rows.length && rows.length
    ? numeratorRows.reduce((sum, month) => sum + (month.numerator ?? 0), 0)
    : null;
  const denominator = denominatorRows.length === rows.length && rows.length
    ? denominatorRows.reduce((sum, month) => sum + (month.denominator ?? 0), 0)
    : null;
  const value = unit === 'count'
    ? (rows.length ? Number(rows.reduce((sum, month) => sum + (month.value ?? 0), 0).toFixed(2)) : null)
    : numerator !== null && denominator
      ? Number(((numerator / denominator) * formulaScale).toFixed(2))
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
  const foundationDefinition = foundationDefinitions[code];
  if (foundationDefinition) return createFoundationIndicator({ code, ...foundationDefinition }, fiscalYear);
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
  const formula = asString(getValue(firstRow ?? {}, 'formula')) ?? base.formula;
  // The normalized view may repeat a human-readable formula, but the numeric
  // multiplier is controlled by the repository rule manifest. This prevents
  // an unreviewed source-view label from changing values or annual roll-ups.
  const formulaScale = getFormulaScale(thipKpiRulesByCode.get(code)?.formulaScale ?? formula);
  const sourceProvidesTarget = rows.some((row) => hasField(row, 'target'));
  const targetFromRows = sourceProvidesTarget
    ? rows.map((row) => asNumber(getValue(row, 'target'))).find((value) => value !== null) ?? null
    : null;
  const rowsByMonth = new Map<number, RawKpiRow>();

  for (const row of rows) {
    const month = rowPeriod(row, periods, fiscalYear);
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
    // Count indicators may legitimately have no denominator. All ratio/rate
    // values still require a non-zero denominator so unavailable data cannot
    // be mistaken for a measured zero.
    const value = denominator === 0
      ? null
      : unit === 'count'
        ? sourceValue ?? numerator
        : denominator === null
          ? null
          : sourceValue ?? (numerator === null ? null : Number(((numerator / denominator) * formulaScale).toFixed(2)));
    const target = targetScope === 'monthly'
      ? sourceProvidesTarget
        ? asNumber(getValue(row ?? {}, 'target'))
        : asNumber(getValue(row ?? {}, 'target')) ?? targetFromRows
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
      // Status is derived from the accepted facts and benchmark metadata. Do
      // not trust a transport-provided status that could disagree with them.
      status: getStatus(value, target, direction),
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
    formula,
    numeratorLabel: rowText('numerator_label', base.numeratorLabel),
    denominatorLabel: rowText('denominator_label', base.denominatorLabel),
    sourceTables: asSourceTables(getValue(firstRow ?? {}, 'source_tables'), base.sourceTables),
    frequency: rowText('frequency', base.frequency),
    reference: rowText('reference', base.reference),
    monthly,
    annual: makeAnnual(
      monthly,
      fiscalYear,
      unit,
      targetScope === 'annual' ? targetFromRows : null,
      direction,
      formulaScale,
    ),
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
  const rows = Array.isArray(response.data) && response.data.length > 0
    ? response.data
    : response.result ?? response.data;
  return Array.isArray(rows) ? rows.filter((row): row is RawKpiRow => Boolean(row && typeof row === 'object')) : [];
}

function assertNormalizedSourceViewRows(rows: RawKpiRow[], fiscalYear: FiscalYear): void {
  const periods = getFiscalMonthPeriods(fiscalYear);
  rows.forEach((row, index) => {
    const code = asString(getValue(row, 'indicator_code'));
    const fiscalMonth = asInteger(getValue(row, 'fiscal_month'));
    if (!code || !thipCatalogueByCode.has(code)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has an unknown or missing indicator_code`);
    }
    if (fiscalMonth === null || fiscalMonth < 1 || fiscalMonth > 12 || !getExpectedFiscalMonths(code).includes(fiscalMonth)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} uses a fiscal_month outside the KPI reporting cadence`);
    }
    const rowFiscalYear = asInteger(getValue(row, 'fiscal_year'));
    const periodStart = asString(getValue(row, 'period_start'));
    const expectedPeriodStart = fiscalMonth === null ? null : periods[fiscalMonth - 1]?.periodStart ?? null;
    if (
      rowFiscalYear !== fiscalYear
      || !periodStart
      || !expectedPeriodStart
      || periodStart.slice(0, 10) !== expectedPeriodStart
      || rowPeriod(row, periods, fiscalYear) === null
    ) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has an invalid fiscal period`);
    }

    const group = asString(getValue(row, 'indicator_group'));
    if (!group || !['D', 'C', 'S', 'H', 'A'].includes(group)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has an invalid indicator_group`);
    }
    if (group !== thipCatalogueByCode.get(code)?.group) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has an indicator_group that does not match ${code}`);
    }
    const unit = asString(getValue(row, 'unit')) as IndicatorUnit | null;
    if (!unit || !validUnits.has(unit)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has an invalid unit`);
    }
    const expectedUnit = thipKpiRulesByCode.get(code);
    if (expectedUnit && unit !== getRuleUnit(expectedUnit)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has unit ${unit}, but ${code} formula requires ${getRuleUnit(expectedUnit)}`);
    }
    const formula = asString(getValue(row, 'formula'));
    if (expectedUnit && formula && getFormulaScale(formula) !== getFormulaScale(expectedUnit.formulaScale)) {
      throw new BmsRequestError(
        'data',
        'response',
        `Normalized THIP source row ${index + 1} has a formula multiplier that conflicts with the registered formula for ${code}`,
      );
    }
    const direction = asString(getValue(row, 'direction')) as IndicatorDirection | null;
    if (!direction || !validDirections.has(direction)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has an invalid direction`);
    }
    const targetScope = asString(getValue(row, 'target_scope')) as TargetScope | null;
    if (!targetScope || !validTargetScopes.has(targetScope)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has an invalid target_scope`);
    }
    for (const field of ['numerator', 'denominator', 'value', 'target', 'percentile']) {
      const raw = getValue(row, field);
      if (raw !== null && raw !== undefined && raw !== '' && asNumber(raw) === null) {
        throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has a non-numeric ${field}`);
      }
    }
    const denominator = asNumber(getValue(row, 'denominator'));
    const numerator = asNumber(getValue(row, 'numerator'));
    const value = asNumber(getValue(row, 'value'));
    const percentile = asNumber(getValue(row, 'percentile'));
    if (denominator === 0 && value !== null) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} must use NULL value when denominator is zero`);
    }
    if (percentile !== null && (percentile < 0 || percentile > 100)) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has percentile outside 0-100`);
    }
    if (unit !== 'count' && denominator === null && value !== null) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} has a value without a denominator for unit ${unit}`);
    }
    const rule = thipKpiRulesByCode.get(code);
    if (unit !== 'count' && numerator !== null && denominator !== null && denominator !== 0 && value !== null && rule) {
      const expectedValue = (numerator / denominator) * getFormulaScale(rule.formulaScale);
      // Source views may round to two or four decimal places. Reject a real
      // calculation mismatch while allowing that documented presentation
      // rounding.
      const roundingTolerance = Math.max(0.02, Math.abs(expectedValue) * 0.0001);
      if (Math.abs(value - expectedValue) > roundingTolerance) {
        throw new BmsRequestError(
          'data',
          'response',
          `Normalized THIP source row ${index + 1} has a value inconsistent with numerator, denominator, and the registered formula for ${code}`,
        );
      }
    }
    for (const field of normalizedSourceMetadataFields) {
      const value = getValue(row, field);
      const present = Array.isArray(value)
        ? value.length > 0
        : asString(value) !== null;
      if (!present) {
        throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} is missing required metadata: ${field}`);
      }
    }
    if (asSourceTables(getValue(row, 'source_tables'), []).length === 0) {
      throw new BmsRequestError('data', 'response', `Normalized THIP source row ${index + 1} is missing required metadata: source_tables`);
    }
  });

  const metadataByCode = new Map<string, { index: number; signature: string }>();
  rows.forEach((row, index) => {
    const code = asString(getValue(row, 'indicator_code'))!;
    const signature = stableSourceMetadataFields.map((field) => {
      if (field === 'source_tables') return asSourceTables(getValue(row, field), []).sort().join('\u001f');
      return asString(getValue(row, field)) ?? '';
    }).join('\u001e');
    const previous = metadataByCode.get(code);
    if (previous && previous.signature !== signature) {
      throw new BmsRequestError(
        'data',
        'response',
        `Normalized THIP source has inconsistent descriptive metadata for ${code} between rows ${previous.index + 1} and ${index + 1}`,
      );
    }
    metadataByCode.set(code, { index, signature });
  });
}

function sourceRefreshTimestamp(rows: RawKpiRow[]): string | null {
  const values = [...new Set(rows
    .map((row) => asString(getValue(row, 'refreshed_at')))
    .filter((value): value is string => Boolean(value)))];
  if (!values.length) return null;
  const invalid = values.find((value) => Number.isNaN(Date.parse(value)));
  if (invalid) {
    throw new BmsRequestError('data', 'response', `Normalized THIP source has invalid refreshed_at: ${invalid}`);
  }
  if (values.length > 1) {
    throw new BmsRequestError('data', 'response', 'Normalized THIP source contains more than one refreshed_at value');
  }
  return values[0] ?? null;
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

function assertRequiredSourceCoverage(coverage: BmsCoverage, sourceView: string): void {
  if (!requiresCompleteSourceView() || coverage.complete) return;
  throw new BmsRequestError(
    'data',
    'response',
    `Normalized THIP source view ${sourceView} is incomplete: ${coverage.coveredCellCount}/${coverage.expectedCellCount} reporting cells and ${coverage.liveIndicatorCount}/${coverage.expectedIndicatorCount} indicators were returned`,
  );
}

export async function loadBmsIndicators(
  runtime: { apiUrl: string; bearerToken: string; appIdentifier: string; marketplaceToken?: string },
  fiscalYear: FiscalYear,
  options?: { signal?: AbortSignal; timeoutMs?: number },
): Promise<BmsDataLoadResult> {
  const sourceView = configuredSourceView();
  if (!sourceView && requiresCompleteSourceView()) {
    throw new BmsRequestError('data', 'config', 'Production BMS build requires VITE_BMS_KPI_SOURCE_VIEW for the complete 232-indicator contract');
  }
  const query = sourceView ? buildSourceViewQuery(sourceView) : queryRegistry.thipIpdFoundation;
  let response: BmsSqlResponse;
  try {
    response = await executeRegisteredQuery(query, runtime, paramsForFiscalYear(fiscalYear, Boolean(sourceView)), runtime.marketplaceToken, { signal: options?.signal, timeoutMs: options?.timeoutMs });
  } catch (error) {
    throw asDataError(error);
  }
  const rows = responseRows(response);
  if (sourceView && rows.length === 0) {
    throw new BmsRequestError('data', 'response', `Normalized THIP source view ${sourceView} returned no rows for fiscal year ${fiscalYear}`);
  }
  if (sourceView) assertNormalizedSourceViewRows(rows, fiscalYear);
  assertNoUnknownCodes(rows);
  const refreshedAt = sourceView && rows.length > 0
    ? sourceRefreshTimestamp(rows) ?? new Date().toISOString()
    : new Date().toISOString();
  const coverage = summarizeCoverage(rows, fiscalYear);
  if (sourceView) assertRequiredSourceCoverage(coverage, sourceView);

  if (sourceView) {
    const codes = new Set<string>([
      ...thipCatalogueByCode.keys(),
      ...rows.map((row) => asString(getValue(row, 'indicator_code'))).filter((code): code is string => Boolean(code)),
    ]);
    const indicators = Array.from(codes)
      .map((code) => buildIndicatorFromRows(code, rows.filter((row) => asString(getValue(row, 'indicator_code')) === code), fiscalYear))
      .filter((indicator): indicator is Indicator => Boolean(indicator));
    return { indicators, rowCount: rows.length, sourceView, liveCodes: coverage.liveCodes, coverage, refreshedAt };
  }

  const byCode = new Map<string, RawKpiRow[]>();
  for (const row of rows) {
    const code = asString(getValue(row, 'indicator_code'));
    if (!code) continue;
    byCode.set(code, [...(byCode.get(code) ?? []), row]);
  }
  // Keep the full catalogue visible during local foundation validation. Only
  // codes returned by HOSxP are marked as BMS-backed; the remaining catalogue
  // entries stay explicitly no-data instead of disappearing or becoming zero.
  const indicators = thipCatalogue
    .map((entry) => buildIndicatorFromRows(entry.code, byCode.get(entry.code) ?? [], fiscalYear) ?? createNoDataIndicator(entry, fiscalYear));
  return {
    indicators,
    rowCount: rows.length,
    sourceView: null,
    liveCodes: coverage.liveCodes,
    coverage,
    refreshedAt,
  };
}
