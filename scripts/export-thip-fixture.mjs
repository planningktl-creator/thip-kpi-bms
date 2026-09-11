import { mkdirSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { createServer } from 'vite';

/**
 * Exports synthetic THIP normalized source-view fixtures from the repository
 * manifests. The fixtures contain no patient data; they exist so the contract
 * audit and the adapter tests can run in CI without a hospital session.
 */

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputDir = resolve(root, 'test-fixtures');
const invalidDir = resolve(outputDir, 'invalid');

const server = await createServer({
  root,
  logLevel: 'error',
  server: { middlewareMode: true },
  appType: 'custom',
});

try {
  const fixture = await server.ssrLoadModule('/src/test-support/thipSourceFixture.ts');

  const complete = fixture.buildCompleteSourceFixture(fixture.FIXTURE_FISCAL_YEAR);
  mkdirSync(outputDir, { recursive: true });
  writeFileSync(
    resolve(outputDir, 'thip-kpi-complete-2026.json'),
    `${JSON.stringify(complete, null, 2)}\n`,
    'utf8',
  );

  mkdirSync(invalidDir, { recursive: true });
  for (const [name, mutate] of Object.entries(fixture.invalidFixtureMutations)) {
    const rows = mutate(complete);
    writeFileSync(resolve(invalidDir, `${name}.json`), `${JSON.stringify(rows, null, 2)}\n`, 'utf8');
  }

  console.log(
    `wrote ${complete.length} complete rows and ${Object.keys(fixture.invalidFixtureMutations).length} invalid fixtures to test-fixtures/`,
  );
} finally {
  await server.close();
}
