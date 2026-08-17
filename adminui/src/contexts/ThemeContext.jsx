import React, { createContext, useContext, useState, useCallback } from 'react'
import { DEFAULT_COLOR } from '../theme/index.js'

const STORAGE_KEY = 'playsher_theme_color'

const ThemeContext = createContext(null)

export function ThemeContextProvider({ children }) {
  const [primaryColor, setPrimaryColorState] = useState(
    () => localStorage.getItem(STORAGE_KEY) || DEFAULT_COLOR
  )

  const setPrimaryColor = useCallback((color) => {
    localStorage.setItem(STORAGE_KEY, color)
    setPrimaryColorState(color)
  }, [])

  return (
    <ThemeContext.Provider value={{ primaryColor, setPrimaryColor }}>
      {children}
    </ThemeContext.Provider>
  )
}

export function useThemeContext() {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useThemeContext must be used within ThemeContextProvider')
  return ctx
}
