import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { createServer } from 'vite';

/**
 * Emits the reporting-layer SQL artifact for the hospital data platform from
 * the repository manifests. The output contains no patient data and is not
 * executed by the app; it is the DDL + per-fiscal-year refresh a site runs to
 * provision VITE_BMS_KPI_SOURCE_VIEW.
 */

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputDir = resolve(root, 'reporting');
const matrix = JSON.parse(readFileSync(resolve(root, 'docs/THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json'), 'utf8'));
const evidence = JSON.stringify(matrix.kpis.map((kpi) => ({ code: kpi.code, path: kpi.monthlyMonitoring.designPath, pdfUnit: kpi.pdf.unit, printedPages: kpi.pdf.printedPages })), null, 2) + '\n';
const evidencePath = resolve(root, 'src/monitoring/evidence.json');
if (process.argv.includes('--check')) {
  if (readFileSync(evidencePath, 'utf8') !== evidence) throw new Error('Generated monitoring evidence drift');
} else writeFileSync(evidencePath, evidence, 'utf8');

const server = await createServer({
  root,
  logLevel: 'error',
  server: { middlewareMode: true },
  appType: 'custom',
});

try {
  const module = await server.ssrLoadModule('/src/services/thipSourceViewSql.ts');
  const artifact = module.buildSourceViewArtifact();
  const monitoring = await server.ssrLoadModule('/src/monitoring/ddl.ts');
  const rules = (await server.ssrLoadModule('/src/monitoring/rules.ts')).monitoringRules;
  const rulesJson = JSON.stringify({ schemaVersion: 'monitoring-rules-1', realApprovedCount: rules.filter((rule) => rule.approval === 'approved').length, rules }, null, 2) + '\n';

  mkdirSync(outputDir, { recursive: true });
  for (const [name, content] of [['thip_kpi_monthly.sql', `${artifact.ddl}\n\n${artifact.refresh}\n`], ['thip_monthly_monitoring.sql', monitoring.monitoringDdl()], ['thip_monitoring_rules.json', rulesJson]]) {
    const path = resolve(outputDir, name);
    if (process.argv.includes('--check')) {
      if (readFileSync(path, 'utf8') !== content) throw new Error(`Generated drift: reporting/${name}; run pnpm sourceview:build`);
    } else writeFileSync(path, content, 'utf8');
  }

  console.log(
    `${process.argv.includes('--check') ? 'verified' : 'wrote'} reporting artifacts · registered=${artifact.registeredCodeCount} pending=${artifact.pendingCodeCount} THIP cells=${artifact.expectedCellCount} monitoring cells=2784`,
  );
} finally {
  await server.close();
}
