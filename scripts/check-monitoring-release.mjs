import { readFileSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

const assets = resolve('dist/assets');
for (const name of readdirSync(assets).filter((name) => name.endsWith('.js'))) {
  const text = readFileSync(resolve(assets, name), 'utf8');
  for (const canary of ['SYNTHETIC_MONITORING_FIXTURE_ONLY', 'synthetic-preview-1', 'PREVIEW ONLY: ผู้ลาออกเดือนนี้', 'SYNTHETIC_PROFILE_CREDENTIAL', 'SYNTHETIC_CACHE_CREDENTIAL']) {
    if (text.includes(canary)) throw new Error(`Synthetic fixture leaked into ${name}: ${canary}`);
  }
}
let rejected = false;
try {
  execFileSync(process.execPath, ['node_modules/vite/bin/vite.js', 'build', '--outDir', 'tmp/forbidden-preview-build'], {
    encoding: 'utf8', env: { ...process.env, VITE_THIP_MONITORING_PREVIEW: 'true' }, stdio: 'pipe',
  });
} catch (error) {
  rejected = String(error.stderr).includes('Development monitoring preview must be disabled');
}
if (!rejected) throw new Error('Production build did not reject the preview flag');
console.log('Production fixture exclusion and preview flag rejection passed');
