import React, { useMemo, useRef, useState } from 'react'
import {
  Box,
  Button,
  Chip,
  IconButton,
  InputAdornment,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import AddIcon from '@mui/icons-material/Add'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import SearchIcon from '@mui/icons-material/Search'
import PersonIcon from '@mui/icons-material/Person'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { coachesApi } from '../../api/coaches.js'

const EMPTY_FORM = {
  name: '',
  email: '',
  phone: '',
  sport: '',
  experience_years: '',
  hourly_rate: '',
  bio: '',
}

export default function AdminCoaches() {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const fileInputRef = useRef(null)

  const [search, setSearch] = useState('')
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [profileImageFile, setProfileImageFile] = useState(null)
  const [deleteTarget, setDeleteTarget] = useState(null) // { id, name }
  const [approvingId, setApprovingId] = useState(null)

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'coaches'],
    queryFn: () => coachesApi.getAll(),
    select: (res) => res.data,
  })

  const coaches = useMemo(() => {
    const raw = data?.coaches ?? data?.data ?? data ?? []
    if (!search.trim()) return raw
    const q = search.toLowerCase()
    return raw.filter(
      (c) =>
        String(c.name ?? '').toLowerCase().includes(q) ||
        String(c.email ?? '').toLowerCase().includes(q) ||
        String(c.sport ?? '').toLowerCase().includes(q),
    )
  }, [data, search])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const approveMutation = useMutation({
    mutationFn: (id) => coachesApi.approve(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'coaches'] })
      notify.success('Coach approved successfully')
      setApprovingId(null)
    },
    onError: () => {
      notify.error('Failed to approve coach')
      setApprovingId(null)
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => coachesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'coaches'] })
      notify.success('Coach deleted successfully')
      setDeleteTarget(null)
    },
    onError: () => notify.error('Failed to delete coach'),
  })

  const createMutation = useMutation({
    mutationFn: (fd) => coachesApi.create(fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'coaches'] })
      notify.success('Coach created successfully')
      handleCloseDrawer()
    },
    onError: () => notify.error('Failed to create coach'),
  })

  // ── Drawer helpers ────────────────────────────────────────────────────────
  const handleOpenDrawer = () => {
    setForm(EMPTY_FORM)
    setProfileImageFile(null)
    setDrawerOpen(true)
  }

  const handleCloseDrawer = () => {
    setDrawerOpen(false)
    setForm(EMPTY_FORM)
    setProfileImageFile(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const handleFormChange = (field) => (e) => {
    setForm((prev) => ({ ...prev, [field]: e.target.value }))
  }

  const handleSubmit = () => {
    if (!form.name.trim() || !form.email.trim()) {
      notify.warning('Name and email are required')
      return
    }
    const fd = new FormData()
    Object.entries(form).forEach(([k, v]) => {
      if (v !== '') fd.append(k, v)
    })
    if (profileImageFile) fd.append('profile_image', profileImageFile)
    createMutation.mutate(fd)
  }

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
    },
    {
      field: 'name',
      headerName: 'Name',
      flex: 1,
      minWidth: 150,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={1}>
          <PersonIcon fontSize="small" sx={{ color: 'text.disabled' }} />
          <Typography variant="body2" fontWeight={500}>
            {row.name ?? '—'}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'email',
      headerName: 'Email',
      flex: 1.2,
      minWidth: 180,
    },
    {
      field: 'sport',
      headerName: 'Sport',
      width: 120,
      renderCell: ({ value }) => value ?? '—',
    },
    {
      field: 'experience_years',
      headerName: 'Exp (yrs)',
      width: 90,
      renderCell: ({ value }) => value ?? '—',
    },
    {
      field: 'hourly_rate',
      headerName: 'Rate (PKR)',
      width: 110,
      renderCell: ({ value }) =>
        value != null ? `₨ ${Number(value).toLocaleString()}` : '—',
    },
    {
      field: 'is_approved',
      headerName: 'Approved',
      width: 110,
      renderCell: ({ value }) => (
        <Chip
          label={value ? 'Yes' : 'No'}
          color={value ? 'success' : 'warning'}
          size="small"
          sx={{ fontWeight: 600, fontSize: '0.72rem' }}
        />
      ),
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 110,
      renderCell: ({ value }) => <StatusChip status={value ?? 'active'} />,
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 110,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => {
        const isApproving =
          approveMutation.isPending && approvingId === row.id
        return (
          <Box display="flex" alignItems="center" gap={0.5}>
            {!row.is_approved && (
              <Tooltip title="Approve coach">
                <span>
                  <IconButton
                    size="small"
                    color="success"
                    disabled={isApproving}
                    onClick={() => {
                      setApprovingId(row.id)
                      approveMutation.mutate(row.id)
                    }}
                  >
                    <CheckCircleOutlineIcon fontSize="small" />
                  </IconButton>
                </span>
              </Tooltip>
            )}
            <Tooltip title="Delete coach">
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
        title="Coaches"
        subtitle="Manage platform coaches"
        actions={
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={handleOpenDrawer}
          >
            Add Coach
          </Button>
        }
      />

      {/* Search */}
      <Box mb={2}>
        <TextField
          size="small"
          placeholder="Search by name, email or sport…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ width: 340 }}
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
        rows={coaches}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* Create DrawerForm */}
      <DrawerForm
        open={drawerOpen}
        onClose={handleCloseDrawer}
        title="Add Coach"
        onSubmit={handleSubmit}
        loading={createMutation.isPending}
        submitLabel="Create Coach"
        width={480}
      >
        <Stack spacing={2.5}>
          <TextField
            label="Full Name"
            value={form.name}
            onChange={handleFormChange('name')}
            size="small"
            fullWidth
            required
          />
          <TextField
            label="Email"
            type="email"
            value={form.email}
            onChange={handleFormChange('email')}
            size="small"
            fullWidth
            required
          />
          <TextField
            label="Phone"
            value={form.phone}
            onChange={handleFormChange('phone')}
            size="small"
            fullWidth
          />
          <TextField
            label="Sport"
            value={form.sport}
            onChange={handleFormChange('sport')}
            size="small"
            fullWidth
            placeholder="e.g. Football, Cricket"
          />
          <TextField
            label="Experience (years)"
            type="number"
            value={form.experience_years}
            onChange={handleFormChange('experience_years')}
            size="small"
            fullWidth
            inputProps={{ min: 0 }}
          />
          <TextField
            label="Hourly Rate (PKR)"
            type="number"
            value={form.hourly_rate}
            onChange={handleFormChange('hourly_rate')}
            size="small"
            fullWidth
            inputProps={{ min: 0 }}
          />
          <TextField
            label="Bio"
            value={form.bio}
            onChange={handleFormChange('bio')}
            size="small"
            fullWidth
            multiline
            rows={3}
            placeholder="Short bio about the coach…"
          />
          <Box>
            <Typography variant="caption" color="text.secondary" mb={0.5} display="block">
              Profile Image
            </Typography>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'block', fontSize: 14 }}
              onChange={(e) => setProfileImageFile(e.target.files?.[0] ?? null)}
            />
            {profileImageFile && (
              <Typography variant="caption" color="text.secondary" mt={0.5} display="block">
                Selected: {profileImageFile.name}
              </Typography>
            )}
          </Box>
        </Stack>
      </DrawerForm>

      {/* Delete confirmation */}
      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget.id)}
        loading={deleteMutation.isPending}
        title="Delete Coach"
        message={`Are you sure you want to permanently delete "${deleteTarget?.name}"? This action cannot be undone.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
