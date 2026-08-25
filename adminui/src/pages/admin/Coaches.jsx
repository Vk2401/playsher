import React, { useRef, useState } from 'react'
import {
  Alert, Avatar, Box, Button, Chip, Grid, InputAdornment, MenuItem,
  Stack, Tab, Tabs, TextField, Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import AddIcon from '@mui/icons-material/Add'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import CloseIcon from '@mui/icons-material/Close'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import EditIcon from '@mui/icons-material/Edit'
import KeyIcon from '@mui/icons-material/Key'
import SearchIcon from '@mui/icons-material/Search'
import PhotoCameraIcon from '@mui/icons-material/PhotoCamera'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { coachesApi } from '../../api/coaches.js'
import { sportsApi } from '../../api/sports.js'

const LEVELS = ['beginner', 'intermediate', 'advanced', 'professional']

const TABS = [
  { label: 'Pending approval', status: 'pending' },
  { label: 'Approved', status: 'approved' },
  { label: 'Deactivated', status: 'inactive' },
  { label: 'All', status: '' },
]

const EMPTY_FORM = {
  name: '', email: '', mobile: '', city: '', sport_id: '', sport_name: '',
  level: 'beginner', experience_years: '', price_per_slot: '', about: '',
  password: '', is_active: true,
}

const rupees = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`

export default function AdminCoaches() {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const fileInputRef = useRef(null)

  const [tab, setTab] = useState(3)
  const [search, setSearch] = useState('')
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [editing, setEditing] = useState(null)     // the coach being edited, or null on create
  const [form, setForm] = useState(EMPTY_FORM)
  const [formErrors, setFormErrors] = useState({})
  const [photo, setPhoto] = useState(null)
  const [photoPreview, setPhotoPreview] = useState(null)

  const [deleteTarget, setDeleteTarget] = useState(null)
  const [approveTarget, setApproveTarget] = useState(null)
  const [rejectTarget, setRejectTarget] = useState(null)
  const [rejectReason, setRejectReason] = useState('')
  const [passwordTarget, setPasswordTarget] = useState(null)
  const [newPassword, setNewPassword] = useState('')

  const status = TABS[tab].status
  const params = { limit: 100, ...(status ? { status } : {}), ...(search.trim() ? { search: search.trim() } : {}) }

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'coaches', params],
    queryFn: () => coachesApi.getAll(params),
    select: (res) => res.data?.data ?? [],
  })

  const sports = useQuery({
    queryKey: ['admin', 'sports'],
    queryFn: () => sportsApi.getAll({ limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['admin', 'coaches'] })

  // ── Mutations ─────────────────────────────────────────────────────────────
  const approveMutation = useMutation({
    mutationFn: (id) => coachesApi.approve(id),
    onSuccess: () => { invalidate(); notify.success('Coach approved and notified.'); setApproveTarget(null) },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not approve this coach.'),
  })

  const rejectMutation = useMutation({
    mutationFn: (id) => coachesApi.reject(id, rejectReason.trim() || undefined),
    onSuccess: () => {
      invalidate()
      notify.success('Application rejected. The coach has been told why.')
      setRejectTarget(null)
      setRejectReason('')
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not reject this coach.'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => coachesApi.delete(id),
    onSuccess: () => { invalidate(); notify.success('Coach deleted.'); setDeleteTarget(null) },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not delete this coach.'),
  })

  const passwordMutation = useMutation({
    mutationFn: (id) => coachesApi.setPassword(id, newPassword),
    onSuccess: () => {
      notify.success('Password set. The coach can now sign in with their email.')
      setPasswordTarget(null)
      setNewPassword('')
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not set that password.'),
  })

  const saveMutation = useMutation({
    mutationFn: (fd) => (editing ? coachesApi.update(editing.id, fd) : coachesApi.create(fd)),
    onSuccess: () => {
      invalidate()
      notify.success(editing ? 'Coach updated.' : 'Coach created.')
      closeDrawer()
    },
    onError: (err) => notify.error(err?.response?.data?.message
      || (editing ? 'Could not update this coach.' : 'Could not create this coach.')),
  })

  // ── Drawer ────────────────────────────────────────────────────────────────
  const openCreate = () => {
    setEditing(null)
    setForm(EMPTY_FORM)
    setFormErrors({})
    setPhoto(null)
    setPhotoPreview(null)
    setDrawerOpen(true)
  }

  const openEdit = (coach) => {
    setEditing(coach)
    setForm({
      name: coach.name ?? '',
      email: coach.email ?? '',
      mobile: coach.mobile ?? '',
      city: coach.city ?? '',
      sport_id: coach.sport_id ?? '',
      sport_name: coach.sport_name ?? '',
      level: coach.level ?? 'beginner',
      experience_years: coach.experience_years ?? '',
      price_per_slot: coach.price_per_slot ?? '',
      about: coach.about ?? '',
      password: '',
      is_active: coach.is_active !== false,
    })
    setFormErrors({})
    setPhoto(null)
    setPhotoPreview(null)
    setDrawerOpen(true)
  }

  const closeDrawer = () => {
    setDrawerOpen(false)
    setEditing(null)
    setForm(EMPTY_FORM)
    setFormErrors({})
    setPhoto(null)
    setPhotoPreview(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

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
    if (!form.name.trim()) next.name = 'Name is required.'
    if (!form.email.trim()) next.email = 'Email is required — it is the coach’s login.'
    else if (!/^\S+@\S+\.\S+$/.test(form.email.trim())) next.email = 'Enter a valid email address.'
    if (form.mobile && !/^\+?[0-9]{7,15}$/.test(form.mobile.trim())) next.mobile = 'Enter a valid mobile number.'
    if (form.price_per_slot !== '' && Number(form.price_per_slot) < 0) next.price_per_slot = 'A price cannot be negative.'
    if (!editing && form.password && form.password.length < 6) next.password = 'Use at least 6 characters.'
    setFormErrors(next)
    return Object.keys(next).length === 0
  }

  const handleSubmit = () => {
    if (!validate()) return
    const fd = new FormData()
    Object.entries(form).forEach(([k, v]) => {
      if (k === 'password' && !v) return
      if (v === '' || v === null || v === undefined) return
      fd.append(k, v)
    })
    if (photo) fd.append('profile_image', photo)
    saveMutation.mutate(fd)
  }

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'name',
      headerName: 'Coach',
      flex: 1,
      minWidth: 220,
      renderCell: ({ row }) => (
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Avatar src={row.profile_picture || undefined} sx={{ width: 32, height: 32 }}>
            {(row.name || '?').charAt(0).toUpperCase()}
          </Avatar>
          <Box>
            <Typography variant="body2" fontWeight={600}>{row.name}</Typography>
            <Typography variant="caption" color="text.secondary">{row.email || 'No email'}</Typography>
          </Box>
        </Stack>
      ),
    },
    {
      field: 'sport',
      headerName: 'Sport',
      width: 130,
      sortable: false,
      valueGetter: (_v, row) => row.sport?.name || row.sport_name || '—',
    },
    {
      field: 'experience_years',
      headerName: 'Exp.',
      width: 80,
      renderCell: ({ row }) => (row.experience_years != null ? `${row.experience_years} yr` : '—'),
    },
    {
      field: 'price_per_slot',
      headerName: 'Rate / 30 min',
      width: 130,
      renderCell: ({ row }) => (Number(row.price_per_slot) > 0
        ? rupees(row.price_per_slot)
        : <Chip label="Not set" size="small" />),
    },
    {
      field: 'is_approved',
      headerName: 'Approval',
      width: 120,
      renderCell: ({ row }) => <StatusChip status={row.is_approved ? 'approved' : 'pending'} />,
    },
    {
      field: 'is_active',
      headerName: 'Account',
      width: 110,
      renderCell: ({ row }) => <StatusChip status={row.is_active ? 'active' : 'inactive'} />,
    },
    {
      field: 'created_at',
      headerName: 'Joined',
      width: 120,
      renderCell: ({ row }) => (row.created_at ? dayjs(row.created_at).format('DD MMM YY') : '—'),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 300,
      sortable: false,
      renderCell: ({ row }) => (
        <Stack direction="row" spacing={0.5}>
          {!row.is_approved && (
            <Button size="small" variant="contained" startIcon={<CheckCircleOutlineIcon />}
              onClick={() => setApproveTarget(row)}>
              Approve
            </Button>
          )}
          {!row.is_approved && (
            <Button size="small" color="error" startIcon={<CloseIcon />}
              onClick={() => { setRejectReason(''); setRejectTarget(row) }}>
              Reject
            </Button>
          )}
          <Button size="small" startIcon={<EditIcon />} onClick={() => openEdit(row)}>Edit</Button>
          <Button size="small" startIcon={<KeyIcon />}
            onClick={() => { setNewPassword(''); setPasswordTarget(row) }}>
            Password
          </Button>
          <Button size="small" color="error" startIcon={<DeleteOutlineIcon />}
            onClick={() => setDeleteTarget(row)}>
            Delete
          </Button>
        </Stack>
      ),
    },
  ]

  const pendingCount = (data ?? []).filter((c) => !c.is_approved).length

  return (
    <Box>
      <PageHeader
        title="Coaches"
        subtitle="Coach accounts, approvals and pricing"
        breadcrumbs={[{ label: 'Admin', href: '/admin/dashboard' }, { label: 'Coaches' }]}
        actions={
          <Stack direction="row" spacing={1} alignItems="center">
            {pendingCount > 0 && tab !== 0 && <Chip color="warning" label={`${pendingCount} pending`} />}
            <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
              Add coach
            </Button>
          </Stack>
        }
      />

      {error && <Alert severity="error" sx={{ mb: 2 }}>Could not load coaches.</Alert>}

      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }} mb={2}>
        <Tabs value={tab} onChange={(_, v) => setTab(v)} variant="scrollable" scrollButtons="auto" sx={{ flex: 1 }}>
          {TABS.map((t) => <Tab key={t.label} label={t.label} />)}
        </Tabs>
        <TextField
          placeholder="Search name, email or mobile"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          size="small"
          sx={{ minWidth: { sm: 260 } }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>
            ),
          }}
        />
      </Stack>

      <DataTable rows={data ?? []} columns={columns} loading={isLoading} error={error} />

      {/* Create / edit */}
      <DrawerForm
        open={drawerOpen}
        onClose={closeDrawer}
        title={editing ? `Edit ${editing.name}` : 'Add coach'}
        onSubmit={handleSubmit}
        loading={saveMutation.isPending}
        submitLabel={editing ? 'Save changes' : 'Create coach'}
        width={520}
      >
        <Grid container spacing={2}>
          <Grid item xs={12}>
            <Stack direction="row" spacing={2} alignItems="center">
              <Avatar
                src={photoPreview || editing?.profile_picture || undefined}
                sx={{ width: 56, height: 56 }}
              >
                {(form.name || '?').charAt(0).toUpperCase()}
              </Avatar>
              <Button component="label" variant="outlined" size="small" startIcon={<PhotoCameraIcon />}>
                Photo
                <input ref={fileInputRef} hidden type="file" accept="image/*" onChange={onPhoto} />
              </Button>
            </Stack>
          </Grid>
          <Grid item xs={12}>
            <TextField label="Full name" value={form.name} onChange={onChange('name')}
              error={Boolean(formErrors.name)} helperText={formErrors.name}
              fullWidth size="small" required />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField label="Email" type="email" value={form.email} onChange={onChange('email')}
              error={Boolean(formErrors.email)} helperText={formErrors.email || 'The coach signs in with this.'}
              fullWidth size="small" required />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField label="Mobile" value={form.mobile} onChange={onChange('mobile')}
              error={Boolean(formErrors.mobile)} helperText={formErrors.mobile}
              fullWidth size="small" />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField select label="Sport" value={form.sport_id} onChange={onChange('sport_id')}
              fullWidth size="small">
              <MenuItem value="">Not set</MenuItem>
              {(sports.data ?? []).map((s) => <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>)}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField select label="Level" value={form.level} onChange={onChange('level')}
              fullWidth size="small">
              {LEVELS.map((l) => (
                <MenuItem key={l} value={l}>{l.charAt(0).toUpperCase() + l.slice(1)}</MenuItem>
              ))}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField label="Years of experience" type="number"
              value={form.experience_years} onChange={onChange('experience_years')}
              fullWidth size="small" inputProps={{ min: 0 }} />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField label="City" value={form.city} onChange={onChange('city')}
              fullWidth size="small" />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField label="Price per 30-min slot" type="number"
              value={form.price_per_slot} onChange={onChange('price_per_slot')}
              error={Boolean(formErrors.price_per_slot)}
              helperText={formErrors.price_per_slot || 'A coach at ₹0 cannot be booked.'}
              fullWidth size="small" inputProps={{ min: 0, step: 10 }}
              InputProps={{ startAdornment: <InputAdornment position="start">₹</InputAdornment> }} />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField select label="Account" value={form.is_active ? 'yes' : 'no'}
              onChange={(e) => setForm((p) => ({ ...p, is_active: e.target.value === 'yes' }))}
              fullWidth size="small">
              <MenuItem value="yes">Active</MenuItem>
              <MenuItem value="no">Deactivated</MenuItem>
            </TextField>
          </Grid>
          {!editing && (
            <Grid item xs={12}>
              <TextField label="Login password (optional)" type="password"
                value={form.password} onChange={onChange('password')}
                error={Boolean(formErrors.password)}
                helperText={formErrors.password
                  || 'Leave blank to create the profile now and issue a password later.'}
                fullWidth size="small" />
            </Grid>
          )}
          <Grid item xs={12}>
            <TextField label="About" value={form.about} onChange={onChange('about')}
              fullWidth size="small" multiline minRows={3} />
          </Grid>
        </Grid>
      </DrawerForm>

      {/* Set / reset password */}
      <DrawerForm
        open={Boolean(passwordTarget)}
        onClose={() => { setPasswordTarget(null); setNewPassword('') }}
        title={`Set password for ${passwordTarget?.name || 'coach'}`}
        onSubmit={() => passwordMutation.mutate(passwordTarget.id)}
        loading={passwordMutation.isPending}
        submitLabel="Set password"
      >
        <Stack spacing={2}>
          <Alert severity="warning">
            This signs the coach out of every device they are currently using.
          </Alert>
          <TextField
            label="New password"
            type="password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            helperText="At least 6 characters. Share it with the coach directly."
            fullWidth
            size="small"
          />
        </Stack>
      </DrawerForm>

      {/* Reject with a reason */}
      <DrawerForm
        open={Boolean(rejectTarget)}
        onClose={() => { setRejectTarget(null); setRejectReason('') }}
        title={`Reject ${rejectTarget?.name || 'this application'}`}
        onSubmit={() => rejectMutation.mutate(rejectTarget.id)}
        loading={rejectMutation.isPending}
        submitLabel="Reject application"
      >
        <Stack spacing={2}>
          <Typography variant="body2" color="text.secondary">
            The coach keeps their account but stays unapproved. Your reason is what
            they will read on their profile.
          </Typography>
          <TextField
            label="Reason"
            value={rejectReason}
            onChange={(e) => setRejectReason(e.target.value)}
            multiline
            minRows={3}
            fullWidth
          />
        </Stack>
      </DrawerForm>

      <ConfirmDialog
        open={Boolean(approveTarget)}
        onClose={() => setApproveTarget(null)}
        onConfirm={() => approveMutation.mutate(approveTarget.id)}
        title="Approve this coach?"
        message={approveTarget
          ? `${approveTarget.name} will appear in the app and can register at grounds.`
          : ''}
        confirmLabel="Approve"
        confirmColor="primary"
        loading={approveMutation.isPending}
      />

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget.id)}
        title="Delete this coach?"
        message={deleteTarget
          ? `${deleteTarget.name} will be removed permanently. A coach with sessions on record cannot be deleted — deactivate them instead.`
          : ''}
        confirmLabel="Delete"
        loading={deleteMutation.isPending}
      />
    </Box>
  )
}
