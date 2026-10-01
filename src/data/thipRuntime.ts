import metadata from './thipRuntimeMetadata.json';
import type { ThipCatalogueEntry } from './thipCatalogue';
import type { ThipKpiRule } from './thipKpiRules';
import type { MonitoringRule } from '@/monitoring/types';

export const runtimeCatalogue = metadata.catalogue as readonly ThipCatalogueEntry[];
export const runtimeCatalogueByCode = new Map(runtimeCatalogue.map((entry) => [entry.code, entry]));
export const runtimeRulesByCode: ReadonlyMap<string, ThipKpiRule> = new Map((metadata.rules as ThipKpiRule[]).map((rule) => [rule.code, rule]));
export const runtimeMonitoringRules = metadata.monitoringRules as readonly MonitoringRule[];
export const runtimeSignatures = metadata.signatures;
