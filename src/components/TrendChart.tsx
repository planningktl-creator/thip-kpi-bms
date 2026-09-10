import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { MonthlyResult } from '@/types/thip';
import { formatIndicatorValue } from '@/utils/format';
import type { Indicator } from '@/types/thip';

type Props = {
  indicator: Indicator;
  compact?: boolean;
};

export function TrendChart({ indicator, compact = false }: Props) {
  const data = indicator.monthly.map((month) => ({
    label: month.label,
    value: month.value,
    target: month.target,
  }));

  return (
    <div className={`trend-chart ${compact ? 'trend-chart-compact' : ''}`}>
      <ResponsiveContainer width="100%" height={compact ? 128 : 270}>
        <AreaChart data={data} margin={{ top: 8, right: 6, left: -24, bottom: 0 }}>
          <defs>
            <linearGradient id={`fill-${indicator.code}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#2dc9c5" stopOpacity={0.34} />
              <stop offset="100%" stopColor="#2dc9c5" stopOpacity={0.02} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="#e1eaee" strokeDasharray="3 5" vertical={false} />
          <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} interval={compact ? 2 : 0} />
          <YAxis axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} width={34} />
          <Tooltip content={<ChartTooltip indicator={indicator} />} />
          <Area type="monotone" dataKey="value" stroke="#149e9b" strokeWidth={2.5} fill={`url(#fill-${indicator.code})`} connectNulls={false} isAnimationActive={false} />
          <Area type="monotone" dataKey="target" stroke="#f4b942" strokeDasharray="5 5" strokeWidth={1.5} fill="none" connectNulls isAnimationActive={false} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

function ChartTooltip({ active, payload, label, indicator }: { active?: boolean; payload?: Array<{ payload?: MonthlyResult & { target?: number | null }; dataKey?: string; value?: number | null }>; label?: string; indicator: Indicator }) {
  if (!active || !payload?.length) return null;
  const monthValue = payload.find((entry) => entry.dataKey === 'value')?.value ?? null;
  const target = payload.find((entry) => entry.dataKey === 'target')?.value ?? indicator.target;
  return (
    <div className="chart-tooltip">
      <strong>{label}</strong>
      <span><i className="tooltip-dot tooltip-dot-aqua" />ผลงาน {formatIndicatorValue(indicator, typeof monthValue === 'number' ? monthValue : null)}</span>
      <span><i className="tooltip-dot tooltip-dot-amber" />เป้าหมาย {formatIndicatorValue(indicator, typeof target === 'number' ? target : null)}</span>
    </div>
  );
}
