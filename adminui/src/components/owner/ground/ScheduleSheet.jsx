import { useState } from 'react'
import { Box, Button, Stack, Switch, TextField, Typography } from '@mui/material'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import ContentCopyIcon from '@mui/icons-material/ContentCopy'

import ActionSheet from '../ActionSheet.jsx'
import { Card } from '../OwnerBits.jsx'
import { schedulesApi } from '../../../api/schedules.js'
import { useNotify } from '../../../hooks/useNotify.js'

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
// Monday first — how people read a week.
const ORDER = [1, 2, 3, 4, 5, 6, 0]
const DEFAULT_DAY = { start_time: '06:00', end_time: '22:00', is_closed: false }

const buildWeek = (existing = []) =>
  DAYS.map((_, i) => {
    const e = existing.find((s) => s.day_of_week === i)
    return e
      ? { day_of_week: i, start_time: String(e.start_time || '06:00').slice(0, 5), end_time: String(e.end_time || '22:00').slice(0, 5), is_closed: Boolean(e.is_closed) }
      : { day_of_week: i, ...DEFAULT_DAY }
  })

/**
 * Weekly opening hours for one sport. Customers can only book inside these
 * hours; slots for each day are made from them.
 */
export default function ScheduleSheet({ open, onClose, groundId, groundSport, schedules }) {
  return (
    <ActionSheet open={open} onClose={onClose} title="Opening hours" subtitle={groundSport?.sport?.name}>
      {open && groundSport && (
        <ScheduleForm key={groundSport.id} groundId={groundId} groundSport={groundSport} schedules={schedules} onClose={onClose} />
      )}
    </ActionSheet>
  )
}

function ScheduleForm({ groundId, groundSport, schedules, onClose }) {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [week, setWeek] = useState(() => buildWeek(schedules))

  const setDay = (i, patch) => setWeek((w) => w.map((d) => (d.day_of_week === i ? { ...d, ...patch } : d)))

  const copyMonday = () => {
    const src = week.find((d) => d.day_of_week === 1 && !d.is_closed) ?? week.find((d) => !d.is_closed)
    if (!src) { notify.warning('Open at least one day first'); return }
    setWeek((w) => w.map((d) => ({ ...d, start_time: src.start_time, end_time: src.end_time })))
    notify.info(`Every day set to ${src.start_time} – ${src.end_time}`)
  }

  const bad = week.filter((d) => !d.is_closed && d.end_time <= d.start_time)

  const mutation = useMutation({
    mutationFn: () => schedulesApi.upsertSchedule(groundId, {
      ground_sport_id: Number(groundSport.id),
      schedules: week.map((d) => ({
        day_of_week: d.day_of_week,
        start_time: `${d.start_time}:00`,
        end_time: `${d.end_time}:00`,
        is_closed: d.is_closed,
      })),
    }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'schedule', groundId] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'slots', groundId] })
      notify.success('Opening hours saved')
      onClose()
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save opening hours'),
  })

  return (
    <Box>
      <Typography variant="body2" color="text.secondary" mb={1.5}>
        Customers can book {groundSport?.sport?.name ?? 'this sport'} only inside these hours. To close one time on one day, use the Slots tab.
      </Typography>
      <Button size="small" startIcon={<ContentCopyIcon />} onClick={copyMonday} sx={{ mb: 1 }}>
        Use Monday&apos;s hours for every day
      </Button>
      <Card sx={{ px: 2 }}>
        {ORDER.map((i, idx) => {
          const d = week[i]
          const invalid = !d.is_closed && d.end_time <= d.start_time
          return (
            <Box key={i} sx={{ py: 1.25, borderBottom: idx === ORDER.length - 1 ? 0 : 1, borderColor: 'divider' }}>
              <Stack direction="row" alignItems="center" justifyContent="space-between">
                <Typography fontWeight={600}>{DAYS[i]}</Typography>
                <Stack direction="row" alignItems="center" spacing={0.5}>
                  <Typography variant="body2" color={d.is_closed ? 'error.main' : 'text.secondary'}>
                    {d.is_closed ? 'Closed' : 'Open'}
                  </Typography>
                  <Switch checked={!d.is_closed} onChange={(e) => setDay(i, { is_closed: !e.target.checked })} inputProps={{ 'aria-label': `${DAYS[i]} open` }} />
                </Stack>
              </Stack>
              {!d.is_closed && (
                <Stack direction="row" spacing={1.5} mt={0.5}>
                  <TextField label="Opens" type="time" value={d.start_time} onChange={(e) => setDay(i, { start_time: e.target.value })} fullWidth InputLabelProps={{ shrink: true }} />
                  <TextField
                    label="Closes"
                    type="time"
                    value={d.end_time}
                    onChange={(e) => setDay(i, { end_time: e.target.value })}
                    fullWidth
                    InputLabelProps={{ shrink: true }}
                    error={invalid}
                    helperText={invalid ? 'Must be after opening' : ''}
                  />
                </Stack>
              )}
            </Box>
          )
        })}
      </Card>
      <Stack spacing={1} mt={2.5}>
        <Button variant="contained" size="large" disabled={bad.length > 0 || mutation.isPending} onClick={() => mutation.mutate()}>
          {mutation.isPending ? 'Saving…' : 'Save opening hours'}
        </Button>
        <Button size="large" onClick={onClose}>Cancel</Button>
      </Stack>
    </Box>
  )
}
