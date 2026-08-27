import React, { useMemo, useState } from 'react'
import {
  Box,
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
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'

import FilterListIcon from '@mui/icons-material/FilterList'
import GroupsIcon from '@mui/icons-material/Groups'
import LocalFireDepartmentIcon from '@mui/icons-material/LocalFireDepartment'
import LockIcon from '@mui/icons-material/Lock'
import SearchIcon from '@mui/icons-material/Search'
import SportsSoccerIcon from '@mui/icons-material/SportsSoccer'
import VisibilityIcon from '@mui/icons-material/Visibility'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import GameDetailDrawer from '../../components/ui/GameDetailDrawer.jsx'
import SeatMeter from '../../components/ui/SeatMeter.jsx'
import StatCard from '../../components/ui/StatCard.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { gamesApi } from '../../api/games.js'

const LEVEL_LABELS = {
  newbie: 'Newbie',
  beginner: 'Beginner',
  intermediate: 'Intermediate',
  advanced: 'Advanced',
  professional: 'Professional',
  ultra_professional: 'Ultra pro',
}

const WHEN_OPTIONS = [
  { value: 'upcoming', label: 'Upcoming' },
  { value: 'today', label: 'Today' },
  { value: 'past', label: 'Past' },
  { value: 'all', label: 'All' },
]

/**
 * Open games running at my grounds.
 *
 * Not "games I published": nearly every game is opened by a customer on their
 * own booking, and what an owner needs to know is how many people are actually
 * turning up to a slot that was sold as one. The endpoint is scoped by venue
 * for that reason, and this page reads the counts and status the API derives
 * rather than recomputing them.
 *
 * Read-only by design. A game belongs to the player who opened it; the owner's
 * lever over the slot is the booking, which lives on the Bookings page.
 */
export default function OwnerGames() {
  const [search, setSearch] = useState('')
  const [when, setWhen] = useState('upcoming')
  const [detailId, setDetailId] = useState(null)

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'games'],
    queryFn: () => gamesApi.getOwnerGames({ limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })

  const all = useMemo(() => (Array.isArray(data) ? data : []), [data])

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase()
    const today = dayjs().format('YYYY-MM-DD')

    return all.filter((g) => {
      const date = g.slot_date ? dayjs(g.slot_date).format('YYYY-MM-DD') : null
      const matchWhen =
        when === 'all' ||
        !date ||
        (when === 'today' && date === today) ||
        (when === 'upcoming' && date >= today) ||
        (when === 'past' && date < today)

      const matchSearch =
        !q ||
        [g.game_name, g.ground_name, g.sport_name, g.host_name]
          .filter(Boolean)
          .some((v) => String(v).toLowerCase().includes(q))

      return matchWhen && matchSearch
    })
  }, [all, search, when])

  // ── Summary ───────────────────────────────────────────────────────────────
  // Scoped to what is on screen, so the filter and the tiles agree.
  const stats = useMemo(() => {
    const open = rows.filter((g) => g.status === 'open')
    return {
      games: rows.length,
      filling: open.filter((g) => g.spots_left > 0 && g.spots_left <= 2).length,
      players: rows.reduce((sum, g) => sum + (g.joined_count ?? 0), 0),
    }
  }, [rows])

  // The owner endpoint has no by-id route and its rows already carry the
  // participants, so the drawer reads the row that is on screen rather than
  // firing a second request for data the page is holding.
  const detail = useMemo(
    () => all.find((g) => g.id === detailId) ?? null,
    [all, detailId],
  )

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'game_name',
      headerName: 'Game',
      flex: 1.3,
      minWidth: 210,
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
      headerName: 'Hosted by',
      flex: 0.8,
      minWidth: 130,
      renderCell: ({ row }) => row.host_name || '—',
    },
    {
      field: 'ground_name',
      headerName: 'Ground',
      flex: 1,
      minWidth: 150,
      renderCell: ({ row }) => row.ground_name || '—',
    },
    {
      field: 'slot_date',
      headerName: 'Slot',
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
      headerName: 'Turning up',
      width: 120,
      renderCell: ({ row }) => (
        <SeatMeter
          joined={row.joined_count}
          capacity={row.max_participants}
          spotsLeft={row.spots_left}
        />
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
      headerName: '',
      width: 70,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => (
        <Tooltip title="See who is coming">
          <IconButton size="small" onClick={() => setDetailId(row.id)}>
            <VisibilityIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      ),
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title="Games"
        subtitle="Open games running at your grounds, whoever published them"
        breadcrumbs={[{ label: 'Owner', href: '/owner' }, { label: 'Games' }]}
      />

      <Grid container spacing={2} mb={3}>
        <Grid item xs={12} sm={4}>
          <StatCard
            title="Games"
            value={stats.games}
            icon={SportsSoccerIcon}
            loading={isLoading}
          />
        </Grid>
        <Grid item xs={12} sm={4}>
          <StatCard
            title="Players expected"
            value={stats.players}
            icon={GroupsIcon}
            loading={isLoading}
          />
        </Grid>
        <Grid item xs={12} sm={4}>
          <StatCard
            title="Last seats"
            value={stats.filling}
            icon={LocalFireDepartmentIcon}
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
          placeholder="Search game, host, ground or sport…"
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

        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>
            <Box component="span" display="flex" alignItems="center" gap={0.5}>
              <FilterListIcon sx={{ fontSize: 16 }} />
              When
            </Box>
          </InputLabel>
          <Select
            value={when}
            label="When"
            onChange={(e) => setWhen(e.target.value)}
          >
            {WHEN_OPTIONS.map((o) => (
              <MenuItem key={o.value} value={o.value}>
                {o.label}
              </MenuItem>
            ))}
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

      <GameDetailDrawer
        open={Boolean(detailId)}
        onClose={() => setDetailId(null)}
        game={detail}
      />
    </Box>
  )
}
