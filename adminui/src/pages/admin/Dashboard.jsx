import React, { useMemo } from 'react'
import { Grid, Box, Typography, Paper } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import {
  AreaChart, Area, PieChart, Pie, Cell, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
} from 'recharts'
import { useTheme } from '@mui/material/styles'
import dayjs from 'dayjs'

import StatCard from '../../components/ui/StatCard.jsx'
import PageHeader from '../../components/ui/PageHeader.jsx'
import EmptyState from '../../components/ui/EmptyState.jsx'
import { usersApi } from '../../api/users.js'
import { groundsApi } from '../../api/grounds.js'
import { bookingsApi } from '../../api/bookings.js'
import { paymentsApi } from '../../api/payments.js'

import PeopleIcon from '@mui/icons-material/People'
import LocationOnIcon from '@mui/icons-material/LocationOn'
import BookOnlineIcon from '@mui/icons-material/BookOnline'
import AttachMoneyIcon from '@mui/icons-material/AttachMoney'

const PAYMENT_COLORS = {
  success: '#6B9E7A',
  pending: '#F4A261',
  failed: '#E76F51',
  refunded: '#5B7FA6',
}

export default function AdminDashboard() {
  const theme = useTheme()
  const primary = theme.palette.primary.main

  const { data: usersData, isLoading: uLoad } = useQuery({
    queryKey: ['admin', 'users'],
    queryFn: () => usersApi.getAll({ page: 1, limit: 1 }),
    select: (res) => res.data,
  })

  const { data: groundsData, isLoading: gLoad } = useQuery({
    queryKey: ['admin', 'grounds'],
    queryFn: () => groundsApi.getAll({ page: 1, limit: 100 }),
    select: (res) => res.data,
  })

  const { data: bookingsData, isLoading: bLoad } = useQuery({
    queryKey: ['admin', 'bookings'],
    queryFn: () => bookingsApi.getAll({ page: 1, limit: 200 }),
    select: (res) => res.data,
  })

  const { data: paymentsData, isLoading: pLoad } = useQuery({
    queryKey: ['admin', 'payments'],
    queryFn: () => paymentsApi.getAll({ page: 1, limit: 500 }),
    select: (res) => res.data,
  })

  const bookings = bookingsData?.bookings ?? bookingsData?.data ?? []
  const payments = paymentsData?.payments ?? paymentsData?.data ?? []
  const grounds  = groundsData?.grounds   ?? groundsData?.data  ?? []

  // ── Chart data — all from real API, empty arrays if no data ─────────────

  const bookingChartData = useMemo(() =>
    Array.from({ length: 14 }, (_, i) => {
      const date = dayjs().subtract(13 - i, 'day')
      const count = bookings.filter(
        (b) => dayjs(b.created_at).format('YYYY-MM-DD') === date.format('YYYY-MM-DD'),
      ).length
      return { date: date.format('MMM D'), count }
    })
  , [bookings])

  const paymentPieData = useMemo(() => {
    const counts = {}
    payments.forEach((p) => {
      const s = p.payment_status || p.status || 'pending'
      counts[s] = (counts[s] || 0) + 1
    })
    return Object.entries(counts).map(([k, v]) => ({
      name: k.charAt(0).toUpperCase() + k.slice(1),
      value: v,
      color: PAYMENT_COLORS[k] || '#999',
    }))
  }, [payments])

  const topGrounds = useMemo(() => {
    const counts = {}
    bookings.forEach((b) => {
      const gid = b.ground_id ?? b.groundId
      if (gid) counts[gid] = (counts[gid] || 0) + 1
    })
    return grounds
      .map((g) => ({
        name: g.name?.slice(0, 16) ?? `G${g.id}`,
        bookings: counts[g.id] ?? 0,
      }))
      .sort((a, b) => b.bookings - a.bookings)
      .slice(0, 5)
  }, [bookings, grounds])

  const totalRevenue = useMemo(() =>
    payments
      .filter((p) => (p.payment_status || p.status) === 'success')
      .reduce((sum, p) => sum + parseFloat(p.amount ?? 0), 0)
  , [payments])

  const stats = [
    {
      title: 'Total Users',
      value: usersData?.total ?? usersData?.pagination?.total ?? '—',
      icon: PeopleIcon,
      loading: uLoad,
    },
    {
      title: 'Total Grounds',
      // Parenthesize the ?? chain before using || to avoid mixing ?? and || without parens
      // Use ?? '—' so that 0 is displayed as 0 rather than treated as missing
      value: (groundsData?.total ?? groundsData?.pagination?.total ?? grounds.length) ?? '—',
      icon: LocationOnIcon,
      loading: gLoad,
    },
    {
      title: 'Total Bookings',
      // Same fix here for bookings
      value: (bookingsData?.total ?? bookingsData?.pagination?.total ?? bookings.length) ?? '—',
      icon: BookOnlineIcon,
      loading: bLoad,
    },
    {
      title: 'Revenue (PKR)',
      value: !pLoad ? `₨${totalRevenue.toLocaleString()}` : '—',
      icon: AttachMoneyIcon,
      loading: pLoad,
    },
  ]

  return (
    <Box>
      <PageHeader title="Dashboard" subtitle="Platform overview and analytics" />

      {/* KPI Cards */}
      <Grid container spacing={2.5} mb={3}>
        {stats.map((s, i) => (
          <Grid item xs={12} sm={6} lg={3} key={i}>
            <StatCard {...s} />
          </Grid>
        ))}
      </Grid>

      {/* Charts row */}
      <Grid container spacing={2.5} mb={2.5}>
        <Grid item xs={12} md={8}>
          <Paper sx={{ p: 3 }}>
            <Typography variant="subtitle1" fontWeight={600} mb={2}>
              Bookings — Last 14 Days
            </Typography>
            <ResponsiveContainer width="100%" height={240}>
              <AreaChart data={bookingChartData}>
                <defs>
                  <linearGradient id="bookGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor={primary} stopOpacity={0.3} />
                    <stop offset="95%" stopColor={primary} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" />
                <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
                <Tooltip />
                <Area
                  type="monotone" dataKey="count" stroke={primary}
                  fill="url(#bookGrad)" strokeWidth={2} name="Bookings"
                />
              </AreaChart>
            </ResponsiveContainer>
          </Paper>
        </Grid>

        <Grid item xs={12} md={4}>
          <Paper sx={{ p: 3, height: '100%' }}>
            <Typography variant="subtitle1" fontWeight={600} mb={2}>
              Payment Status
            </Typography>
            {paymentPieData.length === 0 ? (
              <EmptyState message="No payment data yet" />
            ) : (
              <ResponsiveContainer width="100%" height={240}>
                <PieChart>
                  <Pie
                    data={paymentPieData} cx="50%" cy="50%"
                    innerRadius={55} outerRadius={85}
                    paddingAngle={3} dataKey="value"
                  >
                    {paymentPieData.map((entry, i) => (
                      <Cell key={i} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(v, n) => [v, n]} />
                  <Legend iconSize={10} wrapperStyle={{ fontSize: 12 }} />
                </PieChart>
              </ResponsiveContainer>
            )}
          </Paper>
        </Grid>
      </Grid>

      {/* Top grounds chart */}
      <Paper sx={{ p: 3 }}>
        <Typography variant="subtitle1" fontWeight={600} mb={2}>
          Top 5 Grounds by Bookings
        </Typography>
        {topGrounds.length === 0 ? (
          <EmptyState message="No grounds data yet" />
        ) : (
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={topGrounds} layout="vertical">
              <CartesianGrid
                strokeDasharray="3 3" stroke="rgba(0,0,0,0.06)" horizontal={false}
              />
              <XAxis type="number" tick={{ fontSize: 11 }} allowDecimals={false} />
              <YAxis dataKey="name" type="category" tick={{ fontSize: 11 }} width={90} />
              <Tooltip />
              <Bar dataKey="bookings" fill={primary} radius={[0, 6, 6, 0]} name="Bookings" />
            </BarChart>
          </ResponsiveContainer>
        )}
      </Paper>
    </Box>
  )
}
