import React, { useMemo, useState } from 'react'
import {
  Box,
  Button,
  Chip,
  FormControl,
  FormControlLabel,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Select,
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
import CheckCircleIcon from '@mui/icons-material/CheckCircle'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import OpenInNewIcon from '@mui/icons-material/OpenInNew'
import SearchIcon from '@mui/icons-material/Search'
import SportsIcon from '@mui/icons-material/Sports'
import ToggleOffIcon from '@mui/icons-material/ToggleOff'
import ToggleOnIcon from '@mui/icons-material/ToggleOn'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { groundsApi } from '../../api/grounds.js'
import { groundOwnersApi } from '../../api/groundOwners.js'

const EMPTY_FORM = {
  name: '', description: '', about: '', venue_rules: '',
  address: '', latitude: '', longitude: '', contact_number: '',
  open_for_booking: true, owner_id: '',
}

export default function AdminGrounds() {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const navigate = useNavigate()
  const [search, setSearch] = useState('')

  // ── Drawer state ──────────────────────────────────────────────────────────
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [form, setForm] = useState(EMPTY_FORM)
  const [formErrors, setFormErrors] = useState({})

  // ── Delete confirm state ──────────────────────────────────────────────────
  const [deleteTarget, setDeleteTarget] = useState(null) // { id, name }

  // ── Fetch ────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'grounds'],
    queryFn: () => groundsApi.getAll(),
    select: (res) => res.data,
  })

  const { data: ownersData } = useQuery({
    queryKey: ['admin', 'ground-owners'],
    queryFn: () => groundOwnersApi.getAll(),
    select: (res) => res.data,
  })
  const owners = ownersData?.owners ?? ownersData?.ground_owners ?? ownersData?.data ?? ownersData ?? []

  const grounds = useMemo(() => {
    const raw = data?.grounds ?? data?.data ?? data ?? []
    if (!search.trim()) return raw
    const q = search.toLowerCase()
    return raw.filter(
      (g) =>
        String(g.name ?? '').toLowerCase().includes(q) ||
        String(g.city ?? g.location ?? '').toLowerCase().includes(q) ||
        String(g.owner?.name ?? g.owner?.full_name ?? '').toLowerCase().includes(q),
    )
  }, [data, search])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const approveMutation = useMutation({
    mutationFn: (id) => groundsApi.approve(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'grounds'] })
      notify.success('Ground approved successfully')
    },
    onError: () => notify.error('Failed to approve ground'),
  })

  const toggleMutation = useMutation({
    mutationFn: (id) => groundsApi.toggleStatus(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'grounds'] })
      notify.success('Ground status updated')
    },
    onError: () => notify.error('Failed to update ground status'),
  })

  const createMutation = useMutation({
    mutationFn: (fd) => groundsApi.adminCreate(fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'grounds'] })
      notify.success('Ground created successfully')
      handleCloseDrawer()
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to create ground')
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => groundsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'grounds'] })
      notify.success(`"${deleteTarget?.name}" deleted`)
      setDeleteTarget(null)
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to delete ground')
    },
  })

  // ── Drawer helpers ────────────────────────────────────────────────────────
  const handleOpenDrawer = () => {
    setForm(EMPTY_FORM)
    setFormErrors({})
    setDrawerOpen(true)
  }

  const handleCloseDrawer = () => {
    setDrawerOpen(false)
    setForm(EMPTY_FORM)
    setFormErrors({})
  }

  const handleFieldChange = (e) => {
    const { name, value } = e.target
    setForm((prev) => ({ ...prev, [name]: value }))
    if (formErrors[name]) setFormErrors((prev) => ({ ...prev, [name]: '' }))
  }

  const handleSwitchChange = (e) => {
    setForm((prev) => ({ ...prev, open_for_booking: e.target.checked }))
  }

  const validate = () => {
    const errs = {}
    if (!form.name.trim()) errs.name = 'Name is required'
    if (!form.address.trim()) errs.address = 'Address is required'
    setFormErrors(errs)
    return Object.keys(errs).length === 0
  }

  const handleSubmit = () => {
    if (!validate()) return
    const payload = {
      name: form.name.trim(),
      open_for_booking: form.open_for_booking,
    }
    const optionalText = ['description', 'about', 'venue_rules', 'address', 'contact_number']
    optionalText.forEach((key) => {
      if (form[key].trim() !== '') payload[key] = form[key].trim()
    })
    if (form.latitude !== '') payload.latitude = parseFloat(form.latitude)
    if (form.longitude !== '') payload.longitude = parseFloat(form.longitude)
    if (form.owner_id !== '') payload.owner_id = Number(form.owner_id)
    createMutation.mutate(payload)
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
      headerName: 'Ground Name',
      flex: 1.2,
      minWidth: 170,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={1}>
          <SportsIcon fontSize="small" sx={{ color: 'text.disabled' }} />
          <Typography variant="body2" fontWeight={500}>
            {row.name ?? '—'}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'city',
      headerName: 'Location',
      width: 140,
      renderCell: ({ row }) => row.city ?? row.location ?? '—',
    },
    {
      field: 'owner',
      headerName: 'Owner',
      width: 160,
      renderCell: ({ row }) => {
        const owner = row.owner ?? {}
        const ownerName = owner.name ?? owner.full_name ?? row.owner_name ?? '—'
        return (
          <Typography variant="body2" sx={{ color: 'text.secondary' }}>
            {ownerName}
          </Typography>
        )
      },
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 120,
      renderCell: ({ value }) => <StatusChip status={value ?? 'inactive'} />,
    },
    {
      field: 'is_approved',
      headerName: 'Approved',
      width: 110,
      renderCell: ({ value }) =>
        value ? (
          <Chip label="Approved" color="success" size="small" sx={{ fontWeight: 600, fontSize: '0.72rem' }} />
        ) : (
          <Chip label="Pending" color="warning" size="small" sx={{ fontWeight: 600, fontSize: '0.72rem' }} />
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
      width: 160,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => {
        const isActive =
          String(row.status ?? 'inactive').toLowerCase() === 'active'
        const isApproved = Boolean(row.is_approved)

        const isApproving =
          approveMutation.isPending && approveMutation.variables === row.id
        const isToggling =
          toggleMutation.isPending && toggleMutation.variables === row.id
        const isDeleting =
          deleteMutation.isPending && deleteTarget?.id === row.id

        return (
          <Stack direction="row" alignItems="center" spacing={0.5}>
            {/* Approve — only shown if not yet approved */}
            {!isApproved && (
              <Tooltip title="Approve ground">
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

            {/* Toggle status */}
            <Tooltip title={isActive ? 'Deactivate ground' : 'Activate ground'}>
              <span>
                <IconButton
                  size="small"
                  color={isActive ? 'warning' : 'success'}
                  disabled={isToggling}
                  onClick={() => toggleMutation.mutate(row.id)}
                >
                  {isActive ? (
                    <ToggleOffIcon fontSize="small" />
                  ) : (
                    <ToggleOnIcon fontSize="small" />
                  )}
                </IconButton>
              </span>
            </Tooltip>

            {/* View detail */}
            <Tooltip title="View ground details">
              <IconButton
                size="small"
                color="primary"
                onClick={() => navigate(`/admin/grounds/${row.id}`)}
              >
                <OpenInNewIcon fontSize="small" />
              </IconButton>
            </Tooltip>

            {/* Delete */}
            <Tooltip title="Delete ground">
              <span>
                <IconButton
                  size="small"
                  color="error"
                  disabled={isDeleting}
                  onClick={() => setDeleteTarget({ id: row.id, name: row.name })}
                >
                  <DeleteOutlineIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
          </Stack>
        )
      },
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title="Grounds"
        subtitle="All sports grounds on the platform"
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

      {/* Search bar */}
      <Box mb={2}>
        <TextField
          size="small"
          placeholder="Search by name, city or owner…"
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

      {/* ── Create Ground Drawer ─────────────────────────────────────────── */}
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
            name="name"
            value={form.name}
            onChange={handleFieldChange}
            error={!!formErrors.name}
            helperText={formErrors.name}
            fullWidth
            required
            autoFocus
          />

          <TextField
            label="Description"
            name="description"
            value={form.description}
            onChange={handleFieldChange}
            multiline
            rows={3}
            fullWidth
            placeholder="Short description of the ground…"
          />

          <TextField
            label="About"
            name="about"
            value={form.about}
            onChange={handleFieldChange}
            multiline
            rows={3}
            fullWidth
            placeholder="Detailed information about the ground…"
          />

          <TextField
            label="Venue Rules"
            name="venue_rules"
            value={form.venue_rules}
            onChange={handleFieldChange}
            multiline
            rows={3}
            fullWidth
            placeholder="Rules and regulations for the venue…"
          />

          <TextField
            label="Address"
            name="address"
            value={form.address}
            onChange={handleFieldChange}
            error={!!formErrors.address}
            helperText={formErrors.address}
            fullWidth
            required
          />

          <Stack direction="row" spacing={2}>
            <TextField
              label="Latitude"
              name="latitude"
              type="number"
              value={form.latitude}
              onChange={handleFieldChange}
              fullWidth
              placeholder="e.g. 33.7294"
            />
            <TextField
              label="Longitude"
              name="longitude"
              type="number"
              value={form.longitude}
              onChange={handleFieldChange}
              fullWidth
              placeholder="e.g. 73.0931"
            />
          </Stack>

          <TextField
            label="Contact Number"
            name="contact_number"
            value={form.contact_number}
            onChange={handleFieldChange}
            fullWidth
            placeholder="e.g. +923001234567"
          />

          <FormControl fullWidth size="small">
            <InputLabel>Ground Owner (optional)</InputLabel>
            <Select
              name="owner_id"
              value={form.owner_id}
              label="Ground Owner (optional)"
              onChange={handleFieldChange}
            >
              <MenuItem value=""><em>None</em></MenuItem>
              {owners.map((o) => (
                <MenuItem key={o.id} value={o.id}>
                  {o.name ?? o.full_name ?? o.email} {o.email ? `(${o.email})` : ''}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <FormControlLabel
            control={
              <Switch
                checked={form.open_for_booking}
                onChange={handleSwitchChange}
                color="primary"
              />
            }
            label="Open for Booking"
          />

        </Stack>
      </DrawerForm>

      {/* ── Delete Confirm Dialog ─────────────────────────────────────────── */}
      <ConfirmDialog
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget?.id)}
        loading={deleteMutation.isPending}
        title="Delete Ground"
        message={`Permanently delete "${deleteTarget?.name}"? This action cannot be undone.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
