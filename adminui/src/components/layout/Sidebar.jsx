import React from 'react'
import {
  Drawer, Box, List, ListItemButton, ListItemIcon, ListItemText,
  Typography, IconButton, alpha, Tooltip,
} from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../../contexts/AuthContext.jsx'

// Icons
import DashboardIcon from '@mui/icons-material/Dashboard'
import PeopleIcon from '@mui/icons-material/People'
import BusinessIcon from '@mui/icons-material/Business'
import SportsSoccerIcon from '@mui/icons-material/SportsSoccer'
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter'
import BookOnlineIcon from '@mui/icons-material/BookOnline'
import PaymentIcon from '@mui/icons-material/Payment'
import SportsIcon from '@mui/icons-material/Sports'
import DirectionsRunIcon from '@mui/icons-material/DirectionsRun'
import StarIcon from '@mui/icons-material/Star'
import LocationOnIcon from '@mui/icons-material/LocationOn'
import AccountBalanceIcon from '@mui/icons-material/AccountBalance'
import AccountBalanceWalletIcon from '@mui/icons-material/AccountBalanceWallet'
import PersonIcon from '@mui/icons-material/Person'
import SystemUpdateIcon from '@mui/icons-material/SystemUpdate'
import StorageIcon from '@mui/icons-material/Storage'
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft'
import ChevronRightIcon from '@mui/icons-material/ChevronRight'

const DRAWER_WIDTH = 260
const COLLAPSED_WIDTH = 68

const ADMIN_NAV = [
  { label: 'Dashboard',      icon: DashboardIcon,     path: '/admin/dashboard' },
  { label: 'Users',          icon: PeopleIcon,         path: '/admin/users' },
  { label: 'Ground Owners',  icon: BusinessIcon,       path: '/admin/ground-owners' },
  { label: 'Grounds',        icon: LocationOnIcon,     path: '/admin/grounds' },
  { label: 'Sports',         icon: SportsSoccerIcon,   path: '/admin/sports' },
  { label: 'Amenities',      icon: FitnessCenterIcon,  path: '/admin/amenities' },
  { label: 'Bookings',       icon: BookOnlineIcon,     path: '/admin/bookings' },
  { label: 'Payments',       icon: PaymentIcon,              path: '/admin/payments' },
  { label: 'Settlements',   icon: AccountBalanceWalletIcon, path: '/admin/settlements' },
  { label: 'Games',          icon: SportsIcon,               path: '/admin/games' },
  { label: 'Coaches',        icon: DirectionsRunIcon,  path: '/admin/coaches' },
  { label: 'Reviews',        icon: StarIcon,           path: '/admin/reviews' },
  { label: 'App Versions',   icon: SystemUpdateIcon,   path: '/admin/app-versions' },
  { label: 'Database Schema', icon: StorageIcon,      path: '/admin/database-schema' },
  { label: 'Profile',        icon: PersonIcon,         path: '/admin/profile' },
]

const OWNER_NAV = [
  { label: 'Dashboard',  icon: DashboardIcon,   path: '/owner/dashboard' },
  { label: 'My Grounds', icon: LocationOnIcon,  path: '/owner/grounds' },
  { label: 'Bookings',   icon: BookOnlineIcon,  path: '/owner/bookings' },
  { label: 'Games',        icon: SportsIcon,        path: '/owner/games' },
  { label: 'Bank Details', icon: AccountBalanceIcon, path: '/owner/bank-details' },
  { label: 'Profile',      icon: PersonIcon,         path: '/owner/profile' },
]

function SidebarContent({ open, onToggle, onItemClick }) {
  const theme = useTheme()
  const location = useLocation()
  const navigate = useNavigate()
  const { isAdmin } = useAuth()
  const nav = isAdmin ? ADMIN_NAV : OWNER_NAV

  const isActive = (path) =>
    location.pathname === path || location.pathname.startsWith(path + '/')

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Logo / Brand */}
      <Box
        sx={{
          height: 64, display: 'flex', alignItems: 'center',
          px: open ? 2.5 : 1.5, gap: 1.5, overflow: 'hidden',
          borderBottom: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
          flexShrink: 0,
        }}
      >
        <Box
          sx={{
            width: 36, height: 36, borderRadius: 2, flexShrink: 0,
            background: `linear-gradient(135deg, ${theme.palette.primary.main} 0%, ${alpha(theme.palette.primary.main, 0.7)} 100%)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}
        >
          <SportsSoccerIcon sx={{ color: '#fff', fontSize: 20 }} />
        </Box>
        {open && (
          <Box overflow="hidden">
            <Typography variant="subtitle1" fontWeight={700} noWrap color="primary">
              Playsher
            </Typography>
            <Typography variant="caption" color="text.secondary" noWrap>
              {isAdmin ? 'Admin Panel' : 'Owner Panel'}
            </Typography>
          </Box>
        )}
      </Box>

      {/* Nav Items */}
      <Box flex={1} overflow="auto" py={1}>
        <List dense disablePadding>
          {nav.map((item) => {
            const active = isActive(item.path)
            const Icon = item.icon
            return (
              <Tooltip key={item.path} title={open ? '' : item.label} placement="right">
                <ListItemButton
                  onClick={() => { navigate(item.path); onItemClick?.() }}
                  selected={active}
                  sx={{
                    mx: 1, mb: 0.5, borderRadius: 2,
                    px: open ? 1.5 : 1,
                    minHeight: 44,
                    '&.Mui-selected': {
                      background: alpha(theme.palette.primary.main, 0.12),
                      '&:hover': { background: alpha(theme.palette.primary.main, 0.18) },
                    },
                  }}
                >
                  <ListItemIcon sx={{ minWidth: 36 }}>
                    <Icon
                      sx={{
                        fontSize: 21,
                        color: active ? theme.palette.primary.main : 'text.secondary',
                      }}
                    />
                  </ListItemIcon>
                  {open && (
                    <ListItemText
                      primary={item.label}
                      primaryTypographyProps={{
                        fontSize: '0.875rem',
                        fontWeight: active ? 600 : 400,
                        color: active ? 'primary.main' : 'text.primary',
                        noWrap: true,
                      }}
                    />
                  )}
                </ListItemButton>
              </Tooltip>
            )
          })}
        </List>
      </Box>

      {/* Collapse toggle — desktop only */}
      {onToggle && (
        <Box
          sx={{
            p: 1.5,
            borderTop: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
            display: 'flex',
            justifyContent: open ? 'flex-end' : 'center',
            flexShrink: 0,
          }}
        >
          <IconButton onClick={onToggle} size="small" sx={{ color: 'text.secondary' }}>
            {open ? <ChevronLeftIcon /> : <ChevronRightIcon />}
          </IconButton>
        </Box>
      )}
    </Box>
  )
}

export default function Sidebar({ open, onToggle, mobileOpen, onMobileClose, isMobile }) {
  const theme = useTheme()

  const paperSx = {
    background: 'rgba(255,255,255,0.7)',
    backdropFilter: 'blur(16px)',
    borderRight: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
    boxShadow: '4px 0 20px rgba(0,0,0,0.04)',
    overflow: 'hidden',
  }

  // Mobile: temporary drawer (no flex placeholder)
  if (isMobile) {
    return (
      <Drawer
        variant="temporary"
        open={mobileOpen}
        onClose={onMobileClose}
        ModalProps={{ keepMounted: true }}
        sx={{
          '& .MuiDrawer-paper': {
            width: DRAWER_WIDTH,
            ...paperSx,
          },
        }}
      >
        <SidebarContent open={true} onItemClick={onMobileClose} />
      </Drawer>
    )
  }

  // Desktop: permanent drawer, width collapses
  const drawerWidth = open ? DRAWER_WIDTH : COLLAPSED_WIDTH
  return (
    <Drawer
      variant="permanent"
      sx={{
        width: drawerWidth,
        flexShrink: 0,
        transition: theme.transitions.create('width', {
          easing: theme.transitions.easing.sharp,
          duration: theme.transitions.duration.enteringScreen,
        }),
        '& .MuiDrawer-paper': {
          width: drawerWidth,
          transition: theme.transitions.create('width', {
            easing: theme.transitions.easing.sharp,
            duration: theme.transitions.duration.enteringScreen,
          }),
          ...paperSx,
        },
      }}
    >
      <SidebarContent open={open} onToggle={onToggle} />
    </Drawer>
  )
}
