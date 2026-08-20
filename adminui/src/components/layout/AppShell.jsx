import React, { useState } from 'react'
import { Box, Toolbar, useMediaQuery } from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar.jsx'
import Topbar from './Topbar.jsx'
import OfflineBanner from '../ui/OfflineBanner.jsx'

export default function AppShell() {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))

  // Desktop: sidebar collapsed/expanded; Mobile: drawer open/closed
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [mobileOpen, setMobileOpen] = useState(false)

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh', background: '#F4F7F5' }}>
      <Topbar
        onSidebarToggle={
          isMobile
            ? () => setMobileOpen((v) => !v)
            : () => setSidebarOpen((v) => !v)
        }
        isMobile={isMobile}
      />

      <Sidebar
        open={sidebarOpen}
        onToggle={() => setSidebarOpen((v) => !v)}
        mobileOpen={mobileOpen}
        onMobileClose={() => setMobileOpen(false)}
        isMobile={isMobile}
      />

      {/* Main content — permanent drawer adds its own offset via flex placeholder */}
      <Box
        component="main"
        sx={{
          flexGrow: 1,
          minWidth: 0,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <Toolbar />
        <OfflineBanner />
        <Box sx={{ p: { xs: 2, sm: 3 }, flex: 1 }}>
          <Outlet />
        </Box>
      </Box>
    </Box>
  )
}
