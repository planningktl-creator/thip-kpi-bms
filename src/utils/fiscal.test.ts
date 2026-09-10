import { describe, expect, it } from 'vitest';
import { formatFiscalRange, formatFiscalYear, getFiscalMonthPeriods } from '@/utils/fiscal';

describe('fiscal year display boundary', () => {
  it('maps an ISO fiscal year to Thai Buddhist month labels', () => {
    const periods = getFiscalMonthPeriods(2026);

    expect(periods[0]).toMatchObject({ periodStart: '2025-10-01', label: 'ต.ค. 2568', fiscalMonth: 1 });
    expect(periods[11]).toMatchObject({ periodStart: '2026-09-01', label: 'ก.ย. 2569', fiscalMonth: 12 });
    expect(formatFiscalYear(2026)).toBe('ปีงบประมาณ 2569');
    expect(formatFiscalRange(2026)).toBe('ต.ค. 2568 — ก.ย. 2569');
  });
});
