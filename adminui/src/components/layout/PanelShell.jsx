import React from 'react'
import {
  BottomNavigation, BottomNavigationAction, Box, ButtonBase, Paper, Stack,
  Typography, useMediaQuery,
} from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import SportsSoccerIcon from '@mui/icons-material/SportsSoccer'

import OfflineBanner from '../ui/OfflineBanner.jsx'
import InstallAppButton from '../ui/InstallAppButton.jsx'
import { visibleTabs, activeTabIndex } from '../../config/navigation.jsx'

/**
 * The app-style layout, for any panel.
 *
 * One component serves admin and coach because the only thing that differs
 * between them is their entry in `config/navigation` — the rail, the bottom bar
 * and the More screen all read from there. OwnerShell predates this and keeps
 * its own copy for now; it carries an extra provider and a coach-request badge
 * that do not generalise, and folding it in is a separate change.
 *
 * Phone: four tabs in a fixed bottom bar.
 * Laptop: the same four as a slim rail, content held to a readable width rather
 * than stretched across the screen.
 */
const RAIL = 232

export default function PanelShell({ panel }) {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))
  const { pathname } = useLocation()
  const navigate = useNavigate()

  const tabs = visibleTabs(panel)
  const current = activeTabIndex(panel, pathname)

  return (
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
          <Stack direction="row" spacing={1.25} alignItems="center" sx={{ px: 1.5, mb: 3 }}>
            <Box
              sx={{
                width: 34, height: 34, borderRadius: 1.5, flexShrink: 0,
                bgcolor: 'primary.main', display: 'grid', placeItems: 'center',
              }}
            >
              <SportsSoccerIcon sx={{ color: '#fff', fontSize: 20 }} />
            </Box>
            <Box sx={{ minWidth: 0 }}>
              <Typography fontWeight={800} lineHeight={1.15} noWrap>
                {panel.title}
              </Typography>
              <Typography variant="caption" color="text.secondary" noWrap>
                {panel.subtitle}
              </Typography>
            </Box>
          </Stack>

          <Stack spacing={0.5}>
            {tabs.map((t, i) => {
              const on = i === current
              const Icon = t.icon
              return (
                <ButtonBase
                  key={t.path}
                  onClick={() => navigate(t.path)}
                  sx={{
                    justifyContent: 'flex-start', gap: 1.5, px: 1.5, py: 1.25, borderRadius: 1,
                    bgcolor: on ? alpha(theme.palette.primary.main, 0.12) : 'transparent',
                    color: on ? 'primary.main' : 'text.secondary',
                    '&:hover': { bgcolor: alpha(theme.palette.primary.main, on ? 0.16 : 0.06) },
                  }}
                >
                  <Icon />
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
        {/* Wider than the owner panel's 760: admin pages carry real tables. */}
        <Box sx={{ maxWidth: 1180, mx: 'auto', px: { xs: 2, sm: 3 }, pt: { xs: 2, sm: 3 } }}>
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
            onChange={(_e, i) => navigate(tabs[i].path)}
            sx={{ height: 64, bgcolor: 'transparent' }}
          >
            {tabs.map((t) => {
              const Icon = t.icon
              return (
                <BottomNavigationAction
                  key={t.path}
                  label={t.label}
                  icon={<Icon />}
                  sx={{
                    minWidth: 0,
                    '&.Mui-selected': { color: 'primary.main' },
                    '& .MuiBottomNavigationAction-label': { fontSize: 12 },
                    '& .MuiBottomNavigationAction-label.Mui-selected': { fontWeight: 700, fontSize: 12 },
                  }}
                />
              )
            })}
          </BottomNavigation>
        </Paper>
      )}
    </Box>
  )
}
