import React from 'react'
import {
  Avatar, Box, ButtonBase, Divider, Paper, Stack, Typography,
} from '@mui/material'
import { alpha } from '@mui/material/styles'
import { useNavigate } from 'react-router-dom'
import ChevronRightIcon from '@mui/icons-material/ChevronRight'
import LogoutIcon from '@mui/icons-material/Logout'

import { useAuth } from '../../contexts/AuthContext.jsx'
import { useIsSuperAdmin } from '../../hooks/useIsSuperAdmin.js'
import { visibleGroups } from '../../config/navigation.jsx'

/**
 * The More screen, generated from a panel's navigation config.
 *
 * Everything that does not earn a bottom-bar tab lives here, in titled groups.
 * Because it reads the same config the rail and bottom bar read, hiding a page
 * removes it from all three at once — there is no list here to forget.
 */
export default function MorePage({ panel }) {
  const navigate = useNavigate()
  const { user, logout } = useAuth()
  const isSuperAdmin = useIsSuperAdmin()

  const groups = visibleGroups(panel, { isSuperAdmin })

  const handleLogout = async () => {
    await logout()
    navigate('/login', { replace: true })
  }

  return (
    <Box sx={{ pb: 3 }}>
      <Typography variant="h5" fontWeight={800} mb={0.5}>More</Typography>
      <Typography variant="body2" color="text.secondary" mb={2.5}>
        Everything else in the {panel.subtitle.toLowerCase()} panel
      </Typography>

      {/* Who am I — the one thing people check before they change something. */}
      <Paper sx={{ p: 2, mb: 2.5, borderRadius: 2 }}>
        <Stack direction="row" spacing={1.75} alignItems="center">
          <Avatar sx={{ bgcolor: 'primary.main', width: 44, height: 44, fontWeight: 700 }}>
            {(user?.name || '?').charAt(0).toUpperCase()}
          </Avatar>
          <Box sx={{ minWidth: 0 }}>
            <Typography fontWeight={700} noWrap>{user?.name || 'Signed in'}</Typography>
            <Typography variant="body2" color="text.secondary" noWrap>
              {user?.email || panel.subtitle}
            </Typography>
          </Box>
        </Stack>
      </Paper>

      <Stack spacing={2.5}>
        {groups.map((group) => (
          <Box key={group.title}>
            <Typography
              variant="caption"
              sx={{
                display: 'block', mb: 1, ml: 0.5, fontWeight: 700,
                letterSpacing: '0.06em', textTransform: 'uppercase', color: 'text.secondary',
              }}
            >
              {group.title}
            </Typography>

            {/* One card, hairline-divided rows — the owner panel's list shape. */}
            <Paper sx={{ borderRadius: 2, overflow: 'hidden' }}>
              {group.items.map((item, i) => {
                const Icon = item.icon
                return (
                  <React.Fragment key={item.path}>
                    {i > 0 && <Divider />}
                    <ButtonBase
                      onClick={() => navigate(item.path)}
                      sx={{
                        width: '100%', justifyContent: 'flex-start', gap: 1.75,
                        px: 2, py: 1.75, textAlign: 'left',
                        '&:hover': { bgcolor: (t) => alpha(t.palette.primary.main, 0.04) },
                      }}
                    >
                      <Box
                        sx={{
                          width: 38, height: 38, borderRadius: 1.5, flexShrink: 0,
                          display: 'grid', placeItems: 'center',
                          bgcolor: (t) => alpha(t.palette.primary.main, 0.1),
                          color: 'primary.main',
                        }}
                      >
                        <Icon sx={{ fontSize: 21 }} />
                      </Box>
                      <Box sx={{ flexGrow: 1, minWidth: 0 }}>
                        <Typography fontWeight={600} noWrap>{item.label}</Typography>
                        {item.caption && (
                          <Typography variant="caption" color="text.secondary" noWrap display="block">
                            {item.caption}
                          </Typography>
                        )}
                      </Box>
                      <ChevronRightIcon sx={{ color: 'text.secondary', flexShrink: 0 }} />
                    </ButtonBase>
                  </React.Fragment>
                )
              })}
            </Paper>
          </Box>
        ))}

        <Paper sx={{ borderRadius: 2, overflow: 'hidden' }}>
          <ButtonBase
            onClick={handleLogout}
            sx={{
              width: '100%', justifyContent: 'flex-start', gap: 1.75,
              px: 2, py: 1.75, color: 'error.main',
              '&:hover': { bgcolor: (t) => alpha(t.palette.error.main, 0.05) },
            }}
          >
            <Box
              sx={{
                width: 38, height: 38, borderRadius: 1.5, flexShrink: 0,
                display: 'grid', placeItems: 'center',
                bgcolor: (t) => alpha(t.palette.error.main, 0.1),
              }}
            >
              <LogoutIcon sx={{ fontSize: 21 }} />
            </Box>
            <Typography fontWeight={600} color="inherit">Sign out</Typography>
          </ButtonBase>
        </Paper>
      </Stack>
    </Box>
  )
}
