import React, { useMemo } from 'react'
import { Grid, Box, Paper, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import { useTheme } from '@mui/material/styles'
import dayjs from 'dayjs'
import {
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'

import PageHeader from '../../components/ui/PageHeader.jsx'
import StatCard from '../../components/ui/StatCard.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import { useAuth } from '../../contexts/AuthContext.jsx'
import { groundsApi } from '../../api/grounds.js'
import { bookingsApi } from '../../api/bookings.js'

import LocationOnIcon from '@mui/icons-material/LocationOn'
import BookOnlineIcon from '@mui/icons-material/BookOnline'
import AttachMoneyIcon from '@mui/icons-material/AttachMoney'
import EventAvailableIcon from '@mui/icons-material/EventAvailable'

// Recent bookings table columns
const recentColumns = [
  { field: 'id', headerName: 'ID', width: 60 },
  {
    field: 'user_name',
    headerName: 'Customer',
    flex: 1,
    minWidth: 130,
    renderCell: ({ row }) =>
      row.user?.name ?? row.user_name ?? '—',
  },
  {
    field: 'ground_name',
    headerName: 'Ground',
    flex: 1,
    minWidth: 130,
    renderCell: ({ row }) =>
      row.ground?.name ?? row.ground_name ?? '—',
  },
  {
    field: 'amount',
    headerName: 'Amount',
    width: 110,
    renderCell: ({ row }) => {
      const amt = row.payment?.amount ?? row.amount
      return amt != null ? `₨ ${Number(amt).toLocaleString()}` : '—'
    },
  },
  {
    field: 'status',
    headerName: 'Status',
    width: 120,
    renderCell: ({ value }) => <StatusChip status={value ?? 'pending'} />,
  },
  {
    field: 'created_at',
    headerName: 'Date',
    width: 120,
    renderCell: ({ value }) =>
      value ? dayjs(value).format('DD MMM YYYY') : '—',
  },
]

export default function OwnerDashboard() {
  const theme = useTheme()
  const primary = theme.palette.primary.main
  const { user } = useAuth()

  // ── Queries ───────────────────────────────────────────────────────────────
  const { data: groundsData, isLoading: gLoad } = useQuery({
    queryKey: ['owner', 'grounds'],
    queryFn: () => groundsApi.getOwnerGrounds(),
    select: (res) => res.data,
  })

  const { data: bookingsData, isLoading: bLoad } = useQuery({
    queryKey: ['owner', 'bookings'],
    queryFn: () => bookingsApi.getOwnerBookings(),
    select: (res) => res.data,
  })

  const grounds = useMemo(
    () => groundsData?.grounds ?? groundsData?.data ?? [],
    [groundsData],
  )
  const bookings = useMemo(
    () => bookingsData?.bookings ?? bookingsData?.data ?? [],
    [bookingsData],
  )

  // ── Derived stats ─────────────────────────────────────────────────────────
  const pendingBookings = useMemo(
    () => bookings.filter((b) => b.status === 'pending').length,
    [bookings],
  )

  const totalRevenue = useMemo(
    () =>
      bookings
        .filter((b) => b.status === 'completed' || b.payment?.status === 'success')
        .reduce((sum, b) => sum + parseFloat(b.payment?.amount ?? b.amount ?? 0), 0),
    [bookings],
  )

  const activeSlots = useMemo(
    () =>
      grounds.reduce((sum, g) => sum + (g.active_slots_count ?? 0), 0),
    [grounds],
  )

  // ── Chart data ────────────────────────────────────────────────────────────
  const bookingChartData = useMemo(() => {
    return Array.from({ length: 14 }, (_, i) => {
      const date = dayjs().subtract(13 - i, 'day')
      const label = date.format('MMM D')
      const count = bookings.filter(
        (b) =>
          dayjs(b.created_at).format('YYYY-MM-DD') === date.format('YYYY-MM-DD'),
      ).length
      return { date: label, count }
    })
  }, [bookings])

  const revenuePerGround = useMemo(() => {
    const map = {}
    bookings.forEach((b) => {
      const gid = b.ground_id ?? b.ground?.id
      const gname = b.ground?.name ?? `Ground #${gid}`
      const amt = parseFloat(b.payment?.amount ?? b.amount ?? 0)
      if (gid) {
        if (!map[gid]) map[gid] = { name: gname.slice(0, 18), revenue: 0 }
        if (b.status === 'completed' || b.payment?.status === 'success') {
          map[gid].revenue += amt
        }
      }
    })
    return Object.values(map).sort((a, b) => b.revenue - a.revenue).slice(0, 6)
  }, [bookings])

  const recentBookings = useMemo(
    () => [...bookings].sort((a, b) => dayjs(b.created_at).diff(dayjs(a.created_at))).slice(0, 5),
    [bookings],
  )

  const stats = [
    {
      title: 'My Grounds',
      value: groundsData?.total ?? grounds.length ?? '—',
      icon: LocationOnIcon,
      loading: gLoad,
    },
    {
      title: 'Pending Bookings',
      value: bLoad ? undefined : pendingBookings,
      icon: BookOnlineIcon,
      loading: bLoad,
    },
    {
      title: 'Total Revenue',
      value: bLoad ? undefined : `₨ ${totalRevenue.toLocaleString()}`,
      icon: AttachMoneyIcon,
      loading: bLoad,
    },
    {
      title: 'Active Slots',
      value: gLoad ? undefined : activeSlots || '—',
      icon: EventAvailableIcon,
      loading: gLoad,
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title={`Welcome, ${user?.name ?? 'Owner'}`}
        subtitle="Your grounds overview"
      />

      {/* KPI Cards */}
      <Grid container spacing={2.5} mb={3}>
        {stats.map((s, i) => (
          <Grid item xs={12} sm={6} lg={3} key={i}>
            <StatCard {...s} />
          </Grid>
        ))}
      </Grid>

      {/* Charts row */}
      <Grid container spacing={2.5} mb={3}>
        {/* Bookings over 14 days */}
        <Grid item xs={12} md={7}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="subtitle1" fontWeight={600} mb={2}>
              Bookings — Last 14 Days
            </Typography>
            <ResponsiveContainer width="100%" height={230}>
              <AreaChart data={bookingChartData}>
                <defs>
                  <linearGradient id="ownerBookGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={primary} stopOpacity={0.3} />
                    <stop offset="95%" stopColor={primary} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
                <Tooltip />
                <Area
                  type="monotone"
                  dataKey="count"
                  stroke={primary}
                  fill="url(#ownerBookGrad)"
                  strokeWidth={2}
                  name="Bookings"
                />
              </AreaChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>

        {/* Revenue per ground */}
        <Grid item xs={12} md={5}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="subtitle1" fontWeight={600} mb={2}>
              Revenue per Ground (PKR)
            </Typography>
            <ResponsiveContainer width="100%" height={230}>
              <BarChart data={revenuePerGround} layout="vertical">
                <CartesianGrid
                  strokeDasharray="3 3"
                  stroke="rgba(0,0,0,0.06)"
                  horizontal={false}
                />
                <XAxis type="number" tick={{ fontSize: 11 }} />
                <YAxis
                  dataKey="name"
                  type="category"
                  tick={{ fontSize: 11 }}
                  width={100}
                />
                <Tooltip formatter={(v) => [`₨ ${Number(v).toLocaleString()}`, 'Revenue']} />
                <Bar
                  dataKey="revenue"
                  fill={primary}
                  radius={[0, 6, 6, 0]}
                  name="Revenue (PKR)"
                />
              </BarChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>
      </Grid>

      {/* Recent bookings */}
      <Paper sx={{ p: 3 }}>
        <Typography variant="subtitle1" fontWeight={600} mb={2}>
          Recent Bookings
        </Typography>
        <DataTable
          rows={recentBookings}
          columns={recentColumns}
          loading={bLoad}
          pageSize={5}
          pageSizeOptions={[5]}
          hideFooter={recentBookings.length <= 5}
        />
      </Paper>
    </Box>
  )
}
