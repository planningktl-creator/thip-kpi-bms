import type { IndicatorGroup, IndicatorUnit } from '@/types/thip';
import type { CohortDefinition } from './cohortTypes';

export type ThipKpiRuleStatus =
  | 'foundation'
  | 'needs-local-mapping'
  | 'ready'
  | 'pending-local-source'
  | 'not-applicable';

/**
 * Optional rule evidence. A field is present only when the hospital workflow or
 * dictionary actually supplied it; never populate a placeholder to force a rule
 * to `ready`. `getRuleReadiness()` reports what is still missing.
 */
export type ThipKpiRuleEvidence = {
  /** Structural candidate evidence; never supplies hospital approval/readiness by itself. */
  cohortDefinition?: CohortDefinition;
  /** Hospital release approval is separate from SQL registration/readiness. */
  publicationApproval?: { version: string; from: string; until: string; evidence: string };
  hospitalTargetApproval?: { source: string; from: string; until: string; unit: IndicatorUnit };
  /** Episode/observation grain, e.g. `one-row-per-admission`. */
  episodeGrain?: string;
  /** Source date column that periodizes the result, e.g. `discharge_date`. */
  periodField?: string;
  inclusion?: readonly string[];
  exclusion?: readonly string[];
  /** Approved hospital code-set version, e.g. `icd10-2024-hosxp-v3`. */
  codeSetVersion?: string;
  /** Rule version, bumped whenever the formula or code set changes. */
  ruleVersion?: string;
  /** Accountable domain owner, e.g. `clinical-quality`. */
  owner?: string;
  /** Traceable evidence references, e.g. `THIP KPI.pdf:p.39`. */
  evidence?: readonly string[];
};

export type ThipKpiRule = {
  code: string;
  group: IndicatorGroup;
  title: string;
  pdfPage: number;
  formulaScale: string;
  queryFamily: string;
  /** Candidate tables from the HOSxP schema inventory; not an approved join contract. */
  candidateSourceTables: readonly string[];
  /** PDF tokens for review; must be normalized and signed off per hospital. */
  diagnosisOrProcedureTokens: readonly string[];
  status: ThipKpiRuleStatus;
  queryKey: string | null;
} & ThipKpiRuleEvidence;

export type ThipKpiRuleReadiness = {
  hasEpisodeGrain: boolean;
  hasPeriodField: boolean;
  hasCodeSet: boolean;
  hasOwner: boolean;
  hasEvidence: boolean;
  hasRuleVersion: boolean;
  /** True only when status is `ready` and every required evidence field is present. */
  ready: boolean;
  missing: readonly string[];
};

/**
 * Derives only the display unit from the dictionary formula scale.
 * It never derives a KPI value, target, or direction; those still belong to
 * the approved source view/rule implementation.
 */
export function getRuleUnit(rule: Pick<ThipKpiRule, 'formulaScale'>): IndicatorUnit {
  const scale = rule.formulaScale.replace(/[\s,]/g, '').toLowerCase();
  if (scale.includes('x1000000') || scale.includes('x100000') || scale.includes('x1000')) return 'rate';
  if (scale.includes('x100')) return 'percent';
  return 'ratio';
}

/**
 * Returns the multiplier written in a THIP formula, e.g. `a/b x 1,000` ->
 * 1000. A formula without an explicit multiplier is a plain ratio.
 */
export function getFormulaScale(formula: string): number {
  const match = formula.replace(/,/g, '').match(/[x×]\s*(\d+(?:\.\d+)?)/i);
  if (!match) return 1;
  const scale = Number(match[1]);
  return Number.isFinite(scale) && scale > 0 ? scale : 1;
}

function hasText(value: unknown): boolean {
  return typeof value === 'string' ? value.trim().length > 0 : Array.isArray(value) ? value.length > 0 : false;
}

/**
 * Reports whether a rule carries the evidence required before it may be
 * published. It never mutates the rule and never fills a missing field: a rule
 * that lacks evidence stays `ready: false` even if someone flips its status.
 */
export function getRuleReadiness(rule: ThipKpiRule): ThipKpiRuleReadiness {
  const hasEpisodeGrain = hasText(rule.episodeGrain);
  const hasPeriodField = hasText(rule.periodField);
  const hasCodeSet = hasText(rule.codeSetVersion);
  const hasOwner = hasText(rule.owner);
  const hasEvidence = hasText(rule.evidence);
  const hasRuleVersion = hasText(rule.ruleVersion);
  const missing: string[] = [];
  if (!hasEpisodeGrain) missing.push('episodeGrain');
  if (!hasPeriodField) missing.push('periodField');
  if (!hasCodeSet) missing.push('codeSetVersion');
  if (!hasOwner) missing.push('owner');
  if (!hasEvidence) missing.push('evidence');
  if (!hasRuleVersion) missing.push('ruleVersion');
  return {
    hasEpisodeGrain,
    hasPeriodField,
    hasCodeSet,
    hasOwner,
    hasEvidence,
    hasRuleVersion,
    ready: rule.status === 'ready' && missing.length === 0,
    missing,
  };
}

/**
 * A rule marked `ready` must carry complete evidence; this guard is the single
 * source of truth used by tests and the audit so no placeholder can be
 * published as production.
 */
export function assertRuleReadiness(rule: ThipKpiRule): void {
  if (rule.status !== 'ready') return;
  const readiness = getRuleReadiness(rule);
  if (!readiness.ready) {
    throw new Error(`THIP KPI rule ${rule.code} is marked ready but is missing evidence: ${readiness.missing.join(', ')}`);
  }
}

