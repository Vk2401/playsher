import React, { useState } from 'react'
import {
  Alert, Box, Button, InputAdornment, List, ListItemButton, ListItemText,
  Radio, Stack, TextField, Typography,
} from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import AddIcon from '@mui/icons-material/Add'
import SearchIcon from '@mui/icons-material/Search'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import EmptyState from '../../components/ui/EmptyState.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { coachesApi } from '../../api/coaches.js'

export default function CoachGrounds() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [drawerOpen, setDrawerOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState(null)
  const [note, setNote] = useState('')
  const [withdrawTarget, setWithdrawTarget] = useState(null)

  const links = useQuery({
    queryKey: ['coach', 'grounds'],
    queryFn: () => coachesApi.getMyGrounds(),
    select: (res) => res.data?.data ?? [],
  })

  const joinable = useQuery({
    queryKey: ['coach', 'grounds', 'available', search],
    queryFn: () => coachesApi.getJoinableGrounds(search ? { search, limit: 50 } : { limit: 50 }),
    select: (res) => res.data?.data ?? [],
    enabled: drawerOpen,
  })

  const requestMutation = useMutation({
    mutationFn: () => coachesApi.requestGround(selected.id, note.trim() || undefined),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['coach', 'grounds'] })
      queryClient.invalidateQueries({ queryKey: ['coach', 'dashboard'] })
      notify.success('Request sent. The ground owner will approve or decline it.')
      closeDrawer()
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not send that request.'),
  })

  const withdrawMutation = useMutation({
    mutationFn: (id) => coachesApi.withdrawGround(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['coach', 'grounds'] })
      queryClient.invalidateQueries({ queryKey: ['coach', 'dashboard'] })
      notify.success('Registration withdrawn.')
      setWithdrawTarget(null)
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not withdraw that registration.'),
  })

  const openDrawer = () => {
    setSearch('')
    setSelected(null)
    setNote('')
    setDrawerOpen(true)
  }

  const closeDrawer = () => {
    setDrawerOpen(false)
    setSearch('')
    setSelected(null)
    setNote('')
  }

  const handleSubmit = () => {
    if (!selected) {
      notify.warning('Pick a ground first.')
      return
    }
    requestMutation.mutate()
  }

  const columns = [
    {
      field: 'ground',
      headerName: 'Ground',
      flex: 1,
      minWidth: 200,
      sortable: false,
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2" fontWeight={600}>{row.ground?.name || '—'}</Typography>
          <Typography variant="caption" color="text.secondary">
            {[row.ground?.area, row.ground?.city].filter(Boolean).join(', ')}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 130,
      renderCell: ({ row }) => <StatusChip status={row.status} />,
    },
    {
      field: 'requested_at',
      headerName: 'Requested',
      width: 140,
      renderCell: ({ row }) => (row.requested_at ? dayjs(row.requested_at).format('DD MMM YYYY') : '—'),
    },
    {
      field: 'response_note',
      headerName: "Owner's note",
      flex: 1,
      minWidth: 160,
      sortable: false,
      renderCell: ({ row }) => row.response_note || '—',
    },
    {
      field: 'actions',
      headerName: '',
      width: 130,
      sortable: false,
      renderCell: ({ row }) => (
        <Button
          size="small"
          color="error"
          startIcon={<DeleteOutlineIcon />}
          onClick={() => setWithdrawTarget(row)}
        >
          Withdraw
        </Button>
      ),
    },
  ]

  const approvedCount = (links.data ?? []).filter((l) => l.status === 'approved').length

  return (
    <Box>
      <PageHeader
        title="My Grounds"
        subtitle="Venues where you are allowed to coach. Each one is approved by its owner."
        actions={
          <Button variant="contained" startIcon={<AddIcon />} onClick={openDrawer}>
            Register at a ground
          </Button>
        }
      />

      {!links.isLoading && approvedCount === 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>
          You are not approved at any ground yet. Players can still book you without a
          venue, but a ground has to approve you before sessions can be held there.
        </Alert>
      )}

      <DataTable
        rows={links.data ?? []}
        columns={columns}
        loading={links.isLoading}
        error={links.error}
      />

      <DrawerForm
        open={drawerOpen}
        onClose={closeDrawer}
        title="Register at a ground"
        onSubmit={handleSubmit}
        loading={requestMutation.isPending}
        submitLabel="Send request"
        width={480}
      >
        <Stack spacing={2}>
          <Typography variant="body2" color="text.secondary">
            The ground owner has to approve you before players can book sessions with
            you there.
          </Typography>
          <TextField
            placeholder="Search grounds by name, area or city"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            size="small"
            fullWidth
            InputProps={{
              startAdornment: (
                <InputAdornment position="start"><SearchIcon fontSize="small" /></InputAdornment>
              ),
            }}
          />

          {joinable.isLoading && <Typography variant="body2">Loading grounds…</Typography>}
          {joinable.error && <Alert severity="error">Could not load grounds.</Alert>}
          {!joinable.isLoading && (joinable.data ?? []).length === 0 && (
            <EmptyState message="No grounds left to ask — you have already asked them all." />
          )}

          <List dense sx={{ maxHeight: 320, overflow: 'auto' }}>
            {(joinable.data ?? []).map((ground) => (
              <ListItemButton
                key={ground.id}
                selected={selected?.id === ground.id}
                onClick={() => setSelected(ground)}
                sx={{ borderRadius: 2 }}
              >
                <Radio checked={selected?.id === ground.id} size="small" />
                <ListItemText
                  primary={ground.name}
                  secondary={[ground.area, ground.city].filter(Boolean).join(', ') || ground.address}
                />
              </ListItemButton>
            ))}
          </List>

          <TextField
            label="Message to the owner (optional)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            multiline
            minRows={3}
            fullWidth
          />
        </Stack>
      </DrawerForm>

      <ConfirmDialog
        open={Boolean(withdrawTarget)}
        onClose={() => setWithdrawTarget(null)}
        onConfirm={() => withdrawMutation.mutate(withdrawTarget.id)}
        title="Withdraw this registration?"
        message={withdrawTarget
          ? `You will no longer be bookable at ${withdrawTarget.ground?.name || 'this ground'}. You can ask again later.`
          : ''}
        confirmLabel="Withdraw"
        loading={withdrawMutation.isPending}
      />
    </Box>
  )
}
