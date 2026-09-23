import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config';

/**
 * Test discovery is pinned to `src/`.
 *
 * Without this, Vitest's default glob also collects `tmp/*.test.ts`. Those files are
 * gitignored scratch that writes probe artifacts, so leaving them in the suite means a
 * documented test count can be contradicted by a scratch file — exactly what happened
 * when a full-suite run reported two failures from `tmp/dump_partition.test.ts` that no
 * committed test could reproduce.
 *
 * Consequence to remember: the probes are excluded, not merely filtered, so
 * `npx vitest run tmp/<file>` finds nothing. To execute one, move it under
 * `src/test-support/` first (keep it temporary, or it joins the release suite).
 *
 * The Vite half is merged rather than copied so aliases, plugins and `base` keep a
 * single source of truth in `vite.config.ts`.
 */
export default mergeConfig(viteConfig, defineConfig({
  test: {
    include: ['src/**/*.test.ts', 'src/**/*.test.tsx'],
  },
}));
