import { describe, expect, it } from 'vitest';
import { createNoDataIndicator, thipCatalogue } from '@/data/thipCatalogue';

describe('THIP source catalogue', () => {
  it('contains the complete 2025 dictionary index without duplicate codes', () => {
    expect(thipCatalogue).toHaveLength(232);
    expect(new Set(thipCatalogue.map((entry) => entry.code)).size).toBe(232);
  });

  it('keeps unmapped indicators honest across all fiscal months', () => {
    const indicator = createNoDataIndicator(thipCatalogue[0]);
    expect(indicator.monthly).toHaveLength(12);
    expect(indicator.monthly.every((month) => month.value === null)).toBe(true);
    expect(indicator.monthly.every((month) => month.status === 'no-data')).toBe(true);
    expect(indicator.formula).toBe('a/b x 100,000');
    expect(indicator.reference).toContain('หน้า 286');
    expect(indicator.definition).toContain('ACSC');
  });

  it('honors the requested fiscal year instead of pinning a fixed year', () => {
    const indicator = createNoDataIndicator(thipCatalogue[0], 2025);
    expect(indicator.fiscalYear).toBe(2025);
    expect(indicator.monthly[0]).toMatchObject({ fiscalYear: 2025, periodStart: '2024-10-01' });
    expect(indicator.annual.fiscalYear).toBe(2025);
  });

  it('preserves the dictionary unit for no-data indicators', () => {
    const acsc = createNoDataIndicator(thipCatalogue.find((entry) => entry.code === 'AA0101')!);
    const los = createNoDataIndicator(thipCatalogue.find((entry) => entry.code === 'DG0102')!);

    expect(acsc.unit).toBe('rate');
    expect(los.unit).toBe('ratio');
  });

  it('keeps every catalogue title free of PDF-extraction mojibake', () => {
    const mojibakePattern = /[ÖøêĕĂĆÙðÿœ]/;
    const corrupted = thipCatalogue.filter((entry) => mojibakePattern.test(entry.title));
    expect(corrupted.map((entry) => `${entry.code}: ${entry.title}`)).toEqual([]);
  });

  it('keeps every catalogue Thai title populated and free of mojibake', () => {
    const mojibakePattern = /[ÖøêĕĂĆÙðÿœ]/;
    expect(thipCatalogue.every((entry) => typeof entry.titleTh === 'string' && entry.titleTh.trim().length > 0)).toBe(true);
    const corrupted = thipCatalogue.filter((entry) => mojibakePattern.test(entry.titleTh));
    expect(corrupted.map((entry) => `${entry.code}: ${entry.titleTh}`)).toEqual([]);
  });
});
