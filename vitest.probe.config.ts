import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config';

/**
 * Opt-in config for the scratch probe scripts in `tmp/` (`npm run test:probe`).
 *
 * The release suite (`vitest.config.ts`) pins discovery to `src/` so a gitignored probe
 * cannot change its result. Those probes are still useful — `tmp/dump-foundation.test.ts`
 * regenerates the 177 per-code SQL files that the live extraction scripts read — so this
 * separate config keeps them runnable on demand without rejoining the release suite.
 *
 * Probes write only into the gitignored `tmp/`.
 */
export default mergeConfig(viteConfig, defineConfig({
  test: {
    include: ['tmp/**/*.test.ts'],
  },
}));
