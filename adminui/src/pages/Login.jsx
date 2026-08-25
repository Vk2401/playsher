import React, { useState } from 'react'
import {
  Box, Paper, Typography, Tabs, Tab, TextField, Button,
  InputAdornment, IconButton, CircularProgress, Alert, Link, alpha,
} from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext.jsx'
import InstallAppButton from '../components/ui/InstallAppButton.jsx'

import EmailIcon from '@mui/icons-material/Email'
import LockIcon from '@mui/icons-material/Lock'
import PersonIcon from '@mui/icons-material/Person'
import PhoneIcon from '@mui/icons-material/Phone'
import VisibilityIcon from '@mui/icons-material/Visibility'
import VisibilityOffIcon from '@mui/icons-material/VisibilityOff'
import SportsSoccerIcon from '@mui/icons-material/SportsSoccer'
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings'
import BusinessIcon from '@mui/icons-material/Business'
import SportsIcon from '@mui/icons-material/Sports'

const TABS = [
  { key: 'admin', label: 'Admin', icon: AdminPanelSettingsIcon, blurb: 'Sign in to manage the Playsher platform' },
  { key: 'owner', label: 'Ground Owner', icon: BusinessIcon, blurb: 'Sign in to manage your sports grounds' },
  { key: 'coach', label: 'Coach', icon: SportsIcon, blurb: 'Sign in to manage your sessions and availability' },
]

const EMPTY_SIGNUP = { name: '', email: '', mobile: '', sport_name: '', experience_years: '', password: '' }

export default function Login() {
  const theme = useTheme()
  const navigate = useNavigate()
  const { loginAdmin, loginOwner, loginCoach, registerCoach, isAuthenticated, homePath } = useAuth()

  const [tab, setTab] = useState(0)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPass, setShowPass] = useState(false)
  const [loading, setLoading] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  // Coaches are the only role that can create their own account here, so the
  // sign-up form lives inside the coach tab rather than on a route of its own.
  const [signupMode, setSignupMode] = useState(false)
  const [signup, setSignup] = useState(EMPTY_SIGNUP)
  const [signupErrors, setSignupErrors] = useState({})
  const [successMsg, setSuccessMsg] = useState('')

  // Redirect if already logged in
  React.useEffect(() => {
    if (isAuthenticated) navigate(homePath, { replace: true })
  }, [isAuthenticated, homePath, navigate])

  const active = TABS[tab]

  const resetMessages = () => { setErrorMsg(''); setSuccessMsg('') }

  const handleTabChange = (_, v) => {
    setTab(v)
    setSignupMode(false)
    resetMessages()
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!email.trim() || !password) return
    resetMessages()
    setLoading(true)
    try {
      if (active.key === 'admin') {
        await loginAdmin(email.trim(), password)
        navigate('/admin/dashboard', { replace: true })
      } else if (active.key === 'owner') {
        await loginOwner(email.trim(), password)
        navigate('/owner/dashboard', { replace: true })
      } else {
        await loginCoach(email.trim(), password)
        navigate('/coach/dashboard', { replace: true })
      }
    } catch (err) {
      setErrorMsg(err?.response?.data?.message || err?.message || 'Login failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const validateSignup = () => {
    const next = {}
    if (!signup.name.trim()) next.name = 'Your name is required.'
    if (!/^\S+@\S+\.\S+$/.test(signup.email.trim())) next.email = 'Enter a valid email address.'
    if (!/^\+?[0-9]{7,15}$/.test(signup.mobile.trim())) next.mobile = 'Enter a valid mobile number.'
    if (signup.password.length < 6) next.password = 'Use at least 6 characters.'
    if (signup.experience_years !== '' && Number(signup.experience_years) < 0) {
      next.experience_years = 'Experience cannot be negative.'
    }
    setSignupErrors(next)
    return Object.keys(next).length === 0
  }

  const handleSignup = async (e) => {
    e.preventDefault()
    resetMessages()
    if (!validateSignup()) return
    setLoading(true)
    try {
      await registerCoach({
        name: signup.name.trim(),
        email: signup.email.trim(),
        mobile: signup.mobile.trim(),
        password: signup.password,
        sport_name: signup.sport_name.trim() || undefined,
        experience_years: signup.experience_years === '' ? undefined : Number(signup.experience_years),
      })
      setSuccessMsg('Registration submitted. An admin will review your account — you can sign in once it is approved.')
      setSignup(EMPTY_SIGNUP)
      setSignupMode(false)
    } catch (err) {
      setErrorMsg(err?.response?.data?.message || err?.message || 'Registration failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const onSignupChange = (field) => (e) =>
    setSignup((prev) => ({ ...prev, [field]: e.target.value }))

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
          my: 4,
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
          <Typography variant="body2" color="text.secondary">Partner Panel</Typography>
        </Box>

        {/* Tabs */}
        <Tabs
          value={tab}
          onChange={handleTabChange}
          variant="fullWidth"
          sx={{
            mb: 3,
            '& .MuiTabs-indicator': { height: 3, borderRadius: 2 },
            '& .MuiTab-root': { fontWeight: 600, fontSize: '0.8rem', minWidth: 0, px: 1 },
          }}
        >
          {TABS.map(({ key, label, icon: Icon }) => (
            <Tab key={key} icon={<Icon sx={{ fontSize: 18 }} />} iconPosition="start" label={label} />
          ))}
        </Tabs>

        <Box>
          <Typography variant="body2" color="text.secondary" mb={2.5} textAlign="center">
            {signupMode ? 'Create your coach account — an admin reviews it before you can sign in' : active.blurb}
          </Typography>

          {errorMsg && (
            <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }} onClose={() => setErrorMsg('')}>
              {errorMsg}
            </Alert>
          )}
          {successMsg && (
            <Alert severity="success" sx={{ mb: 2, borderRadius: 2 }} onClose={() => setSuccessMsg('')}>
              {successMsg}
            </Alert>
          )}

          {signupMode ? (
            <Box component="form" onSubmit={handleSignup} display="flex" flexDirection="column" gap={2}>
              <TextField
                label="Full name"
                value={signup.name}
                onChange={onSignupChange('name')}
                error={Boolean(signupErrors.name)}
                helperText={signupErrors.name}
                required fullWidth
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <PersonIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="Email address"
                type="email"
                value={signup.email}
                onChange={onSignupChange('email')}
                error={Boolean(signupErrors.email)}
                helperText={signupErrors.email || 'This is the address you will sign in with.'}
                required fullWidth
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <EmailIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="Mobile number"
                value={signup.mobile}
                onChange={onSignupChange('mobile')}
                error={Boolean(signupErrors.mobile)}
                helperText={signupErrors.mobile}
                required fullWidth
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <PhoneIcon sx={{ color: 'text.secondary', fontSize: 20 }} />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="Sport you coach"
                value={signup.sport_name}
                onChange={onSignupChange('sport_name')}
                fullWidth
                placeholder="Cricket, Football, Badminton…"
              />
              <TextField
                label="Years of experience"
                type="number"
                value={signup.experience_years}
                onChange={onSignupChange('experience_years')}
                error={Boolean(signupErrors.experience_years)}
                helperText={signupErrors.experience_years}
                fullWidth
                inputProps={{ min: 0 }}
              />
              <TextField
                label="Password"
                type={showPass ? 'text' : 'password'}
                value={signup.password}
                onChange={onSignupChange('password')}
                error={Boolean(signupErrors.password)}
                helperText={signupErrors.password}
                required fullWidth
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
                disabled={loading}
                sx={{ mt: 1, py: 1.5, fontSize: '1rem' }}
                startIcon={loading ? <CircularProgress size={20} color="inherit" /> : null}
              >
                {loading ? 'Submitting…' : 'Create coach account'}
              </Button>
              <Typography variant="body2" textAlign="center" color="text.secondary">
                Already registered?{' '}
                <Link component="button" type="button" underline="hover"
                  onClick={() => { setSignupMode(false); resetMessages() }}>
                  Sign in
                </Link>
              </Typography>
            </Box>
          ) : (
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

              {active.key === 'coach' && (
                <Typography variant="body2" textAlign="center" color="text.secondary">
                  New coach?{' '}
                  <Link component="button" type="button" underline="hover"
                    onClick={() => { setSignupMode(true); resetMessages() }}>
                    Create an account
                  </Link>
                </Typography>
              )}
            </Box>
          )}

          {/* The login screen is where most people first arrive, and browsers
              no longer surface installation on their own — so offer it here.
              Renders nothing when already installed or not installable. */}
          <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2.5 }}>
            <InstallAppButton />
          </Box>
        </Box>
      </Paper>
    </Box>
  )
}
