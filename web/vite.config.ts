import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

const apiProxyTarget =
  process.env.VITE_API_PROXY_TARGET ?? 'http://localhost:3000'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': apiProxyTarget,
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
  },
})
