import { registerSW } from 'virtual:pwa-register'

/**
 * Service-worker registration, kept out of React so it runs once per page load
 * rather than per mount.
 *
 * `vite-plugin-pwa` is configured with `registerType: 'prompt'`, so a new build
 * waits in the background until the user accepts. The callbacks below are what
 * `PwaUpdatePrompt` listens to.
 */

let updateServiceWorker = null
const listeners = new Set()
let state = { needRefresh: false, offlineReady: false }

function emit(next) {
  state = { ...state, ...next }
  listeners.forEach((fn) => fn(state))
}

/** Subscribe to SW state. Returns an unsubscribe function. */
export function onPwaState(listener) {
  listeners.add(listener)
  listener(state)
  return () => listeners.delete(listener)
}

/** Activate the waiting service worker and reload into the new build. */
export function applyUpdate() {
  if (updateServiceWorker) updateServiceWorker(true)
}

/** Dismiss the prompt without updating; it returns on the next load. */
export function dismissUpdate() {
  emit({ needRefresh: false })
}

export function dismissOfflineReady() {
  emit({ offlineReady: false })
}

export function initPwa() {
  // No SW in dev (devOptions.enabled is false) and none without browser support.
  if (import.meta.env.DEV || !('serviceWorker' in navigator)) return

  updateServiceWorker = registerSW({
    immediate: true,
    onNeedRefresh: () => emit({ needRefresh: true }),
    onOfflineReady: () => emit({ offlineReady: true }),
    onRegisterError: (error) => {
      // Registration failing must never take the panel down with it — the app
      // works fine unregistered, it just loses offline shell loading.
      console.error('[pwa] service worker registration failed', error)
    },
  })
}

/**
 * Drop every cache and unregister the worker.
 *
 * Called on logout: these panels run on shared office machines, and leaving one
 * admin's cached app shell and precache entries behind for the next person is
 * exactly the kind of residue a service worker makes easy to forget.
 */
export async function purgePwaCaches() {
  if (!('serviceWorker' in navigator)) return
  try {
    if ('caches' in window) {
      const keys = await caches.keys()
      await Promise.all(keys.map((key) => caches.delete(key)))
    }
    const registrations = await navigator.serviceWorker.getRegistrations()
    await Promise.all(registrations.map((r) => r.unregister()))
  } catch (error) {
    console.error('[pwa] failed to purge caches on logout', error)
  }
}
