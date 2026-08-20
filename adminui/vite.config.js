import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { resolve } from 'path'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      // 'prompt', not 'autoUpdate': admins spend their time inside half-filled
      // DrawerForms, and a silent reload would discard that work. UpdatePrompt
      // asks first and only reloads on confirmation.
      registerType: 'prompt',
      injectRegister: null, // registration is owned by src/pwa/registerSW.js
      includeAssets: ['favicon.svg', 'favicon-32x32.png', 'apple-touch-icon.png'],

      manifest: {
        name: 'Playsher Admin',
        short_name: 'Playsher',
        description: 'Playsher admin and ground-owner panel — grounds, bookings and payouts.',
        id: '/',
        start_url: '/',
        scope: '/',
        display: 'standalone',
        orientation: 'any',
        // Matches the default Sage swatch. The in-app palette picker is a
        // runtime preference and cannot change an installed manifest.
        theme_color: '#6B9E7A',
        background_color: '#F4F7F5',
        categories: ['business', 'productivity', 'sports'],
        icons: [
          { src: 'pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png' },
          {
            src: 'pwa-maskable-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
        shortcuts: [
          { name: 'Dashboard', url: '/admin/dashboard' },
          { name: 'Bookings', url: '/admin/bookings' },
          { name: 'Grounds', url: '/admin/grounds' },
        ],
      },

      workbox: {
        globPatterns: ['**/*.{js,css,html,svg,png,ico,woff,woff2}'],
        // The app shell serves every SPA route...
        navigateFallback: '/index.html',
        // ...but must never stand in for the API or the SW itself.
        navigateFallbackDenylist: [/^\/api\//, /^\/sw\.js$/, /^\/manifest\.webmanifest$/],
        clientsClaim: true,
        skipWaiting: false, // the prompt decides when to activate
        cleanupOutdatedCaches: true,

        runtimeCaching: [
          {
            // Every API response here is authenticated, per-user and mutable.
            // Caching it would risk showing one admin another's data on a
            // shared machine, and would serve stale rows after a mutation.
            urlPattern: ({ url }) =>
              url.pathname.startsWith('/api/') || /\/api\/v\d+\//.test(url.href),
            handler: 'NetworkOnly',
          },
          {
            // Google Fonts stylesheet: revalidate in the background so a font
            // change lands without blocking first paint.
            urlPattern: ({ url }) => url.origin === 'https://fonts.googleapis.com',
            handler: 'StaleWhileRevalidate',
            options: { cacheName: 'google-fonts-stylesheets' },
          },
          {
            // The font files themselves are immutable and safe to keep.
            urlPattern: ({ url }) => url.origin === 'https://fonts.gstatic.com',
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-webfonts',
              cacheableResponse: { statuses: [0, 200] },
              expiration: { maxEntries: 20, maxAgeSeconds: 60 * 60 * 24 * 365 },
            },
          },
        ],
      },

      devOptions: {
        // Off by default: a service worker in `npm run dev` caches modules and
        // makes HMR behave unpredictably. Flip to true to debug the SW itself.
        enabled: false,
        type: 'module',
      },
    }),
  ],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
})
