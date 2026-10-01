import { createServer } from 'vite';
import { mkdirSync, writeFileSync } from 'node:fs';
const server = await createServer({ logLevel: 'error', server: { middlewareMode: true, hmr: false }, appType: 'custom' });
try {
  const { codeComparisonQueries } = await server.ssrLoadModule('/src/services/thipFoundationPlan.ts');
  mkdirSync('tmp/sql-performance', { recursive: true });
  writeFileSync('tmp/sql-performance/queries.json', JSON.stringify(['DH0101','DH0112','CE0102','HH0102','HE0101','SH0101'].map(codeComparisonQueries)));
} finally { await server.close(); }
