import React, { useMemo, useRef, useState } from 'react'
import {
  Box,
  Button,
  Chip,
  FormControlLabel,
  IconButton,
  InputAdornment,
  Stack,
  Switch,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import dayjs from 'dayjs'

import AddIcon from '@mui/icons-material/Add'
import VisibilityOutlinedIcon from '@mui/icons-material/VisibilityOutlined'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import SearchIcon from '@mui/icons-material/Search'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { groundsApi } from '../../api/grounds.js'

const EMPTY_FORM = {
  name: '',
  description: '',
  about: '',
  venue_rules: '',
  address: '',
  latitude: '',
  longitude: '',
  contact_number: '',
  is_active: true,
}

export default function OwnerGrounds() {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const navigate = useNavigate()
  const fileInputRef = useRef(null)

  const [search, setSearch] = useState('')
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [mainImageFile, setMainImageFile] = useState(null)
  const [deleteTarget, setDeleteTarget] = useState(null) // { id, name }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'grounds'],
    queryFn: () => groundsApi.getOwnerGrounds(),
    select: (res) => res.data,
  })

  const grounds = useMemo(() => {
    const raw = data?.grounds ?? data?.data ?? data ?? []
    if (!search.trim()) return raw
    const q = search.toLowerCase()
    return raw.filter(
      (g) =>
        String(g.name ?? '').toLowerCase().includes(q) ||
        String(g.city ?? '').toLowerCase().includes(q) ||
        String(g.address ?? '').toLowerCase().includes(q),
    )
  }, [data, search])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const createMutation = useMutation({
    mutationFn: (fd) => groundsApi.create(fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'grounds'] })
      notify.success('Ground created successfully')
      handleCloseDrawer()
    },
    onError: () => notify.error('Failed to create ground'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => groundsApi.deleteOwner(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'grounds'] })
      notify.success('Ground deleted successfully')
      setDeleteTarget(null)
    },
    onError: () => notify.error('Failed to delete ground'),
  })

  // ── Drawer helpers ────────────────────────────────────────────────────────
  const handleOpenDrawer = () => {
    setForm(EMPTY_FORM)
    setMainImageFile(null)
    setDrawerOpen(true)
  }

  const handleCloseDrawer = () => {
    setDrawerOpen(false)
    setForm(EMPTY_FORM)
    setMainImageFile(null)
    if (fileInputRef.current) fileInputRef.current.value = ''
  }

  const handleFormChange = (field) => (e) => {
    setForm((prev) => ({ ...prev, [field]: e.target.value }))
  }

  const handleSubmit = () => {
    if (!form.name.trim()) {
      notify.warning('Ground name is required')
      return
    }
    const fd = new FormData()
    Object.entries(form).forEach(([k, v]) => {
      if (k === 'is_active') {
        fd.append(k, v ? 'true' : 'false')
      } else if (v !== '') {
        fd.append(k, v)
      }
    })
    if (mainImageFile) fd.append('cover_image', mainImageFile)
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
      minWidth: 160,
      renderCell: ({ value }) => (
        <Typography variant="body2" fontWeight={500}>
          {value ?? '—'}
        </Typography>
      ),
    },
    {
      field: 'city',
      headerName: 'City',
      width: 120,
      renderCell: ({ value }) => value ?? '—',
    },
    {
      field: 'address',
      headerName: 'Address',
      flex: 1.2,
      minWidth: 160,
      renderCell: ({ value }) => (
        <Tooltip title={value ?? ''}>
          <Typography
            variant="body2"
            color="text.secondary"
            noWrap
            sx={{ maxWidth: 200 }}
          >
            {value ?? '—'}
          </Typography>
        </Tooltip>
      ),
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 110,
      renderCell: ({ value }) => <StatusChip status={value ?? 'active'} />,
    },
    {
      field: 'is_approved',
      headerName: 'Approved',
      width: 110,
      renderCell: ({ value }) => (
        <Chip
          label={value ? 'Approved' : 'Pending'}
          color={value ? 'success' : 'warning'}
          size="small"
          sx={{ fontWeight: 600, fontSize: '0.72rem' }}
        />
      ),
    },
    {
      field: 'created_at',
      headerName: 'Created',
      width: 130,
      renderCell: ({ value }) =>
        value ? dayjs(value).format('DD MMM YYYY') : '—',
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 100,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={0.5}>
          <Tooltip title="View details">
            <span>
              <IconButton
                size="small"
                color="primary"
                onClick={() => navigate(`/owner/grounds/${row.id}`)}
              >
                <VisibilityOutlinedIcon fontSize="small" />
              </IconButton>
            </span>
          </Tooltip>
          <Tooltip title="Delete ground">
            <span>
              <IconButton
                size="small"
                color="error"
                onClick={() =>
                  setDeleteTarget({ id: row.id, name: row.name ?? `#${row.id}` })
                }
              >
                <DeleteOutlineIcon fontSize="small" />
              </IconButton>
            </span>
          </Tooltip>
        </Box>
      ),
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title="My Grounds"
        subtitle="Manage and monitor your sports grounds"
        actions={
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={handleOpenDrawer}
          >
            Add Ground
          </Button>
        }
      />

      {/* Search */}
      <Box mb={2}>
        <TextField
          size="small"
          placeholder="Search by name, city or address…"
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
        rows={grounds}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* Create DrawerForm */}
      <DrawerForm
        open={drawerOpen}
        onClose={handleCloseDrawer}
        title="Add New Ground"
        onSubmit={handleSubmit}
        loading={createMutation.isPending}
        submitLabel="Create Ground"
        width={500}
      >
        <Stack spacing={2.5}>
          <TextField
            label="Ground Name"
            value={form.name}
            onChange={handleFormChange('name')}
            size="small"
            fullWidth
            required
          />
          <TextField
            label="Description"
            value={form.description}
            onChange={handleFormChange('description')}
            size="small"
            fullWidth
            multiline
            rows={3}
            placeholder="Brief description of the ground…"
          />
          <TextField
            label="About"
            value={form.about}
            onChange={handleFormChange('about')}
            size="small"
            fullWidth
            multiline
            rows={3}
            placeholder="Detailed info about the ground…"
          />
          <TextField
            label="Venue Rules"
            value={form.venue_rules}
            onChange={handleFormChange('venue_rules')}
            size="small"
            fullWidth
            multiline
            rows={3}
            placeholder="Rules for players at this venue…"
          />
          <TextField
            label="Address"
            value={form.address}
            onChange={handleFormChange('address')}
            size="small"
            fullWidth
          />
          <Stack direction="row" spacing={2}>
            <TextField
              label="Latitude"
              type="number"
              value={form.latitude}
              onChange={handleFormChange('latitude')}
              size="small"
              fullWidth
              inputProps={{ step: 'any' }}
            />
            <TextField
              label="Longitude"
              type="number"
              value={form.longitude}
              onChange={handleFormChange('longitude')}
              size="small"
              fullWidth
              inputProps={{ step: 'any' }}
            />
          </Stack>
          <TextField
            label="Contact Number"
            value={form.contact_number}
            onChange={handleFormChange('contact_number')}
            size="small"
            fullWidth
          />
          <FormControlLabel
            control={
              <Switch
                checked={form.is_active}
                onChange={(e) => setForm((prev) => ({ ...prev, is_active: e.target.checked }))}
              />
            }
            label="Open for Booking"
          />
          <Box>
            <Typography variant="caption" color="text.secondary" mb={0.5} display="block">
              Main Image
            </Typography>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'block', fontSize: 14 }}
              onChange={(e) => setMainImageFile(e.target.files?.[0] ?? null)}
            />
            {mainImageFile && (
              <Typography variant="caption" color="text.secondary" mt={0.5} display="block">
                Selected: {mainImageFile.name}
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
        title="Delete Ground"
        message={`Are you sure you want to permanently delete "${deleteTarget?.name}"? All slots and data linked to this ground will be removed.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
