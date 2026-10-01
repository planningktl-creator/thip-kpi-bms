import type { FiscalYear } from '@/types/thip';

export const BUDDHIST_ERA_OFFSET = 543;
const bangkokFormatter = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Bangkok', year: 'numeric', month: '2-digit', day: '2-digit' });
const buddhistTimestampFormatter = new Intl.DateTimeFormat('th-TH-u-ca-buddhist-nu-latn', {
  calendar: 'buddhist', numberingSystem: 'latn', timeZone: 'Asia/Bangkok',
  year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
});
const dates = new WeakMap<Date, { time: number; iso: string }>();
const periodsByYear = new Map<FiscalYear, readonly FiscalMonthPeriod[]>();

const thaiMonthNames = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
] as const;

export type FiscalMonthPeriod = {
  fiscalYear: FiscalYear;
  fiscalMonth: number;
  month: number;
  calendarYear: number;
  periodStart: string;
  monthLabel: string;
  label: string;
};

function pad(value: number): string {
  return String(value).padStart(2, '0');
}

export function toBuddhistYear(calendarYear: number): number {
  return calendarYear + BUDDHIST_ERA_OFFSET;
}

export function formatBuddhistYear(calendarYear: number): string {
  return `พ.ศ. ${toBuddhistYear(calendarYear)}`;
}

/** Calendar dates are business dates, not instants: never shift them by timezone. */
export function formatThaiDate(isoDate: string | null | undefined): string {
  if (!isoDate || !/^\d{4}-\d{2}-\d{2}$/.test(isoDate)) return '—';
  const [year, month, day] = isoDate.split('-').map(Number);
  const date = new Date(`${isoDate}T00:00:00Z`);
  if (year < 1 || date.getUTCFullYear() !== year || date.getUTCMonth() + 1 !== month || date.getUTCDate() !== day) return '—';
  return `${day} ${thaiMonthNames[month - 1]} ${formatBuddhistYear(year)}`;
}

/** Offset-qualified ISO timestamps (or epoch milliseconds) always display in Bangkok. */
export function formatThaiDateTime(value: string | number | null | undefined): string {
  if (value === null || value === undefined || (typeof value === 'string' && !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})$/.test(value))) return '—';
  if (typeof value === 'string' && formatThaiDate(value.slice(0, 10)) === '—') return '—';
  const date = new Date(value);
  if (!Number.isFinite(date.getTime())) return '—';
  const parts = buddhistTimestampFormatter.formatToParts(date);
  const part = (type: string) => parts.find((item) => item.type === type)!.value;
  return `${part('day')} ${part('month')} พ.ศ. ${part('year')} ${part('hour')}:${part('minute')}:${part('second')}`;
}

export function formatFiscalYear(fiscalYear: FiscalYear): string {
  return `ปีงบประมาณ ${toBuddhistYear(fiscalYear)}`;
}

export function formatFiscalYearShort(fiscalYear: FiscalYear): string {
  return `FY${toBuddhistYear(fiscalYear)}`;
}

export function getCurrentFiscalYear(date = new Date()): FiscalYear {
  const iso = bangkokDate(date);
  const calendarYear = Number(iso.slice(0, 4));
  return Number(iso.slice(5, 7)) >= 10 ? calendarYear + 1 : calendarYear;
}

export function bangkokDate(date = new Date()): string {
  const cached = dates.get(date);
  if (cached?.time === date.getTime()) return cached.iso;
  const parts = bangkokFormatter.formatToParts(date);
  const part = (type: string) => parts.find((item) => item.type === type)!.value;
  const iso = `${part('year')}-${part('month')}-${part('day')}`;
  dates.set(date, { time: date.getTime(), iso });
  return iso;
}

export function fiscalPeriodEnd(fiscalYear: number, fiscalMonth: number): string {
  return fiscalMonth === 12 ? `${fiscalYear}-10-01` : getFiscalMonthPeriods(fiscalYear)[fiscalMonth].periodStart;
}

export function formatThaiMonth(isoDate: string): string {
  const month = Number(isoDate.slice(5, 7));
  return thaiMonthNames[month - 1] ?? '—';
}

export function formatThaiMonthYear(isoDate: string): string {
  const calendarYear = Number(isoDate.slice(0, 4));
  return `${formatThaiMonth(isoDate)} ${toBuddhistYear(calendarYear)}`;
}

export function getFiscalMonthPeriods(fiscalYear: FiscalYear): readonly FiscalMonthPeriod[] {
  const cached = periodsByYear.get(fiscalYear);
  if (cached) return cached;
  const periods = Object.freeze(Array.from({ length: 12 }, (_, index) => {
    const month = ((index + 9) % 12) + 1;
    const calendarYear = month >= 10 ? fiscalYear - 1 : fiscalYear;
    const periodStart = `${calendarYear}-${pad(month)}-01`;
    return Object.freeze({
      fiscalYear,
      fiscalMonth: index + 1,
      month,
      calendarYear,
      periodStart,
      monthLabel: thaiMonthNames[month - 1],
      label: formatThaiMonthYear(periodStart),
    });
  }));
  if (periodsByYear.size >= 32) periodsByYear.delete(periodsByYear.keys().next().value!);
  periodsByYear.set(fiscalYear, periods);
  return periods;
}

export function formatFiscalRange(fiscalYear: FiscalYear): string {
  const periods = getFiscalMonthPeriods(fiscalYear);
  return `${periods[0].label} — ${periods[periods.length - 1].label}`;
}
