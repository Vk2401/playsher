import { useMemo, useState } from 'react'
import { Box, Button, ButtonBase, Chip, Skeleton, Stack, TextField, Typography } from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'
import LockIcon from '@mui/icons-material/Lock'
import AddIcon from '@mui/icons-material/Add'
import ScheduleIcon from '@mui/icons-material/Schedule'
import WarningAmberIcon from '@mui/icons-material/WarningAmber'
import EventBusyOutlinedIcon from '@mui/icons-material/EventBusyOutlined'

import DateStrip from '../DateStrip.jsx'
import ActionSheet from '../ActionSheet.jsx'
import BookingSheet from '../BookingSheet.jsx'
import ScheduleSheet from './ScheduleSheet.jsx'
import { Banner, Card, EmptyNote, ListRow } from '../OwnerBits.jsx'
import { bookingInfo, clock, clockShort, todayYmd, toMinutes, unwrapList, ymd } from '../ownerFormat.js'
import { slotsApi } from '../../../api/slots.js'
import { schedulesApi } from '../../../api/schedules.js'
import { bookingsApi } from '../../../api/bookings.js'
import { useNotify } from '../../../hooks/useNotify.js'

/**
 * One day of 30-minute slots for one sport, as tiles.
 * Free → tap to close it. Closed → tap to open it again. Booked → tap to see
 * the booking. A slot that holds a booking is never toggled from here, so an
 * owner cannot accidentally reopen a paid time for a second customer.
 */
export default function SlotsTab({ groundId, onAddSport }) {
  const theme = useTheme()
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [date, setDate] = useState(todayYmd())
  const [gsId, setGsId] = useState(null)
  const [showEarlier, setShowEarlier] = useState(false)
  const [picked, setPicked] = useState(null) // slot being acted on
  const [booking, setBooking] = useState(null)
  const [adding, setAdding] = useState(false)
  const [hoursFor, setHoursFor] = useState(null)

  const slotsKey = ['owner', 'slots', groundId, date]
  const slotsQ = useQuery({
    queryKey: slotsKey,
    queryFn: () => slotsApi.getGroundSlots(groundId, { date }),
    select: (res) => res.data?.data ?? {},
    enabled: Boolean(groundId),
  })
  const bookingsQ = useQuery({
    queryKey: ['owner', 'bookings', { date, ground_id: groundId }],
    queryFn: () => bookingsApi.getOwnerBookings({ date, ground_id: groundId, limit: 100 }),
    select: unwrapList,
    enabled: Boolean(groundId),
  })
  const scheduleQ = useQuery({
    queryKey: ['owner', 'schedule', groundId],
    queryFn: () => schedulesApi.getSchedule(groundId),
    select: (res) => res.data?.data?.ground_sports ?? [],
    enabled: Boolean(groundId),
  })

  const sports = slotsQ.data?.ground_sports ?? []
  const current = sports.find((s) => s.id === gsId) ?? sports[0]
  const schedule = (scheduleQ.data ?? []).find((g) => g.id === current?.id)?.schedules ?? []
  const hasOpenDay = schedule.some((s) => !s.is_closed)

  const nowMin = dayjs().hour() * 60 + dayjs().minute()
  const isToday = date === todayYmd()
  const isPastDay = dayjs(date).isBefore(dayjs(), 'day')

  const tiles = useMemo(() => {
    const active = (bookingsQ.data ?? []).filter((b) => b.status !== 'cancelled')
    return (slotsQ.data?.slots ?? [])
      .filter((s) => s.ground_sport_id === current?.id)
      .sort((a, b) => toMinutes(a.slot_start_time) - toMinutes(b.slot_start_time))
      .map((s) => {
        const start = toMinutes(s.slot_start_time)
        const b = active.find((bk) => bk.ground_sport_id === s.ground_sport_id
          && toMinutes(bk.slot_time_from) <= start && start < toMinutes(bk.slot_time_to))
        const past = isPastDay || (isToday && toMinutes(s.slot_end_time) <= nowMin)
        let state = s.is_available ? 'free' : 'closed'
        if (b) state = 'booked'
        return { slot: s, booking: b, state, past }
      })
  }, [slotsQ.data, bookingsQ.data, current, isToday, isPastDay, nowMin])

  const hiddenCount = isToday && !showEarlier ? tiles.filter((t) => t.past).length : 0
  const visible = hiddenCount ? tiles.filter((t) => !t.past) : tiles

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['owner', 'slots', groundId] })
  }

  const toggle = useMutation({
    mutationFn: (slot) => slotsApi.toggleStatus(groundId, slot.id),
    onSuccess: (_r, slot) => {
      notify.success(slot.is_available ? `${clock(slot.slot_start_time)} closed for booking` : `${clock(slot.slot_start_time)} open for booking again`)
      setPicked(null)
      invalidate()
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not change that time'),
  })
  const remove = useMutation({
    mutationFn: (slot) => slotsApi.delete(groundId, slot.id),
    onSuccess: () => { notify.success('Time removed from this day'); setPicked(null); invalidate() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not remove that time'),
  })

  const look = {
    free: { bg: 'background.paper', border: theme.palette.divider, color: 'text.primary', label: 'Free' },
    booked: { bg: alpha(theme.palette.primary.main, 0.14), border: 'transparent', color: 'primary.dark', label: 'Booked' },
    closed: { bg: alpha(theme.palette.error.main, 0.1), border: 'transparent', color: 'error.main', label: 'Closed' },
  }

  if (slotsQ.isSuccess && sports.length === 0) {
    return (
      <Card sx={{ mt: 2 }}>
        <EmptyNote
          icon={EventBusyOutlinedIcon}
          title="No sports yet"
          text="Add a sport first. Then set its opening hours and the times appear here."
          action={<Button variant="contained" onClick={onAddSport}>Add a sport</Button>}
        />
      </Card>
    )
  }

  return (
    <Box mt={2}>
      {sports.length > 1 && (
        <Stack direction="row" spacing={1} mb={1.5} sx={{ overflowX: 'auto' }}>
          {sports.map((s) => (
            <Chip
              key={s.id}
              label={`${s.sport?.name ?? 'Sport'}${s.is_active === false ? ' (paused)' : ''}`}
              onClick={() => setGsId(s.id)}
              color={s.id === current?.id ? 'primary' : 'default'}
              variant={s.id === current?.id ? 'filled' : 'outlined'}
              sx={{ fontWeight: 600, bgcolor: s.id === current?.id ? undefined : 'background.paper' }}
            />
          ))}
        </Stack>
      )}

      <DateStrip value={date} onChange={(d) => { setDate(d); setShowEarlier(false) }} from={0} to={13} />

      {scheduleQ.isSuccess && current && !hasOpenDay && (
        <Box mt={1.5}>
          <Banner tone="warning" icon={WarningAmberIcon} onClick={() => setHoursFor(current)}>
            {current.sport?.name} has no opening hours, so customers see no times. Set them now.
          </Banner>
        </Box>
      )}

      <Stack direction="row" spacing={2} mt={1.5} mb={1.25}>
        {['free', 'booked', 'closed'].map((k) => (
          <Stack key={k} direction="row" spacing={0.75} alignItems="center">
            <Box sx={{ width: 12, height: 12, borderRadius: 0.5, bgcolor: look[k].bg, border: 1.5, borderColor: k === 'free' ? 'text.disabled' : look[k].border }} />
            <Typography variant="caption" color="text.secondary">{look[k].label}</Typography>
          </Stack>
        ))}
      </Stack>

      {slotsQ.isLoading && (
        <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 1 }}>
          {Array.from({ length: 9 }).map((_, i) => <Skeleton key={i} variant="rounded" height={60} />)}
        </Box>
      )}
      {slotsQ.isError && <Banner tone="error">Could not load times. Check your internet and try again.</Banner>}

      {slotsQ.isSuccess && visible.length === 0 && (
        <Card>
          <EmptyNote
            icon={EventBusyOutlinedIcon}
            title={hiddenCount ? 'Today is over' : 'No times on this day'}
            text={hiddenCount ? 'All of today’s times have passed.' : 'This day is closed in the opening hours. You can still add an extra time.'}
          />
        </Card>
      )}

      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: 'repeat(3, 1fr)', sm: 'repeat(4, 1fr)' }, gap: 1 }}>
        {visible.map((t) => {
          const l = look[t.state]
          return (
            <ButtonBase
              key={t.slot.id}
              disabled={t.past && t.state !== 'booked'}
              onClick={() => (t.state === 'booked' ? setBooking(t.booking) : setPicked(t.slot))}
              sx={{
                flexDirection: 'column', py: 1.25, px: 0.5, borderRadius: 1,
                bgcolor: l.bg, border: 1.5, borderColor: l.border, opacity: t.past ? 0.5 : 1,
              }}
            >
              <Stack direction="row" spacing={0.5} alignItems="center" sx={{ color: l.color }}>
                {t.state === 'closed' && <LockIcon sx={{ fontSize: 13 }} />}
                <Typography fontWeight={700} fontSize={14} color="inherit">{clockShort(t.slot.slot_start_time)}</Typography>
              </Stack>
              <Typography variant="caption" sx={{ color: l.color, opacity: 0.85, maxWidth: '100%', px: 0.5 }} noWrap>
                {t.state === 'booked' ? bookingInfo(t.booking).customer.split(' ')[0] : t.past ? 'Over' : l.label}
              </Typography>
            </ButtonBase>
          )
        })}
      </Box>

      {hiddenCount > 0 && (
        <Button size="small" onClick={() => setShowEarlier(true)} sx={{ mt: 1 }}>
          Show {hiddenCount} earlier time{hiddenCount === 1 ? '' : 's'} today
        </Button>
      )}

      <Typography variant="body2" color="text.secondary" mt={1.5}>
        Tap a free time to close it. Tap a booked time to see who booked.
      </Typography>

      <Card sx={{ mt: 2, overflow: 'hidden' }}>
        {current && (
          <ListRow icon={ScheduleIcon} label={`Opening hours for ${current.sport?.name ?? 'this sport'}`} hint="The hours customers can book, every week" onClick={() => setHoursFor(current)} />
        )}
        {!isPastDay && (
          <ListRow icon={AddIcon} label="Add an extra time on this day" hint="For a one-off opening outside normal hours" onClick={() => setAdding(true)} last />
        )}
      </Card>

      {/* Close / open / remove one time */}
      <ActionSheet
        open={Boolean(picked)}
        onClose={() => setPicked(null)}
        title={picked?.is_available ? 'Close this time?' : 'This time is closed'}
        subtitle={picked ? `${clock(picked.slot_start_time)} – ${clock(picked.slot_end_time)} · ${current?.sport?.name ?? ''} · ${dayjs(date).format('ddd, D MMM')}` : ''}
        actions={picked && (
          <>
            <Button
              variant="contained"
              color={picked.is_available ? 'error' : 'primary'}
              size="large"
              disabled={toggle.isPending}
              onClick={() => toggle.mutate(picked)}
            >
              {picked.is_available ? 'Close this time' : 'Open for booking again'}
            </Button>
            <Button color="error" size="large" disabled={remove.isPending} onClick={() => remove.mutate(picked)}>
              Remove this time from the day
            </Button>
          </>
        )}
      >
        <Typography color="text.secondary">
          {picked?.is_available
            ? 'Customers will not be able to book this time in the app. You can open it again any time.'
            : 'Customers cannot book this time. Open it again to let them book.'}
        </Typography>
      </ActionSheet>

      <AddSlotSheet
        open={adding}
        onClose={() => setAdding(false)}
        groundId={groundId}
        groundSport={current}
        date={date}
        onDone={invalidate}
      />
      <ScheduleSheet
        open={Boolean(hoursFor)}
        onClose={() => setHoursFor(null)}
        groundId={groundId}
        groundSport={hoursFor}
        schedules={(scheduleQ.data ?? []).find((g) => g.id === hoursFor?.id)?.schedules ?? []}
      />
      <BookingSheet booking={booking} onClose={() => setBooking(null)} />
    </Box>
  )
}

function AddSlotSheet({ open, onClose, groundId, groundSport, date, onDone }) {
  const notify = useNotify()
  const [from, setFrom] = useState('06:00')
  const [to, setTo] = useState('06:30')
  const invalid = to <= from

  const mutation = useMutation({
    mutationFn: () => slotsApi.create(groundId, {
      ground_sport_id: groundSport.id,
      slot_date: ymd(date),
      slot_start_time: `${from}:00`,
      slot_end_time: `${to}:00`,
    }),
    onSuccess: () => { notify.success('Extra time added'); onDone(); onClose() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not add that time'),
  })

  return (
    <ActionSheet
      open={open}
      onClose={onClose}
      title="Add an extra time"
      subtitle={`${groundSport?.sport?.name ?? ''} · ${dayjs(date).format('ddd, D MMM')}`}
      actions={(
        <>
          <Button variant="contained" size="large" disabled={invalid || mutation.isPending || !groundSport} onClick={() => mutation.mutate()}>
            {mutation.isPending ? 'Adding…' : 'Add time'}
          </Button>
          <Button size="large" onClick={onClose}>Cancel</Button>
        </>
      )}
    >
      <Typography variant="body2" color="text.secondary" mb={2}>
        Customers book in 30-minute blocks, so keep it to 30 minutes, or add several.
      </Typography>
      <Stack direction="row" spacing={1.5}>
        <TextField label="Starts" type="time" value={from} onChange={(e) => setFrom(e.target.value)} fullWidth InputLabelProps={{ shrink: true }} />
        <TextField label="Ends" type="time" value={to} onChange={(e) => setTo(e.target.value)} fullWidth InputLabelProps={{ shrink: true }} error={invalid} helperText={invalid ? 'Must be after start' : ''} />
      </Stack>
    </ActionSheet>
  )
}
