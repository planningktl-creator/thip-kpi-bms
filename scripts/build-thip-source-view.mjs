import { mkdirSync, writeFileSync } from 'node:fs';
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

const server = await createServer({
  root,
  logLevel: 'error',
  server: { middlewareMode: true },
  appType: 'custom',
});

try {
  const module = await server.ssrLoadModule('/src/services/thipSourceViewSql.ts');
  const artifact = module.buildSourceViewArtifact();

  mkdirSync(outputDir, { recursive: true });
  writeFileSync(resolve(outputDir, 'thip_kpi_monthly.sql'), `${artifact.ddl}\n\n${artifact.refresh}\n`, 'utf8');

  console.log(
    `wrote reporting/thip_kpi_monthly.sql · registered=${artifact.registeredCodeCount} pending=${artifact.pendingCodeCount} cells=${artifact.expectedCellCount}`,
  );
} finally {
  await server.close();
}
