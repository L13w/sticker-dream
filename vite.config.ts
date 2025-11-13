import { defineConfig } from 'vite';

export default defineConfig({
  server: {
    port: 7767,
    host: true,
    allowedHosts: ['local.wesbos.com','stickers.calutil.com'],
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
});

