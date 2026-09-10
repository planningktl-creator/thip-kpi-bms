import type { Indicator, IndicatorStatus } from '@/types/thip';

const integerFormatter = new Intl.NumberFormat('th-TH', {
  maximumFractionDigits: 0,
});

const decimalFormatter = new Intl.NumberFormat('th-TH', {
  minimumFractionDigits: 1,
  maximumFractionDigits: 2,
});

export function formatNumber(value: number | null | undefined, digits = 0): string {
  if (value === null || value === undefined || Number.isNaN(value)) return '—';
  return digits === 0 ? integerFormatter.format(value) : decimalFormatter.format(value);
}

export function formatIndicatorValue(indicator: Indicator, value: number | null): string {
  if (value === null) return 'ไม่มีข้อมูล';
  if (indicator.unit === 'percent') return `${formatNumber(value, 1)}%`;
  if (indicator.unit === 'rate') return `${formatNumber(value, 2)}`;
  if (indicator.unit === 'ratio') return `${formatNumber(value, 2)}x`;
  return formatNumber(value);
}

export function formatCompact(value: number): string {
  return new Intl.NumberFormat('th-TH', {
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(value);
}

export function formatDelta(current: number | null, previous: number | null, indicator: Indicator): string {
  if (current === null || previous === null) return 'ไม่มีฐานเปรียบเทียบ';
  const delta = current - previous;
  if (Math.abs(delta) < 0.005) return 'ทรงตัว';
  const improved = indicator.direction === 'lower-is-better' ? delta < 0 : delta > 0;
  const sign = delta > 0 ? '+' : '';
  return `${sign}${formatNumber(delta, 1)} ${improved ? 'ดีขึ้น' : 'ควรติดตาม'}`;
}

export const statusLabel: Record<IndicatorStatus, string> = {
  'on-track': 'ตามเป้าหมาย',
  watch: 'เฝ้าระวัง',
  action: 'ควรเร่งดำเนินการ',
  'no-data': 'ยังไม่มีข้อมูล',
};

export const statusClass: Record<IndicatorStatus, string> = {
  'on-track': 'status-good',
  watch: 'status-watch',
  action: 'status-action',
  'no-data': 'status-muted',
};

