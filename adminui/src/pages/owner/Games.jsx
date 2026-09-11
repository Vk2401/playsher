import { useMemo, useState } from 'react'
import { Box, ButtonBase, InputAdornment, LinearProgress, Skeleton, Stack, TextField, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'
import SearchIcon from '@mui/icons-material/Search'
import LockOutlinedIcon from '@mui/icons-material/LockOutlined'
import EmojiEventsOutlinedIcon from '@mui/icons-material/EmojiEventsOutlined'

import GameDetailDrawer from '../../components/ui/GameDetailDrawer.jsx'
import { Banner, Card, EmptyNote, FilterChips, Pill, ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { clock, dayLabel, todayYmd, ymd } from '../../components/owner/ownerFormat.js'
import { gamesApi } from '../../api/games.js'

const LEVELS = {
  newbie: 'Newbie', beginner: 'Beginner', intermediate: 'Intermediate',
  advanced: 'Advanced', professional: 'Professional', ultra_professional: 'Ultra pro',
}

/**
 * Open games running at the owner's grounds — whoever published them — so the
 * owner knows how many people will actually turn up. Read-only: a game belongs
 * to the player who opened it; the owner's lever is the booking.
 */
export default function OwnerGames() {
  const [when, setWhen] = useState('upcoming')
  const [search, setSearch] = useState('')
  const [detailId, setDetailId] = useState(null)

  const q = useQuery({
    queryKey: ['owner', 'games'],
    queryFn: () => gamesApi.getOwnerGames({ limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })
  const all = useMemo(() => q.data ?? [], [q.data])

  const today = todayYmd()
  const matchWhen = (g, w) => {
    const d = g.slot_date ? ymd(g.slot_date) : null
    if (w === 'all' || !d) return true
    if (w === 'today') return d === today
    if (w === 'upcoming') return d >= today
    return d < today
  }
  const term = search.trim().toLowerCase()
  const rows = all
    .filter((g) => matchWhen(g, when))
    .filter((g) => !term || [g.game_name, g.ground_name, g.sport_name, g.host_name].filter(Boolean).some((v) => String(v).toLowerCase().includes(term)))
    .sort((a, b) => (when === 'past' ? -1 : 1) * (dayjs(`${ymd(a.slot_date)}T${a.slot_time_from || '00:00'}`) - dayjs(`${ymd(b.slot_date)}T${b.slot_time_from || '00:00'}`)))

  const options = ['upcoming', 'today', 'past', 'all'].map((w) => ({
    value: w, label: w[0].toUpperCase() + w.slice(1), count: all.filter((g) => matchWhen(g, w)).length,
  }))

  const detail = all.find((g) => g.id === detailId) ?? null

  return (
    <Box>
      <ScreenHeader title="Games" subtitle="Open games at your grounds and who is coming" back="/owner/more" />
      <TextField
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search game, sport or host"
        fullWidth
        sx={{ mb: 1.5, '& .MuiOutlinedInput-root': { bgcolor: 'background.paper' } }}
        InputProps={{ startAdornment: <InputAdornment position="start"><SearchIcon color="action" /></InputAdornment> }}
      />
      <FilterChips options={options} value={when} onChange={setWhen} />

      <Box mt={2}>
        {q.isLoading && [0, 1].map((i) => <Skeleton key={i} variant="rounded" height={130} sx={{ mb: 1.25 }} />)}
        {q.isError && <Banner tone="error">Could not load games.</Banner>}
        {q.isSuccess && rows.length === 0 && (
          <Card><EmptyNote icon={EmojiEventsOutlinedIcon} title="No games" text="When players open a game on a booking at your ground, it shows here." /></Card>
        )}
        {rows.map((g) => {
          const cap = Number(g.max_participants || 0)
          const joined = Number(g.joined_count || 0)
          return (
            <ButtonBase key={g.id} onClick={() => setDetailId(g.id)} sx={{ width: '100%', display: 'block', textAlign: 'left', borderRadius: 1, mb: 1.25 }}>
              <Card sx={{ p: 2 }}>
                <Stack direction="row" justifyContent="space-between" alignItems="center" spacing={1}>
                  <Typography fontWeight={700} noWrap>{g.game_name || `Game #${g.id}`}</Typography>
                  <Stack direction="row" spacing={0.75}>
                    {g.visibility === 'private' && <Pill tone="neutral" icon={<LockOutlinedIcon />} label="Invite only" />}
                    {g.status && g.status !== 'open' && <Pill tone="neutral" label={g.status[0].toUpperCase() + g.status.slice(1)} />}
                  </Stack>
                </Stack>
                <Typography variant="body2" color="text.secondary">
                  {[g.sport_name, LEVELS[g.game_level] ?? g.game_level, g.host_name ? `Host: ${g.host_name}` : null].filter(Boolean).join(' · ')}
                </Typography>
                <Typography variant="body2" fontWeight={600} mt={0.75}>
                  {g.slot_date ? dayLabel(g.slot_date) : '—'}{g.slot_time_from ? `, ${clock(g.slot_time_from)}` : ''}{g.slot_time_to ? ` – ${clock(g.slot_time_to)}` : ''}
                  {g.ground_name ? <Typography component="span" variant="body2" color="text.secondary"> · {g.ground_name}</Typography> : null}
                </Typography>
                {cap > 0 && (
                  <Box mt={1.5}>
                    <Stack direction="row" justifyContent="space-between">
                      <Typography variant="caption" color="text.secondary" fontWeight={600}>Players coming</Typography>
                      <Typography variant="caption" fontWeight={700}>
                        {joined} of {cap}{g.spots_left > 0 && g.spots_left <= 2 ? ` · ${g.spots_left} left` : ''}
                      </Typography>
                    </Stack>
                    <LinearProgress variant="determinate" value={Math.min(100, (joined / cap) * 100)} sx={{ height: 8, borderRadius: 1, mt: 0.5 }} />
                  </Box>
                )}
                <Typography variant="body2" fontWeight={600} color="primary.dark" mt={1.25}>See who is coming</Typography>
              </Card>
            </ButtonBase>
          )
        })}
      </Box>

      <GameDetailDrawer open={Boolean(detailId)} onClose={() => setDetailId(null)} game={detail} />
    </Box>
  )
}
