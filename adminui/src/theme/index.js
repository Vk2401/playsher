import { createTheme, alpha } from '@mui/material/styles'

export const PALETTE_SWATCHES = [
  { name: 'Sage',   hex: '#6B9E7A' },
  { name: 'Forest', hex: '#4A7C59' },
  { name: 'Slate',  hex: '#5B7FA6' },
  { name: 'Terra',  hex: '#A06B5A' },
  { name: 'Plum',   hex: '#7B6BA8' },
  { name: 'Teal',   hex: '#4A8B8B' },
]

export const DEFAULT_COLOR = '#6B9E7A'

export function createAppTheme(primaryColor = DEFAULT_COLOR) {
  return createTheme({
    palette: {
      mode: 'light',
      primary: {
        main: primaryColor,
        light: alpha(primaryColor, 0.7),
        dark: darken(primaryColor, 0.2),
        contrastText: '#fff',
      },
      background: {
        default: '#F4F7F5',
        paper: 'rgba(255,255,255,0.88)',
      },
      text: {
        primary: '#1A2B22',
        secondary: '#5A7060',
      },
      divider: alpha(primaryColor, 0.15),
    },
    typography: {
      fontFamily: "'Inter', sans-serif",
      h4: { fontWeight: 700 },
      h5: { fontWeight: 700 },
      h6: { fontWeight: 600 },
      subtitle1: { fontWeight: 600 },
      button: { fontWeight: 600, textTransform: 'none' },
    },
    shape: {
      borderRadius: 14,
    },
    shadows: [
      'none',
      '0 1px 4px rgba(0,0,0,0.06)',
      '0 2px 8px rgba(0,0,0,0.08)',
      '0 4px 16px rgba(0,0,0,0.10)',
      '0 8px 24px rgba(0,0,0,0.12)',
      ...Array(20).fill('0 8px 32px rgba(0,0,0,0.14)'),
    ],
    components: {
      MuiButton: {
        styleOverrides: {
          root: {
            borderRadius: 10,
            paddingLeft: 20,
            paddingRight: 20,
          },
          containedPrimary: {
            background: `linear-gradient(135deg, ${primaryColor} 0%, ${darken(primaryColor, 0.15)} 100%)`,
            boxShadow: `0 4px 14px ${alpha(primaryColor, 0.35)}`,
            '&:hover': {
              boxShadow: `0 6px 20px ${alpha(primaryColor, 0.5)}`,
            },
          },
        },
      },
      MuiPaper: {
        styleOverrides: {
          root: {
            backgroundImage: 'none',
            backdropFilter: 'blur(8px)',
            border: `1px solid ${alpha(primaryColor, 0.15)}`,
          },
        },
      },
      MuiCard: {
        styleOverrides: {
          root: {
            border: `1px solid ${alpha(primaryColor, 0.15)}`,
            boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
          },
        },
      },
      MuiDrawer: {
        styleOverrides: {
          paper: {
            border: 'none',
            boxShadow: '-8px 0 32px rgba(0,0,0,0.12)',
          },
        },
      },
      MuiTableCell: {
        styleOverrides: {
          head: { fontWeight: 600, fontSize: '0.8rem', textTransform: 'uppercase', letterSpacing: '0.05em' },
        },
      },
      MuiChip: {
        styleOverrides: {
          root: { fontWeight: 600, fontSize: '0.75rem' },
        },
      },
      MuiTextField: {
        defaultProps: { size: 'small' },
      },
      MuiSelect: {
        defaultProps: { size: 'small' },
      },
    },
  })
}

function darken(hex, amount) {
  const num = parseInt(hex.replace('#', ''), 16)
  const r = Math.max(0, (num >> 16) - Math.round(255 * amount))
  const g = Math.max(0, ((num >> 8) & 0x00FF) - Math.round(255 * amount))
  const b = Math.max(0, (num & 0x0000FF) - Math.round(255 * amount))
  return '#' + ((r << 16) | (g << 8) | b).toString(16).padStart(6, '0')
}
