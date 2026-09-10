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
  });
});
