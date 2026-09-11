import type { RefreshedAt } from '@/types/thip';

export type FreshnessState = 'unavailable' | 'stale' | 'fresh';

export type DataSourceState = 'loading' | 'live' | 'partial' | 'unavailable';

/** Default freshness SLA for a reporting source, in hours. */
export const REFRESH_SLA_HOURS = 36;

/**
 * Classifies how current the last successful source refresh is. It never
 * invents data: without a timestamp the source is `unavailable`, and a
 * timestamp older than the SLA is `stale`.
 */
export function getFreshnessState(
  refreshedAt: RefreshedAt | null,
  now: Date = new Date(),
  slaHours = REFRESH_SLA_HOURS,
): FreshnessState {
  if (!refreshedAt) return 'unavailable';
  const timestamp = Date.parse(refreshedAt);
  if (Number.isNaN(timestamp)) return 'unavailable';
  const ageHours = (now.getTime() - timestamp) / 3_600_000;
  return ageHours > slaHours ? 'stale' : 'fresh';
}

export type DataQualityTone = 'good' | 'warning' | 'error' | 'muted';

export type DataQualitySummary = {
  state: DataSourceState;
  freshness: FreshnessState;
  tone: DataQualityTone;
  label: string;
  detail: string;
};

/**
 * Produces the user-facing data-quality signal for the dashboard. It separates
 * `unavailable`, `stale`, `partial`, and `live` so a missing source is never
 * presented as a zero result.
 */
export function getDataQualitySummary(params: {
  dataSource: DataSourceState;
  refreshedAt: RefreshedAt | null;
  liveIndicatorCount: number;
  expectedIndicatorCount: number;
  coveredCellCount: number;
  expectedCellCount: number;
  now?: Date;
}): DataQualitySummary {
  const { dataSource, refreshedAt, liveIndicatorCount, expectedIndicatorCount, coveredCellCount, expectedCellCount } = params;
  const freshness = getFreshnessState(refreshedAt, params.now ?? new Date());
  const coverage = `${liveIndicatorCount}/${expectedIndicatorCount} ตัวชี้วัด · ${coveredCellCount}/${expectedCellCount} งวดรายงาน`;

  if (dataSource === 'loading') {
    return { state: dataSource, freshness, tone: 'muted', label: 'กำลังอ่านข้อมูล', detail: 'กำลังรอผลลัพธ์จาก registered query' };
  }
  if (dataSource === 'unavailable') {
    return { state: dataSource, freshness, tone: 'error', label: 'ไม่มีข้อมูลจริง', detail: 'ไม่พบผลลัพธ์จาก BMS · ระบบไม่แสดงค่า 0 แทนข้อมูลที่หายไป' };
  }
  if (dataSource === 'partial') {
    return { state: dataSource, freshness, tone: 'warning', label: 'ข้อมูลบางส่วน', detail: `source view ยังไม่ครบตาม cadence · ${coverage}` };
  }
  if (freshness === 'stale') {
    return { state: dataSource, freshness, tone: 'warning', label: 'ข้อมูลล่าช้า', detail: `ข้อมูลชุดล่าสุดเกิน SLA ${REFRESH_SLA_HOURS} ชั่วโมง · ${coverage}` };
  }
  return { state: dataSource, freshness, tone: 'good', label: 'ข้อมูลครบถ้วน', detail: `อ่านครบตามรอบรายงาน · ${coverage}` };
}

export const freshnessLabel: Record<FreshnessState, string> = {
  unavailable: 'ยังไม่มีการอ่านข้อมูลจริง',
  stale: 'ข้อมูลล่าช้า',
  fresh: 'ข้อมูลเป็นปัจจุบัน',
};
