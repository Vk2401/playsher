import React, { useMemo, useState } from 'react'
import {
  Box,
  Button,
  Chip,
  FormControl,
  Grid,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import BlockIcon from '@mui/icons-material/Block'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import FilterListIcon from '@mui/icons-material/FilterList'
import GroupsIcon from '@mui/icons-material/Groups'
import LocalFireDepartmentIcon from '@mui/icons-material/LocalFireDepartment'
import LockIcon from '@mui/icons-material/Lock'
import SearchIcon from '@mui/icons-material/Search'
import SportsSoccerIcon from '@mui/icons-material/SportsSoccer'
import VisibilityIcon from '@mui/icons-material/Visibility'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import GameDetailDrawer from '../../components/ui/GameDetailDrawer.jsx'
import SeatMeter from '../../components/ui/SeatMeter.jsx'
import StatCard from '../../components/ui/StatCard.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { gamesApi } from '../../api/games.js'

const LEVEL_LABELS = {
  newbie: 'Newbie',
  beginner: 'Beginner',
  intermediate: 'Intermediate',
  advanced: 'Advanced',
  professional: 'Professional',
  ultra_professional: 'Ultra pro',
}

const STATUSES = ['open', 'full', 'in_progress', 'completed', 'cancelled']

/**
 * Every open game on the platform.
 *
 * A game is a customer's booking with seats opened on it, so the row a
 * moderator needs is not the `games` table — it is the venue, the schedule and
 * the seats, all of which the API now flattens onto each row and derives once
 * (`backend-api/src/utils/gameView.js`). The page reads them; it never
 * recomputes a status or a seat count of its own.
 *
 * Nothing here edits a game: the host owns its name, level and capacity. The
 * two moderation actions are calling a game off — which notifies the players
 * who joined and leaves the booking alone — and, as a last resort, deleting
 * the row.
 */
export default function AdminGames() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [visibility, setVisibility] = useState('all')

  const [detailId, setDetailId] = useState(null)
  const [cancelTarget, setCancelTarget] = useState(null) // { id, name }
  const [deleteTarget, setDeleteTarget] = useState(null) // { id, name }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  // Visibility is a stored column, so the server filters it; status is derived
  // per row and filtered below, where the derivation already lives.
  const queryParams = useMemo(
    () => ({ limit: 100, ...(visibility === 'all' ? {} : { visibility }) }),
    [visibility],
  )

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'games', queryParams],
    queryFn: () => gamesApi.getAll(queryParams),
    select: (res) => res.data?.data ?? [],
  })

  const { data: detail, isFetching: detailLoading } = useQuery({
    queryKey: ['admin', 'games', detailId],
    queryFn: () => gamesApi.getById(detailId),
    select: (res) => res.data?.data ?? null,
    enabled: Boolean(detailId),
  })

  const all = useMemo(() => (Array.isArray(data) ? data : []), [data])

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase()
    return all.filter((g) => {
      const matchStatus = statusFilter === 'all' || g.status === statusFilter
      const matchSearch =
        !q ||
        [g.game_name, g.ground_name, g.ground_city, g.sport_name, g.host_name]
          .filter(Boolean)
          .some((v) => String(v).toLowerCase().includes(q))
      return matchStatus && matchSearch
    })
  }, [all, search, statusFilter])

  // ── Summary ───────────────────────────────────────────────────────────────
  // Counted over the page that was fetched, which the caption says plainly
  // rather than implying these are platform-wide totals.
  const stats = useMemo(() => {
    const open = all.filter((g) => g.status === 'open')
    return {
      open: open.length,
      filling: open.filter((g) => g.spots_left > 0 && g.spots_left <= 2).length,
      full: all.filter((g) => g.status === 'full').length,
      players: all.reduce((sum, g) => sum + (g.joined_count ?? 0), 0),
    }
  }, [all])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const invalidate = () =>
    queryClient.invalidateQueries({ queryKey: ['admin', 'games'] })

  const cancelMutation = useMutation({
    mutationFn: (id) => gamesApi.cancel(id),
    onSuccess: () => {
      invalidate()
      notify.success(`"${cancelTarget?.name}" was called off — players notified`)
      setCancelTarget(null)
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to cancel this game'),
  })

  const deleteMutation = useMutation({
    mutationFn: (id) => gamesApi.delete(id),
    onSuccess: () => {
      invalidate()
      notify.success(`"${deleteTarget?.name}" deleted`)
      setDeleteTarget(null)
      setDetailId(null)
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to delete this game'),
  })

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'game_name',
      headerName: 'Game',
      flex: 1.4,
      minWidth: 220,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center" gap={1} minWidth={0}>
          <SportsSoccerIcon fontSize="small" sx={{ color: 'text.disabled' }} />
          <Box minWidth={0}>
            <Typography variant="body2" fontWeight={600} noWrap>
              {row.game_name || `Game #${row.id}`}
            </Typography>
            <Typography variant="caption" color="text.secondary" noWrap>
              {[row.sport_name, LEVEL_LABELS[row.game_level] ?? row.game_level]
                .filter(Boolean)
                .join(' · ') || '—'}
            </Typography>
          </Box>
          {row.visibility === 'private' && (
            <Tooltip title="Invite only — not listed in Discover">
              <LockIcon sx={{ fontSize: 15, color: 'text.disabled' }} />
            </Tooltip>
          )}
        </Box>
      ),
    },
    {
      field: 'host_name',
      headerName: 'Host',
      flex: 0.8,
      minWidth: 130,
      renderCell: ({ row }) => row.host_name || '—',
    },
    {
      field: 'ground_name',
      headerName: 'Venue',
      flex: 1,
      minWidth: 160,
      renderCell: ({ row }) => (
        <Box minWidth={0}>
          <Typography variant="body2" noWrap>
            {row.ground_name || '—'}
          </Typography>
          <Typography variant="caption" color="text.secondary" noWrap>
            {[row.ground_area, row.ground_city].filter(Boolean).join(', ') || '—'}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'slot_date',
      headerName: 'When',
      width: 165,
      renderCell: ({ row }) => {
        const date = row.slot_date ? dayjs(row.slot_date) : null
        if (!date?.isValid()) return '—'
        return (
          <Box>
            <Typography variant="body2">{date.format('DD MMM YYYY')}</Typography>
            <Typography variant="caption" color="text.secondary">
              {String(row.slot_time_from || '').slice(0, 5)}
              {row.slot_time_to ? ` – ${String(row.slot_time_to).slice(0, 5)}` : ''}
            </Typography>
          </Box>
        )
      },
    },
    {
      field: 'joined_count',
      headerName: 'Seats',
      width: 110,
      sortable: true,
      renderCell: ({ row }) => (
        <SeatMeter
          joined={row.joined_count}
          capacity={row.max_participants}
          spotsLeft={row.spots_left}
        />
      ),
    },
    {
      field: 'price_per_player',
      headerName: 'Per player',
      width: 110,
      renderCell: ({ value }) =>
        value > 0 ? (
          `₹${Number(value).toLocaleString('en-IN')}`
        ) : (
          <Typography variant="caption" color="text.secondary">
            On request
          </Typography>
        ),
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 130,
      renderCell: ({ value }) => <StatusChip status={value || 'open'} />,
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 130,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => {
        const name = row.game_name || `#${row.id}`
        return (
          <Stack direction="row" spacing={0.5}>
            <Tooltip title="View players">
              <IconButton size="small" onClick={() => setDetailId(row.id)}>
                <VisibilityIcon fontSize="small" />
              </IconButton>
            </Tooltip>
            <Tooltip
              title={
                row.is_active === false
                  ? 'Already cancelled'
                  : 'Call off — notifies everyone who joined'
              }
            >
              <span>
                <IconButton
                  size="small"
                  color="warning"
                  disabled={row.is_active === false}
                  onClick={() => setCancelTarget({ id: row.id, name })}
                >
                  <BlockIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
            <Tooltip title="Delete permanently">
              <IconButton
                size="small"
                color="error"
                onClick={() => setDeleteTarget({ id: row.id, name })}
              >
                <DeleteOutlineIcon fontSize="small" />
              </IconButton>
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
        title="Games"
        subtitle="Open games players have published on their own bookings"
        breadcrumbs={[{ label: 'Admin', href: '/admin' }, { label: 'Games' }]}
      />

      <Grid container spacing={2} mb={3}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Open now"
            value={stats.open}
            icon={SportsSoccerIcon}
            loading={isLoading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Last seats"
            value={stats.filling}
            icon={LocalFireDepartmentIcon}
            loading={isLoading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Full"
            value={stats.full}
            icon={GroupsIcon}
            loading={isLoading}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard
            title="Seats taken"
            value={stats.players}
            icon={GroupsIcon}
            loading={isLoading}
          />
        </Grid>
      </Grid>

      {/* Filters row */}
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={2}
        mb={2}
        alignItems={{ xs: 'stretch', sm: 'center' }}
        flexWrap="wrap"
        useFlexGap
      >
        <TextField
          size="small"
          placeholder="Search game, host, venue or sport…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ width: { xs: '100%', sm: 320 } }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
        />

        <FormControl size="small" sx={{ minWidth: 170 }}>
          <InputLabel>
            <Box component="span" display="flex" alignItems="center" gap={0.5}>
              <FilterListIcon sx={{ fontSize: 16 }} />
              Status
            </Box>
          </InputLabel>
          <Select
            value={statusFilter}
            label="Status"
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <MenuItem value="all">All statuses</MenuItem>
            {STATUSES.map((s) => (
              <MenuItem key={s} value={s}>
                <StatusChip status={s} />
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Visibility</InputLabel>
          <Select
            value={visibility}
            label="Visibility"
            onChange={(e) => setVisibility(e.target.value)}
          >
            <MenuItem value="all">All games</MenuItem>
            <MenuItem value="public">Public</MenuItem>
            <MenuItem value="private">Invite only</MenuItem>
          </Select>
        </FormControl>

        {rows.length !== all.length && (
          <Chip
            size="small"
            variant="outlined"
            label={`Showing ${rows.length} of ${all.length}`}
          />
        )}
      </Stack>

      <DataTable rows={rows} columns={columns} loading={isLoading} error={error} />

      <Typography variant="caption" color="text.secondary" display="block" mt={1}>
        Counts above cover the most recent 100 games.
      </Typography>

      <GameDetailDrawer
        open={Boolean(detailId)}
        onClose={() => setDetailId(null)}
        game={detail}
        loading={detailLoading && !detail}
        action={
          detail && detail.is_active !== false ? (
            <Button
              variant="contained"
              color="warning"
              startIcon={<BlockIcon />}
              onClick={() =>
                setCancelTarget({
                  id: detail.id,
                  name: detail.game_name || `#${detail.id}`,
                })
              }
            >
              Call off
            </Button>
          ) : null
        }
      />

      <ConfirmDialog
        open={Boolean(cancelTarget)}
        onClose={() => setCancelTarget(null)}
        onConfirm={() => cancelMutation.mutate(cancelTarget.id)}
        loading={cancelMutation.isPending}
        title="Call off this game?"
        message={`Everyone who joined "${cancelTarget?.name}" is notified. The customer's booking is untouched — only the open game is closed.`}
        confirmLabel="Call it off"
        confirmColor="warning"
      />

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget.id)}
        loading={deleteMutation.isPending}
        title="Delete Game"
        message={`Permanently delete "${deleteTarget?.name}" and every participant record on it? Nobody is notified — prefer calling the game off unless this row should never have existed.`}
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
