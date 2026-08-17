import React, { useMemo, useState } from 'react'
import {
  Box,
  IconButton,
  InputAdornment,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import SearchIcon from '@mui/icons-material/Search'
import SportsIcon from '@mui/icons-material/Sports'
import GroupIcon from '@mui/icons-material/Group'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { gamesApi } from '../../api/games.js'

export default function AdminGames() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [search, setSearch] = useState('')
  const [deleteTarget, setDeleteTarget] = useState(null) // { id, title }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'games'],
    queryFn: () => gamesApi.getAll(),
    select: (res) => res.data,
  })

  const games = useMemo(() => {
    const raw = data?.games ?? data?.data ?? data ?? []
    if (!search.trim()) return raw
    const q = search.toLowerCase()
    return raw.filter(
      (g) =>
        String(g.title ?? g.name ?? '').toLowerCase().includes(q) ||
        String(g.ground?.name ?? '').toLowerCase().includes(q) ||
        String(g.sport?.name ?? g.sport_name ?? '').toLowerCase().includes(q),
    )
  }, [data, search])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: (id) => gamesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'games'] })
      notify.success('Game deleted successfully')
      setDeleteTarget(null)
    },
    onError: () => notify.error('Failed to delete game'),
  })

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
    },
    {
      field: 'title',
      headerName: 'Title / Name',
      flex: 1.2,
      minWidth: 160,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={1}>
          <SportsIcon fontSize="small" sx={{ color: 'text.disabled' }} />
          <Typography variant="body2" fontWeight={500}>
            {row.title ?? row.name ?? '—'}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'ground_name',
      headerName: 'Ground',
      flex: 1,
      minWidth: 140,
      renderCell: ({ row }) =>
        row.ground?.name ?? row.ground_name ?? '—',
    },
    {
      field: 'sport_name',
      headerName: 'Sport',
      width: 130,
      renderCell: ({ row }) =>
        row.sport?.name ?? row.sport_name ?? '—',
    },
    {
      field: 'scheduled_at',
      headerName: 'Scheduled At',
      width: 160,
      renderCell: ({ value }) =>
        value ? dayjs(value).format('DD MMM YYYY, HH:mm') : '—',
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 120,
      renderCell: ({ value }) => <StatusChip status={value ?? 'open'} />,
    },
    {
      field: 'participants_count',
      headerName: 'Participants',
      width: 110,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={0.5}>
          <GroupIcon fontSize="small" sx={{ color: 'text.disabled' }} />
          <Typography variant="body2">
            {row.participants_count ?? row.participants?.length ?? 0}
          </Typography>
        </Box>
      ),
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 80,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center">
          <Tooltip title="Delete game">
            <span>
              <IconButton
                size="small"
                color="error"
                onClick={() =>
                  setDeleteTarget({ id: row.id, title: row.title ?? row.name ?? `#${row.id}` })
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
      <PageHeader title="Games" subtitle="All scheduled games on the platform" />

      {/* Search */}
      <Box mb={2}>
        <TextField
          size="small"
          placeholder="Search by title, ground or sport…"
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
        rows={games}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* Delete confirmation */}
      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget.id)}
        loading={deleteMutation.isPending}
        title="Delete Game"
        message={`Are you sure you want to permanently delete "${deleteTarget?.title}"? This action cannot be undone.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
