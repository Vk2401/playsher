import React, { useState } from 'react'
import {
  Box,
  Alert,
  AlertTitle,
  Switch,
  TextField,
  IconButton,
  Tooltip,
  Typography,
  Stack,
  FormControlLabel,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

import EditIcon from '@mui/icons-material/Edit'
import AndroidIcon from '@mui/icons-material/Android'
import PhoneIphoneIcon from '@mui/icons-material/PhoneIphone'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { appVersionsApi } from '../../api/appVersions.js'

const PLATFORM_LABELS = { android: 'Android', ios: 'iOS' }
const PLATFORM_ICONS = { android: AndroidIcon, ios: PhoneIphoneIcon }
const INITIAL_EDIT_FORM = {
  latest_version: '',
  min_supported_version: '',
  update_url: '',
  release_notes: '',
  is_active: true,
}

/** Dotted numbers, optionally with Flutter's +build suffix. Mirrors the API's rule. */
const VERSION_PATTERN = /^\d+(\.\d+)*(\+\d+)?$/

/** Compare dotted versions numerically — '1.10.0' must beat '1.9.0', which string order gets wrong. */
function compareVersions(a, b) {
  const parse = (v) => String(v).split('+')[0].split('.').map(Number)
  const left = parse(a)
  const right = parse(b)
  for (let i = 0; i < Math.max(left.length, right.length); i += 1) {
    const l = left[i] ?? 0
    const r = right[i] ?? 0
    if (l !== r) return l < r ? -1 : 1
  }
  return 0
}

export default function AppVersions() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [editTarget, setEditTarget] = useState(null) // { platform, ... }
  const [editForm, setEditForm] = useState(INITIAL_EDIT_FORM)
  const [editFormErrors, setEditFormErrors] = useState({})

  // ── Query ──────────────────────────────────────────────────────────────────
  const { data: versions = [], isLoading, error } = useQuery({
    queryKey: ['admin', 'app-versions'],
    queryFn: () => appVersionsApi.getAll(),
    select: (res) => res.data?.data ?? [],
  })

  // ── Mutation ───────────────────────────────────────────────────────────────
  const updateMutation = useMutation({
    mutationFn: ({ platform, data }) => appVersionsApi.update(platform, data),
    onSuccess: (_res, variables) => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'app-versions'] })
      notify.success(`${PLATFORM_LABELS[variables.platform]} version settings saved`)
      handleCloseEdit()
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to save version settings'),
  })

  // ── Edit handlers ──────────────────────────────────────────────────────────
  const handleOpenEdit = (row) => {
    setEditTarget(row)
    setEditForm({
      latest_version: row.latest_version || '',
      min_supported_version: row.min_supported_version || '',
      update_url: row.update_url || '',
      release_notes: row.release_notes || '',
      // A platform that has never been configured comes back inactive; default
      // the switch on, since an admin opening this drawer means to configure it.
      is_active: row.id === null ? true : Boolean(row.is_active),
    })
    setEditFormErrors({})
  }

  const handleCloseEdit = () => {
    setEditTarget(null)
    setEditForm(INITIAL_EDIT_FORM)
    setEditFormErrors({})
  }

  /**
   * Clear a field's error as soon as the user edits it, as the other CRUD pages
   * do — leaving a stale message under a field they just corrected reads as if
   * the fix did not take.
   */
  const handleChange = (name, value) => {
    setEditForm((prev) => ({ ...prev, [name]: value }))
    setEditFormErrors((prev) => {
      if (!prev[name] && !(name === 'latest_version' && prev.min_supported_version)) return prev
      const next = { ...prev, [name]: '' }
      // The "newer than latest" message hangs off the minimum field but either
      // side can be the one that resolves it.
      if (name === 'latest_version') next.min_supported_version = ''
      return next
    })
  }

  const validate = () => {
    const errors = {}
    const { latest_version: latest, min_supported_version: min, update_url: url } = editForm

    if (!latest.trim()) errors.latest_version = 'Latest version is required'
    else if (!VERSION_PATTERN.test(latest.trim()))
      errors.latest_version = 'Use dotted numbers, e.g. 1.4.0'

    if (!min.trim()) errors.min_supported_version = 'Minimum supported version is required'
    else if (!VERSION_PATTERN.test(min.trim()))
      errors.min_supported_version = 'Use dotted numbers, e.g. 1.2.0'

    // Catch the footgun here as well as on the server: a minimum above the
    // latest build forces every user into an update that does not exist.
    if (!errors.latest_version && !errors.min_supported_version && compareVersions(min, latest) === 1)
      errors.min_supported_version = 'Cannot be newer than the latest version'

    if (url.trim()) {
      try {
        new URL(url.trim())
      } catch {
        errors.update_url = 'Enter a full URL, e.g. https://play.google.com/...'
      }
    }

    setEditFormErrors(errors)
    return Object.keys(errors).length === 0
  }

  const handleSubmitEdit = () => {
    if (!validate()) return
    updateMutation.mutate({
      platform: editTarget.platform,
      data: {
        latest_version: editForm.latest_version.trim(),
        min_supported_version: editForm.min_supported_version.trim(),
        update_url: editForm.update_url.trim() || null,
        release_notes: editForm.release_notes.trim() || null,
        is_active: editForm.is_active,
      },
    })
  }

  // ── Columns ────────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'platform',
      headerName: 'Platform',
      flex: 1,
      minWidth: 150,
      renderCell: (params) => {
        const Icon = PLATFORM_ICONS[params.value]
        return (
          <Stack direction="row" alignItems="center" gap={1}>
            {Icon && <Icon fontSize="small" color="action" />}
            <Typography variant="body2" fontWeight={600}>
              {PLATFORM_LABELS[params.value] || params.value}
            </Typography>
          </Stack>
        )
      },
    },
    {
      field: 'latest_version',
      headerName: 'Latest version',
      flex: 1,
      minWidth: 140,
      renderCell: (params) =>
        params.value || (
          <Typography variant="body2" color="text.secondary">
            Not set
          </Typography>
        ),
    },
    {
      field: 'min_supported_version',
      headerName: 'Minimum supported',
      flex: 1,
      minWidth: 160,
      renderCell: (params) =>
        params.value || (
          <Typography variant="body2" color="text.secondary">
            Not set
          </Typography>
        ),
    },
    {
      field: 'is_active',
      headerName: 'Checks',
      flex: 0.7,
      minWidth: 120,
      renderCell: (params) => (
        <StatusChip status={params.value ? 'active' : 'inactive'} />
      ),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      sortable: false,
      filterable: false,
      width: 100,
      renderCell: (params) => (
        <Tooltip title="Edit version settings">
          <IconButton size="small" onClick={() => handleOpenEdit(params.row)}>
            <EditIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      ),
    },
  ]

  return (
    <Box>
      <PageHeader
        title="App Versions"
        subtitle="Control which mobile app builds may keep running"
        breadcrumbs={[{ label: 'Admin', href: '/admin/dashboard' }, { label: 'App Versions' }]}
      />

      <Alert severity="info" sx={{ mb: 3 }}>
        <AlertTitle>How these thresholds behave</AlertTitle>
        A build older than the <strong>latest version</strong> sees a dismissible
        &ldquo;update available&rdquo; prompt. A build older than the{' '}
        <strong>minimum supported version</strong> is blocked until the user updates — use it
        only to retire a build that is genuinely broken. Turning{' '}
        <strong>checks</strong> off stops all prompting for that platform, which is the way to
        walk back a mistake without shipping a new app.
      </Alert>

      <DataTable
        rows={versions}
        columns={columns}
        loading={isLoading}
        error={error}
        getRowId={(row) => row.platform}
      />

      <DrawerForm
        open={Boolean(editTarget)}
        onClose={handleCloseEdit}
        title={`${PLATFORM_LABELS[editTarget?.platform] || ''} version settings`}
        onSubmit={handleSubmitEdit}
        loading={updateMutation.isPending}
        submitLabel="Save"
      >
        <Stack gap={2.5}>
          <TextField
            label="Latest version"
            value={editForm.latest_version}
            onChange={(e) => handleChange('latest_version', e.target.value)}
            error={Boolean(editFormErrors.latest_version)}
            helperText={
              editFormErrors.latest_version ||
              'The newest build in the store. Older builds are prompted to update.'
            }
            placeholder="1.4.0"
            fullWidth
          />

          <TextField
            label="Minimum supported version"
            value={editForm.min_supported_version}
            onChange={(e) => handleChange('min_supported_version', e.target.value)}
            error={Boolean(editFormErrors.min_supported_version)}
            helperText={
              editFormErrors.min_supported_version ||
              'Anything older than this is blocked from using the app.'
            }
            placeholder="1.2.0"
            fullWidth
          />

          <TextField
            label="Update link"
            value={editForm.update_url}
            onChange={(e) => handleChange('update_url', e.target.value)}
            error={Boolean(editFormErrors.update_url)}
            helperText={
              editFormErrors.update_url ||
              'Where the update button sends the user — the store listing for this platform.'
            }
            placeholder="https://play.google.com/store/apps/details?id=..."
            fullWidth
          />

          <TextField
            label="Release notes"
            value={editForm.release_notes}
            onChange={(e) => handleChange('release_notes', e.target.value)}
            helperText="Shown in the update prompt. Optional."
            multiline
            minRows={3}
            fullWidth
          />

          <FormControlLabel
            control={
              <Switch
                checked={editForm.is_active}
                onChange={(e) => setEditForm({ ...editForm, is_active: e.target.checked })}
              />
            }
            label="Version checks enabled"
          />

          {editForm.is_active &&
            editForm.latest_version.trim() &&
            editForm.min_supported_version.trim() &&
            VERSION_PATTERN.test(editForm.min_supported_version.trim()) &&
            VERSION_PATTERN.test(editForm.latest_version.trim()) &&
            compareVersions(editForm.min_supported_version, editForm.latest_version) < 1 && (
              <Alert
                severity={
                  compareVersions(editForm.min_supported_version, editForm.latest_version) === 0
                    ? 'warning'
                    : 'info'
                }
              >
                {compareVersions(editForm.min_supported_version, editForm.latest_version) === 0
                  ? `Every build below ${editForm.latest_version.trim()} will be blocked immediately.`
                  : `Builds below ${editForm.min_supported_version.trim()} will be blocked; builds from ${editForm.min_supported_version.trim()} up to ${editForm.latest_version.trim()} will see a dismissible prompt.`}
              </Alert>
            )}
        </Stack>
      </DrawerForm>
    </Box>
  )
}
