import {
  Bar,
  BarChart,
  CartesianGrid,
  ComposedChart,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { Indicator, MonthlyResult } from '@/types/thip';
import { formatThaiMonth } from '@/utils/fiscal';
import { formatIndicatorValue } from '@/utils/format';

export type ChartMode = 'bar' | 'line';

type Props = {
  indicator: Indicator;
  mode?: ChartMode;
  compact?: boolean;
};

export function TrendChart({ indicator, mode = 'bar', compact = false }: Props) {
  const data = indicator.monthly.map((month) => ({
    label: formatThaiMonth(month.periodStart),
    fullLabel: month.label,
    value: month.value,
    target: indicator.targetScope === 'monthly' ? month.target : null,
  }));
  const height = compact ? 128 : 270;
  const hasData = indicator.monthly.some((month) => month.value !== null);

  return (
    <div className={`trend-chart ${compact ? 'trend-chart-compact' : ''} trend-chart-${mode}`} role="img" aria-label={`กราฟ${mode === 'bar' ? 'แท่ง' : 'แนวโน้ม'}ตามรอบรายงานของ ${indicator.code} ${indicator.titleTh}`} data-testid={`monthly-${mode}-chart`}>
      {!hasData && <div className="chart-empty-state"><strong>ยังไม่มีข้อมูลตามรอบรายงาน</strong><span>กราฟจะแสดงเมื่อผูก source view ของโรงพยาบาล</span></div>}
      <ResponsiveContainer width="100%" height={height}>
        {mode === 'bar' ? (
          <ComposedChart data={data} margin={{ top: 8, right: 6, left: -24, bottom: 0 }} barCategoryGap="24%">
            <CartesianGrid stroke="#e1eaee" strokeDasharray="3 5" vertical={false} />
            <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} interval={compact ? 2 : 0} />
            <YAxis axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} width={34} />
            <Tooltip content={<ChartTooltip indicator={indicator} />} />
            <Bar dataKey="value" name="ผลงาน" fill="#2dc9c5" radius={[5, 5, 1, 1]} maxBarSize={32} isAnimationActive={false} />
            {indicator.targetScope === 'monthly' && data.some((month) => month.target !== null) && (
              <Line type="monotone" dataKey="target" name="เป้าหมาย" stroke="#f4b942" strokeDasharray="5 5" strokeWidth={1.5} dot={false} connectNulls={false} isAnimationActive={false} />
            )}
          </ComposedChart>
        ) : (
          <LineChart data={data} margin={{ top: 8, right: 6, left: -24, bottom: 0 }}>
            <CartesianGrid stroke="#e1eaee" strokeDasharray="3 5" vertical={false} />
            <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} interval={compact ? 2 : 0} />
            <YAxis axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} width={34} />
            <Tooltip content={<ChartTooltip indicator={indicator} />} />
            <Line type="monotone" dataKey="value" stroke="#149e9b" strokeWidth={2.5} dot={{ r: 3, fill: '#149e9b', strokeWidth: 0 }} activeDot={{ r: 5 }} connectNulls={false} isAnimationActive={false} />
            {indicator.targetScope === 'monthly' && data.some((month) => month.target !== null) && (
              <Line type="monotone" dataKey="target" stroke="#f4b942" strokeDasharray="5 5" strokeWidth={1.5} dot={false} connectNulls isAnimationActive={false} />
            )}
          </LineChart>
        )}
      </ResponsiveContainer>
    </div>
  );
}

function ChartTooltip({ active, payload, indicator }: { active?: boolean; payload?: Array<{ payload?: MonthlyResult & { fullLabel?: string; target?: number | null }; dataKey?: string; value?: number | null }>; indicator: Indicator }) {
  if (!active || !payload?.length) return null;
  const source = payload[0]?.payload;
  const monthValue = payload.find((entry) => entry.dataKey === 'value')?.value ?? null;
  const target = indicator.targetScope === 'monthly' && typeof source?.target === 'number' ? source.target : null;
  return (
    <div className="chart-tooltip">
      <strong>{source?.fullLabel ?? 'เดือนงบประมาณ'}</strong>
      <span><i className="tooltip-dot tooltip-dot-aqua" />ผลงาน {formatIndicatorValue(indicator, typeof monthValue === 'number' ? monthValue : null)}</span>
      {target !== null && <span><i className="tooltip-dot tooltip-dot-amber" />เป้าหมายต่อรอบรายงาน {formatIndicatorValue(indicator, target)}</span>}
    </div>
  );
}
