import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createServer } from 'vite';

const server = await createServer({ logLevel: 'error', server: { middlewareMode: true, hmr: false }, appType: 'custom' });
try {
  const { codeCteDependencies } = await server.ssrLoadModule('/src/services/thipFoundationPlan.ts');
  const { planThipSteps } = await server.ssrLoadModule('/src/services/thipStepLoader.ts');
  const { assertRegisteredReadOnlyQuery, externalRegisteredCodes } = await server.ssrLoadModule('/src/services/queryRegistry.ts');
  const { getExpectedFiscalMonths, getReportingCadence } = await server.ssrLoadModule('/src/data/thipReporting.ts');
  const plan = planThipSteps(2026);
  if (plan.length !== 177 || externalRegisteredCodes.length !== 55) throw new Error('Step manifest coverage changed; review the contract');
  const steps = plan.map(({ code, key, query, start, end }) => {
    assertRegisteredReadOnlyQuery(query);
    if (/\*\s*(100|1000|100000)\s*\//.test(query.sql)) throw new Error(`Integer ratio in ${code}`);
    if ([...query.sql.matchAll(/'([A-Z]{2}\d{4}(?:\.\d)?)' AS indicator_code/g)].length !== 1) throw new Error(`Multi-code query in ${code}`);
    return { code, key, cteDependencies: codeCteDependencies([code]), cadence: getReportingCadence(code), expectedMonths: getExpectedFiscalMonths(code), start, end, sqlBytes: Buffer.byteLength(query.sql), sqlSha256: createHash('sha256').update(query.sql).digest('hex') };
  });
  const text = JSON.stringify({ schemaVersion: 'thip-sequential-candidates/1', series: 'thip-report', concurrency: 1, gapMs: 1000, observationWindow: 'full-fiscal-year', approval: 'unapproved', steps, skippedExternalCodes: externalRegisteredCodes }, null, 2) + '\n';
  const path = 'reporting/thip_step_queries.manifest.json';
  if (process.argv.includes('--check')) { if (readFileSync(path, 'utf8') !== text) throw new Error('Step manifest drift; run pnpm steps:build'); }
  else writeFileSync(path, text, 'utf8');
  console.log(`${process.argv.includes('--check') ? 'Verified' : 'Generated'} 177 registered single-code queries / 55 external placeholders; no credentials or patient rows`);
} finally { await server.close(); }
