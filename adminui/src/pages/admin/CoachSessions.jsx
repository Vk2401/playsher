import React, { useState } from 'react'
import { Alert, Box, Stack, Tab, Tabs, TextField, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { coachesApi } from '../../api/coaches.js'

const TABS = [
  { label: 'All', status: '' },
  { label: 'Awaiting coach', status: 'pending' },
  { label: 'Confirmed', status: 'confirmed' },
  { label: 'Completed', status: 'completed' },
  { label: 'Cancelled', status: 'cancelled' },
]

const time = (t) => String(t ?? '').slice(0, 5)
const rupees = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`

export default function AdminCoachSessions() {
  const [tab, setTab] = useState(0)
  const [date, setDate] = useState('')

  const status = TABS[tab].status
  const params = { limit: 100, ...(status ? { status } : {}), ...(date ? { date } : {}) }

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'coach-bookings', params],
    queryFn: () => coachesApi.getAllSessions(params),
    select: (res) => res.data?.data ?? [],
  })

  const columns = [
    {
      field: 'booking_reference',
      headerName: 'Reference',
      width: 190,
      renderCell: ({ row }) => row.booking_reference || `#${row.id}`,
    },
    {
      field: 'session_date',
      headerName: 'When',
      width: 180,
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
      field: 'coach',
      headerName: 'Coach',
      flex: 1,
      minWidth: 150,
      sortable: false,
      valueGetter: (_v, row) => row.coach?.name || '—',
    },
    {
      field: 'user',
      headerName: 'Player',
      flex: 1,
      minWidth: 150,
      sortable: false,
      valueGetter: (_v, row) => row.user?.name || '—',
    },
    {
      field: 'ground',
      headerName: 'Venue',
      flex: 1,
      minWidth: 140,
      sortable: false,
      valueGetter: (_v, row) => row.ground?.name || 'No venue',
    },
    {
      field: 'total_amount',
      headerName: 'Amount',
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
        subtitle="Every coaching session booked on the platform"
        breadcrumbs={[{ label: 'Admin', href: '/admin/dashboard' }, { label: 'Coach Sessions' }]}
      />

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
