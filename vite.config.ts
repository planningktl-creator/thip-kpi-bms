import { fileURLToPath, URL } from 'node:url';
import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

const configuredBasePath = process.env.VITE_BASE_PATH?.trim() || '/';
const basePath = configuredBasePath.endsWith('/') ? configuredBasePath : `${configuredBasePath}/`;

export default defineConfig({
  base: basePath,
  plugins: [react(), {
    name: 'reject-production-monitoring-preview',
    config(_config, { command, mode }) {
      const env = loadEnv(mode, process.cwd(), 'VITE_');
      if (command === 'build' && (env.VITE_THIP_MONITORING_PREVIEW === 'true' || process.env.VITE_THIP_MONITORING_PREVIEW === 'true')) throw new Error('Development monitoring preview must be disabled for production builds');
    },
  }],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
  },
});
