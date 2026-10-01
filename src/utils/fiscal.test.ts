import { describe, expect, it } from 'vitest';
import { bangkokDate, formatFiscalRange, formatFiscalYear, formatThaiDate, formatThaiDateTime, getCurrentFiscalYear, getFiscalMonthPeriods } from '@/utils/fiscal';
import { formatRefreshTime } from '@/utils/format';

describe('fiscal year display boundary', () => {
  it('maps an ISO fiscal year to Thai Buddhist month labels', () => {
    const periods = getFiscalMonthPeriods(2026);

    expect(periods[0]).toMatchObject({ periodStart: '2025-10-01', label: 'ต.ค. 2568', fiscalMonth: 1 });
    expect(periods[11]).toMatchObject({ periodStart: '2026-09-01', label: 'ก.ย. 2569', fiscalMonth: 12 });
    expect(formatFiscalYear(2026)).toBe('ปีงบประมาณ 2569');
    expect(formatFiscalRange(2026)).toBe('ต.ค. 2568 — ก.ย. 2569');
  });

  it('derives the current fiscal year from the October boundary', () => {
    expect(getCurrentFiscalYear(new Date('2026-09-11T00:00:00Z'))).toBe(2026);
    expect(getCurrentFiscalYear(new Date('2026-10-01T00:00:00Z'))).toBe(2027);
  });

  it('uses Bangkok midnight and invalidates a reused Date when its time changes', () => {
    const date = new Date('2026-09-30T16:59:59Z');
    expect(bangkokDate(date)).toBe('2026-09-30');
    expect(getCurrentFiscalYear(date)).toBe(2026);
    date.setTime(date.getTime() + 1000);
    expect(bangkokDate(date)).toBe('2026-10-01');
    expect(getCurrentFiscalYear(date)).toBe(2027);
  });

  it('shares immutable periods without mixing fiscal years', () => {
    const periods = getFiscalMonthPeriods(2026);
    expect(getFiscalMonthPeriods(2026)).toBe(periods);
    expect(Object.isFrozen(periods)).toBe(true);
    expect(periods.every(Object.isFrozen)).toBe(true);
    expect(getFiscalMonthPeriods(2027)[0].periodStart).toBe('2026-10-01');
    expect(periods[0].periodStart).toBe('2025-10-01');
  });

  it('displays calendar dates in BE without shifting or using BE leap-year arithmetic', () => {
    expect(formatThaiDate('2025-10-01')).toBe('1 ต.ค. พ.ศ. 2568');
    expect(formatThaiDate('2024-02-29')).toBe('29 ก.พ. พ.ศ. 2567');
    for (const invalid of [null, undefined, '', '2025-02-29', '2026-02-30', '2026-13-01', '2026-00-00', '0000-01-01', '2026-10-01T00:00:00Z']) {
      expect(formatThaiDate(invalid)).toBe('—');
    }
  });

  it('displays timestamps at Bangkok midnight and new year with exactly one BE conversion', () => {
    expect(formatThaiDateTime('2026-09-30T16:59:59Z')).toBe('30 ก.ย. พ.ศ. 2569 23:59:59');
    expect(formatThaiDateTime('2026-09-30T17:00:00Z')).toBe('1 ต.ค. พ.ศ. 2569 00:00:00');
    const instant = '2025-12-31T17:00:00Z';
    expect(formatThaiDateTime(instant)).toBe('1 ม.ค. พ.ศ. 2569 00:00:00');
    expect(formatThaiDateTime('2026-01-01T00:00:00+07:00')).toBe(formatThaiDateTime(instant));
    expect(formatThaiDateTime(Date.parse(instant))).toBe(formatThaiDateTime(instant));
    expect(formatRefreshTime(instant)).toBe(formatThaiDateTime(instant));
  });

  it('does not silently interpret an ambiguous timestamp in the computer timezone', () => {
    for (const invalid of [null, undefined, '', 'invalid', '2026-10-01', '2026-10-01T00:00:00', '2026-02-30T00:00:00Z', NaN]) {
      expect(formatThaiDateTime(invalid)).toBe('—');
    }
    expect(formatRefreshTime(null)).toBe('—');
  });
});
