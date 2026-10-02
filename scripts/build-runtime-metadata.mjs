import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createServer } from 'vite';

// Evaluate canonical sources in the build process, never ship their rich evidence
// or all registered SQL just to display the monitoring matrix.
const server = await createServer({ logLevel: 'error', server: { middlewareMode: true, hmr: false }, appType: 'custom' });
const hash = (value) => createHash('sha256').update(typeof value === 'string' ? value : JSON.stringify(value)).digest('hex');
const output = (path, value) => {
  const text = JSON.stringify(value) + '\n';
  if (process.argv.includes('--check')) {
    if (readFileSync(path, 'utf8') !== text) throw new Error(`Runtime metadata drift: ${path}`);
  } else writeFileSync(path, text);
};
try {
  const { thipCatalogue } = await server.ssrLoadModule('/src/data/thipCatalogue.ts');
  const { monitoringRules } = await server.ssrLoadModule('/src/monitoring/ruleSource.ts');
  const { thipKpiRulesByCode } = await server.ssrLoadModule('/src/data/thipKpiRules.ts');
  const { planFoundationRequests } = await server.ssrLoadModule('/src/services/thipFoundationPlan.ts');
  const { hosxpRegisteredCodes } = await server.ssrLoadModule('/src/services/queryRegistry.ts');
  const { getDictionaryEntry } = await server.ssrLoadModule('/src/data/thipDictionary.ts');
  const { getReportingCadence } = await server.ssrLoadModule('/src/data/thipReporting.ts');
  const { getFormulaScale } = await server.ssrLoadModule('/src/data/thipRuleLogic.ts');
  const rules = [...thipKpiRulesByCode.values()].map(({ cohortDefinition, ...rule }) => rule);
  const ordered = ['DH0101', 'DH0112', ...hosxpRegisteredCodes.filter((code) => !['DH0101', 'DH0112'].includes(code)).sort()];
  const signatures = ordered.map((code) => ({ code, sqlHash: hash(planFoundationRequests({ fiscalYear: 2026, chunkSize: 1, codes: [code] })[0].query.sql), ruleHash: hash(thipKpiRulesByCode.get(code)) }));
  if (rules.length !== 232 || monitoringRules.length !== 232 || signatures.length !== 177) throw new Error('Runtime coverage changed');
  const bridges = monitoringRules.filter(rule => rule.capability === 'candidate-native-monthly-period'
    && getReportingCadence(rule.code) === 'monthly' && signatures.some(item => item.code === rule.code)
    && getFormulaScale(thipKpiRulesByCode.get(rule.code).formulaScale) === rule.scale).map(rule => ({
      code: rule.code, version: 'reporting-monthly-bridge/1', unit: rule.unit, scale: rule.scale,
      sourceRuleHash: signatures.find(item => item.code === rule.code).ruleHash,
      cohortHash: hash(thipKpiRulesByCode.get(rule.code).cohortDefinition),
      evidence: `Same monthly reporting fact, cohort, event date and observation window; review only. THIP KPI.pdf:p.${thipKpiRulesByCode.get(rule.code).pdfPage}`,
    }));
  const reportingDefinitions = [...thipKpiRulesByCode.values()].map(rule => ({ code: rule.code, formula: rule.cohortDefinition?.formula ?? rule.formulaScale, method: rule.cohortDefinition?.observationWindow ?? 'Source-supplied reporting period only', ruleHash: hash(rule) }));
  output('src/data/thipRuntimeMetadata.json', { catalogue: thipCatalogue, rules, monitoringRules, signatures, bridges, reportingDefinitions });
  const families = [...new Set(thipCatalogue.map((entry) => entry.code.slice(0, 2)))].sort();
  mkdirSync('src/data/evidence', { recursive: true });
  for (const family of families) {
    const entries = thipCatalogue.filter((entry) => entry.code.startsWith(family));
    output(`src/data/evidence/${family}.json`, Object.fromEntries(entries.map(({ code }) => [code, { dictionary: getDictionaryEntry(code), cohort: thipKpiRulesByCode.get(code)?.cohortDefinition }])));
  }
  console.log(`Verified/generated 232 runtime rules, 177 fingerprints and ${families.length} evidence families`);
} finally { await server.close(); }
