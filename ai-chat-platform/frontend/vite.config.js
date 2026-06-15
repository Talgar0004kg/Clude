import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// base: './' — относительные пути, чтобы корректно работать на GitHub Pages
// из подпапки. Роутинг построен на HashRouter, поэтому серверная настройка
// перенаправлений не нужна.
export default defineConfig({
  plugins: [react()],
  base: './',
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:4000'
    }
  }
})
