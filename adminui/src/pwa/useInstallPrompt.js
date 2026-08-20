import { useCallback, useEffect, useState } from 'react'

/**
 * Surfaces the browser's install flow.
 *
 * Browsers stopped showing an automatic install banner: Chrome on desktop only
 * puts a small icon in the omnibox, and Android's mini-infobar is suppressed
 * for good once dismissed. So a PWA that never calls `prompt()` itself looks
 * uninstallable to most users even when it fully meets the criteria.
 *
 * `beforeinstallprompt` fires early — often before React mounts — so
 * `initPwa()` starts capturing it at page load and this hook reads what was
 * captured. Without that the event is routinely missed.
 */

let deferredPrompt = null
const listeners = new Set()

function emit() {
  listeners.forEach((fn) => fn(deferredPrompt))
}

/** Called once from initPwa(), before React mounts. */
export function captureInstallPrompt() {
  if (typeof window === 'undefined') return

  window.addEventListener('beforeinstallprompt', (event) => {
    // Suppress the mini-infobar so our own button owns the moment.
    event.preventDefault()
    deferredPrompt = event
    emit()
  })

  window.addEventListener('appinstalled', () => {
    deferredPrompt = null
    emit()
  })
}

/** True when the page is already running as an installed app. */
export function isStandalone() {
  if (typeof window === 'undefined') return false
  return (
    window.matchMedia?.('(display-mode: standalone)').matches ||
    // iOS Safari predates display-mode and uses this instead.
    window.navigator.standalone === true
  )
}

/** iOS Safari never fires beforeinstallprompt; it needs manual instructions. */
export function isIos() {
  if (typeof navigator === 'undefined') return false
  return (
    /iphone|ipad|ipod/i.test(navigator.userAgent) ||
    // iPadOS 13+ reports as a Mac, distinguished by touch support.
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
  )
}

export function useInstallPrompt() {
  const [prompt, setPrompt] = useState(deferredPrompt)
  const [installed, setInstalled] = useState(isStandalone())

  useEffect(() => {
    const listener = (value) => {
      setPrompt(value)
      if (value === null) setInstalled(isStandalone())
    }
    listeners.add(listener)
    return () => listeners.delete(listener)
  }, [])

  /** Opens the browser's install dialog. Resolves to the user's choice. */
  const install = useCallback(async () => {
    if (!deferredPrompt) return 'unavailable'
    deferredPrompt.prompt()
    const { outcome } = await deferredPrompt.userChoice
    // The event is single-use: a dismissed prompt cannot be replayed, the
    // browser fires a fresh one when it decides the user is ready again.
    deferredPrompt = null
    emit()
    return outcome
  }, [])

  return {
    /** Chromium-family: the browser has offered installation. */
    canInstall: Boolean(prompt),
    /** iOS: installable, but only through the Share menu. */
    needsIosInstructions: isIos() && !installed,
    installed,
    install,
  }
}
