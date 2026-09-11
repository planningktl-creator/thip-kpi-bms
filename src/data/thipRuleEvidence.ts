import type { ThipKpiRuleEvidence } from '@/data/thipKpiRules';

/**
 * Curated rule evidence, keyed by indicator code.
 *
 * Only entries with a real, traceable source belong here. A field is omitted
 * when the hospital workflow has not supplied it, so `getRuleReadiness()`
 * reports it as missing and the rule cannot be published as `ready`. The
 * foundation codes below have dictionary evidence but no hospital owner
 * sign-off yet, so `owner` is intentionally absent.
 */
export const thipRuleEvidenceByCode: Readonly<Record<string, ThipKpiRuleEvidence>> = {
  DH0101: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-acs',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.39', 'queryRegistry:thipIpdFoundation'],
  },
  'DH0101.1': {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-acs-stemi',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.40', 'queryRegistry:thipIpdFoundation'],
  },
  'DH0101.2': {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-acs-nste',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.41', 'queryRegistry:thipIpdFoundation'],
  },
  DH0102: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'admission_datetime',
    codeSetVersion: 'thip-2025-pdf-acs',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.42', 'queryRegistry:thipIpdFoundation'],
  },
  DH0112: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-acs',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.54', 'queryRegistry:thipIpdFoundation'],
  },
  DN0101: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-stroke',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.67', 'queryRegistry:thipIpdFoundation'],
  },
  DN0107: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-stroke',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.73', 'queryRegistry:thipIpdFoundation'],
  },
  DN0109: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-stroke',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.74', 'queryRegistry:thipIpdFoundation'],
  },
  DN0302: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'admission_datetime',
    codeSetVersion: 'thip-2025-pdf-head-injury',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.77', 'queryRegistry:thipIpdFoundation'],
  },
  DR0101: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-pneumonia',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.79', 'queryRegistry:thipIpdFoundation'],
  },
  DR0102: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-pneumonia',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.80', 'queryRegistry:thipIpdFoundation'],
  },
  DR0403: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-copd',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.90', 'queryRegistry:thipIpdFoundation'],
  },
  DG0102: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-ugih',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.121', 'queryRegistry:thipIpdFoundation'],
  },
  DG0202: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-appendicitis',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.123', 'queryRegistry:thipIpdFoundation'],
  },
  CE0101: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'admission_datetime',
    codeSetVersion: 'thip-2025-pdf-sepsis',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.194', 'queryRegistry:thipIpdFoundation'],
  },
  CI0101: {
    episodeGrain: 'one-row-per-admission',
    periodField: 'discharge_date',
    codeSetVersion: 'thip-2025-pdf-sepsis',
    ruleVersion: 'foundation-2026.1',
    evidence: ['THIP KPI.pdf:p.199', 'queryRegistry:thipIpdFoundation'],
  },
};
