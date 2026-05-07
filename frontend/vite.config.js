import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In production, the React build is served by Nginx, and Nginx
// proxies /api/* to the application-tier EC2. So API calls in the
// React code use a relative URL like fetch('/api/notes').
//
// During local dev (`npm run dev`), this proxy forwards /api to a
// local backend on :3001 if you happen to run one.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
      },
    },
  },
});
