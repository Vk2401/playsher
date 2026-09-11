import { Badge, BottomNavigation, BottomNavigationAction, Box, ButtonBase, Paper, Stack, Typography, useMediaQuery } from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'

import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined'
import EventNoteOutlinedIcon from '@mui/icons-material/EventNoteOutlined'
import StadiumOutlinedIcon from '@mui/icons-material/StadiumOutlined'
import MenuIcon from '@mui/icons-material/Menu'

import OfflineBanner from '../ui/OfflineBanner.jsx'
import InstallAppButton from '../ui/InstallAppButton.jsx'
import { OwnerGroundProvider } from '../../contexts/OwnerGroundContext.jsx'
import { usePendingCoachRequests } from '../../hooks/useOwnerCounts.js'

/**
 * Layout for the ground-owner panel only.
 *
 * The admin and coach panels keep AppShell. Owners get an app-style layout:
 * four tabs in a bottom bar on a phone, the same four as a slim side rail on a
 * laptop, and content held to a readable width instead of stretched tables.
 */
const TABS = [
  { label: 'Today', path: '/owner/dashboard', icon: WbSunnyOutlinedIcon },
  { label: 'Bookings', path: '/owner/bookings', icon: EventNoteOutlinedIcon },
  { label: 'My Ground', path: '/owner/my-ground', icon: StadiumOutlinedIcon },
  { label: 'More', path: '/owner/more', icon: MenuIcon },
]

// Screens opened from "More" keep the More tab lit.
const MORE_CHILDREN = ['/owner/coach-requests', '/owner/coach-sessions', '/owner/games',
  '/owner/bank-details', '/owner/profile', '/owner/notifications']

const RAIL = 232

function activeTab(pathname) {
  const direct = TABS.findIndex((t) => pathname === t.path || pathname.startsWith(`${t.path}/`))
  if (direct >= 0) return direct
  if (MORE_CHILDREN.some((p) => pathname.startsWith(p))) return 3
  if (pathname.startsWith('/owner/grounds')) return 2
  return 0
}

export default function OwnerShell() {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))
  const { pathname } = useLocation()
  const navigate = useNavigate()
  const pendingCoach = usePendingCoachRequests()
  const current = activeTab(pathname)

  const icon = (t, i) => {
    const Icon = t.icon
    return i === 3 && pendingCoach > 0
      ? <Badge color="warning" variant="dot"><Icon /></Badge>
      : <Icon />
  }

  return (
    <OwnerGroundProvider>
      <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
        {!isMobile && (
          <Box
            component="nav"
            sx={{
              position: 'fixed', top: 0, bottom: 0, left: 0, width: RAIL,
              bgcolor: 'background.paper', borderRight: 1, borderColor: 'divider',
              display: 'flex', flexDirection: 'column', px: 2, py: 3,
            }}
          >
            <Box px={1.5} mb={3}>
              <Typography variant="h6" fontWeight={800} color="primary.dark">
                Playsher
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Ground owner
              </Typography>
            </Box>
            <Stack spacing={0.5}>
              {TABS.map((t, i) => {
                const on = i === current
                return (
                  <ButtonBase
                    key={t.path}
                    onClick={() => navigate(t.path)}
                    sx={{
                      justifyContent: 'flex-start', gap: 1.5, px: 1.5, py: 1.25, borderRadius: 1,
                      bgcolor: on ? alpha(theme.palette.primary.main, 0.14) : 'transparent',
                      color: on ? 'primary.dark' : 'text.secondary',
                      '&:hover': { bgcolor: alpha(theme.palette.primary.main, on ? 0.18 : 0.06) },
                    }}
                  >
                    {icon(t, i)}
                    <Typography fontWeight={on ? 700 : 500} color="inherit">
                      {t.label}
                    </Typography>
                  </ButtonBase>
                )
              })}
            </Stack>
            <Box flexGrow={1} />
            <InstallAppButton />
          </Box>
        )}

        <Box
          component="main"
          sx={{
            ml: isMobile ? 0 : `${RAIL}px`,
            pb: isMobile ? 'calc(80px + env(safe-area-inset-bottom))' : 4,
          }}
        >
          <OfflineBanner />
          <Box sx={{ maxWidth: 760, mx: 'auto', px: { xs: 2, sm: 3 }, pt: { xs: 2, sm: 3 } }}>
            <Outlet />
          </Box>
        </Box>

        {isMobile && (
          <Paper
            elevation={0}
            sx={{
              position: 'fixed', left: 0, right: 0, bottom: 0, zIndex: theme.zIndex.appBar,
              borderTop: 1, borderColor: 'divider', borderRadius: 0,
              pb: 'env(safe-area-inset-bottom)', bgcolor: 'background.paper',
            }}
          >
            <BottomNavigation
              showLabels
              value={current}
              onChange={(_e, i) => navigate(TABS[i].path)}
              sx={{ height: 64, bgcolor: 'transparent' }}
            >
              {TABS.map((t, i) => (
                <BottomNavigationAction
                  key={t.path}
                  label={t.label}
                  icon={icon(t, i)}
                  sx={{
                    minWidth: 0,
                    '&.Mui-selected': { color: 'primary.dark' },
                    '& .MuiBottomNavigationAction-label.Mui-selected': { fontWeight: 700, fontSize: 12 },
                    '& .MuiBottomNavigationAction-label': { fontSize: 12 },
                  }}
                />
              ))}
            </BottomNavigation>
          </Paper>
        )}
      </Box>
    </OwnerGroundProvider>
  )
}
