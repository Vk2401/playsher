import { useMemo, useState } from 'react'
import { Badge, Box, Button, IconButton, Skeleton, Stack, Typography } from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import dayjs from 'dayjs'
import { Bar, BarChart, ResponsiveContainer, Tooltip, XAxis } from 'recharts'

import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone'
import PhoneIcon from '@mui/icons-material/Phone'
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined'
import HourglassTopIcon from '@mui/icons-material/HourglassTop'
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined'
import AccountBalanceOutlinedIcon from '@mui/icons-material/AccountBalanceOutlined'
import EventBusyOutlinedIcon from '@mui/icons-material/EventBusyOutlined'
import StadiumOutlinedIcon from '@mui/icons-material/StadiumOutlined'

import GroundSwitcher from '../../components/owner/GroundSwitcher.jsx'
import BookingCard from '../../components/owner/BookingCard.jsx'
import BookingSheet from '../../components/owner/BookingSheet.jsx'
import GroundFormSheet from '../../components/owner/GroundFormSheet.jsx'
import { Banner, Card, EmptyNote, SectionTitle } from '../../components/owner/OwnerBits.jsx'
import {
  bookingEnd, bookingInfo, bookingMoney, bookingStart, clock, isUpcoming, rupee, telHref, todayYmd, unwrapList, ymd,
} from '../../components/owner/ownerFormat.js'
import { useAuth } from '../../contexts/AuthContext.jsx'
import { useOwnerGround } from '../../contexts/OwnerGroundContext.jsx'
import { usePendingCoachRequests, useUnreadNotifications } from '../../hooks/useOwnerCounts.js'
import { bookingsApi } from '../../api/bookings.js'
import { bankDetailsApi } from '../../api/bankDetails.js'

/**
 * Today — the owner's home screen.
 *
 * Answers the questions an owner has when they open the app at the ground:
 * who is next, how much cash do I collect, and is anything waiting on me.
 * The old analytics dashboard is replaced by a simple last-7-days card.
 */
export default function OwnerToday() {
  const theme = useTheme()
  const navigate = useNavigate()
  const { user } = useAuth()
  const { ground, groundId, grounds, isLoading: groundsLoading } = useOwnerGround()
  const pendingCoach = usePendingCoachRequests()
  const unread = useUnreadNotifications()
  const [open, setOpen] = useState(null)
  const [adding, setAdding] = useState(false)

  const today = todayYmd()
  const weekFrom = ymd(dayjs().subtract(6, 'day'))

  const todayQ = useQuery({
    queryKey: ['owner', 'bookings', { date: today, ground_id: groundId }],
    queryFn: () => bookingsApi.getOwnerBookings({ date: today, ground_id: groundId, limit: 100 }),
    select: unwrapList,
    enabled: Boolean(groundId),
    refetchInterval: 60_000,
  })

  const weekQ = useQuery({
    queryKey: ['owner', 'bookings', { date_from: weekFrom, date_to: today, ground_id: groundId }],
    queryFn: () => bookingsApi.getOwnerBookings({ date_from: weekFrom, date_to: today, ground_id: groundId, limit: 100 }),
    select: unwrapList,
    enabled: Boolean(groundId),
  })

  const bankQ = useQuery({
    queryKey: ['owner', 'bank-details'],
    queryFn: () => bankDetailsApi.get(),
    select: (res) => res.data?.bank_details || res.data?.data || null,
  })

  const todays = useMemo(
    () => [...(todayQ.data ?? [])].sort((a, b) => bookingStart(a) - bookingStart(b)),
    [todayQ.data],
  )
  const active = todays.filter((b) => b.status !== 'cancelled')
  const next = todays.find((b) => isUpcoming(b) && bookingStart(b).isAfter(dayjs()))
    ?? todays.find((b) => isUpcoming(b))
  const paidOnline = active.reduce((s, b) => s + bookingMoney(b).paidOnline, 0)
  const atGround = active.reduce((s, b) => s + bookingMoney(b).balance, 0)
  const awaiting = todays.filter((b) => b.status === 'pending')

  const week = useMemo(() => {
    const rows = (weekQ.data ?? []).filter((b) => b.status !== 'cancelled')
    return Array.from({ length: 7 }, (_, i) => {
      const d = dayjs().subtract(6 - i, 'day')
      const key = ymd(d)
      const dayRows = rows.filter((b) => ymd(b.slot_date) === key)
      return {
        day: i === 6 ? 'Today' : d.format('dd'),
        bookings: dayRows.length,
        earned: dayRows.reduce((s, b) => s + bookingMoney(b).total, 0),
      }
    })
  }, [weekQ.data])
  const weekTotal = week.reduce((s, d) => s + d.earned, 0)
  const weekCount = week.reduce((s, d) => s + d.bookings, 0)

  const hour = dayjs().hour()
  const greeting = `${hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening'}${user?.name ? `, ${user.name.split(' ')[0]}` : ''}`

  // Nothing to show until the owner has a ground.
  if (!groundsLoading && grounds.length === 0) {
    return (
      <Box>
        <Typography variant="h5" fontWeight={800} mb={1}>{greeting}</Typography>
        <Card>
          <EmptyNote
            icon={StadiumOutlinedIcon}
            title="Add your first ground"
            text="Once Playsher approves it, customers can find it and book in the app."
            action={<Button variant="contained" onClick={() => setAdding(true)}>Add a ground</Button>}
          />
        </Card>
        <GroundFormSheet open={adding} onClose={() => setAdding(false)} />
      </Box>
    )
  }

  const attention = []
  if (ground && !ground.is_approved) {
    attention.push({ key: 'review', tone: 'warning', icon: InfoOutlinedIcon, text: 'Playsher is reviewing this ground. Customers can book it once it is approved.' })
  }
  if (ground && ground.is_active === false) {
    attention.push({ key: 'closed', tone: 'error', icon: EventBusyOutlinedIcon, text: 'This ground is closed for booking.', onClick: () => navigate('/owner/my-ground') })
  }
  if (pendingCoach > 0) {
    attention.push({ key: 'coach', tone: 'primary', icon: GroupsOutlinedIcon, text: `${pendingCoach} coach ${pendingCoach > 1 ? 'requests need' : 'request needs'} your answer`, onClick: () => navigate('/owner/coach-requests') })
  }
  awaiting.forEach((b) => attention.push({
    key: `pay-${b.id}`, tone: 'warning', icon: HourglassTopIcon,
    text: `${bookingInfo(b).customer} is paying for ${clock(b.slot_time_from)}`, onClick: () => setOpen(b),
  }))
  if (bankQ.isSuccess && !bankQ.data) {
    attention.push({ key: 'bank', tone: 'error', icon: AccountBalanceOutlinedIcon, text: 'Add your bank details so online payments can reach you', onClick: () => navigate('/owner/bank-details') })
  }

  // Timeline with a "now" line between the past and the rest of the day.
  const nowIndex = todays.findIndex((b) => bookingStart(b).isAfter(dayjs()))
  const minsToNext = next ? bookingStart(next).diff(dayjs(), 'minute') : 0
  const nextLabel = !next ? '' : minsToNext <= 0 ? 'Playing now'
    : minsToNext < 60 ? `in ${minsToNext} min` : `at ${clock(next.slot_time_from)}`

  const loading = groundsLoading || todayQ.isLoading

  return (
    <Box>
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
        <GroundSwitcher greeting={greeting} />
        <IconButton onClick={() => navigate('/owner/notifications')} aria-label="Notifications" sx={{ mt: 0.5 }}>
          <Badge color="warning" badgeContent={unread} max={9}>
            <NotificationsNoneIcon />
          </Badge>
        </IconButton>
      </Stack>

      {/* Next booking */}
      {loading ? (
        <Skeleton variant="rounded" height={150} />
      ) : next ? (
        <Box
          sx={{
            borderRadius: 1, p: 2.25, color: 'primary.contrastText',
            background: `linear-gradient(145deg, ${theme.palette.primary.main} 0%, ${theme.palette.primary.dark} 100%)`,
          }}
        >
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Typography variant="body2" fontWeight={600} sx={{ opacity: 0.9 }}>Next booking</Typography>
            <Box sx={{ px: 1.25, py: 0.25, borderRadius: 1, bgcolor: alpha(theme.palette.common.white, 0.2) }}>
              <Typography variant="caption" fontWeight={700} color="inherit">{nextLabel}</Typography>
            </Box>
          </Stack>
          <Typography variant="h5" fontWeight={800} mt={1} color="inherit">{bookingInfo(next).customer}</Typography>
          <Typography variant="body2" sx={{ opacity: 0.92 }}>
            {clock(next.slot_time_from)} – {clock(next.slot_time_to)} · {bookingInfo(next).sport}
          </Typography>
          <Stack direction="row" justifyContent="space-between" alignItems="center" mt={2} spacing={1}>
            <Typography variant="body2" fontWeight={700} color="inherit">
              {bookingMoney(next).balance > 0 ? `Collect ${rupee(bookingMoney(next).balance)} at ground` : next.status === 'pending' ? 'Customer is paying now' : 'Fully paid online'}
            </Typography>
            <Stack direction="row" spacing={1}>
              {bookingInfo(next).mobile && (
                <IconButton href={telHref(bookingInfo(next).mobile)} aria-label="Call customer" sx={{ bgcolor: 'common.white', color: 'primary.dark', '&:hover': { bgcolor: alpha(theme.palette.common.white, 0.9) } }}>
                  <PhoneIcon fontSize="small" />
                </IconButton>
              )}
              <Button onClick={() => setOpen(next)} sx={{ color: 'inherit', bgcolor: alpha(theme.palette.common.white, 0.18), '&:hover': { bgcolor: alpha(theme.palette.common.white, 0.28) } }}>
                Details
              </Button>
            </Stack>
          </Stack>
        </Box>
      ) : (
        <Card sx={{ p: 2.25 }}>
          <Typography fontWeight={700}>No more bookings today</Typography>
          <Typography variant="body2" color="text.secondary">New bookings show up here as soon as customers book.</Typography>
        </Card>
      )}

      {/* Today in numbers */}
      <Stack direction="row" spacing={1.25} mt={1.5}>
        {[
          { label: 'Bookings', value: active.length, color: 'text.primary' },
          { label: 'Paid online', value: rupee(paidOnline), color: 'primary.dark' },
          { label: 'At ground', value: rupee(atGround), color: 'warning.dark' },
        ].map((s) => (
          <Card key={s.label} sx={{ flex: 1, p: 1.5, minWidth: 0 }}>
            <Typography variant="caption" color="text.secondary" fontWeight={500}>{s.label}</Typography>
            {loading
              ? <Skeleton width="70%" height={28} />
              : <Typography fontWeight={800} fontSize={18} color={s.color} noWrap>{s.value}</Typography>}
          </Card>
        ))}
      </Stack>

      {attention.length > 0 && (
        <>
          <SectionTitle>Needs your attention</SectionTitle>
          {attention.map((a) => (
            <Banner key={a.key} tone={a.tone} icon={a.icon} onClick={a.onClick}>{a.text}</Banner>
          ))}
        </>
      )}

      <SectionTitle action="All bookings" onAction={() => navigate('/owner/bookings')}>
        Today&apos;s schedule
      </SectionTitle>
      {loading && [0, 1, 2].map((i) => <Skeleton key={i} variant="rounded" height={84} sx={{ mb: 1.25 }} />)}
      {todayQ.isError && (
        <Banner tone="error">Could not load today&apos;s bookings. Check your internet and pull to refresh.</Banner>
      )}
      {!loading && !todayQ.isError && todays.length === 0 && (
        <Card><EmptyNote icon={EventBusyOutlinedIcon} title="No bookings today" text="When customers book, they appear here." /></Card>
      )}
      {todays.map((b, i) => (
        <Box key={b.id}>
          {i === nowIndex && i > 0 && <NowLine />}
          <BookingCard booking={b} onOpen={setOpen} dim={bookingEnd(b).isBefore(dayjs()) && b.status !== 'pending'} />
        </Box>
      ))}
      {todays.length > 0 && nowIndex === -1 && <NowLine />}

      {/* Last 7 days — replaces the old charts */}
      <SectionTitle>Last 7 days</SectionTitle>
      <Card sx={{ p: 2 }}>
        <Stack direction="row" justifyContent="space-between">
          <Box>
            <Typography variant="caption" color="text.secondary">Booking value</Typography>
            <Typography fontWeight={800} fontSize={20}>{rupee(weekTotal)}</Typography>
          </Box>
          <Box textAlign="right">
            <Typography variant="caption" color="text.secondary">Bookings</Typography>
            <Typography fontWeight={800} fontSize={20}>{weekCount}</Typography>
          </Box>
        </Stack>
        <Box height={120} mt={1}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={week} margin={{ top: 8, right: 0, left: 0, bottom: 0 }}>
              <XAxis dataKey="day" tickLine={false} axisLine={false} tick={{ fontSize: 11, fill: theme.palette.text.secondary }} />
              <Tooltip
                cursor={{ fill: alpha(theme.palette.primary.main, 0.08) }}
                formatter={(v, name) => (name === 'earned' ? [rupee(v), 'Value'] : [v, 'Bookings'])}
              />
              <Bar dataKey="earned" fill={theme.palette.primary.main} radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </Box>
        <Typography variant="caption" color="text.secondary">
          Total value of bookings played, online and at the ground. Cancelled bookings are left out.
        </Typography>
      </Card>

      <BookingSheet booking={open} onClose={() => setOpen(null)} />
    </Box>
  )
}

function NowLine() {
  return (
    <Stack direction="row" alignItems="center" spacing={1} my={1}>
      <Typography variant="caption" fontWeight={700} color="error.main">Now {dayjs().format('h:mm A')}</Typography>
      <Box sx={{ flex: 1, height: 2, bgcolor: 'error.main', opacity: 0.4, borderRadius: 1 }} />
    </Stack>
  )
}
