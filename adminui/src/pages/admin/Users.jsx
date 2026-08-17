import React, { useMemo, useState } from 'react'
import {
  Box, Button, Grid, IconButton, InputAdornment,
  TextField, Tooltip, Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import PersonIcon from '@mui/icons-material/Person'
import PersonOffIcon from '@mui/icons-material/PersonOff'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import EditIcon from '@mui/icons-material/Edit'
import SearchIcon from '@mui/icons-material/Search'
import PersonAddIcon from '@mui/icons-material/PersonAdd'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { usersApi } from '../../api/users.js'

const EMPTY_FORM = { name: '', email: '', mobile: '', password: '' }
const EMPTY_EDIT_FORM = { name: '', email: '', mobile: '' }

export default function AdminUsers() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [search, setSearch] = useState('')
  const [deleteTarget, setDeleteTarget] = useState(null)
  const [addOpen, setAddOpen] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [formErrors, setFormErrors] = useState({})

  // ── Edit state ────────────────────────────────────────────────────────────
  const [editTarget, setEditTarget] = useState(null)   // { id, name, email, mobile }
  const [editForm, setEditForm] = useState(EMPTY_EDIT_FORM)
  const [editFormErrors, setEditFormErrors] = useState({})

  // ── Fetch ────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'users'],
    queryFn: () => usersApi.getAll(),
    select: (res) => res.data,
  })

  const users = useMemo(() => {
    const raw = data?.users ?? data?.data ?? data ?? []
    if (!search.trim()) return raw
    const q = search.toLowerCase()
    return raw.filter(
      (u) =>
        String(u.name ?? '').toLowerCase().includes(q) ||
        String(u.email ?? '').toLowerCase().includes(q) ||
        String(u.mobile ?? '').toLowerCase().includes(q),
    )
  }, [data, search])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const createMutation = useMutation({
    mutationFn: (data) => usersApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] })
      notify.success('User created successfully')
      setAddOpen(false)
      setForm(EMPTY_FORM)
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to create user'),
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }) => usersApi.update(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] })
      notify.success('User updated')
      setEditTarget(null)
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to update user'),
  })

  const toggleMutation = useMutation({
    mutationFn: (id) => usersApi.toggleStatus(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] })
      notify.success('User status updated')
    },
    onError: () => notify.error('Failed to update user status'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => usersApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'users'] })
      notify.success('User deleted successfully')
      setDeleteTarget(null)
    },
    onError: () => notify.error('Failed to delete user'),
  })

  // ── Add form helpers ───────────────────────────────────────────────────────
  const handleField = (field) => (e) =>
    setForm((f) => ({ ...f, [field]: e.target.value }))

  const validate = () => {
    const errs = {}
    if (!form.name.trim()) errs.name = 'Name is required'
    if (!form.mobile.trim()) errs.mobile = 'Mobile is required'
    if (!form.password.trim()) errs.password = 'Password is required'
    setFormErrors(errs)
    return Object.keys(errs).length === 0
  }

  const handleAddSubmit = () => {
    if (!validate()) return
    createMutation.mutate({
      name: form.name.trim(),
      email: form.email.trim() || undefined,
      mobile: form.mobile.trim(),
      password: form.password,
    })
  }

  const handleAddClose = () => {
    setAddOpen(false)
    setForm(EMPTY_FORM)
    setFormErrors({})
  }

  // ── Edit form helpers ──────────────────────────────────────────────────────
  const handleEditField = (field) => (e) =>
    setEditForm((f) => ({ ...f, [field]: e.target.value }))

  const validateEdit = () => {
    const errs = {}
    if (!editForm.name.trim()) errs.name = 'Name is required'
    if (!editForm.mobile.trim()) errs.mobile = 'Mobile is required'
    setEditFormErrors(errs)
    return Object.keys(errs).length === 0
  }

  const handleEditOpen = (row) => {
    setEditTarget({ id: row.id, name: row.name ?? row.full_name ?? '', email: row.email ?? '', mobile: row.mobile ?? '' })
    setEditForm({
      name: row.name ?? row.full_name ?? '',
      email: row.email ?? '',
      mobile: row.mobile ?? '',
    })
    setEditFormErrors({})
  }

  const handleEditClose = () => {
    setEditTarget(null)
    setEditForm(EMPTY_EDIT_FORM)
    setEditFormErrors({})
  }

  const handleEditSubmit = () => {
    if (!validateEdit()) return
    updateMutation.mutate({
      id: editTarget.id,
      payload: {
        name: editForm.name.trim(),
        mobile: editForm.mobile.trim(),
        email: editForm.email.trim() || undefined,
      },
    })
  }

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    { field: 'id', headerName: 'ID', width: 70, sortable: true },
    {
      field: 'name',
      headerName: 'Name',
      flex: 1,
      minWidth: 150,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={1}>
          <PersonIcon fontSize="small" sx={{ color: 'text.disabled' }} />
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
      field: 'is_active',
      headerName: 'Status',
      width: 120,
      renderCell: ({ row }) => {
        const active = row.is_active !== false && String(row.status ?? 'active').toLowerCase() !== 'inactive'
        return <StatusChip status={active ? 'active' : 'inactive'} />
      },
    },
    {
      field: 'created_at',
      headerName: 'Joined',
      width: 140,
      renderCell: ({ value }) =>
        value ? dayjs(value).format('DD MMM YYYY') : '—',
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 140,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => {
        const isActive =
          row.is_active !== false &&
          String(row.status ?? 'active').toLowerCase() !== 'inactive'
        const isToggling =
          toggleMutation.isPending && toggleMutation.variables === row.id
        return (
          <Box display="flex" alignItems="center" gap={0.5}>
            <Tooltip title="Edit user">
              <span>
                <IconButton
                  size="small"
                  color="primary"
                  onClick={() => handleEditOpen(row)}
                >
                  <EditIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>

            <Tooltip title={isActive ? 'Deactivate user' : 'Activate user'}>
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

            <Tooltip title="Delete user">
              <span>
                <IconButton
                  size="small"
                  color="error"
                  onClick={() =>
                    setDeleteTarget({ id: row.id, name: row.name ?? row.email })
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
        title="Users"
        subtitle="Manage platform users"
        actions={
          <Button
            variant="contained"
            startIcon={<PersonAddIcon />}
            onClick={() => setAddOpen(true)}
          >
            Add User
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
        rows={users}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* Add User Drawer */}
      <DrawerForm
        open={addOpen}
        onClose={handleAddClose}
        title="Add New User"
        onSubmit={handleAddSubmit}
        loading={createMutation.isPending}
        submitLabel="Create User"
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
              label="Email (optional)"
              value={form.email}
              onChange={handleField('email')}
              fullWidth size="small"
              type="email"
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

      {/* Edit User Drawer */}
      <DrawerForm
        open={Boolean(editTarget)}
        onClose={handleEditClose}
        title="Edit User"
        onSubmit={handleEditSubmit}
        loading={updateMutation.isPending}
        submitLabel="Save Changes"
      >
        <Grid container spacing={2}>
          <Grid item xs={12}>
            <TextField
              label="Full Name *"
              value={editForm.name}
              onChange={handleEditField('name')}
              fullWidth size="small"
              error={Boolean(editFormErrors.name)}
              helperText={editFormErrors.name}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Mobile *"
              value={editForm.mobile}
              onChange={handleEditField('mobile')}
              fullWidth size="small"
              error={Boolean(editFormErrors.mobile)}
              helperText={editFormErrors.mobile}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              label="Email (optional)"
              value={editForm.email}
              onChange={handleEditField('email')}
              fullWidth size="small"
              type="email"
            />
          </Grid>
        </Grid>
      </DrawerForm>

      {/* Delete confirmation */}
      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget.id)}
        loading={deleteMutation.isPending}
        title="Delete User"
        message={`Are you sure you want to permanently delete "${deleteTarget?.name}"? This action cannot be undone.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
