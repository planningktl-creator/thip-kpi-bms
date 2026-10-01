import type { ThipKpiRuleEvidence } from './thipRuleLogic';
import rawCohorts from './thipCohortEvidence.json';
import type { CohortDefinition } from './cohortTypes';
import { curatedEvidenceByCode } from './thipCuratedEvidence';
// Structural extraction never supplies a clinical owner, local code set or release approval.
export const thipRuleEvidenceByCode: Record<string, ThipKpiRuleEvidence> = { ...curatedEvidenceByCode };
for (const cohort of rawCohorts as CohortDefinition[]) {
  thipRuleEvidenceByCode[cohort.code] = { ...curatedEvidenceByCode[cohort.code], cohortDefinition: cohort };
}
