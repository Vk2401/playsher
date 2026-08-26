import React, { createContext, useContext, useState, useCallback, useEffect } from 'react'
import apiClient from '../api/client.js'
import { purgePwaCaches } from '../pwa/registerSW.js'

const AuthContext = createContext(null)

const STORAGE_KEYS = {
  accessToken: 'playsher_access_token',
  refreshToken: 'playsher_refresh_token',
  user: 'playsher_user',
}

/** Decode JWT payload without verifying signature (client-side only). */
function decodeJwt(token) {
  try {
    const payload = token.split('.')[1]
    return JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')))
  } catch {
    return null
  }
}

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEYS.user)) } catch { return null }
  })
  const [accessToken, setAccessToken] = useState(() => localStorage.getItem(STORAGE_KEYS.accessToken))
  const [loading, setLoading] = useState(false)

  const saveAuth = useCallback((data) => {
    const { access_token, refresh_token } = data

    // user can come as data.user (admin/user) or data.owner (legacy ground_owner)
    let u = data.user || data.owner || null

    // Fallback: decode JWT to get id + role if backend didn't include a user object
    if (!u && access_token) {
      const decoded = decodeJwt(access_token)
      if (decoded?.id) {
        u = { id: decoded.id, role: decoded.role }
      }
    }

    localStorage.setItem(STORAGE_KEYS.accessToken, access_token)
    if (refresh_token) localStorage.setItem(STORAGE_KEYS.refreshToken, refresh_token)
    localStorage.setItem(STORAGE_KEYS.user, JSON.stringify(u))

    setAccessToken(access_token)
    setUser(u)
    apiClient.defaults.headers.common['Authorization'] = `Bearer ${access_token}`
  }, [])

  const clearAuth = useCallback(() => {
    localStorage.removeItem(STORAGE_KEYS.accessToken)
    localStorage.removeItem(STORAGE_KEYS.refreshToken)
    localStorage.removeItem(STORAGE_KEYS.user)
    setAccessToken(null)
    setUser(null)
    delete apiClient.defaults.headers.common['Authorization']
  }, [])

  // Restore Authorization header on mount / token change
  useEffect(() => {
    if (accessToken) {
      apiClient.defaults.headers.common['Authorization'] = `Bearer ${accessToken}`
    }
  }, [accessToken])

  const loginAdmin = useCallback(async (email, password) => {
    setLoading(true)
    try {
      const { data } = await apiClient.post('/auth/admin/login', { email, password })
      // API wraps response in data.data; handle both shapes
      saveAuth(data.data ?? data)
      return data
    } finally {
      setLoading(false)
    }
  }, [saveAuth])

  const loginOwner = useCallback(async (email, password) => {
    setLoading(true)
    try {
      const { data } = await apiClient.post('/auth/ground-owner/login', { email, password })
      saveAuth(data.data ?? data)
      return data
    } finally {
      setLoading(false)
    }
  }, [saveAuth])

  const loginCoach = useCallback(async (email, password) => {
    setLoading(true)
    try {
      const { data } = await apiClient.post('/auth/coach/login', { email, password })
      saveAuth(data.data ?? data)
      return data
    } finally {
      setLoading(false)
    }
  }, [saveAuth])

  // Self-registration, which owners do not have: a coach signs up here and
  // waits for an admin to approve them. No token comes back, so the caller
  // shows the "pending approval" message rather than navigating into a panel.
  const registerCoach = useCallback(async (payload) => {
    setLoading(true)
    try {
      const { data } = await apiClient.post('/auth/coach/register', payload)
      return data
    } finally {
      setLoading(false)
    }
  }, [])

  const logout = useCallback(async () => {
    try {
      const refreshToken = localStorage.getItem(STORAGE_KEYS.refreshToken)
      if (refreshToken) await apiClient.post('/auth/logout', { refresh_token: refreshToken })
    } catch { /* ignore */ } finally {
      clearAuth()
      // These panels run on shared office machines. Clearing storage is not
      // enough once a service worker is installed: its caches would outlive
      // the session and serve this admin's shell to whoever signs in next.
      await purgePwaCaches()
    }
  }, [clearAuth])

  const isAdmin = user?.role === 'admin'
  const isOwner = user?.role === 'ground_owner'
  const isCoach = user?.role === 'coach'
  const isAuthenticated = Boolean(user && accessToken)

  /** Where this account's panel starts. One place, so every redirect agrees. */
  const homePath = isAdmin ? '/admin/dashboard'
    : isOwner ? '/owner/dashboard'
      : isCoach ? '/coach/dashboard'
        : '/login'

  return (
    <AuthContext.Provider value={{
      user, accessToken, loading, isAuthenticated, isAdmin, isOwner, isCoach, homePath,
      loginAdmin, loginOwner, loginCoach, registerCoach, logout, saveAuth, clearAuth,
    }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
