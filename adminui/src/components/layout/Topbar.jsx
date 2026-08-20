import React, { useState } from 'react'
import {
  AppBar, Toolbar, Box, Typography, IconButton, Avatar,
  Menu, MenuItem, ListItemIcon, Divider, Tooltip, alpha,
} from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext.jsx'
import { useThemeContext } from '../../contexts/ThemeContext.jsx'
import { PALETTE_SWATCHES } from '../../theme/index.js'
import InstallAppButton from '../ui/InstallAppButton.jsx'

import LogoutIcon from '@mui/icons-material/Logout'
import PersonIcon from '@mui/icons-material/Person'
import PaletteIcon from '@mui/icons-material/Palette'
import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone'
import MenuIcon from '@mui/icons-material/Menu'

export default function Topbar({ onSidebarToggle }) {
  const theme = useTheme()
  const navigate = useNavigate()
  const { user, logout, isAdmin } = useAuth()
  const { primaryColor, setPrimaryColor } = useThemeContext()

  const [anchorEl, setAnchorEl] = useState(null)

  const handleLogout = async () => {
    setAnchorEl(null)
    await logout()
    navigate('/login', { replace: true })
  }

  const initials = user
    ? (user.name || user.full_name || user.email || 'U')
        .split(' ')
        .map((n) => n[0])
        .slice(0, 2)
        .join('')
        .toUpperCase()
    : 'U'

  return (
    <AppBar
      position="fixed"
      elevation={0}
      sx={{
        zIndex: theme.zIndex.drawer + 1,
        background: 'rgba(255,255,255,0.88)',
        backdropFilter: 'blur(16px)',
        borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
        color: 'text.primary',
      }}
    >
      <Toolbar sx={{ gap: 2 }}>
        {/* Sidebar toggle */}
        <IconButton
          onClick={onSidebarToggle}
          sx={{ color: 'text.secondary' }}
        >
          <MenuIcon />
        </IconButton>

        {/* Spacer */}
        <Box flex={1} />

        {/* Theme swatches */}
        <Tooltip title="Change theme color">
          <Box display="flex" alignItems="center" gap={0.75}>
            <PaletteIcon sx={{ color: 'text.secondary', fontSize: 18 }} />
            {PALETTE_SWATCHES.map((s) => (
              <Box
                key={s.hex}
                onClick={() => setPrimaryColor(s.hex)}
                sx={{
                  width: 20, height: 20,
                  borderRadius: '50%',
                  background: s.hex,
                  cursor: 'pointer',
                  border: primaryColor === s.hex
                    ? `2px solid ${theme.palette.text.primary}`
                    : '2px solid transparent',
                  transition: 'transform 0.15s',
                  '&:hover': { transform: 'scale(1.25)' },
                }}
              />
            ))}
          </Box>
        </Tooltip>

        <Divider orientation="vertical" flexItem sx={{ mx: 0.5 }} />

        {/* Notification bell */}
        <InstallAppButton variant="icon" />

        <IconButton size="small" sx={{ color: 'text.secondary' }}>
          <NotificationsNoneIcon />
        </IconButton>

        {/* Avatar */}
        <Tooltip title={user?.name || user?.full_name || user?.email || 'Account'}>
          <IconButton onClick={(e) => setAnchorEl(e.currentTarget)} sx={{ p: 0.5 }}>
            <Avatar
              sx={{
                width: 36, height: 36,
                background: `linear-gradient(135deg, ${primaryColor} 0%, ${alpha(primaryColor, 0.7)} 100%)`,
                fontSize: '0.875rem',
                fontWeight: 700,
              }}
            >
              {initials}
            </Avatar>
          </IconButton>
        </Tooltip>

        <Menu
          anchorEl={anchorEl}
          open={Boolean(anchorEl)}
          onClose={() => setAnchorEl(null)}
          transformOrigin={{ horizontal: 'right', vertical: 'top' }}
          anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
          PaperProps={{ sx: { mt: 1, minWidth: 200 } }}
        >
          <Box px={2} py={1}>
            <Typography variant="body2" fontWeight={600}>
              {user?.name || user?.full_name || user?.email}
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {isAdmin ? 'Administrator' : 'Ground Owner'}
            </Typography>
          </Box>
          <Divider />
          <MenuItem onClick={() => { setAnchorEl(null); navigate(isAdmin ? '/admin/profile' : '/owner/profile') }}>
            <ListItemIcon><PersonIcon fontSize="small" /></ListItemIcon>
            Profile
          </MenuItem>
          <Divider />
          <MenuItem onClick={handleLogout} sx={{ color: 'error.main' }}>
            <ListItemIcon><LogoutIcon fontSize="small" color="error" /></ListItemIcon>
            Logout
          </MenuItem>
        </Menu>
      </Toolbar>
    </AppBar>
  )
}
