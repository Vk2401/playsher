import { useState } from 'react'
import { Box, Button, Skeleton, Stack, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'
import PhoneIcon from '@mui/icons-material/Phone'
import SportsOutlinedIcon from '@mui/icons-material/SportsOutlined'

import { Banner, Card, EmptyNote, FilterChips, InfoRow, Pill, ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { clock, dayLabel, prettyPhone, rupee, telHref } from '../../components/owner/ownerFormat.js'
import { coachesApi } from '../../api/coaches.js'

const TABS = [
  { value: 'upcoming', label: 'Upcoming', params: { upcoming: 'true' } },
  { value: 'confirmed', label: 'Confirmed', params: { status: 'confirmed' } },
  { value: 'completed', label: 'Completed', params: { status: 'completed' } },
  { value: 'all', label: 'All', params: {} },
]
const STATUS_TONE = { pending: 'warning', confirmed: 'primary', completed: 'neutral', cancelled: 'error', rejected: 'error' }

/** Coaching sessions booked on the owner's grounds. Players pay at the ground. */
export default function OwnerCoachSessions() {
  const [tab, setTab] = useState('upcoming')
  const params = TABS.find((t) => t.value === tab)?.params ?? {}

  const q = useQuery({
    queryKey: ['owner', 'coach-sessions', tab],
    queryFn: () => coachesApi.getOwnerSessions({ ...params, limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })
  const rows = q.data ?? []

  return (
    <Box>
      <ScreenHeader title="Coach sessions" subtitle="Training booked on your grounds. Players pay at the ground." back="/owner/more" />
      <FilterChips options={TABS} value={tab} onChange={setTab} />
      <Box mt={2}>
        {q.isLoading && [0, 1].map((i) => <Skeleton key={i} variant="rounded" height={150} sx={{ mb: 1.25 }} />)}
        {q.isError && <Banner tone="error">Could not load coach sessions.</Banner>}
        {q.isSuccess && rows.length === 0 && (
          <Card><EmptyNote icon={SportsOutlinedIcon} title="No sessions" text="Sessions coaches book at your grounds show here." /></Card>
        )}
        {rows.map((s) => (
          <Card key={s.id} sx={{ p: 2, mb: 1.25 }}>
            <Stack direction="row" justifyContent="space-between" alignItems="center" spacing={1}>
              <Typography fontWeight={700}>
                {dayLabel(s.session_date)} · {clock(s.time_from)} – {clock(s.time_to)}
              </Typography>
              <Pill tone={STATUS_TONE[s.status] ?? 'neutral'} label={s.status ? s.status[0].toUpperCase() + s.status.slice(1) : '—'} />
            </Stack>
            <Typography variant="body2" color="text.secondary">{dayjs(s.session_date).format('D MMM YYYY')}{s.ground?.name ? ` · ${s.ground.name}` : ''}</Typography>
            <Box mt={1}>
              <InfoRow label="Coach" value={`${s.coach?.name || '—'}${s.coach?.mobile ? ` · ${prettyPhone(s.coach.mobile)}` : ''}`} />
              <InfoRow label="Player" value={`${s.user?.name || '—'}${s.user?.mobile ? ` · ${prettyPhone(s.user.mobile)}` : ''}`} />
              <InfoRow label="Coach fee" value={rupee(s.total_amount)} last />
            </Box>
            <Stack direction="row" spacing={1} mt={1.25}>
              {s.coach?.mobile && <Button size="small" variant="outlined" startIcon={<PhoneIcon />} href={telHref(s.coach.mobile)}>Coach</Button>}
              {s.user?.mobile && <Button size="small" variant="outlined" startIcon={<PhoneIcon />} href={telHref(s.user.mobile)}>Player</Button>}
            </Stack>
          </Card>
        ))}
      </Box>
    </Box>
  )
}
