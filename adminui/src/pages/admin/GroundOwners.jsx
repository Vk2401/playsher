import React, { useMemo, useState } from 'react'
import {
  Box, Button, FormControlLabel, Grid, IconButton, InputAdornment,
  Stack, Switch, TextField, Tooltip, Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import CheckCircleIcon from '@mui/icons-material/CheckCircle'
import PersonOffIcon from '@mui/icons-material/PersonOff'
import PersonIcon from '@mui/icons-material/Person'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import SearchIcon from '@mui/icons-material/Search'
import BusinessIcon from '@mui/icons-material/Business'
import PersonAddIcon from '@mui/icons-material/PersonAdd'
import EditIcon from '@mui/icons-material/Edit'
import LockResetIcon from '@mui/icons-material/LockReset'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { groundOwnersApi } from '../../api/groundOwners.js'

const EMPTY_FORM = { name: '', email: '', mobile: '', password: '' }
const EMPTY_EDIT = { name: '', email: '', mobile: '', is_active: true, is_approved: false }

export default function AdminGroundOwners() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [search, setSearch] = useState('')
  const [deleteTarget, setDeleteTarget] = useState(null)
  const [addOpen, setAddOpen] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [formErrors, setFormErrors] = useState({})
  const [editTarget, setEditTarget] = useState(null)
  const [editForm, setEditForm] = useState(EMPTY_EDIT)
  const [editErrors, setEditErrors] = useState({})
  const [pwTarget, setPwTarget] = useState(null)
  const [pwValue, setPwValue] = useState('')
  const [pwError, setPwError] = useState('')

  // ── Fetch ────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'ground-owners'],
    queryFn: () => groundOwnersApi.getAll(),
    select: (res) => res.data,
  })

  const owners = useMemo(() => {
    const raw = data?.owners ?? data?.ground_owners ?? data?.data ?? data ?? []
    if (!search.trim()) return raw
    const q = search.toLowerCase()
    return raw.filter(
      (o) =>
        String(o.name ?? o.full_name ?? '').toLowerCase().includes(q) ||
        String(o.email ?? '').toLowerCase().includes(q) ||
        String(o.mobile ?? '').toLowerCase().includes(q),
    )
  }, [data, search])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const createMutation = useMutation({
    mutationFn: (data) => groundOwnersApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground-owners'] })
      notify.success('Ground owner created successfully')
      setAddOpen(false)
      setForm(EMPTY_FORM)
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to create ground owner'),
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => groundOwnersApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground-owners'] })
      notify.success('Ground owner updated')
      setEditTarget(null)
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to update ground owner'),
  })

  const resetPasswordMutation = useMutation({
    mutationFn: ({ id, password }) => groundOwnersApi.resetPassword(id, password),
    onSuccess: () => {
      notify.success('Password reset — the owner has been signed out everywhere')
      setPwTarget(null)
      setPwValue('')
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to reset password'),
  })

  const openEdit = (row) => {
    setEditErrors({})
    setEditForm({
      name: row.name ?? '',
      email: row.email ?? '',
      mobile: row.mobile ?? '',
      is_active: row.is_active ?? true,
      is_approved: row.is_approved ?? false,
    })
    setEditTarget({ id: row.id, name: row.name })
  }

  const submitEdit = () => {
    const errs = {}
    if (!editForm.name.trim()) errs.name = 'Name is required'
    if (!editForm.email.trim()) errs.email = 'Email is required'
    else if (!editForm.email.includes('@')) errs.email = 'Enter a valid email'
    if (!editForm.mobile.trim()) errs.mobile = 'Mobile is required'
    setEditErrors(errs)
    if (Object.keys(errs).length > 0) return

    updateMutation.mutate({
      id: editTarget.id,
      data: {
        name: editForm.name.trim(),
        email: editForm.email.trim(),
        mobile: editForm.mobile.trim(),
        is_active: editForm.is_active,
        is_approved: editForm.is_approved,
      },
    })
  }

  const submitPassword = () => {
    if (pwValue.length < 8) {
      setPwError('Password must be at least 8 characters')
      return
    }
    setPwError('')
    resetPasswordMutation.mutate({ id: pwTarget.id, password: pwValue })
  }

  const approveMutation = useMutation({
    mutationFn: (id) => groundOwnersApi.approve(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground-owners'] })
      notify.success('Owner approved successfully')
    },
    onError: () => notify.error('Failed to approve owner'),
  })

  const toggleMutation = useMutation({
    mutationFn: (id) => groundOwnersApi.toggleStatus(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground-owners'] })
      notify.success('Owner status updated')
    },
    onError: () => notify.error('Failed to update owner status'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => groundOwnersApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground-owners'] })
      notify.success('Ground owner deleted successfully')
      setDeleteTarget(null)
    },
    onError: () => notify.error('Failed to delete ground owner'),
  })

  // ── Add form helpers ───────────────────────────────────────────────────────
  const handleField = (field) => (e) =>
    setForm((f) => ({ ...f, [field]: e.target.value }))

  const validate = () => {
    const errs = {}
    if (!form.name.trim()) errs.name = 'Name is required'
    if (!form.email.trim()) errs.email = 'Email is required'
    if (!form.mobile.trim()) errs.mobile = 'Mobile is required'
    if (!form.password.trim()) errs.password = 'Password is required'
    setFormErrors(errs)
    return Object.keys(errs).length === 0
  }

  const handleAddSubmit = () => {
    if (!validate()) return
    createMutation.mutate({
      name: form.name.trim(),
      email: form.email.trim(),
      mobile: form.mobile.trim(),
      password: form.password,
    })
  }

  const handleAddClose = () => {
    setAddOpen(false)
    setForm(EMPTY_FORM)
    setFormErrors({})
  }

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    { field: 'id', headerName: 'ID', width: 70 },
    {
      field: 'name',
      headerName: 'Name',
      flex: 1,
      minWidth: 160,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={1}>
          <BusinessIcon fontSize="small" sx={{ color: 'text.disabled' }} />
          <Typography variant="body2" fontWeight={500}>
            {row.name ?? row.full_name ?? '—'}
          </Typography>
        </Box>
      ),
    },
    { field: 'email', headerName: 'Email', flex: 1.2, minWidth: 190 },
    {
      field: 'mobile',
      headerName: 'Mobile',
      width: 140,
      renderCell: ({ value }) => value ?? '—',
    },
    {
      field: 'is_approved',
      headerName: 'Approved',
      width: 120,
      renderCell: ({ value }) => (
        <StatusChip status={value ? 'approved' : 'pending'} />
      ),
    },
    {
      field: 'is_active',
      headerName: 'Active',
      width: 100,
      renderCell: ({ value }) => (
        <StatusChip status={value !== false ? 'active' : 'inactive'} />
      ),
    },
    {
      field: 'created_at',
      headerName: 'Joined',
      width: 130,
      renderCell: ({ value }) =>
        value ? dayjs(value).format('DD MMM YYYY') : '—',
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 170,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => {
        const isApproved = row.is_approved === true
        const isActive = row.is_active !== false
        const isApproving =
          approveMutation.isPending && approveMutation.variables === row.id
        const isToggling =
          toggleMutation.isPending && toggleMutation.variables === row.id

        return (
          <Box display="flex" alignItems="center" gap={0.5}>
            <Tooltip title="Edit profile">
              <IconButton size="small" color="primary" onClick={() => openEdit(row)}>
                <EditIcon fontSize="small" />
              </IconButton>
            </Tooltip>

            <Tooltip title="Reset password">
              <IconButton
                size="small"
                color="warning"
                onClick={() => { setPwValue(''); setPwError(''); setPwTarget({ id: row.id, name: row.name }) }}
              >
                <LockResetIcon fontSize="small" />
              </IconButton>
            </Tooltip>

            {/* Approve — only for unapproved owners */}
            {!isApproved && (
              <Tooltip title="Approve owner">
                <span>
                  <IconButton
                    size="small"
                    color="success"
                    disabled={isApproving}
                    onClick={() => approveMutation.mutate(row.id)}
                  >
                    <CheckCircleIcon fontSize="small" />
                  </IconButton>
                </span>
              </Tooltip>
            )}

            {/* Toggle active / inactive */}
            <Tooltip title={isActive ? 'Deactivate' : 'Activate'}>
              <span>
                <IconButton
                  size="small"
                  color={isActive ? 'warning' : 'success'}
                  disabled={isToggling}
                  onClick={() => toggleMutation.mutate(row.id)}
                >
                  {isActive ? (
                    <PersonOffIcon fontSize="small" />
                  ) : (
                    <PersonIcon fontSize="small" />
                  )}
                </IconButton>
              </span>
            </Tooltip>

            {/* Delete */}
            <Tooltip title="Delete owner">
              <span>
                <IconButton
                  size="small"
                  color="error"
                  onClick={() =>
                    setDeleteTarget({
                      id: row.id,
                      name: row.name ?? row.full_name ?? row.email,
                    })
                  }
                >
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
          </Box>
        )
      },
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title="Ground Owners"
        subtitle="Manage ground owner accounts"
        actions={
          <Button
            variant="contained"
            startIcon={<PersonAddIcon />}
            onClick={() => setAddOpen(true)}
          >
            Add Ground Owner
          </Button>
        }
      />

      <Box mb={2}>
        <TextField
          size="small"
          placeholder="Search by name, email or mobile…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ width: 320 }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
        />
      </Box>

      <DataTable
        rows={owners}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* Add Ground Owner Drawer */}
      <DrawerForm
        open={addOpen}
        onClose={handleAddClose}
        title="Add Ground Owner"
        onSubmit={handleAddSubmit}
        loading={createMutation.isPending}
        submitLabel="Create Owner"
      >
        <Grid container spacing={2}>
          <Grid item xs={12}>
            <TextField
              label="Full Name *"
              value={form.name}
              onChange={handleField('name')}
              fullWidth size="small"
              error={Boolean(formErrors.name)}
              helperText={formErrors.name}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Email *"
              value={form.email}
              onChange={handleField('email')}
              fullWidth size="small"
              type="email"
              error={Boolean(formErrors.email)}
              helperText={formErrors.email}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Mobile *"
              value={form.mobile}
              onChange={handleField('mobile')}
              fullWidth size="small"
              error={Boolean(formErrors.mobile)}
              helperText={formErrors.mobile}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Password *"
              value={form.password}
              onChange={handleField('password')}
              fullWidth size="small"
              type="password"
              error={Boolean(formErrors.password)}
              helperText={formErrors.password}
            />
          </Grid>
        </Grid>
      </DrawerForm>

      {/* Delete confirmation */}
      <DrawerForm
        open={Boolean(editTarget)}
        onClose={() => { setEditTarget(null); setEditErrors({}) }}
        title={`Edit ${editTarget?.name ?? 'ground owner'}`}
        onSubmit={submitEdit}
        loading={updateMutation.isPending}
        submitLabel="Save changes"
        width={460}
      >
        <Stack spacing={2}>
          <TextField
            label="Name" size="small" fullWidth required
            value={editForm.name}
            error={Boolean(editErrors.name)} helperText={editErrors.name}
            onChange={(e) => setEditForm((p) => ({ ...p, name: e.target.value }))}
          />
          <TextField
            label="Email" size="small" fullWidth required
            value={editForm.email}
            error={Boolean(editErrors.email)} helperText={editErrors.email}
            onChange={(e) => setEditForm((p) => ({ ...p, email: e.target.value }))}
          />
          <TextField
            label="Mobile" size="small" fullWidth required
            value={editForm.mobile}
            error={Boolean(editErrors.mobile)} helperText={editErrors.mobile}
            onChange={(e) => setEditForm((p) => ({ ...p, mobile: e.target.value }))}
          />
          <FormControlLabel
            control={
              <Switch
                checked={editForm.is_approved}
                onChange={(e) => setEditForm((p) => ({ ...p, is_approved: e.target.checked }))}
              />
            }
            label={editForm.is_approved
              ? 'Approved — their grounds can go live'
              : 'Not approved — their grounds stay hidden'}
          />
          <FormControlLabel
            control={
              <Switch
                checked={editForm.is_active}
                onChange={(e) => setEditForm((p) => ({ ...p, is_active: e.target.checked }))}
              />
            }
            label={editForm.is_active
              ? 'Active — can sign in'
              : 'Deactivated — signed out of every device'}
          />
        </Stack>
      </DrawerForm>

      <DrawerForm
        open={Boolean(pwTarget)}
        onClose={() => { setPwTarget(null); setPwValue(''); setPwError('') }}
        title={`Reset password — ${pwTarget?.name ?? ''}`}
        onSubmit={submitPassword}
        loading={resetPasswordMutation.isPending}
        submitLabel="Reset password"
        width={420}
      >
        <Stack spacing={2}>
          <Typography variant="body2" color="text.secondary">
            Sets a new password immediately and signs this owner out of every
            device. Tell them the new password through a channel you trust —
            it is not emailed to them.
          </Typography>
          <TextField
            label="New password" size="small" fullWidth required
            type="text"
            autoComplete="new-password"
            value={pwValue}
            error={Boolean(pwError)}
            helperText={pwError || 'At least 8 characters'}
            onChange={(e) => { setPwValue(e.target.value); setPwError('') }}
          />
        </Stack>
      </DrawerForm>

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget.id)}
        loading={deleteMutation.isPending}
        title="Delete Ground Owner"
        message={`Are you sure you want to permanently delete "${deleteTarget?.name}"? All associated data may be affected.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
