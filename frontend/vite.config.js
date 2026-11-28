import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig(({ mode }) => ({
  plugins: [react()],
  build: {
    sourcemap: false,
  },
  esbuild: mode === 'production' ? { drop: ['console', 'debugger'] } : undefined,
}))
