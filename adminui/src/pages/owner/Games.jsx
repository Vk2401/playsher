import React, { useMemo, useState } from 'react'
import {
  Box,
  InputAdornment,
  TextField,
  Typography,
} from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'

import SearchIcon from '@mui/icons-material/Search'
import SportsIcon from '@mui/icons-material/Sports'
import GroupIcon from '@mui/icons-material/Group'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { gamesApi } from '../../api/games.js'

export default function OwnerGames() {
  const [search, setSearch] = useState('')

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'games'],
    queryFn: () => gamesApi.getOwnerGames(),
    select: (res) => res.data,
  })

  const games = useMemo(() => {
    const raw = data?.games ?? data?.data ?? data ?? []
    if (!search.trim()) return raw
    const q = search.toLowerCase()
    return raw.filter(
      (g) =>
        String(g.title ?? g.name ?? '').toLowerCase().includes(q) ||
        String(g.ground?.name ?? g.ground_name ?? '').toLowerCase().includes(q) ||
        String(g.sport?.name ?? g.sport_name ?? '').toLowerCase().includes(q),
    )
  }, [data, search])

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
    },
    {
      field: 'title',
      headerName: 'Title',
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
      width: 170,
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
      width: 120,
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
      field: 'max_participants',
      headerName: 'Max Players',
      width: 110,
      renderCell: ({ value }) => value ?? '—',
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title="Games"
        subtitle="Games on your grounds"
      />

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
    </Box>
  )
}
