import type { Indicator, MonthlyResult } from '@/types/thip';
import { getFormulaScale, thipKpiRulesByCode } from '@/data/thipKpiRules';

/**
 * Per-indicator statistical process control chart.
 *
 * - `p-chart` (percent/rate indicators measured as numerator/denominator):
 *   center line = weighted period proportion; per-period 3-sigma limits
 *   sqrt(p(1-p)/n) so small cohorts get wider limits. Values are multiplied by
 *   the rule's formula scale so limits match the displayed unit.
 * - `individuals` (count indicators, ratio units, or facts without a usable
 *   denominator): I-MR chart. CL = mean, sigma estimated from the mean moving
 *   range (MRbar / 1.128), limits = CL ± 2.66 x MRbar, lower limit clipped at 0
 *   because every THIP unit is non-negative.
 *
 * Signals: (1) a point beyond its 3-sigma limits and (2) a run of eight
 * consecutive points on one side of the center line.
 */
export type ControlChartKind = 'p-chart' | 'individuals';

export type ControlSignal = 'none' | 'beyond-limits' | 'run';

export type ControlPoint = {
  fiscalMonth: number;
  label: string;
  value: number | null;
  numerator: number | null;
  denominator: number | null;
  ucl: number | null;
  lcl: number | null;
  /** null when limits are not computable (fewer than two measured points). */
  inControl: boolean | null;
  signal: ControlSignal;
};

export type ControlChartModel = {
  kind: ControlChartKind;
  cl: number | null;
  points: ControlPoint[];
  measuredPointCount: number;
  hasLimits: boolean;
  beyondLimitsCount: number;
  runSignalCount: number;
  sigmaLabel: string;
  methodLabel: string;
};

const MOVING_RANGE_CONSTANT = 1.128;
const RUN_LENGTH = 8;

export function buildControlChart(indicator: Indicator): ControlChartModel {
  const rule = thipKpiRulesByCode.get(indicator.code);
  const unit = indicator.unit;
  const formulaScale = getFormulaScale(rule?.formulaScale ?? indicator.formula);
  const measured = indicator.monthly.filter((month) => month.value !== null);

  const pChartFacts = measured.filter(
    (month) => month.numerator !== null && month.denominator !== null && month.denominator > 0
      && month.numerator <= month.denominator,
  );
  const proportionsFit = unit !== 'count'
    && measured.length >= 2
    && pChartFacts.length === measured.length;
  const kind: ControlChartKind = proportionsFit ? 'p-chart' : 'individuals';

  let cl: number | null = null;
  let clProportion = 0;
  let individualsSigma = 0;
  if (measured.length >= 1) {
    if (kind === 'p-chart') {
      const totalNumerator = pChartFacts.reduce((sum, month) => sum + (month.numerator ?? 0), 0);
      const totalDenominator = pChartFacts.reduce((sum, month) => sum + (month.denominator ?? 0), 0);
      clProportion = totalDenominator > 0 ? totalNumerator / totalDenominator : 0;
      cl = Number((clProportion * formulaScale).toFixed(4));
    } else {
      const values = measured.map((month) => month.value ?? 0);
      cl = Number((values.reduce((sum, value) => sum + value, 0) / values.length).toFixed(4));
      if (values.length >= 2) {
        const movingRanges = values.slice(1).map((value, index) => Math.abs(value - values[index]!));
        const meanMovingRange = movingRanges.reduce((sum, range) => sum + range, 0) / movingRanges.length;
        individualsSigma = meanMovingRange / MOVING_RANGE_CONSTANT;
      }
    }
  }

  const hasLimits = measured.length >= 2 && cl !== null;

  const points: ControlPoint[] = indicator.monthly.map((month) => {
    const base: ControlPoint = {
      fiscalMonth: month.fiscalMonth,
      label: month.label,
      value: month.value,
      numerator: month.numerator,
      denominator: month.denominator,
      ucl: null,
      lcl: null,
      inControl: null,
      signal: 'none',
    };
    if (!hasLimits || cl === null || month.value === null) return base;
    let ucl = cl;
    let lcl = cl;
    if (kind === 'p-chart') {
      const n = month.denominator && month.denominator > 0 ? month.denominator : null;
      if (n) {
        const sigma = Math.sqrt((clProportion * (1 - clProportion)) / n) * formulaScale;
        ucl = cl + 3 * sigma;
        lcl = Math.max(0, cl - 3 * sigma);
      } else {
        ucl = cl;
        lcl = cl;
      }
    } else {
      const delta = 3 * individualsSigma;
      ucl = cl + delta;
      lcl = Math.max(0, cl - delta);
    }
    const beyond = month.value > ucl || month.value < lcl;
    return { ...base, ucl: Number(ucl.toFixed(4)), lcl: Number(lcl.toFixed(4)), inControl: !beyond, signal: beyond ? 'beyond-limits' : 'none' };
  });

  // Run rule: eight consecutive measured points strictly on one side of CL.
  let runSignalCount = 0;
  if (hasLimits && cl !== null) {
    let runSide: 'above' | 'below' | null = null;
    let runLength = 0;
    let runIndices: number[] = [];
    for (const point of points) {
      if (point.value === null) continue;
      const side = point.value >= cl ? 'above' : 'below';
      if (side === runSide) {
        runLength += 1;
        runIndices.push(point.fiscalMonth);
      } else {
        runSide = side;
        runLength = 1;
        runIndices = [point.fiscalMonth];
      }
      if (runLength === RUN_LENGTH) {
        runSignalCount += 1;
        for (const index of runIndices) {
          const target = points.find((candidate) => candidate.fiscalMonth === index);
          if (target && target.signal === 'none') target.signal = 'run';
        }
      }
    }
  }

  const beyondLimitsCount = points.filter((point) => point.signal === 'beyond-limits').length;
  const methodLabel = kind === 'p-chart'
    ? 'p-chart (สัดส่วน 3σ ตามขนาดกลุ่มรายงวด)'
    : 'Individuals chart (I-MR, 3σ จาก Moving Range)';
  const sigmaLabel = kind === 'p-chart'
    ? 'CL = สัดส่วนถ่วงน้ำหนักทั้งปี · ขอบเขต ±3σ ต่อรอบที่ √(p(1−p)/n)'
    : 'CL = ค่าเฉลี่ย · σ ประมาณจาก MR̄/1.128 · ขอบเขต CL ± 2.66×MR̄';

  return {
    kind,
    cl,
    points,
    measuredPointCount: measured.length,
    hasLimits,
    beyondLimitsCount,
    runSignalCount,
    sigmaLabel,
    methodLabel,
  };
}

/** Convenience for chart tooltips: month metadata kept next to the point. */
export function controlPointMonths(points: readonly ControlPoint[], months: readonly MonthlyResult[]): ControlPoint[] {
  return points.map((point) => ({
    ...point,
    label: months.find((month) => month.fiscalMonth === point.fiscalMonth)?.label ?? point.label,
  }));
}
