import React from 'react'
import { Alert, AlertTitle, Box, Button, Grid, Paper, Stack, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'

import BookOnlineIcon from '@mui/icons-material/BookOnline'
import EventAvailableIcon from '@mui/icons-material/EventAvailable'
import HourglassEmptyIcon from '@mui/icons-material/HourglassEmpty'
import LocationOnIcon from '@mui/icons-material/LocationOn'
import CurrencyRupeeIcon from '@mui/icons-material/CurrencyRupee'
import TaskAltIcon from '@mui/icons-material/TaskAlt'

import PageHeader from '../../components/ui/PageHeader.jsx'
import StatCard from '../../components/ui/StatCard.jsx'
import { coachesApi } from '../../api/coaches.js'

const rupees = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`

export default function CoachDashboard() {
  const navigate = useNavigate()

  const { data, isLoading, error } = useQuery({
    queryKey: ['coach', 'dashboard'],
    queryFn: () => coachesApi.getDashboard(),
    select: (res) => res.data?.data ?? null,
  })

  const priceIsSet = Number(data?.price_per_slot ?? 0) > 0

  return (
    <Box>
      <PageHeader
        title="Coach Dashboard"
        subtitle="Your sessions, earnings and account status"
      />

      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          Could not load your dashboard. {error?.response?.data?.message || 'Please try again.'}
        </Alert>
      )}

      {/* The three things that stop a coach from being bookable, said plainly
          and each with the button that fixes it. */}
      {!isLoading && data && (
        <Stack spacing={2} mb={3}>
          {!data.is_approved && (
            <Alert severity="warning">
              <AlertTitle>Account pending approval</AlertTitle>
              A Playsher admin is reviewing your account. You can set your price and
              availability now — players will see you as soon as you are approved.
            </Alert>
          )}
          {!priceIsSet && (
            <Alert
              severity="info"
              action={
                <Button size="small" onClick={() => navigate('/coach/profile')}>Set price</Button>
              }
            >
              <AlertTitle>No price set</AlertTitle>
              Players cannot book you until you set a price for a 30-minute slot.
            </Alert>
          )}
          {!data.has_availability && (
            <Alert
              severity="info"
              action={
                <Button size="small" onClick={() => navigate('/coach/availability')}>Set hours</Button>
              }
            >
              <AlertTitle>No availability set</AlertTitle>
              Add the hours you work so players have times to choose from.
            </Alert>
          )}
        </Stack>
      )}

      <Grid container spacing={2.5}>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Upcoming" value={data?.upcoming_sessions} icon={EventAvailableIcon} loading={isLoading} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Awaiting your reply" value={data?.pending_sessions} icon={HourglassEmptyIcon} loading={isLoading} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Total sessions" value={data?.total_sessions} icon={BookOnlineIcon} loading={isLoading} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Completed" value={data?.completed_sessions} icon={TaskAltIcon} loading={isLoading} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Earnings" value={rupees(data?.total_earnings)} icon={CurrencyRupeeIcon} loading={isLoading} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Approved grounds" value={data?.approved_grounds} icon={LocationOnIcon} loading={isLoading} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Ground requests open" value={data?.pending_ground_requests} icon={HourglassEmptyIcon} loading={isLoading} />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <StatCard title="Your rate" value={priceIsSet ? `${rupees(data?.price_per_slot)} / 30 min` : '—'} icon={CurrencyRupeeIcon} loading={isLoading} />
        </Grid>
      </Grid>

      <Paper sx={{ p: 3, mt: 3 }}>
        <Typography variant="subtitle1" fontWeight={700} mb={1}>Next steps</Typography>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} mt={2}>
          <Button variant="contained" onClick={() => navigate('/coach/bookings')}>
            Review session requests
          </Button>
          <Button variant="outlined" onClick={() => navigate('/coach/availability')}>
            Edit availability
          </Button>
          <Button variant="outlined" onClick={() => navigate('/coach/grounds')}>
            Register at a ground
          </Button>
        </Stack>
      </Paper>
    </Box>
  )
}
