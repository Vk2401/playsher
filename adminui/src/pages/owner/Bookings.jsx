import { useMemo, useState } from 'react'
import { Box, IconButton, InputAdornment, Skeleton, TextField, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'
import SearchIcon from '@mui/icons-material/Search'
import CloseIcon from '@mui/icons-material/Close'
import EventBusyOutlinedIcon from '@mui/icons-material/EventBusyOutlined'

import GroundSwitcher from '../../components/owner/GroundSwitcher.jsx'
import DateStrip from '../../components/owner/DateStrip.jsx'
import BookingCard from '../../components/owner/BookingCard.jsx'
import BookingSheet from '../../components/owner/BookingSheet.jsx'
import { Banner, Card, EmptyNote, FilterChips } from '../../components/owner/OwnerBits.jsx'
import { bookingMoney, bookingStart, isUpcoming, rupee, todayYmd, unwrapList, ymd } from '../../components/owner/ownerFormat.js'
import { useOwnerGround } from '../../contexts/OwnerGroundContext.jsx'
import { bookingsApi } from '../../api/bookings.js'

const FILTERS = [
  { value: 'all', label: 'All', match: () => true },
  { value: 'upcoming', label: 'Upcoming', match: isUpcoming },
  { value: 'pending', label: 'Awaiting payment', match: (b) => b.status === 'pending' },
  { value: 'completed', label: 'Completed', match: (b) => b.status === 'completed' },
  { value: 'cancelled', label: 'Cancelled', match: (b) => b.status === 'cancelled' },
]

// Range the day strip covers — a week of history and two weeks ahead.
const STRIP_FROM = -7
const STRIP_TO = 14

/**
 * Bookings as cards, one day at a time. Search looks across every date by
 * customer name, phone number or booking ID.
 */
export default function OwnerBookings() {
  const { groundId } = useOwnerGround()
  const [date, setDate] = useState(todayYmd())
  const [filter, setFilter] = useState('all')
  const [search, setSearch] = useState('')
  const [open, setOpen] = useState(null)

  const term = search.trim()
  const searching = term.length >= 2

  const dayQ = useQuery({
    queryKey: ['owner', 'bookings', { date, ground_id: groundId }],
    queryFn: () => bookingsApi.getOwnerBookings({ date, ground_id: groundId, limit: 100 }),
    select: unwrapList,
    enabled: Boolean(groundId) && !searching,
  })

  const searchQ = useQuery({
    queryKey: ['owner', 'bookings', { search: term, ground_id: groundId }],
    queryFn: () => bookingsApi.getOwnerBookings({ search: term, ground_id: groundId, limit: 50 }),
    select: unwrapList,
    enabled: Boolean(groundId) && searching,
  })

  // Dots under days that have bookings.
  const rangeFrom = ymd(dayjs().add(STRIP_FROM, 'day'))
  const rangeTo = ymd(dayjs().add(STRIP_TO, 'day'))
  const rangeQ = useQuery({
    queryKey: ['owner', 'bookings', { date_from: rangeFrom, date_to: rangeTo, ground_id: groundId }],
    queryFn: () => bookingsApi.getOwnerBookings({ date_from: rangeFrom, date_to: rangeTo, ground_id: groundId, limit: 100 }),
    select: unwrapList,
    enabled: Boolean(groundId),
  })
  const counts = useMemo(() => {
    const m = {}
    ;(rangeQ.data ?? []).forEach((b) => {
      if (b.status === 'cancelled') return
      const k = ymd(b.slot_date)
      m[k] = (m[k] || 0) + 1
    })
    return m
  }, [rangeQ.data])

  const q = searching ? searchQ : dayQ
  const base = useMemo(() => {
    const rows = q.data ?? []
    return searching
      ? [...rows].sort((a, b) => bookingStart(b) - bookingStart(a))
      : [...rows].sort((a, b) => bookingStart(a) - bookingStart(b))
  }, [q.data, searching])

  const active = FILTERS.find((f) => f.value === filter) ?? FILTERS[0]
  const rows = base.filter(active.match)
  const toCollect = rows.reduce((s, b) => s + (isUpcoming(b) ? bookingMoney(b).balance : 0), 0)
  const options = FILTERS.map((f) => ({ ...f, count: base.filter(f.match).length }))
    .filter((f) => f.value === 'all' || f.count > 0 || f.value === filter)

  return (
    <Box>
      <GroundSwitcher />

      <TextField
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search name, phone or booking ID"
        fullWidth
        size="medium"
        sx={{ mb: 2, '& .MuiOutlinedInput-root': { bgcolor: 'background.paper' } }}
        InputProps={{
          startAdornment: <InputAdornment position="start"><SearchIcon color="action" /></InputAdornment>,
          endAdornment: search ? (
            <InputAdornment position="end">
              <IconButton size="small" onClick={() => setSearch('')} aria-label="Clear search"><CloseIcon fontSize="small" /></IconButton>
            </InputAdornment>
          ) : null,
        }}
      />

      {!searching && <DateStrip value={date} onChange={setDate} from={STRIP_FROM} to={STRIP_TO} counts={counts} />}

      {/* One chip is not a filter. With a single option this row was a lone
          "All 0" pill sitting under the date strip, adding a line and saying
          nothing. */}
      {options.length > 1 && (
        <Box mt={1.5}>
          <FilterChips options={options} value={filter} onChange={setFilter} />
        </Box>
      )}

      {/* The strip above already names the day; repeating "Today, 11 September
          2026" under it spent a line restating the selected chip. This line
          now carries only what the strip cannot: how many, and how much is
          still to collect. */}
      <Typography variant="body2" color="text.secondary" mt={1.75} mb={1.25}>
        {searching
          ? `${rows.length} result${rows.length === 1 ? '' : 's'} for “${term}”`
          : `${rows.length} booking${rows.length === 1 ? '' : 's'}`}
        {toCollect > 0 && (
          <Typography component="span" variant="body2" fontWeight={700} color="warning.dark"> · {rupee(toCollect)} to collect</Typography>
        )}
      </Typography>

      {q.isLoading && [0, 1, 2].map((i) => <Skeleton key={i} variant="rounded" height={84} sx={{ mb: 1.25 }} />)}
      {q.isError && <Banner tone="error">Could not load bookings. Check your internet and try again.</Banner>}
      {!q.isLoading && !q.isError && rows.length === 0 && (
        <Card>
          <EmptyNote
            icon={EventBusyOutlinedIcon}
            title={searching ? 'No bookings found' : 'No bookings'}
            text={searching ? 'Try a different name, number or booking ID.' : 'Nothing here for this day. Pick another day above.'}
          />
        </Card>
      )}
      {rows.length > 0 && (
        <Card sx={{ p: 0, overflow: 'hidden' }}>
          {rows.map((b, i) => (
            <BookingCard
              key={b.id}
              booking={b}
              onOpen={setOpen}
              showDate={searching}
              last={i === rows.length - 1}
            />
          ))}
        </Card>
      )}

      <BookingSheet booking={open} onClose={() => setOpen(null)} />
    </Box>
  )
}
