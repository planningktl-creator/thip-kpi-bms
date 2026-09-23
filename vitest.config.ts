import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config';

/**
 * Test discovery is pinned to `src/`.
 *
 * Without this, Vitest's default glob also collects `tmp/*.test.ts`, which are
 * gitignored scratch probes. That makes the suite non-deterministic: `tmp/dump-foundation.test.ts`
 * writes the 177 per-code SQL files and exceeds the 5 s default timeout under CPU
 * contention, so a documented result could be contradicted by a scratch file. Reproduced
 * by running two Vitest processes at once — one reported
 * `1 failed | 1215 passed` from that probe while the other passed.
 *
 * Consequence to remember: the probes are excluded, not merely filtered, so
 * `npx vitest run tmp/<file>` finds nothing. Run them with `npm run test:probe`
 * (which uses `vitest.probe.config.ts`) instead.
 *
 * The Vite half is merged rather than copied so aliases, plugins and `base` keep a
 * single source of truth in `vite.config.ts`.
 */
export default mergeConfig(viteConfig, defineConfig({
  test: {
    include: ['src/**/*.test.ts', 'src/**/*.test.tsx'],
  },
}));
