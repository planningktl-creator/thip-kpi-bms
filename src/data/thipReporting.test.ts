import { describe, expect, it } from 'vitest';
import { thipCatalogue } from '@/data/thipCatalogue';
import { expectedFiscalMonthsByCadence, getExpectedFiscalMonths, getLatestApplicableFiscalMonth, getPreviousApplicableFiscalMonth, getReportingCadence, thipReportingCadenceByCode } from '@/data/thipReporting';

describe('THIP reporting cadence', () => {
  it('covers every catalogue code and preserves the dictionary cadence split', () => {
    expect(Object.keys(thipReportingCadenceByCode)).toHaveLength(232);
    expect(thipCatalogue.every((entry) => Boolean(thipReportingCadenceByCode[entry.code]))).toBe(true);
    expect(Object.values(thipReportingCadenceByCode).filter((cadence) => cadence === 'monthly')).toHaveLength(112);
    expect(Object.values(thipReportingCadenceByCode).filter((cadence) => cadence === 'quarterly')).toHaveLength(19);
    expect(Object.values(thipReportingCadenceByCode).filter((cadence) => cadence === 'semiannual')).toHaveLength(31);
    expect(Object.values(thipReportingCadenceByCode).filter((cadence) => cadence === 'annual')).toHaveLength(70);
  });

  it('uses fiscal-period start months for non-monthly reporting', () => {
    expect(getReportingCadence('AA0101')).toBe('annual');
    expect(getExpectedFiscalMonths('AA0101')).toEqual(expectedFiscalMonthsByCadence.annual);
    expect(getExpectedFiscalMonths('DH0101')).toHaveLength(12);
    expect(getExpectedFiscalMonths('DH0110')).toEqual([1, 4, 7, 10]);
    expect(getExpectedFiscalMonths('DC0108')).toEqual([1, 7]);
  });

  it('selects the latest applicable period without fabricating a non-reporting month', () => {
    expect(getLatestApplicableFiscalMonth('AA0101', 12)).toBe(1);
    expect(getLatestApplicableFiscalMonth('DH0110', 5)).toBe(4);
    expect(getLatestApplicableFiscalMonth('DC0108', 12)).toBe(7);
    expect(getPreviousApplicableFiscalMonth('DH0110', 4)).toBe(1);
    expect(getPreviousApplicableFiscalMonth('AA0101', 1)).toBeNull();
  });
});
