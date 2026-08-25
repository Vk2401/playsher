import React, { useEffect, useRef, useState } from 'react'
import {
  Alert, Avatar, Box, Button, Grid, InputAdornment, MenuItem, Paper,
  Stack, TextField, Typography,
} from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import SaveIcon from '@mui/icons-material/Save'
import PhotoCameraIcon from '@mui/icons-material/PhotoCamera'

import PageHeader from '../../components/ui/PageHeader.jsx'
import ChangePasswordCard from '../../components/ui/ChangePasswordCard.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { coachesApi } from '../../api/coaches.js'
import { sportsApi } from '../../api/sports.js'

const LEVELS = ['beginner', 'intermediate', 'advanced', 'professional']

const EMPTY = {
  name: '', mobile: '', city: '', sport_id: '', sport_name: '', level: 'beginner',
  experience_years: '', price_per_slot: '', about: '', experience_details: '',
  awards: '', qualities: '',
}

export default function CoachProfile() {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const fileInputRef = useRef(null)

  const [form, setForm] = useState(EMPTY)
  const [formErrors, setFormErrors] = useState({})
  const [photo, setPhoto] = useState(null)
  const [photoPreview, setPhotoPreview] = useState(null)

  const profile = useQuery({
    queryKey: ['coach', 'profile'],
    queryFn: () => coachesApi.getProfile(),
    select: (res) => res.data?.data ?? null,
  })

  const sports = useQuery({
    queryKey: ['sports', 'public'],
    queryFn: () => sportsApi.getPublic({ limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })

  useEffect(() => {
    const c = profile.data
    if (!c) return
    setForm({
      name: c.name ?? '',
      mobile: c.mobile ?? '',
      city: c.city ?? '',
      sport_id: c.sport_id ?? '',
      sport_name: c.sport_name ?? '',
      level: c.level ?? 'beginner',
      experience_years: c.experience_years ?? '',
      price_per_slot: c.price_per_slot ?? '',
      about: c.about ?? '',
      experience_details: c.experience_details ?? '',
      awards: c.awards ?? '',
      qualities: c.qualities ?? '',
    })
  }, [profile.data])

  const mutation = useMutation({
    mutationFn: (fd) => coachesApi.updateProfile(fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['coach', 'profile'] })
      queryClient.invalidateQueries({ queryKey: ['coach', 'dashboard'] })
      notify.success('Profile updated.')
      setPhoto(null)
      setPhotoPreview(null)
      if (fileInputRef.current) fileInputRef.current.value = ''
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save your profile.'),
  })

  const onChange = (field) => (e) =>
    setForm((prev) => ({ ...prev, [field]: e.target.value }))

  const onPhoto = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    setPhoto(file)
    setPhotoPreview(URL.createObjectURL(file))
  }

  const validate = () => {
    const next = {}
    if (!form.name.trim()) next.name = 'Your name is required.'
    if (form.mobile && !/^\+?[0-9]{7,15}$/.test(form.mobile.trim())) {
      next.mobile = 'Enter a valid mobile number.'
    }
    if (form.price_per_slot !== '' && Number(form.price_per_slot) < 0) {
      next.price_per_slot = 'A price cannot be negative.'
    }
    if (form.experience_years !== '' && Number(form.experience_years) < 0) {
      next.experience_years = 'Experience cannot be negative.'
    }
    setFormErrors(next)
    return Object.keys(next).length === 0
  }

  const handleSave = () => {
    if (!validate()) return
    const fd = new FormData()
    Object.entries(form).forEach(([k, v]) => {
      if (v !== '' && v !== null && v !== undefined) fd.append(k, v)
    })
    if (photo) fd.append('profile_image', photo)
    mutation.mutate(fd)
  }

  const coach = profile.data
  const priceIsSet = Number(coach?.price_per_slot ?? 0) > 0

  return (
    <Box>
      <PageHeader
        title="My Profile"
        subtitle="What players see, and what you charge"
        actions={
          <Button
            variant="contained"
            startIcon={<SaveIcon />}
            onClick={handleSave}
            disabled={mutation.isPending || profile.isLoading}
          >
            {mutation.isPending ? 'Saving…' : 'Save changes'}
          </Button>
        }
      />

      {profile.error && (
        <Alert severity="error" sx={{ mb: 2 }}>Could not load your profile.</Alert>
      )}
      {coach && !priceIsSet && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          Set a price below — a coach priced at ₹0 cannot be booked at all.
        </Alert>
      )}

      <Grid container spacing={3}>
        <Grid item xs={12} md={4}>
          <Paper sx={{ p: 3, textAlign: 'center' }}>
            <Avatar
              src={photoPreview || coach?.profile_picture || undefined}
              sx={{ width: 96, height: 96, mx: 'auto', mb: 2, fontSize: 32 }}
            >
              {(coach?.name || '?').charAt(0).toUpperCase()}
            </Avatar>
            <Typography variant="h6">{coach?.name || '—'}</Typography>
            <Typography variant="body2" color="text.secondary" mb={1}>
              {coach?.email || '—'}
            </Typography>
            <Stack direction="row" spacing={1} justifyContent="center" mb={2}>
              <StatusChip status={coach?.is_approved ? 'approved' : 'pending'} />
              <StatusChip status={coach?.is_active ? 'active' : 'inactive'} />
            </Stack>
            {coach?.rejection_reason && (
              <Alert severity="warning" sx={{ textAlign: 'left', mb: 2 }}>
                {coach.rejection_reason}
              </Alert>
            )}
            <Button component="label" variant="outlined" startIcon={<PhotoCameraIcon />} size="small">
              Change photo
              <input ref={fileInputRef} hidden type="file" accept="image/*" onChange={onPhoto} />
            </Button>
            <Typography variant="caption" color="text.secondary" display="block" mt={1.5}>
              Your email is your login. Ask an admin to change it.
            </Typography>
          </Paper>
        </Grid>

        <Grid item xs={12} md={8}>
          <Paper sx={{ p: { xs: 2, sm: 3 } }}>
            <Typography variant="subtitle1" fontWeight={700} mb={2}>Details</Typography>
            <Grid container spacing={2}>
              <Grid item xs={12} sm={6}>
                <TextField
                  label="Full name" value={form.name} onChange={onChange('name')}
                  error={Boolean(formErrors.name)} helperText={formErrors.name}
                  fullWidth size="small" required
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  label="Mobile" value={form.mobile} onChange={onChange('mobile')}
                  error={Boolean(formErrors.mobile)} helperText={formErrors.mobile}
                  fullWidth size="small"
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  select label="Sport" value={form.sport_id} onChange={onChange('sport_id')}
                  fullWidth size="small"
                >
                  <MenuItem value="">Not set</MenuItem>
                  {(sports.data ?? []).map((s) => (
                    <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
                  ))}
                </TextField>
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  select label="Coaching level" value={form.level} onChange={onChange('level')}
                  fullWidth size="small"
                >
                  {LEVELS.map((l) => (
                    <MenuItem key={l} value={l}>{l.charAt(0).toUpperCase() + l.slice(1)}</MenuItem>
                  ))}
                </TextField>
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  label="Years of experience" type="number"
                  value={form.experience_years} onChange={onChange('experience_years')}
                  error={Boolean(formErrors.experience_years)} helperText={formErrors.experience_years}
                  fullWidth size="small" inputProps={{ min: 0 }}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  label="City" value={form.city} onChange={onChange('city')}
                  fullWidth size="small"
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  label="Price per 30-minute slot" type="number"
                  value={form.price_per_slot} onChange={onChange('price_per_slot')}
                  error={Boolean(formErrors.price_per_slot)}
                  helperText={formErrors.price_per_slot
                    || 'A one-hour session costs twice this.'}
                  fullWidth size="small"
                  inputProps={{ min: 0, step: 10 }}
                  InputProps={{
                    startAdornment: <InputAdornment position="start">₹</InputAdornment>,
                  }}
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  label="About you" value={form.about} onChange={onChange('about')}
                  fullWidth size="small" multiline minRows={3}
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  label="Experience" value={form.experience_details}
                  onChange={onChange('experience_details')}
                  fullWidth size="small" multiline minRows={2}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  label="Awards" value={form.awards} onChange={onChange('awards')}
                  fullWidth size="small" multiline minRows={2}
                />
              </Grid>
              <Grid item xs={12} sm={6}>
                <TextField
                  label="What you are known for" value={form.qualities}
                  onChange={onChange('qualities')}
                  fullWidth size="small" multiline minRows={2}
                />
              </Grid>
            </Grid>
          </Paper>

          <Box mt={3}>
            <ChangePasswordCard />
          </Box>
        </Grid>
      </Grid>
    </Box>
  )
}
