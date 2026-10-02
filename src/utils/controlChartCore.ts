export type ControlChartKind = 'p-chart' | 'individuals';
export type ControlSignal = 'none' | 'beyond-limits' | 'run';
export type ControlPeriod = {
  fiscalMonth: number; label: string; value: number | null;
  numerator: number | null; denominator: number | null;
  periodStart?: string; periodEnd?: string;
};
export type ControlPoint = ControlPeriod & {
  ucl: number | null; lcl: number | null; inControl: boolean | null; signal: ControlSignal;
};
export type ControlChartModel = {
  kind: ControlChartKind; cl: number | null; points: ControlPoint[];
  measuredPointCount: number; hasLimits: boolean; beyondLimitsCount: number;
  runSignalCount: number; sigmaLabel: string; methodLabel: string;
};

/** Shewhart charts use disjoint periods, never overlapping cumulative YTD values. */
export function buildPeriodControlChart(
  periods: readonly ControlPeriod[], scale: number, allowProportions: boolean
): ControlChartModel {
  const measured = periods.filter(point => point.value !== null);
  const proportionsFit = allowProportions && measured.length >= 2 && measured.every(point =>
    point.numerator !== null && point.denominator !== null &&
    Number.isInteger(point.numerator) && Number.isInteger(point.denominator) &&
    point.denominator > 0 && point.numerator >= 0 && point.numerator <= point.denominator);
  const kind: ControlChartKind = proportionsFit ? 'p-chart' : 'individuals';
  const adjacent = (a: ControlPeriod, b: ControlPeriod) => a.periodEnd && b.periodStart
    ? a.periodEnd === b.periodStart : b.fiscalMonth === a.fiscalMonth + 1;
  const ranges = periods.slice(1).flatMap((point, index) => {
    const previous = periods[index];
    return point.value !== null && previous.value !== null && adjacent(previous, point)
      ? [Math.abs(point.value - previous.value)] : [];
  });
  const proportion = proportionsFit
    ? measured.reduce((sum, point) => sum + point.numerator!, 0) /
      measured.reduce((sum, point) => sum + point.denominator!, 0) : 0;
  const cl = measured.length ? proportionsFit ? proportion * scale
    : measured.reduce((sum, point) => sum + point.value!, 0) / measured.length : null;
  const sigma = ranges.length ? ranges.reduce((sum, range) => sum + range, 0) / ranges.length / 1.128 : 0;
  const hasLimits = measured.length >= 2 && cl !== null && Number.isFinite(cl) &&
    (kind === 'p-chart' || ranges.length > 0);
  const points = periods.map((point): ControlPoint => {
    const base = { ...point, ucl: null, lcl: null, inControl: null, signal: 'none' as const };
    if (!hasLimits || cl === null || point.value === null) return base;
    const delta = kind === 'p-chart' ? 3 * Math.sqrt(proportion * (1 - proportion) / point.denominator!) * scale : 3 * sigma;
    const ucl = kind === 'p-chart' ? Math.min(scale, cl + delta) : cl + delta;
    const lcl = Math.max(0, cl - delta);
    const beyond = point.value > ucl || point.value < lcl;
    return { ...base, ucl, lcl, inControl: !beyond, signal: beyond ? 'beyond-limits' : 'none' };
  });
  let run: ControlPoint[] = [], side = 0, runSignalCount = 0;
  for (const point of points) {
    const nextSide = point.value === null || cl === null ? 0 : Math.sign(point.value - cl);
    const previous = run.at(-1);
    if (!nextSide || nextSide !== side || previous && !adjacent(previous, point)) run = [];
    side = nextSide;
    if (!nextSide || !hasLimits) continue;
    run.push(point);
    if (run.length === 8) runSignalCount++;
    if (run.length >= 8) for (const member of run) if (member.signal === 'none') member.signal = 'run';
  }
  return { kind, cl, points, measuredPointCount: measured.length, hasLimits,
    beyondLimitsCount: points.filter(point => point.signal === 'beyond-limits').length, runSignalCount,
    methodLabel: kind === 'p-chart' ? 'p-chart · สัดส่วนรายงวด' : 'Individuals · Moving Range รายงวด',
    sigmaLabel: kind === 'p-chart'
      ? 'CL = Σ ตัวตั้ง / Σ ตัวหาร × scale; ขอบเขต ±3σ ตามตัวหารแต่ละงวด'
      : 'CL = ค่าเฉลี่ยรายงวด; σ = MR̄/1.128 จากงวดที่ต่อเนื่องกัน',
  };
}
