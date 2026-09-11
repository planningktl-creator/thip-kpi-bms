import { describe, expect, it } from 'vitest';
import { thipCatalogue } from '@/data/thipCatalogue';
import {
  getImplementationTier,
  getPendingReason,
  pendingLocalSourceCodes,
  registeredRuleCodes,
  thipImplementation,
} from '@/data/thipImplementation';

describe('THIP implementation tiers', () => {
  it('classifies every catalogue code into exactly one tier', () => {
    expect(thipImplementation).toHaveLength(232);
    expect(new Set(thipImplementation.map((entry) => entry.code)).size).toBe(232);
    const classified = new Set([...registeredRuleCodes, ...pendingLocalSourceCodes]);
    for (const entry of thipCatalogue) {
      expect(classified.has(entry.code), entry.code).toBe(true);
    }
  });

  it('does not overlap registered and pending codes', () => {
    const registered = new Set(registeredRuleCodes);
    for (const code of pendingLocalSourceCodes) {
      expect(registered.has(code), code).toBe(false);
    }
  });

  it('keeps the registered set aligned with the manifest foundation codes', () => {
    // Every registered code must exist in the rule manifest.
    for (const code of registeredRuleCodes) {
      expect(thipImplementation.find((entry) => entry.code === code)?.tier, code).toBe('registered');
    }
  });

  it('gives every pending code a non-empty reason and every registered code none', () => {
    for (const code of pendingLocalSourceCodes) {
      const reason = getPendingReason(code);
      expect(reason, code).toBeTruthy();
      expect(getImplementationTier(code)).toBe('pending-local-source');
    }
    for (const code of registeredRuleCodes) {
      expect(getPendingReason(code), code).toBeNull();
      expect(getImplementationTier(code)).toBe('registered');
    }
  });
});
