import { describe, expect, it } from 'vitest';
import { isExternalBranch } from '@/services/thipFamilyBase';
import {
  branchCodeOf,
  thipBatchApproximations,
  thipBatchBranchByCode,
  thipBatchBranches,
  thipExternalCodes,
} from '@/services/thipFamilies/index';

describe('THIP batch family registry', () => {
  it('registers exactly one fact branch per batch code with no duplicates', () => {
    expect(thipBatchBranches.length).toBe(thipBatchBranchByCode.size);
    for (const sql of thipBatchBranches) {
      expect(branchCodeOf(sql)).not.toBeNull();
    }
  });

  it('registers the 171 batch codes beyond the legacy in-registry families', () => {
    // The legacy FAMILY_BRANCHES in queryRegistry cover the 61-code registered
    // core; these modules cover the remaining 171 codes of the 232-code
    // manifest. queryRegistry.test asserts that all 232 resolve exactly once.
    expect(thipBatchBranchByCode.size).toBe(171);
    expect(Object.keys(thipBatchApproximations)).toHaveLength(171);
  });

  it('documents an approximation note for every batch code', () => {
    for (const code of thipBatchBranchByCode.keys()) {
      expect(thipBatchApproximations[code], `missing approximation note for ${code}`).toBeTruthy();
    }
  });

  it('keeps every branch inside the read-only aggregate contract', () => {
    for (const [code, sql] of thipBatchBranchByCode) {
      if (isExternalBranch(sql)) {
        expect(sql, code).toContain('FROM external_facts');
      } else {
        expect(sql, code).toContain('AS numerator');
        expect(sql, code).toContain('AS denominator');
        expect(sql, code).toContain('AS value');
        expect(sql, code).toMatch(/GROUP BY 2, 3, 4/);
      }
      expect(sql, code).not.toMatch(/\b[A-Z]\d{2}\./); // no dotted ICD codes
    }
  });

  it('flags external-fact codes consistently', () => {
    for (const code of thipExternalCodes) {
      expect(isExternalBranch(thipBatchBranchByCode.get(code)!), code).toBe(true);
    }
  });
});
