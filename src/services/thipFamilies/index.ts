import { ACS_STROKE_ACUTE_APPROXIMATIONS, ACS_STROKE_ACUTE_BRANCHES } from '@/services/thipFamilies/acs_stroke_acute';
import { ACSC_ED_TOBACCO_APPROXIMATIONS, ACSC_ED_TOBACCO_BRANCHES } from '@/services/thipFamilies/acsc_ed_tobacco';
import { NCD_MENTAL_APPROXIMATIONS, NCD_MENTAL_BRANCHES } from '@/services/thipFamilies/ncd_mental';
import { MATERNAL_SPECIALTY_APPROXIMATIONS, MATERNAL_SPECIALTY_BRANCHES } from '@/services/thipFamilies/maternal_specialty';
import { SAFETY_OPERATIONS_APPROXIMATIONS, SAFETY_OPERATIONS_BRANCHES } from '@/services/thipFamilies/safety_operations';
import { HR_EMPLOYEE_APPROXIMATIONS, HR_EMPLOYEE_BRANCHES } from '@/services/thipFamilies/hr_employee';
import { CUSTOMER_FINANCE_GOV_APPROXIMATIONS, CUSTOMER_FINANCE_GOV_BRANCHES } from '@/services/thipFamilies/customer_finance_gov';
import { isExternalBranch } from '@/services/thipFamilyBase';

/**
 * Registry of the batch family modules: one read-only fact branch per
 * previously pending THIP code, plus the documented approximations that
 * describe what each branch actually measures and what the hospital owner
 * must confirm. Integration (queryRegistry, reporting refresh) reads these
 * maps so the family modules stay self-contained.
 */
export const thipBatchBranches: readonly string[] = [
  ...ACS_STROKE_ACUTE_BRANCHES,
  ...ACSC_ED_TOBACCO_BRANCHES,
  ...NCD_MENTAL_BRANCHES,
  ...MATERNAL_SPECIALTY_BRANCHES,
  ...SAFETY_OPERATIONS_BRANCHES,
  ...HR_EMPLOYEE_BRANCHES,
  ...CUSTOMER_FINANCE_GOV_BRANCHES,
];

export const thipBatchApproximations: Readonly<Record<string, string>> = {
  ...ACS_STROKE_ACUTE_APPROXIMATIONS,
  ...ACSC_ED_TOBACCO_APPROXIMATIONS,
  ...NCD_MENTAL_APPROXIMATIONS,
  ...MATERNAL_SPECIALTY_APPROXIMATIONS,
  ...SAFETY_OPERATIONS_APPROXIMATIONS,
  ...HR_EMPLOYEE_APPROXIMATIONS,
  ...CUSTOMER_FINANCE_GOV_APPROXIMATIONS,
};

const BRANCH_CODE_PATTERN = /'([A-Z]{2}[0-9]{4}(?:\.[0-9]+)?)'\s+AS\s+indicator_code/i;

export function branchCodeOf(sql: string): string | null {
  const match = BRANCH_CODE_PATTERN.exec(sql);
  return match ? match[1]! : null;
}

/** Exactly one branch per code; duplicates or unlabelled branches are wiring bugs. */
export const thipBatchBranchByCode: ReadonlyMap<string, string> = (() => {
  const map = new Map<string, string>();
  for (const sql of thipBatchBranches) {
    const code = branchCodeOf(sql);
    if (!code) throw new Error('THIP batch branch without a recognizable indicator code label');
    if (map.has(code)) throw new Error(`THIP batch registered two branches for ${code}`);
    map.set(code, sql);
  }
  return map;
})();

/** Codes served from `reporting.thip_external_facts` (hospital-loaded aggregates). */
export const thipExternalCodes: readonly string[] = [...thipBatchBranchByCode.keys()]
  .filter((code) => isExternalBranch(thipBatchBranchByCode.get(code)!))
  .sort();
