import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/',
  build: { outDir: 'dist', chunkSizeWarningLimit: 1500 },
  server: {
    port: 5173,
    proxy: {
      // 后端 context-path 就是 /api，这里绝对不能 rewrite
      '/api': {
        target: 'http://localhost:9000',
        changeOrigin: true,
      },
    },
  },
})