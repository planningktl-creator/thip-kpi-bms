import type { LucideIcon } from 'lucide-react';

type Props = {
  eyebrow: string;
  value: string;
  helper: string;
  icon: LucideIcon;
  tone?: 'aqua' | 'amber' | 'coral' | 'violet';
  trend?: string;
};

export function MetricCard({ eyebrow, value, helper, icon: Icon, tone = 'aqua', trend }: Props) {
  return (
    <article className={`metric-card metric-${tone}`}>
      <div className="metric-topline">
        <span className="metric-eyebrow">{eyebrow}</span>
        <span className="metric-icon" aria-hidden="true"><Icon size={17} strokeWidth={2} /></span>
      </div>
      <div className="metric-value">{value}</div>
      <div className="metric-bottomline">
        <span>{helper}</span>
        {trend && <strong>{trend}</strong>}
      </div>
    </article>
  );
}
