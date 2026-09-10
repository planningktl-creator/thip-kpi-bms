import type { FiscalYear } from '@/types/thip';

export const BUDDHIST_ERA_OFFSET = 543;

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

export function formatFiscalYear(fiscalYear: FiscalYear): string {
  return `ปีงบประมาณ ${toBuddhistYear(fiscalYear)}`;
}

export function formatFiscalYearShort(fiscalYear: FiscalYear): string {
  return `FY${toBuddhistYear(fiscalYear)}`;
}

export function formatThaiMonth(isoDate: string): string {
  const month = Number(isoDate.slice(5, 7));
  return thaiMonthNames[month - 1] ?? '—';
}

export function formatThaiMonthYear(isoDate: string): string {
  const calendarYear = Number(isoDate.slice(0, 4));
  return `${formatThaiMonth(isoDate)} ${toBuddhistYear(calendarYear)}`;
}

export function getFiscalMonthPeriods(fiscalYear: FiscalYear): FiscalMonthPeriod[] {
  return Array.from({ length: 12 }, (_, index) => {
    const month = ((index + 9) % 12) + 1;
    const calendarYear = month >= 10 ? fiscalYear - 1 : fiscalYear;
    const periodStart = `${calendarYear}-${pad(month)}-01`;
    return {
      fiscalYear,
      fiscalMonth: index + 1,
      month,
      calendarYear,
      periodStart,
      monthLabel: thaiMonthNames[month - 1],
      label: formatThaiMonthYear(periodStart),
    };
  });
}

export function formatFiscalRange(fiscalYear: FiscalYear): string {
  const periods = getFiscalMonthPeriods(fiscalYear);
  return `${periods[0].label} — ${periods[periods.length - 1].label}`;
}
