import {
  CartesianGrid,
  ComposedChart,
  Line,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { Indicator } from '@/types/thip';
import { buildControlChart, type ControlChartModel, type ControlPoint } from '@/utils/controlChart';
import { formatThaiMonth } from '@/utils/fiscal';
import { formatIndicatorValue, formatNumber } from '@/utils/format';

type Props = {
  indicator: Indicator;
};

type ChartRow = {
  label: string;
  fullLabel: string;
  value: number | null;
  ucl: number | null;
  lcl: number | null;
};

/**
 * Per-indicator control chart: measured values with center line (CL), 3-sigma
 * upper/lower control limits (UCL/LCL), and special-cause signals marked in red.
 */
export function ControlChart({ indicator }: Props) {
  const model = buildControlChart(indicator);
  const data: ChartRow[] = model.points.map((point) => ({
    label: formatThaiMonth(indicator.monthly.find((month) => month.fiscalMonth === point.fiscalMonth)?.periodStart ?? ''),
    fullLabel: point.label,
    value: point.value,
    ucl: point.ucl,
    lcl: point.lcl,
  }));

  return (
    <div className="control-chart-block" data-testid="control-chart">
      {model.measuredPointCount === 0 ? (
        <div className="chart-empty-state"><strong>ยังไม่มีข้อมูลสำหรับแผนภูมิควบคุม</strong><span>แผนภูมิจะคำนวณ CL/UCL/LCL อัตโนมัติเมื่อมีผลลัพธ์จริงอย่างน้อย 1 งวด</span></div>
      ) : (
        <>
          <div className="control-stats">
            <span className="control-stat"><small>วิธีคำนวณ</small><strong>{model.methodLabel}</strong></span>
            <span className="control-stat"><small>เส้นกลาง (CL)</small><strong>{formatIndicatorValue(indicator, model.cl)}</strong></span>
            <span className="control-stat"><small>ขอบควบคุม</small><strong>CL ± 3σ (UCL/LCL)</strong></span>
            <span className="control-stat"><small>สัญญาณผิดปกติ</small><strong className={model.beyondLimitsCount + model.runSignalCount > 0 ? 'text-bad' : 'text-good'}>{model.beyondLimitsCount} จุดนอกขอบเขต · {model.runSignalCount} แถวรัน</strong></span>
          </div>
          <ResponsiveContainer width="100%" height={270}>
            <ComposedChart data={data} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
              <CartesianGrid stroke="#e1eaee" strokeDasharray="3 5" vertical={false} />
              <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} />
              <YAxis axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} width={44} domain={['auto', 'auto']} />
              <Tooltip content={<ControlTooltip indicator={indicator} model={model} />} />
              {model.cl !== null && <ReferenceLine y={model.cl} stroke="#149e9b" strokeDasharray="6 4" strokeWidth={1.5} label={{ value: 'CL', position: 'insideTopRight', fill: '#149e9b', fontSize: 10 }} />}
              {model.hasLimits && <Line dataKey="ucl" name="UCL" stroke="#e8743b" strokeDasharray="4 4" strokeWidth={1.2} dot={false} connectNulls isAnimationActive={false} />}
              {model.hasLimits && <Line dataKey="lcl" name="LCL" stroke="#e8743b" strokeDasharray="4 4" strokeWidth={1.2} dot={false} connectNulls isAnimationActive={false} />}
              <Line
                type="monotone"
                dataKey="value"
                name="ผลงาน"
                stroke="#2dc9c5"
                strokeWidth={2.5}
                isAnimationActive={false}
                connectNulls={false}
                dot={(props: { cx?: number; cy?: number; payload?: ChartRow; index?: number }) => {
                  const point: ControlPoint | undefined = model.points[props.index ?? -1];
                  const signal = point?.signal ?? 'none';
                  const fill = signal === 'beyond-limits' ? '#d64541' : signal === 'run' ? '#f4b942' : '#149e9b';
                  return <circle cx={props.cx} cy={props.cy} r={4} fill={fill} strokeWidth={0} />;
                }}
              />
            </ComposedChart>
          </ResponsiveContainer>
          <div className="control-footnote"><span>{model.sigmaLabel}</span><span>จุดแดง = นอกขอบควบคุม 3σ · จุดเหลือง = รัน 8 จุดติดกันข้างเดียว</span></div>
        </>
      )}
    </div>
  );
}

function ControlTooltip({ active, payload, indicator, model }: { active?: boolean; payload?: Array<{ payload?: ChartRow }>; indicator: Indicator; model: ControlChartModel }) {
  if (!active || !payload?.length) return null;
  const source = payload[0]?.payload;
  const point = model.points.find((candidate) => candidate.label === source?.fullLabel);
  return (
    <div className="chart-tooltip">
      <strong>{source?.fullLabel ?? 'งวดรายงาน'}</strong>
      <span><i className="tooltip-dot tooltip-dot-aqua" />ผลงาน {formatIndicatorValue(indicator, source?.value ?? null)}</span>
      {point?.ucl !== null && point?.ucl !== undefined && <span>UCL {formatIndicatorValue(indicator, point.ucl)}</span>}
      {point?.lcl !== null && point?.lcl !== undefined && <span>LCL {formatIndicatorValue(indicator, point.lcl)}</span>}
      {point?.denominator !== null && point?.denominator !== undefined && <span>n = {formatNumber(point.denominator)}</span>}
    </div>
  );
}
