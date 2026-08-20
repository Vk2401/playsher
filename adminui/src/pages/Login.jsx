import React, { useState } from 'react'
import {
  Box, Paper, Typography, Tabs, Tab, TextField, Button,
  InputAdornment, IconButton, CircularProgress, Alert, alpha,
} from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext.jsx'

import EmailIcon from '@mui/icons-material/Email'
import LockIcon from '@mui/icons-material/Lock'
import VisibilityIcon from '@mui/icons-material/Visibility'
import VisibilityOffIcon from '@mui/icons-material/VisibilityOff'
import SportsSoccerIcon from '@mui/icons-material/SportsSoccer'
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings'
import BusinessIcon from '@mui/icons-material/Business'

export default function Login() {
  const theme = useTheme()
  const navigate = useNavigate()
  const { loginAdmin, loginOwner, isAuthenticated, isAdmin } = useAuth()

  const [tab, setTab] = useState(0)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPass, setShowPass] = useState(false)
  const [loading, setLoading] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  // Redirect if already logged in
  React.useEffect(() => {
    if (isAuthenticated) {
      navigate(isAdmin ? '/admin/dashboard' : '/owner/dashboard', { replace: true })
    }
  }, [isAuthenticated, isAdmin, navigate])

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!email.trim() || !password) return
    setErrorMsg('')
    setLoading(true)
    try {
      if (tab === 0) {
        await loginAdmin(email.trim(), password)
        navigate('/admin/dashboard', { replace: true })
      } else {
        await loginOwner(email.trim(), password)
        navigate('/owner/dashboard', { replace: true })
      }
    } catch (err) {
      const msg = err?.response?.data?.message || err?.message || 'Login failed. Please try again.'
      setErrorMsg(msg)
    } finally {
      setLoading(false)
    }
  }

  const primary = theme.palette.primary.main

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: `linear-gradient(135deg, ${alpha(primary, 0.08)} 0%, ${alpha(primary, 0.03)} 100%)`,
        p: 2,
      }}
    >
      {/* Background decoration */}
      <Box sx={{
        position: 'fixed', top: -100, right: -100, width: 400, height: 400,
        borderRadius: '50%', background: alpha(primary, 0.06), pointerEvents: 'none',
      }} />
      <Box sx={{
        position: 'fixed', bottom: -80, left: -80, width: 300, height: 300,
        borderRadius: '50%', background: alpha(primary, 0.04), pointerEvents: 'none',
      }} />

      <Paper
        sx={{
          width: '100%', maxWidth: 440,
          p: 4, borderRadius: 4,
          boxShadow: '0 20px 60px rgba(0,0,0,0.12)',
          background: 'rgba(255,255,255,0.95)',
          backdropFilter: 'blur(20px)',
          position: 'relative', zIndex: 1,
        }}
      >
        {/* Logo */}
        <Box display="flex" flexDirection="column" alignItems="center" mb={3}>
          <Box sx={{
            width: 64, height: 64, borderRadius: 3, mb: 2,
            background: `linear-gradient(135deg, ${primary} 0%, ${alpha(primary, 0.6)} 100%)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 8px 24px ${alpha(primary, 0.35)}`,
          }}>
            <SportsSoccerIcon sx={{ color: '#fff', fontSize: 32 }} />
          </Box>
          <Typography variant="h5" fontWeight={800} color="primary">Playsher</Typography>
          <Typography variant="body2" color="text.secondary">Admin Panel</Typography>
        </Box>

        {/* Tabs */}
        <Tabs
          value={tab}
          onChange={(_, v) => { setTab(v); setErrorMsg('') }}
          variant="fullWidth"
          sx={{
            mb: 3,
            '& .MuiTabs-indicator': { height: 3, borderRadius: 2 },
            '& .MuiTab-root': { fontWeight: 600, fontSize: '0.875rem' },
          }}
        >
          <Tab
            icon={<AdminPanelSettingsIcon sx={{ fontSize: 18 }} />}
            iconPosition="start"
            label="Admin"
          />
          <Tab
            icon={<BusinessIcon sx={{ fontSize: 18 }} />}
            iconPosition="start"
            label="Ground Owner"
          />
        </Tabs>

        {/* Tab content */}
        <Box
          sx={{
            opacity: 1,
            transform: 'translateY(0)',
            transition: 'opacity 0.2s, transform 0.2s',
          }}
        >
          <Typography variant="body2" color="text.secondary" mb={2.5} textAlign="center">
            {tab === 0
              ? 'Sign in to manage the Playsher platform'
              : 'Sign in to manage your sports grounds'}
          </Typography>

          {errorMsg && (
            <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }} onClose={() => setErrorMsg('')}>
              {errorMsg}
            </Alert>
          )}

          <Box component="form" onSubmit={handleSubmit} display="flex" flexDirection="column" gap={2}>
            <TextField
              label="Email address"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              fullWidth
              size="medium"
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <EmailIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                  </InputAdornment>
                ),
              }}
            />
            <TextField
              label="Password"
              type={showPass ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              fullWidth
              size="medium"
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <LockIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                  </InputAdornment>
                ),
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton onClick={() => setShowPass((v) => !v)} edge="end" size="small">
                      {showPass ? <VisibilityOffIcon /> : <VisibilityIcon />}
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />
            <Button
              type="submit"
              variant="contained"
              size="large"
              fullWidth
              disabled={loading || !email || !password}
              sx={{ mt: 1, py: 1.5, fontSize: '1rem' }}
              startIcon={loading ? <CircularProgress size={20} color="inherit" /> : null}
            >
              {loading ? 'Signing in...' : 'Sign in'}
            </Button>
          </Box>
        </Box>
      </Paper>
    </Box>
  )
}
