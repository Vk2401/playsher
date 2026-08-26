import React, { useState } from 'react'
import { Alert, Box, Stack, Tab, Tabs, TextField, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { coachesApi } from '../../api/coaches.js'

const TABS = [
  { label: 'Upcoming', params: { upcoming: 'true' } },
  { label: 'Confirmed', params: { status: 'confirmed' } },
  { label: 'Completed', params: { status: 'completed' } },
  { label: 'All', params: {} },
]

const time = (t) => String(t ?? '').slice(0, 5)
const rupees = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`

export default function OwnerCoachSessions() {
  const [tab, setTab] = useState(0)
  const [date, setDate] = useState('')

  const params = { ...TABS[tab].params, limit: 100, ...(date ? { date } : {}) }

  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'coach-sessions', params],
    queryFn: () => coachesApi.getOwnerSessions(params),
    select: (res) => res.data?.data ?? [],
  })

  const columns = [
    {
      field: 'session_date',
      headerName: 'When',
      width: 190,
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2" fontWeight={600}>
            {dayjs(row.session_date).format('DD MMM YYYY')}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {time(row.time_from)} – {time(row.time_to)}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'ground',
      headerName: 'Ground',
      flex: 1,
      minWidth: 140,
      sortable: false,
      valueGetter: (_v, row) => row.ground?.name || '—',
    },
    {
      field: 'coach',
      headerName: 'Coach',
      flex: 1,
      minWidth: 160,
      sortable: false,
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2">{row.coach?.name || '—'}</Typography>
          <Typography variant="caption" color="text.secondary">{row.coach?.mobile || ''}</Typography>
        </Box>
      ),
    },
    {
      field: 'user',
      headerName: 'Player',
      flex: 1,
      minWidth: 150,
      sortable: false,
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2">{row.user?.name || '—'}</Typography>
          <Typography variant="caption" color="text.secondary">{row.user?.mobile || ''}</Typography>
        </Box>
      ),
    },
    {
      field: 'total_amount',
      headerName: 'Coach fee',
      width: 110,
      renderCell: ({ row }) => rupees(row.total_amount),
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 130,
      renderCell: ({ row }) => <StatusChip status={row.status} />,
    },
  ]

  return (
    <Box>
      <PageHeader
        title="Coach Sessions"
        subtitle="Coaching sessions booked on your courts"
      />

      <Alert severity="info" sx={{ mb: 2 }}>
        These sessions are arranged between a player and a coach you approved. The
        fee shown is the coach&rsquo;s, not a ground booking.
      </Alert>

      {error && <Alert severity="error" sx={{ mb: 2 }}>Could not load coaching sessions.</Alert>}

      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }} mb={2}>
        <Tabs value={tab} onChange={(_, v) => setTab(v)} variant="scrollable" scrollButtons="auto" sx={{ flex: 1 }}>
          {TABS.map((t) => <Tab key={t.label} label={t.label} />)}
        </Tabs>
        <TextField
          label="On a date"
          type="date"
          size="small"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          InputLabelProps={{ shrink: true }}
        />
      </Stack>

      <DataTable rows={data ?? []} columns={columns} loading={isLoading} error={error} />
    </Box>
  )
}
