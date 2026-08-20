import React, { useState } from 'react'
import {
  Paper, Box, Typography, TextField, Button, Stack, Alert,
  InputAdornment, IconButton, CircularProgress,
} from '@mui/material'
import { useMutation } from '@tanstack/react-query'
import VisibilityIcon from '@mui/icons-material/Visibility'
import VisibilityOffIcon from '@mui/icons-material/VisibilityOff'
import LockResetIcon from '@mui/icons-material/LockReset'

import { authApi } from '../../api/auth.js'
import { useAuth } from '../../contexts/AuthContext.jsx'
import { useNotify } from '../../hooks/useNotify.js'

const INITIAL_FORM = { current_password: '', new_password: '', confirm_password: '' }
const MIN_LENGTH = 8

/**
 * Self-service password change, shared by the admin and owner profile pages.
 *
 * A successful change revokes every refresh token for the account — including
 * the one this browser is holding. Rather than let the session die on its next
 * refresh a quarter of an hour later, sign the user out here and say why.
 */
export default function ChangePasswordCard() {
  const { logout } = useAuth()
  const notify = useNotify()

  const [form, setForm] = useState(INITIAL_FORM)
  const [formErrors, setFormErrors] = useState({})
  const [visible, setVisible] = useState(false)

  const mutation = useMutation({
    mutationFn: () => authApi.changePassword(form.current_password, form.new_password),
    onSuccess: async () => {
      setForm(INITIAL_FORM)
      notify.success('Password changed. Please sign in again.')
      await logout()
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Could not change your password'),
  })

  const handleChange = (name, value) => {
    setForm((prev) => ({ ...prev, [name]: value }))
    // Clear the message for the field being corrected, and re-check the pair
    // when either half of the confirmation changes.
    setFormErrors((prev) => {
      if (!prev[name] && !prev.confirm_password) return prev
      const next = { ...prev, [name]: '' }
      if (name === 'new_password') next.confirm_password = ''
      return next
    })
  }

  const validate = () => {
    const errors = {}
    if (!form.current_password) errors.current_password = 'Enter your current password'
    if (!form.new_password) errors.new_password = 'Enter a new password'
    else if (form.new_password.length < MIN_LENGTH)
      errors.new_password = `Use at least ${MIN_LENGTH} characters`
    else if (form.new_password === form.current_password)
      errors.new_password = 'Choose a password different from your current one'

    if (form.new_password && form.confirm_password !== form.new_password)
      errors.confirm_password = 'Passwords do not match'

    setFormErrors(errors)
    return Object.keys(errors).length === 0
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    if (mutation.isPending) return
    if (validate()) mutation.mutate()
  }

  const toggle = (
    <InputAdornment position="end">
      <IconButton
        onClick={() => setVisible((v) => !v)}
        edge="end"
        aria-label={visible ? 'Hide passwords' : 'Show passwords'}
      >
        {visible ? <VisibilityOffIcon /> : <VisibilityIcon />}
      </IconButton>
    </InputAdornment>
  )

  return (
    <Paper sx={{ p: 3 }}>
      <Box display="flex" alignItems="center" gap={1} mb={0.5}>
        <LockResetIcon color="primary" />
        <Typography variant="h6" fontWeight={700}>Change password</Typography>
      </Box>
      <Typography variant="body2" color="text.secondary" mb={2.5}>
        You will be signed out of this and every other device once it is changed.
      </Typography>

      {/* A real form element so password managers offer to update the saved entry. */}
      <Box component="form" onSubmit={handleSubmit} noValidate>
        <Stack gap={2.5}>
          <TextField
            label="Current password"
            type={visible ? 'text' : 'password'}
            value={form.current_password}
            onChange={(e) => handleChange('current_password', e.target.value)}
            error={Boolean(formErrors.current_password)}
            helperText={formErrors.current_password}
            autoComplete="current-password"
            slotProps={{ input: { endAdornment: toggle } }}
            fullWidth
          />

          <TextField
            label="New password"
            type={visible ? 'text' : 'password'}
            value={form.new_password}
            onChange={(e) => handleChange('new_password', e.target.value)}
            error={Boolean(formErrors.new_password)}
            helperText={formErrors.new_password || `At least ${MIN_LENGTH} characters`}
            autoComplete="new-password"
            fullWidth
          />

          <TextField
            label="Confirm new password"
            type={visible ? 'text' : 'password'}
            value={form.confirm_password}
            onChange={(e) => handleChange('confirm_password', e.target.value)}
            error={Boolean(formErrors.confirm_password)}
            helperText={formErrors.confirm_password}
            autoComplete="new-password"
            fullWidth
          />

          {mutation.isError && (
            <Alert severity="error">
              {mutation.error?.response?.data?.message || 'Could not change your password'}
            </Alert>
          )}

          <Box>
            <Button
              type="submit"
              variant="contained"
              disabled={mutation.isPending}
              startIcon={
                mutation.isPending
                  ? <CircularProgress size={16} color="inherit" />
                  : null
              }
            >
              {mutation.isPending ? 'Changing…' : 'Change password'}
            </Button>
          </Box>
        </Stack>
      </Box>
    </Paper>
  )
}
