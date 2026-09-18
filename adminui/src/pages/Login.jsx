import React, { useState } from 'react'
import {
  Box, Typography, TextField, Button, ButtonBase,
  InputAdornment, IconButton, CircularProgress, Alert, Link, Stack, alpha,
} from '@mui/material'
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
import ArrowForwardIcon from '@mui/icons-material/ArrowForward'

/**
 * The brand blue, taken from the customer app (`mobile_app/lib/core/app_colors.dart`)
 * rather than from the theme. The palette picker is a signed-in preference — one
 * admin's choice of Sage or Plum should not repaint the front door, which is the
 * one screen every role sees and the only place the product introduces itself.
 */
const BRAND = {
  blue: '#0061C2',
  lift: '#2E7FE0',
  ink: '#0B2A5B',
  sky: '#5AA9FF',
}

const TABS = [
  { key: 'admin', label: 'Admin', blurb: 'Sign in to manage the Playsher platform' },
  { key: 'owner', label: 'Ground Owner', blurb: 'Sign in to manage your sports grounds' },
  { key: 'coach', label: 'Coach', blurb: 'Sign in to manage your sessions and availability' },
]

const EMPTY_SIGNUP = { name: '', email: '', mobile: '', sport_name: '', experience_years: '', password: '' }

/** Shared field styling — a roomy well that fills on focus rather than glowing. */
const fieldSx = {
  '& .MuiOutlinedInput-root': {
    borderRadius: 2.5,
    backgroundColor: '#F7F9FC',
    fontSize: '1rem',
    transition: 'background-color .15s, box-shadow .15s',
    '& fieldset': { borderColor: '#E1E7F0' },
    '&:hover fieldset': { borderColor: '#C6D3E4' },
    '&.Mui-focused': {
      backgroundColor: '#fff',
      '& fieldset': { borderColor: BRAND.blue, borderWidth: 2 },
    },
  },
  // A password field is typed into under time pressure on a phone at a ground;
  // the extra height is the difference between hitting it and hitting the label.
  // Explicit px, not the spacing scale — a bare 20 here means theme.spacing(20).
  '& .MuiOutlinedInput-input': { paddingTop: '19px', paddingBottom: '19px' },
  '& .MuiInputLabel-root': { fontSize: '0.95rem' },
  '& .MuiInputLabel-root.Mui-focused': { color: BRAND.blue },
}

export default function Login() {
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

  const handleTabChange = (v) => {
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
      setSuccessMsg('Registration submitted. An admin will review your account, and you can sign in once it is approved.')
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

  return (
    <Box
      sx={{
        minHeight: '100vh', display: 'flex',
        flexDirection: { xs: 'column', md: 'row' },
        bgcolor: '#fff',
      }}
    >

      {/* ── Phone: the brand block becomes a banner ────────────────────────
          The same colour and the same marks as the desktop half, laid across
          the top instead of down the side, with the form sheet lifted over its
          bottom edge. A phone gets the brand too — it just gets less of it. */}
      <Box
        sx={{
          display: { xs: 'flex', md: 'none' },
          flexDirection: 'column', justifyContent: 'flex-end',
          bgcolor: BRAND.blue, position: 'relative', overflow: 'hidden',
          px: 3, pt: 5, pb: 5.5,
        }}
      >
        <Box
          component="svg"
          viewBox="0 0 400 260"
          aria-hidden="true"
          sx={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.18 }}
        >
          <circle cx="352" cy="24" r="120" fill="none" stroke="#fff" strokeWidth="1.5" />
          <circle cx="352" cy="24" r="76" fill="none" stroke="#fff" strokeWidth="1.5" />
          <circle cx="352" cy="24" r="34" fill="none" stroke="#fff" strokeWidth="1.5" />
        </Box>

        <Box sx={{ position: 'relative' }}>
          <Stack direction="row" spacing={1.25} alignItems="center" sx={{ mb: 2.5 }}>
            <Box
              sx={{
                width: 36, height: 36, borderRadius: 1.75, bgcolor: '#fff',
                display: 'grid', placeItems: 'center', flexShrink: 0,
              }}
            >
              <SportsSoccerIcon sx={{ color: BRAND.blue, fontSize: 21 }} />
            </Box>
            <Box>
              <Typography sx={{ fontWeight: 800, fontSize: '1.05rem', color: '#fff', lineHeight: 1.1 }}>
                Playsher
              </Typography>
              <Typography sx={{ fontSize: '0.72rem', color: alpha('#fff', 0.7) }}>Partner Panel</Typography>
            </Box>
          </Stack>

          <Typography
            sx={{ color: '#fff', fontWeight: 800, fontSize: '1.9rem', letterSpacing: '-0.02em', lineHeight: 1.1 }}
          >
            Welcome back
          </Typography>
          <Typography sx={{ color: alpha('#fff', 0.78), fontSize: '0.9rem', mt: 0.75 }}>
            Grounds, bookings and payouts, all in one panel.
          </Typography>
        </Box>
      </Box>

      {/* ── Left: the brand block ──────────────────────────────────────────
          Desktop only — below md the banner above stands in for it. */}
      <Box
        sx={{
          display: { xs: 'none', md: 'flex' },
          flex: '0 0 52%',
          bgcolor: BRAND.blue,
          position: 'relative',
          overflow: 'hidden',
          flexDirection: 'column',
          justifyContent: 'center',
          px: { md: 6, lg: 9 },
          py: 8,
        }}
      >
        {/* Flat field markings, not a gradient wash — the block stays one colour. */}
        <Box
          component="svg"
          viewBox="0 0 600 600"
          aria-hidden="true"
          sx={{
            position: 'absolute', inset: 0, width: '100%', height: '100%',
            opacity: 0.16, pointerEvents: 'none',
          }}
        >
          <circle cx="520" cy="70" r="190" fill="none" stroke="#fff" strokeWidth="1.5" />
          <circle cx="520" cy="70" r="120" fill="none" stroke="#fff" strokeWidth="1.5" />
          <circle cx="520" cy="70" r="52" fill="none" stroke="#fff" strokeWidth="1.5" />
        </Box>

        <Box sx={{ position: 'relative', maxWidth: 520 }}>
          <Typography
            sx={{
              color: '#fff', fontWeight: 800, letterSpacing: '-0.02em',
              fontSize: { md: '2.6rem', lg: '3.2rem' }, lineHeight: 1.05, mb: 2,
            }}
          >
            Welcome back
          </Typography>
          <Typography sx={{ color: alpha('#fff', 0.82), fontSize: '1.05rem', lineHeight: 1.6, mb: 5, maxWidth: 420 }}>
            Manage your grounds, bookings and payouts. The whole Playsher
            operation from one panel.
          </Typography>

          <PitchScene />

          <Stack direction="row" spacing={4} sx={{ mt: 5 }}>
            {[['Grounds', 'live availability'], ['Bookings', 'slot by slot'], ['Payouts', 'what you are owed']].map(
              ([head, sub]) => (
                <Box key={head}>
                  <Typography sx={{ color: '#fff', fontWeight: 700, fontSize: '0.95rem' }}>{head}</Typography>
                  <Typography sx={{ color: alpha('#fff', 0.62), fontSize: '0.8rem' }}>{sub}</Typography>
                </Box>
              ),
            )}
          </Stack>
        </Box>
      </Box>

      {/* ── Right: the form ────────────────────────────────────────────── */}
      <Box
        sx={{
          flex: 1, display: 'flex', flexDirection: 'column',
          alignItems: 'center',
          // Centred in the right half on desktop; on a phone the banner already
          // fills the top, so centring what is left strands the form mid-screen.
          justifyContent: { xs: 'flex-start', md: 'center' },
          px: { xs: 3, sm: 6 }, pt: { xs: 4, md: 6 }, pb: { xs: 5, md: 6 },
          overflowY: 'auto',
          // On a phone the form is a sheet pulled up over the banner's bottom
          // edge; on desktop it is simply the right half and none of this applies.
          bgcolor: '#fff',
          borderTopLeftRadius: { xs: 28, md: 0 },
          borderTopRightRadius: { xs: 28, md: 0 },
          mt: { xs: -3.5, md: 0 },
          position: 'relative',
          zIndex: 1,
        }}
      >
        <Box sx={{ width: '100%', maxWidth: 440 }}>

          {/* Logo lockup — desktop only; the phone banner already carries it. */}
          <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 4, display: { xs: 'none', md: 'flex' } }}>
            <Box
              sx={{
                width: 42, height: 42, borderRadius: 2, bgcolor: BRAND.blue,
                display: 'grid', placeItems: 'center', flexShrink: 0,
              }}
            >
              <SportsSoccerIcon sx={{ color: '#fff', fontSize: 24 }} />
            </Box>
            <Box>
              <Typography sx={{ fontWeight: 800, fontSize: '1.2rem', color: BRAND.ink, lineHeight: 1.1 }}>
                Playsher
              </Typography>
              <Typography sx={{ fontSize: '0.78rem', color: 'text.secondary' }}>Partner Panel</Typography>
            </Box>
          </Stack>

          <Typography sx={{ fontWeight: 800, fontSize: '1.55rem', color: BRAND.ink, mb: 0.5 }}>
            {signupMode ? 'Create your coach account' : 'Log in'}
          </Typography>
          <Typography sx={{ color: 'text.secondary', fontSize: '0.9rem', mb: 3 }}>
            {signupMode ? 'An admin reviews it before you can sign in' : active.blurb}
          </Typography>

          {/* Role picker — a segmented control rather than tabs, so the three
              roles read as a choice of door, not as pages of one form. */}
          <Box
            sx={{
              display: 'flex', gap: 0.5, p: 0.5, mb: 3,
              bgcolor: '#F1F5FA', borderRadius: 2.5,
            }}
          >
            {TABS.map(({ key, label }, i) => {
              const selected = tab === i
              return (
                <ButtonBase
                  key={key}
                  onClick={() => handleTabChange(i)}
                  sx={{
                    // No icons: three short words in a row read faster than three
                    // words each dragging a glyph, and "Ground Owner" stops wrapping.
                    flex: 1, py: 1.35, px: 1, borderRadius: 2,
                    fontSize: '0.875rem', fontWeight: selected ? 700 : 500,
                    letterSpacing: '-0.005em', whiteSpace: 'nowrap',
                    color: selected ? BRAND.blue : '#64748B',
                    bgcolor: selected ? '#fff' : 'transparent',
                    boxShadow: selected ? '0 1px 2px rgba(11,42,91,0.10)' : 'none',
                    transition: 'background-color .15s, color .15s',
                    '&:hover': { bgcolor: selected ? '#fff' : alpha('#fff', 0.7) },
                  }}
                >
                  {label}
                </ButtonBase>
              )
            })}
          </Box>

          {errorMsg && (
            <Alert severity="error" sx={{ mb: 2, borderRadius: 2.5 }} onClose={() => setErrorMsg('')}>
              {errorMsg}
            </Alert>
          )}
          {successMsg && (
            <Alert severity="success" sx={{ mb: 2, borderRadius: 2.5 }} onClose={() => setSuccessMsg('')}>
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
                required fullWidth sx={fieldSx}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <PersonIcon sx={{ color: '#94A3B8', fontSize: 20 }} />
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
                required fullWidth sx={fieldSx}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <EmailIcon sx={{ color: '#94A3B8', fontSize: 20 }} />
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
                required fullWidth sx={fieldSx}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <PhoneIcon sx={{ color: '#94A3B8', fontSize: 20 }} />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="Sport you coach"
                value={signup.sport_name}
                onChange={onSignupChange('sport_name')}
                fullWidth sx={fieldSx}
                placeholder="Cricket, Football, Badminton…"
              />
              <TextField
                label="Years of experience"
                type="number"
                value={signup.experience_years}
                onChange={onSignupChange('experience_years')}
                error={Boolean(signupErrors.experience_years)}
                helperText={signupErrors.experience_years}
                fullWidth sx={fieldSx}
                inputProps={{ min: 0 }}
              />
              <TextField
                label="Password"
                type={showPass ? 'text' : 'password'}
                value={signup.password}
                onChange={onSignupChange('password')}
                error={Boolean(signupErrors.password)}
                helperText={signupErrors.password}
                required fullWidth sx={fieldSx}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <LockIcon sx={{ color: '#94A3B8', fontSize: 20 }} />
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
              <SubmitButton loading={loading} label="Create coach account" busyLabel="Submitting…" />
              <Typography variant="body2" textAlign="center" color="text.secondary">
                Already registered?{' '}
                <Link
                  component="button" type="button" underline="hover"
                  sx={{ color: BRAND.blue, fontWeight: 600 }}
                  onClick={() => { setSignupMode(false); resetMessages() }}
                >
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
                required fullWidth sx={fieldSx}
                placeholder="name@example.com"
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <EmailIcon sx={{ color: '#94A3B8', fontSize: 20 }} />
                    </InputAdornment>
                  ),
                }}
              />
              <TextField
                label="Password"
                type={showPass ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required fullWidth sx={fieldSx}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <LockIcon sx={{ color: '#94A3B8', fontSize: 20 }} />
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
              <SubmitButton
                loading={loading}
                disabled={!email || !password}
                label="Log in"
                busyLabel="Signing in…"
              />

              {/* The sign-up line exists only for coaches, but the slot is always
                  here. Rendering it conditionally moved every field up the page
                  when you switched tabs — the column is vertically centred, so a
                  single extra line shifts the whole form under the cursor. */}
              <Box sx={{ minHeight: 24, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {active.key === 'coach' && (
                  <Typography variant="body2" color="text.secondary">
                    New coach?{' '}
                    <Link
                      component="button" type="button" underline="hover"
                      sx={{ color: BRAND.blue, fontWeight: 600 }}
                      onClick={() => { setSignupMode(true); resetMessages() }}
                    >
                      Create an account
                    </Link>
                  </Typography>
                )}
              </Box>
            </Box>
          )}

          {/* The login screen is where most people first arrive, and browsers
              no longer surface installation on their own — so offer it here.
              Renders nothing when already installed or not installable. */}
          <Box sx={{ display: 'flex', justifyContent: 'center', mt: 3 }}>
            <InstallAppButton />
          </Box>
        </Box>
      </Box>
    </Box>
  )
}

/** The one filled button on the page. Solid, not the theme's gradient. */
function SubmitButton({ loading, disabled, label, busyLabel }) {
  return (
    <Button
      type="submit"
      variant="contained"
      size="large"
      fullWidth
      disabled={loading || disabled}
      endIcon={loading ? null : <ArrowForwardIcon />}
      startIcon={loading ? <CircularProgress size={18} color="inherit" /> : null}
      sx={{
        mt: 1.5, py: 1.9, borderRadius: 2.5,
        fontSize: '1rem', fontWeight: 700, textTransform: 'none',
        background: BRAND.blue,
        boxShadow: 'none',
        '&:hover': { background: BRAND.ink, boxShadow: 'none' },
        '&.Mui-disabled': { background: '#CBD5E1', color: '#fff' },
      }}
    >
      {loading ? busyLabel : label}
    </Button>
  )
}

/**
 * Flat scene: a booking sheet over a pitch. Drawn inline rather than shipped as
 * an asset — it is two dozen rectangles, and a file would mean a second thing to
 * keep in sync with the brand colour.
 */
function PitchScene() {
  const slots = [0, 1, 2, 3, 4, 5, 6, 7]
  return (
    <Box
      component="svg"
      viewBox="0 0 420 210"
      aria-hidden="true"
      sx={{ width: '100%', maxWidth: 420, height: 'auto', display: 'block' }}
    >
      {/* pitch */}
      <rect x="18" y="26" width="290" height="160" rx="8" fill={BRAND.lift} />
      <line x1="163" y1="26" x2="163" y2="186" stroke={alpha('#fff', 0.45)} strokeWidth="2" />
      <circle cx="163" cy="106" r="32" fill="none" stroke={alpha('#fff', 0.45)} strokeWidth="2" />
      <rect x="18" y="66" width="34" height="80" fill="none" stroke={alpha('#fff', 0.45)} strokeWidth="2" />
      <rect x="274" y="66" width="34" height="80" fill="none" stroke={alpha('#fff', 0.45)} strokeWidth="2" />

      {/* booking sheet */}
      <rect x="196" y="6" width="206" height="198" rx="12" fill="#fff" />
      <rect x="216" y="28" width="92" height="10" rx="5" fill={BRAND.ink} />
      <rect x="216" y="46" width="60" height="8" rx="4" fill="#CBD5E1" />
      {slots.map((i) => {
        const col = i % 4
        const row = Math.floor(i / 4)
        const taken = [1, 2, 6].includes(i)
        return (
          <rect
            key={i}
            x={216 + col * 46}
            y={72 + row * 34}
            width="38"
            height="26"
            rx="6"
            fill={taken ? BRAND.blue : '#E8EFF8'}
          />
        )
      })}
      <rect x="216" y="150" width="166" height="32" rx="8" fill={BRAND.sky} />
      <rect x="272" y="162" width="54" height="8" rx="4" fill="#fff" />
    </Box>
  )
}
