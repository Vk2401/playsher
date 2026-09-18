import { createTheme, alpha } from '@mui/material/styles'

export const PALETTE_SWATCHES = [
  // Playsher is the customer app's own brand blue (mobile_app/lib/core/app_colors.dart).
  // It leads the list and is the default: the panel and the app are one product,
  // and an admin who has never opened the picker should see the product's colour.
  { name: 'Playsher', hex: '#0061C2' },
  { name: 'Sage',   hex: '#6B9E7A' },
  { name: 'Forest', hex: '#4A7C59' },
  { name: 'Slate',  hex: '#5B7FA6' },
  { name: 'Terra',  hex: '#A06B5A' },
  { name: 'Plum',   hex: '#7B6BA8' },
  { name: 'Teal',   hex: '#4A8B8B' },
]

export const DEFAULT_COLOR = '#0061C2'

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
        default: '#F4F7FB',
        paper: '#FFFFFF',
      },
      text: {
        primary: '#0F1B2D',
        secondary: '#5A6B80',
      },
      divider: '#E3E8EF',
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
      borderRadius: 10,
    },
    // Surfaces are defined by a hairline border, not by depth. Only the two
    // genuinely floating things (menu, dialog) get a shadow at all.
    shadows: [
      'none',
      'none',
      'none',
      'none',
      '0 4px 16px rgba(15,27,45,0.08)',
      ...Array(20).fill('0 8px 28px rgba(15,27,45,0.10)'),
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
            background: primaryColor,
            boxShadow: 'none',
            '&:hover': { background: darken(primaryColor, 0.15), boxShadow: 'none' },
          },
        },
      },
      MuiPaper: {
        styleOverrides: {
          root: {
            backgroundImage: 'none',
            border: '1px solid #E3E8EF',
          },
        },
      },
      MuiCard: {
        styleOverrides: {
          root: { border: '1px solid #E3E8EF', boxShadow: 'none' },
        },
      },
      MuiDrawer: {
        styleOverrides: {
          paper: { border: 'none', boxShadow: 'none' },
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
