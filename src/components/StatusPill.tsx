import type { IndicatorStatus } from '@/types/thip';
import { statusClass, statusLabel } from '@/utils/format';

type Props = {
  status: IndicatorStatus;
  compact?: boolean;
};

export function StatusPill({ status, compact = false }: Props) {
  return (
    <span className={`status-pill ${statusClass[status]} ${compact ? 'status-pill-compact' : ''}`}>
      <span className="status-dot" aria-hidden="true" />
      {statusLabel[status]}
    </span>
  );
}
