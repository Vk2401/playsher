import React, { useState, useMemo } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Box, Stack, TextField, Select, MenuItem, InputAdornment, Button, Chip,
  IconButton, Tooltip, Alert, AlertTitle, Typography, FormControlLabel, Switch,
  InputLabel, FormControl, FormHelperText,
} from '@mui/material'
import SearchIcon from '@mui/icons-material/Search'
import AddIcon from '@mui/icons-material/Add'
import EditIcon from '@mui/icons-material/Edit'
import KeyIcon from '@mui/icons-material/Key'
import BlockIcon from '@mui/icons-material/Block'
import CheckCircleIcon from '@mui/icons-material/CheckCircle'
import ShieldIcon from '@mui/icons-material/Shield'
import PersonIcon from '@mui/icons-material/Person'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import EmptyState from '../../components/ui/EmptyState.jsx'
import { adminsApi } from '../../api/admins.js'
import { useNotify } from '../../hooks/useNotify.js'
import { useAuth } from '../../contexts/AuthContext.jsx'

const ROLE_LABEL = { super_admin: 'Super admin', admin: 'Admin' }
const MOBILE_RE = /^[6-9]\d{9}$/
const BLANK = { name: '', email: '', mobile: '', password: '', role: 'admin' }

export default function Admins() {
  const notify = useNotify()
  const queryClient = useQueryClient()
  const { user } = useAuth()

  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')

  const [createOpen, setCreateOpen] = useState(false)
  const [createForm, setCreateForm] = useState(BLANK)
  const [createErrors, setCreateErrors] = useState({})

  const [editTarget, setEditTarget] = useState(null)
  const [editForm, setEditForm] = useState(BLANK)
  const [editErrors, setEditErrors] = useState({})

  const [passwordTarget, setPasswordTarget] = useState(null)
  const [newPassword, setNewPassword] = useState('')
  const [passwordError, setPasswordError] = useState('')

  const [statusTarget, setStatusTarget] = useState(null)

  const me = useQuery({
    queryKey: ['admin', 'admins', 'me'],
    queryFn: () => adminsApi.me(),
    select: (res) => res.data?.data ?? null,
  })

  const isSuper = me.data?.is_super_admin === true

  const admins = useQuery({
    queryKey: ['admin', 'admins'],
    queryFn: () => adminsApi.getAll({ limit: 100 }),
    select: (res) => res.data?.data ?? [],
    // Pointless to fetch the list the server will refuse.
    enabled: isSuper,
  })

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['admin', 'admins'] })
  }

  const createMutation = useMutation({
    mutationFn: (payload) => adminsApi.create(payload),
    onSuccess: () => {
      invalidate()
      notify.success('Admin created successfully')
      closeCreate()
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to create the admin'),
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }) => adminsApi.update(id, payload),
    onSuccess: () => {
      invalidate()
      notify.success('Admin updated successfully')
      closeEdit()
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to update the admin'),
  })

  const statusMutation = useMutation({
    mutationFn: (id) => adminsApi.toggleStatus(id),
    onSuccess: (res) => {
      invalidate()
      notify.success(res.data?.message || 'Status updated')
      setStatusTarget(null)
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to change the status')
      setStatusTarget(null)
    },
  })

  const passwordMutation = useMutation({
    mutationFn: ({ id, password }) => adminsApi.resetPassword(id, password),
    onSuccess: () => {
      notify.success('Password reset. Share it with them over a private channel.')
      closePassword()
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to reset the password'),
  })

  // ── Form handling ─────────────────────────────────────────────────────────
  const openCreate = () => {
    setCreateForm(BLANK)
    setCreateErrors({})
    setCreateOpen(true)
  }
  const closeCreate = () => {
    setCreateOpen(false)
    setCreateForm(BLANK)
    setCreateErrors({})
  }

  const openEdit = (row) => {
    setEditForm({ name: row.name, email: row.email, mobile: row.mobile, role: row.role })
    setEditErrors({})
    setEditTarget(row)
  }
  const closeEdit = () => {
    setEditTarget(null)
    setEditForm(BLANK)
    setEditErrors({})
  }

  const closePassword = () => {
    setPasswordTarget(null)
    setNewPassword('')
    setPasswordError('')
  }

  const validate = (form, { withPassword }) => {
    const errors = {}
    if (!form.name || form.name.trim().length < 2) errors.name = 'Name must be at least 2 characters'
    if (!/^\S+@\S+\.\S+$/.test(form.email || '')) errors.email = 'Enter a valid email address'
    if (!MOBILE_RE.test(form.mobile || '')) errors.mobile = 'Enter a 10-digit Indian mobile number'
    if (withPassword && (form.password || '').length < 8) {
      errors.password = 'Password must be at least 8 characters'
    }
    return errors
  }

  const submitCreate = () => {
    const errors = validate(createForm, { withPassword: true })
    setCreateErrors(errors)
    if (Object.keys(errors).length) return
    createMutation.mutate(createForm)
  }

  const submitEdit = () => {
    const errors = validate(editForm, { withPassword: false })
    setEditErrors(errors)
    if (Object.keys(errors).length) return
    updateMutation.mutate({ id: editTarget.id, payload: editForm })
  }

  const submitPassword = () => {
    if ((newPassword || '').length < 8) {
      setPasswordError('Password must be at least 8 characters')
      return
    }
    setPasswordError('')
    passwordMutation.mutate({ id: passwordTarget.id, password: newPassword })
  }

  // ── Filtering (the list endpoint supports it, but the page holds ≤100 rows
  // and filtering locally keeps typing instant) ─────────────────────────────
  const rows = useMemo(() => {
    const term = search.trim().toLowerCase()
    return (admins.data ?? []).filter((a) => {
      if (roleFilter !== 'all' && a.role !== roleFilter) return false
      if (statusFilter !== 'all' && a.is_active !== (statusFilter === 'active')) return false
      if (!term) return true
      return [a.name, a.email, a.mobile].some((v) => String(v || '').toLowerCase().includes(term))
    })
  }, [admins.data, search, roleFilter, statusFilter])

  // /me is the authoritative answer; the stored auth user is only a fallback for
  // the first render, before that query resolves.
  const myId = me.data?.id ?? user?.id
  const isMe = (row) => Number(row.id) === Number(myId)

  const columns = [
    {
      field: 'name',
      headerName: 'Name',
      flex: 1,
      minWidth: 170,
      renderCell: ({ row }) => (
        <Stack direction="row" gap={1} alignItems="center">
          <Typography variant="body2">{row.name}</Typography>
          {isMe(row) && <Chip size="small" label="You" variant="outlined" />}
        </Stack>
      ),
    },
    { field: 'email', headerName: 'Email', flex: 1.2, minWidth: 200 },
    { field: 'mobile', headerName: 'Mobile', width: 130 },
    {
      field: 'role',
      headerName: 'Tier',
      width: 150,
      renderCell: ({ row }) => (
        <Chip
          size="small"
          icon={row.role === 'super_admin' ? <ShieldIcon /> : <PersonIcon />}
          label={ROLE_LABEL[row.role] || row.role}
          color={row.role === 'super_admin' ? 'primary' : 'default'}
          variant={row.role === 'super_admin' ? 'filled' : 'outlined'}
        />
      ),
    },
    {
      field: 'is_active',
      headerName: 'Status',
      width: 130,
      renderCell: ({ row }) => (
        <Chip
          size="small"
          icon={row.is_active ? <CheckCircleIcon /> : <BlockIcon />}
          label={row.is_active ? 'Active' : 'Deactivated'}
          color={row.is_active ? 'success' : 'default'}
          variant="outlined"
        />
      ),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 150,
      sortable: false,
      renderCell: ({ row }) => (
        <Stack direction="row" gap={0.5}>
          <Tooltip title="Edit details and tier">
            <IconButton size="small" onClick={() => openEdit(row)}>
              <EditIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <Tooltip title={isMe(row)
            ? 'Change your own password from your profile'
            : 'Reset password'}>
            <span>
              <IconButton
                size="small"
                disabled={isMe(row)}
                onClick={() => setPasswordTarget(row)}
              >
                <KeyIcon fontSize="small" />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title={isMe(row)
            ? 'You cannot deactivate your own account'
            : row.is_active ? 'Deactivate' : 'Activate'}>
            <span>
              <IconButton
                size="small"
                color={row.is_active ? 'error' : 'success'}
                disabled={isMe(row)}
                onClick={() => setStatusTarget(row)}
              >
                {row.is_active ? <BlockIcon fontSize="small" /> : <CheckCircleIcon fontSize="small" />}
              </IconButton>
            </span>
          </Tooltip>
        </Stack>
      ),
    },
  ]

  // ── Not a super admin: say so plainly rather than showing an empty table ──
  if (me.isSuccess && !isSuper) {
    return (
      <Box>
        <PageHeader
          title="Admins"
          subtitle="Manage who can sign in to the admin panel"
          breadcrumbs={[{ label: 'Admin', href: '/admin/dashboard' }, { label: 'Admins' }]}
        />
        <EmptyState
          icon={ShieldIcon}
          message="Only a super admin can view or manage admin accounts. Ask one of them to raise your tier."
        />
      </Box>
    )
  }

  return (
    <Box>
      <PageHeader
        title="Admins"
        subtitle="Manage who can sign in to the admin panel"
        breadcrumbs={[{ label: 'Admin', href: '/admin/dashboard' }, { label: 'Admins' }]}
        actions={
          <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
            Add Admin
          </Button>
        }
      />

      {me.data?.is_bootstrap_super_admin && (
        <Alert severity="info" sx={{ mb: 2 }}>
          <AlertTitle>You are the acting super admin</AlertTitle>
          No super admin is set yet, so the longest-standing account — yours — holds the tier
          for now. Promote someone explicitly (including yourself, via another super admin) to
          make it permanent.
        </Alert>
      )}

      <Stack direction={{ xs: 'column', sm: 'row' }} gap={1.5} mb={2}>
        <TextField
          size="small"
          placeholder="Search name, email or mobile"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ flex: 1, minWidth: 220 }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>
            ),
          }}
        />
        <Select size="small" value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}
          sx={{ minWidth: 160 }}>
          <MenuItem value="all">All tiers</MenuItem>
          <MenuItem value="super_admin">Super admin</MenuItem>
          <MenuItem value="admin">Admin</MenuItem>
        </Select>
        <Select size="small" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}
          sx={{ minWidth: 160 }}>
          <MenuItem value="all">All statuses</MenuItem>
          <MenuItem value="active">Active</MenuItem>
          <MenuItem value="inactive">Deactivated</MenuItem>
        </Select>
      </Stack>

      <DataTable
        rows={rows}
        columns={columns}
        loading={me.isLoading || admins.isLoading}
        error={admins.error}
      />

      {/* ── Create ─────────────────────────────────────────────────────────── */}
      <DrawerForm
        open={createOpen}
        onClose={closeCreate}
        title="Add Admin"
        onSubmit={submitCreate}
        loading={createMutation.isPending}
        submitLabel="Create Admin"
      >
        <Stack gap={2}>
          <TextField label="Name" value={createForm.name} required
            error={Boolean(createErrors.name)} helperText={createErrors.name}
            onChange={(e) => setCreateForm({ ...createForm, name: e.target.value })} />
          <TextField label="Email" type="email" value={createForm.email} required
            error={Boolean(createErrors.email)} helperText={createErrors.email}
            onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })} />
          <TextField label="Mobile" value={createForm.mobile} required
            error={Boolean(createErrors.mobile)} helperText={createErrors.mobile}
            onChange={(e) => setCreateForm({ ...createForm, mobile: e.target.value })} />
          <TextField label="Password" type="password" value={createForm.password} required
            error={Boolean(createErrors.password)}
            helperText={createErrors.password || 'At least 8 characters'}
            onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })} />
          <FormControl>
            <InputLabel id="create-role">Tier</InputLabel>
            <Select labelId="create-role" label="Tier" value={createForm.role}
              onChange={(e) => setCreateForm({ ...createForm, role: e.target.value })}>
              <MenuItem value="admin">Admin</MenuItem>
              <MenuItem value="super_admin">Super admin</MenuItem>
            </Select>
            <FormHelperText>
              A super admin can manage other admin accounts and the database schema.
            </FormHelperText>
          </FormControl>
        </Stack>
      </DrawerForm>

      {/* ── Edit ───────────────────────────────────────────────────────────── */}
      <DrawerForm
        open={Boolean(editTarget)}
        onClose={closeEdit}
        title={`Edit ${editTarget?.name ?? 'Admin'}`}
        onSubmit={submitEdit}
        loading={updateMutation.isPending}
      >
        <Stack gap={2}>
          <TextField label="Name" value={editForm.name} required
            error={Boolean(editErrors.name)} helperText={editErrors.name}
            onChange={(e) => setEditForm({ ...editForm, name: e.target.value })} />
          <TextField label="Email" type="email" value={editForm.email} required
            error={Boolean(editErrors.email)} helperText={editErrors.email}
            onChange={(e) => setEditForm({ ...editForm, email: e.target.value })} />
          <TextField label="Mobile" value={editForm.mobile} required
            error={Boolean(editErrors.mobile)} helperText={editErrors.mobile}
            onChange={(e) => setEditForm({ ...editForm, mobile: e.target.value })} />
          <FormControlLabel
            control={
              <Switch
                checked={editForm.role === 'super_admin'}
                disabled={editTarget ? isMe(editTarget) : false}
                onChange={(e) =>
                  setEditForm({ ...editForm, role: e.target.checked ? 'super_admin' : 'admin' })}
              />
            }
            label="Super admin"
          />
          {editTarget && isMe(editTarget) && (
            <Alert severity="info">
              You cannot change your own tier. Another super admin has to do it.
            </Alert>
          )}
        </Stack>
      </DrawerForm>

      {/* ── Reset password ─────────────────────────────────────────────────── */}
      <DrawerForm
        open={Boolean(passwordTarget)}
        onClose={closePassword}
        title={`Reset password — ${passwordTarget?.name ?? ''}`}
        onSubmit={submitPassword}
        loading={passwordMutation.isPending}
        submitLabel="Reset Password"
      >
        <Stack gap={2}>
          <Alert severity="warning">
            This sets a new password immediately, without their current one. They are not
            notified — pass it on yourself, over a private channel.
          </Alert>
          <TextField label="New password" type="password" value={newPassword} required
            error={Boolean(passwordError)}
            helperText={passwordError || 'At least 8 characters'}
            onChange={(e) => setNewPassword(e.target.value)} />
        </Stack>
      </DrawerForm>

      {/* ── Activate / deactivate ──────────────────────────────────────────── */}
      <ConfirmDialog
        open={Boolean(statusTarget)}
        onClose={() => setStatusTarget(null)}
        onConfirm={() => statusMutation.mutate(statusTarget.id)}
        loading={statusMutation.isPending}
        title={statusTarget?.is_active ? 'Deactivate admin?' : 'Activate admin?'}
        confirmLabel={statusTarget?.is_active ? 'Deactivate' : 'Activate'}
        confirmColor={statusTarget?.is_active ? 'error' : 'primary'}
        message={statusTarget?.is_active
          ? `${statusTarget?.name} will no longer be able to sign in. The account is kept, not `
            + 'deleted, so this can be undone at any time.'
          : `${statusTarget?.name} will be able to sign in again.`}
      />
    </Box>
  )
}
