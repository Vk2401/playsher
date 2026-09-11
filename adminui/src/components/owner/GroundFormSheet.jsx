import { useEffect, useMemo, useState } from 'react'
import { Box, Button, FormControlLabel, InputAdornment, Stack, Switch, TextField, Typography } from '@mui/material'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import MyLocationIcon from '@mui/icons-material/MyLocation'
import AddPhotoAlternateOutlinedIcon from '@mui/icons-material/AddPhotoAlternateOutlined'

import ActionSheet from './ActionSheet.jsx'
import { groundsApi } from '../../api/grounds.js'
import { useNotify } from '../../hooks/useNotify.js'

const EMPTY = {
  name: '', area: '', city: '', address: '', contact_number: '', price_per_slot: '',
  has_roof: false, is_active: true, description: '', about: '', venue_rules: '',
  latitude: '', longitude: '',
}

const fromGround = (g) => ({
  name: g?.name ?? '',
  area: g?.area ?? '',
  city: g?.city ?? '',
  address: g?.address ?? '',
  contact_number: g?.contact_number ?? '',
  price_per_slot: g?.price_per_slot ?? '',
  has_roof: Boolean(g?.has_roof),
  is_active: g?.is_active ?? true,
  description: g?.description ?? '',
  about: g?.about ?? '',
  venue_rules: g?.venue_rules ?? '',
  latitude: g?.latitude ?? '',
  longitude: g?.longitude ?? '',
})

/**
 * Add a ground, or edit one. Every field the old ground form had is here,
 * grouped the way an owner thinks about them: the basics, how customers find
 * you, and what they read before booking.
 */
export default function GroundFormSheet({ open, onClose, ground, onCreated }) {
  const editing = Boolean(ground)
  return (
    <ActionSheet open={open} onClose={onClose} title={editing ? 'Edit ground details' : 'Add a new ground'}>
      {/* keyed so the form resets every time it opens */}
      {open && <GroundForm key={ground?.id ?? 'new'} ground={ground} onClose={onClose} onCreated={onCreated} />}
    </ActionSheet>
  )
}

function GroundForm({ ground, onClose, onCreated }) {
  const editing = Boolean(ground)
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [form, setForm] = useState(() => (editing ? fromGround(ground) : EMPTY))
  const [errors, setErrors] = useState({})
  const [cover, setCover] = useState(null)
  const [locating, setLocating] = useState(false)
  const coverPreview = useMemo(() => (cover ? URL.createObjectURL(cover) : null), [cover])
  useEffect(() => () => { if (coverPreview) URL.revokeObjectURL(coverPreview) }, [coverPreview])

  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }))

  const mutation = useMutation({
    mutationFn: (fd) => (editing ? groundsApi.update(ground.id, fd) : groundsApi.create(fd)),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'grounds'] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground'] })
      notify.success(editing ? 'Ground details saved' : 'Ground added. Playsher will review it before customers can book.')
      if (!editing) onCreated?.(res.data?.data?.id)
      onClose()
    },
    onError: (err) => notify.error(err?.response?.data?.message || (editing ? 'Could not save the ground' : 'Could not add the ground')),
  })

  const validate = () => {
    const e = {}
    if (!form.name.trim()) e.name = 'Enter the ground name'
    if (form.price_per_slot !== '' && (Number.isNaN(Number(form.price_per_slot)) || Number(form.price_per_slot) < 0)) {
      e.price_per_slot = 'Enter a price in rupees'
    }
    const digits = String(form.contact_number).replace(/\D/g, '')
    if (form.contact_number && digits.length < 10) e.contact_number = 'Enter a 10-digit phone number'
    if (form.latitude !== '' && Math.abs(Number(form.latitude)) > 90) e.latitude = 'Not a valid latitude'
    if (form.longitude !== '' && Math.abs(Number(form.longitude)) > 180) e.longitude = 'Not a valid longitude'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  const submit = () => {
    if (!validate()) return
    const fd = new FormData()
    Object.entries(form).forEach(([k, v]) => {
      if (k === 'has_roof' || k === 'is_active') fd.append(k, v ? 'true' : 'false')
      else if (v !== '' && v != null) fd.append(k, typeof v === 'string' ? v.trim() : v)
    })
    if (cover) fd.append('cover_image', cover)
    mutation.mutate(fd)
  }

  const useMyLocation = () => {
    if (!navigator.geolocation) {
      notify.warning('This device cannot share its location')
      return
    }
    setLocating(true)
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setForm((f) => ({
          ...f,
          latitude: pos.coords.latitude.toFixed(6),
          longitude: pos.coords.longitude.toFixed(6),
        }))
        setLocating(false)
        notify.success('Location added. Stand at the ground when you do this.')
      },
      () => {
        setLocating(false)
        notify.error('Could not get your location. Allow location access and try again.')
      },
      { enableHighAccuracy: true, timeout: 15000 },
    )
  }

  const group = (title) => (
    <Typography variant="subtitle2" fontWeight={700} color="text.secondary" sx={{ mt: 2.5, mb: 1 }}>
      {title}
    </Typography>
  )

  return (
    <Box>
      {group('Basics')}
      <Stack spacing={1.75}>
        <TextField label="Ground name" required value={form.name} onChange={set('name')} error={!!errors.name} helperText={errors.name} fullWidth />
        <TextField
          label="Price for 30 minutes"
          value={form.price_per_slot}
          onChange={set('price_per_slot')}
          error={!!errors.price_per_slot}
          helperText={errors.price_per_slot || 'Customers book in 30-minute blocks'}
          inputMode="numeric"
          InputProps={{ startAdornment: <InputAdornment position="start">₹</InputAdornment> }}
          fullWidth
        />
        <TextField label="Contact number" value={form.contact_number} onChange={set('contact_number')} error={!!errors.contact_number} helperText={errors.contact_number} inputMode="tel" fullWidth />
        <FormControlLabel control={<Switch checked={form.has_roof} onChange={set('has_roof')} />} label="Indoor or covered (has a roof)" />
        <FormControlLabel control={<Switch checked={form.is_active} onChange={set('is_active')} />} label="Open for booking" />
      </Stack>

      {group('Where is it')}
      <Stack spacing={1.75}>
        <TextField label="Full address" value={form.address} onChange={set('address')} multiline minRows={2} fullWidth />
        <Stack direction="row" spacing={1.5}>
          <TextField label="Area" value={form.area} onChange={set('area')} fullWidth />
          <TextField label="City" value={form.city} onChange={set('city')} fullWidth />
        </Stack>
        <Button variant="outlined" startIcon={<MyLocationIcon />} onClick={useMyLocation} disabled={locating}>
          {locating ? 'Finding you…' : 'Use my current location for the map'}
        </Button>
        <Stack direction="row" spacing={1.5}>
          <TextField label="Latitude" value={form.latitude} onChange={set('latitude')} error={!!errors.latitude} helperText={errors.latitude} inputMode="decimal" fullWidth />
          <TextField label="Longitude" value={form.longitude} onChange={set('longitude')} error={!!errors.longitude} helperText={errors.longitude} inputMode="decimal" fullWidth />
        </Stack>
      </Stack>

      {group('What customers read')}
      <Stack spacing={1.75}>
        <TextField label="Short description" value={form.description} onChange={set('description')} multiline minRows={2} fullWidth />
        <TextField label="About the ground" value={form.about} onChange={set('about')} multiline minRows={3} fullWidth />
        <TextField label="Ground rules" value={form.venue_rules} onChange={set('venue_rules')} multiline minRows={2} placeholder="e.g. Non-marking shoes only" fullWidth />
        <Button component="label" variant="outlined" startIcon={<AddPhotoAlternateOutlinedIcon />}>
          {cover ? cover.name : editing ? 'Change cover photo' : 'Add a cover photo'}
          <input hidden type="file" accept="image/*" onChange={(e) => setCover(e.target.files?.[0] ?? null)} />
        </Button>
        {cover && (
          <Box component="img" src={coverPreview} alt="" sx={{ width: '100%', maxHeight: 180, objectFit: 'cover', borderRadius: 1 }} />
        )}
      </Stack>

      <Stack spacing={1} mt={3}>
        <Button variant="contained" size="large" onClick={submit} disabled={mutation.isPending}>
          {mutation.isPending ? 'Saving…' : editing ? 'Save details' : 'Add ground'}
        </Button>
        <Button size="large" onClick={onClose}>Cancel</Button>
      </Stack>
    </Box>
  )
}
