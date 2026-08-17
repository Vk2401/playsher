import React, { useState, useMemo, useRef } from 'react'
import {
  Box,
  Button,
  TextField,
  Avatar,
  IconButton,
  Tooltip,
  Typography,
  Chip,
  Stack,
  InputAdornment,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

import AddIcon from '@mui/icons-material/Add'
import CheckCircleIcon from '@mui/icons-material/CheckCircle'
import DeleteIcon from '@mui/icons-material/Delete'
import EditIcon from '@mui/icons-material/Edit'
import SearchIcon from '@mui/icons-material/Search'
import UploadFileIcon from '@mui/icons-material/UploadFile'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { sportsApi } from '../../api/sports.js'

const INITIAL_FORM = { name: '', description: '', image: null }

export default function Sports() {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const fileInputRef = useRef(null)
  const editFileInputRef = useRef(null)

  const [search, setSearch] = useState('')
  const [drawerOpen, setDrawerOpen] = useState(false)
  const [form, setForm] = useState(INITIAL_FORM)
  const [imagePreview, setImagePreview] = useState(null)
  const [formErrors, setFormErrors] = useState({})

  const [deleteTarget, setDeleteTarget] = useState(null)   // { id, name }
  const [approveTarget, setApproveTarget] = useState(null) // { id, name }

  // ── Edit state ─────────────────────────────────────────────────────────────
  const [editDrawerOpen, setEditDrawerOpen] = useState(false)
  const [editTarget, setEditTarget] = useState(null)        // { id, name, description, image_url }
  const [editForm, setEditForm] = useState(INITIAL_FORM)
  const [editImagePreview, setEditImagePreview] = useState(null)
  const [editFormErrors, setEditFormErrors] = useState({})

  // ── Query ──────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'sports'],
    queryFn: () => sportsApi.getAll(),
    select: (res) => res.data?.sports || res.data?.data || res.data || [],
  })

  const rows = useMemo(() => {
    const list = Array.isArray(data) ? data : []
    if (!search.trim()) return list
    const q = search.toLowerCase()
    return list.filter((r) => r.name?.toLowerCase().includes(q))
  }, [data, search])

  // ── Mutations ──────────────────────────────────────────────────────────────
  const createMutation = useMutation({
    mutationFn: (fd) => sportsApi.create(fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'sports'] })
      notify.success('Sport created successfully')
      handleCloseDrawer()
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to create sport')
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, fd }) => sportsApi.update(id, fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'sports'] })
      notify.success('Sport updated successfully')
      handleCloseEditDrawer()
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to update sport')
    },
  })

  const approveMutation = useMutation({
    mutationFn: (id) => sportsApi.approve(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'sports'] })
      notify.success(`"${approveTarget?.name}" approved`)
      setApproveTarget(null)
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to approve sport')
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => sportsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'sports'] })
      notify.success(`"${deleteTarget?.name}" deleted`)
      setDeleteTarget(null)
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to delete sport')
    },
  })

  // ── Create drawer helpers ──────────────────────────────────────────────────
  const handleOpenDrawer = () => {
    setForm(INITIAL_FORM)
    setImagePreview(null)
    setFormErrors({})
    setDrawerOpen(true)
  }

  const handleCloseDrawer = () => {
    setDrawerOpen(false)
    setForm(INITIAL_FORM)
    setImagePreview(null)
    setFormErrors({})
  }

  const handleFieldChange = (e) => {
    const { name, value } = e.target
    setForm((prev) => ({ ...prev, [name]: value }))
    if (formErrors[name]) setFormErrors((prev) => ({ ...prev, [name]: '' }))
  }

  const handleFileChange = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    setForm((prev) => ({ ...prev, image: file }))
    setImagePreview(URL.createObjectURL(file))
    if (formErrors.image) setFormErrors((prev) => ({ ...prev, image: '' }))
  }

  const validate = () => {
    const errs = {}
    if (!form.name.trim()) errs.name = 'Name is required'
    setFormErrors(errs)
    return Object.keys(errs).length === 0
  }

  const handleSubmit = () => {
    if (!validate()) return
    const fd = new FormData()
    fd.append('name', form.name.trim())
    fd.append('description', form.description.trim())
    if (form.image) fd.append('image', form.image)
    createMutation.mutate(fd)
  }

  // ── Edit drawer helpers ────────────────────────────────────────────────────
  const handleOpenEditDrawer = (row) => {
    setEditTarget({ id: row.id, name: row.name, description: row.description, image_url: row.image_url || row.image })
    setEditForm({ name: row.name, description: row.description || '', image: null })
    setEditImagePreview(row.image_url || row.image || null)
    setEditFormErrors({})
    setEditDrawerOpen(true)
  }

  const handleCloseEditDrawer = () => {
    setEditDrawerOpen(false)
    setEditTarget(null)
    setEditForm(INITIAL_FORM)
    setEditImagePreview(null)
    setEditFormErrors({})
  }

  const handleEditFieldChange = (e) => {
    const { name, value } = e.target
    setEditForm((prev) => ({ ...prev, [name]: value }))
    if (editFormErrors[name]) setEditFormErrors((prev) => ({ ...prev, [name]: '' }))
  }

  const handleEditFileChange = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    setEditForm((prev) => ({ ...prev, image: file }))
    setEditImagePreview(URL.createObjectURL(file))
    if (editFormErrors.image) setEditFormErrors((prev) => ({ ...prev, image: '' }))
  }

  const validateEdit = () => {
    const errs = {}
    if (!editForm.name.trim()) errs.name = 'Name is required'
    setEditFormErrors(errs)
    return Object.keys(errs).length === 0
  }

  const handleEditSubmit = () => {
    if (!validateEdit()) return
    const fd = new FormData()
    fd.append('name', editForm.name.trim())
    fd.append('description', editForm.description.trim())
    if (editForm.image) fd.append('image', editForm.image)
    updateMutation.mutate({ id: editTarget.id, fd })
  }

  // ── Columns ────────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
      renderCell: ({ value }) => (
        <Typography variant="body2" color="text.secondary">
          #{value}
        </Typography>
      ),
    },
    {
      field: 'image_url',
      headerName: 'Image',
      width: 80,
      sortable: false,
      renderCell: ({ row }) => (
        <Avatar
          src={row.image_url || row.image}
          alt={row.name}
          variant="rounded"
          sx={{ width: 40, height: 40, bgcolor: 'primary.light' }}
        >
          {row.name?.charAt(0).toUpperCase()}
        </Avatar>
      ),
    },
    {
      field: 'name',
      headerName: 'Name',
      flex: 1,
      minWidth: 140,
      renderCell: ({ value }) => (
        <Typography variant="body2" fontWeight={600}>
          {value}
        </Typography>
      ),
    },
    {
      field: 'description',
      headerName: 'Description',
      flex: 2,
      minWidth: 200,
      renderCell: ({ value }) => (
        <Typography
          variant="body2"
          color="text.secondary"
          sx={{
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}
        >
          {value || '—'}
        </Typography>
      ),
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
      field: 'status',
      headerName: 'Status',
      width: 100,
      renderCell: ({ value }) => <StatusChip status={value || 'active'} />,
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 130,
      sortable: false,
      align: 'center',
      headerAlign: 'center',
      renderCell: ({ row }) => (
        <Stack direction="row" spacing={0.5} alignItems="center">
          {!row.is_approved && (
            <Tooltip title="Approve Sport">
              <IconButton
                size="small"
                color="success"
                onClick={() => setApproveTarget({ id: row.id, name: row.name })}
              >
                <CheckCircleIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          )}
          <Tooltip title="Edit Sport">
            <IconButton
              size="small"
              color="primary"
              onClick={() => handleOpenEditDrawer(row)}
            >
              <EditIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <Tooltip title="Delete Sport">
            <IconButton
              size="small"
              color="error"
              onClick={() => setDeleteTarget({ id: row.id, name: row.name })}
            >
              <DeleteIcon fontSize="small" />
            </IconButton>
          </Tooltip>
        </Stack>
      ),
    },
  ]

  return (
    <Box>
      <PageHeader
        title="Sports"
        subtitle="Manage platform sports and categories"
        breadcrumbs={[
          { label: 'Admin', href: '/admin' },
          { label: 'Sports' },
        ]}
        actions={
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={handleOpenDrawer}
          >
            Add Sport
          </Button>
        }
      />

      {/* Search bar */}
      <Box mb={2} maxWidth={360}>
        <TextField
          fullWidth
          size="small"
          placeholder="Search by sport name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
        />
      </Box>

      {/* Data table */}
      <DataTable
        rows={rows}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* ── Create Drawer ─────────────────────────────────────────────────── */}
      <DrawerForm
        open={drawerOpen}
        onClose={handleCloseDrawer}
        title="Add New Sport"
        onSubmit={handleSubmit}
        loading={createMutation.isPending}
        submitLabel="Create Sport"
      >
        <Stack spacing={2.5}>
          <TextField
            label="Sport Name"
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
            placeholder="Brief description of the sport…"
          />

          {/* Image upload */}
          <Box>
            <Typography variant="caption" color="text.secondary" display="block" mb={1}>
              Sport Image (optional)
            </Typography>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={handleFileChange}
            />
            <Button
              variant="outlined"
              startIcon={<UploadFileIcon />}
              onClick={() => fileInputRef.current?.click()}
              size="small"
              sx={{ mb: 1 }}
            >
              {form.image ? 'Change Image' : 'Upload Image'}
            </Button>
            {form.image && (
              <Typography variant="caption" color="text.secondary" display="block">
                {form.image.name}
              </Typography>
            )}
            {imagePreview && (
              <Box mt={1.5}>
                <Avatar
                  src={imagePreview}
                  variant="rounded"
                  sx={{ width: 80, height: 80, border: '1px solid', borderColor: 'divider' }}
                />
              </Box>
            )}
          </Box>
        </Stack>
      </DrawerForm>

      {/* ── Edit Drawer ───────────────────────────────────────────────────── */}
      <DrawerForm
        open={editDrawerOpen}
        onClose={handleCloseEditDrawer}
        title="Edit Sport"
        onSubmit={handleEditSubmit}
        loading={updateMutation.isPending}
        submitLabel="Save Changes"
      >
        <Stack spacing={2.5}>
          <TextField
            label="Sport Name"
            name="name"
            value={editForm.name}
            onChange={handleEditFieldChange}
            error={!!editFormErrors.name}
            helperText={editFormErrors.name}
            fullWidth
            required
            autoFocus
          />

          <TextField
            label="Description"
            name="description"
            value={editForm.description}
            onChange={handleEditFieldChange}
            multiline
            rows={3}
            fullWidth
            placeholder="Brief description of the sport…"
          />

          {/* Image upload */}
          <Box>
            <Typography variant="caption" color="text.secondary" display="block" mb={1}>
              Sport Image (optional — leave blank to keep existing)
            </Typography>
            <input
              ref={editFileInputRef}
              type="file"
              accept="image/*"
              style={{ display: 'none' }}
              onChange={handleEditFileChange}
            />
            <Button
              variant="outlined"
              startIcon={<UploadFileIcon />}
              onClick={() => editFileInputRef.current?.click()}
              size="small"
              sx={{ mb: 1 }}
            >
              {editForm.image ? 'Change Image' : 'Upload New Image'}
            </Button>
            {editForm.image && (
              <Typography variant="caption" color="text.secondary" display="block">
                {editForm.image.name}
              </Typography>
            )}
            {editImagePreview && (
              <Box mt={1.5}>
                <Avatar
                  src={editImagePreview}
                  variant="rounded"
                  sx={{ width: 80, height: 80, border: '1px solid', borderColor: 'divider' }}
                />
              </Box>
            )}
          </Box>
        </Stack>
      </DrawerForm>

      {/* ── Approve Confirm ───────────────────────────────────────────────── */}
      <ConfirmDialog
        open={!!approveTarget}
        onClose={() => setApproveTarget(null)}
        onConfirm={() => approveMutation.mutate(approveTarget?.id)}
        loading={approveMutation.isPending}
        title="Approve Sport"
        message={`Approve "${approveTarget?.name}"? It will become publicly visible.`}
        confirmLabel="Approve"
        confirmColor="success"
      />

      {/* ── Delete Confirm ────────────────────────────────────────────────── */}
      <ConfirmDialog
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget?.id)}
        loading={deleteMutation.isPending}
        title="Delete Sport"
        message={`Permanently delete "${deleteTarget?.name}"? This action cannot be undone.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
