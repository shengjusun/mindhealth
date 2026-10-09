// AI生成
import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  base: '/',
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  build: { outDir: 'dist', chunkSizeWarningLimit: 1500 },
  server: {
    // 与 admin(5173) 错开，避免同时开发时端口冲突
    port: 5174,
    proxy: {
      // 后端 context-path 就是 /api，这里绝对不能 rewrite
      '/api': {
        target: 'http://localhost:9000',
        changeOrigin: true,
      },
    },
  },
})
