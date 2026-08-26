import React, { useMemo, useState } from 'react'
import {
  Alert, Avatar, Box, Button, Chip, Stack, Tab, Tabs, TextField, Typography,
} from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import CloseIcon from '@mui/icons-material/Close'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { coachesApi } from '../../api/coaches.js'

const TABS = [
  { label: 'Waiting on you', status: 'pending' },
  { label: 'Approved', status: 'approved' },
  { label: 'Declined', status: 'rejected' },
  { label: 'All', status: '' },
]

const rupees = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`

export default function OwnerCoachRequests() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [tab, setTab] = useState(0)
  const [detail, setDetail] = useState(null)
  const [decision, setDecision] = useState(null) // { row, action: 'approve' | 'reject' }
  const [note, setNote] = useState('')

  const status = TABS[tab].status

  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'coach-requests', status],
    queryFn: () => coachesApi.getOwnerRequests(status ? { status, limit: 100 } : { limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })

  const rows = useMemo(() => data ?? [], [data])
  const pendingCount = useMemo(
    () => rows.filter((r) => r.status === 'pending').length,
    [rows],
  )

  const decide = useMutation({
    mutationFn: ({ row, action }) => (action === 'approve'
      ? coachesApi.approveOwnerRequest(row.id, note.trim() || undefined)
      : coachesApi.rejectOwnerRequest(row.id, note.trim() || undefined)),
    onSuccess: (_res, vars) => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'coach-requests'] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'coaches'] })
      notify.success(vars.action === 'approve'
        ? 'Coach approved. Players can now book them at your ground.'
        : 'Request declined. The coach has been told.')
      setDecision(null)
      setNote('')
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save that decision.'),
  })

  const columns = [
    {
      field: 'coach',
      headerName: 'Coach',
      flex: 1,
      minWidth: 220,
      sortable: false,
      renderCell: ({ row }) => (
        <Stack direction="row" spacing={1.5} alignItems="center">
          <Avatar src={row.coach?.profile_picture || undefined} sx={{ width: 32, height: 32 }}>
            {(row.coach?.name || '?').charAt(0).toUpperCase()}
          </Avatar>
          <Box>
            <Typography variant="body2" fontWeight={600}>{row.coach?.name || '—'}</Typography>
            <Typography variant="caption" color="text.secondary">
              {row.coach?.sport_name || 'Sport not set'}
            </Typography>
          </Box>
        </Stack>
      ),
    },
    {
      field: 'ground',
      headerName: 'Your ground',
      flex: 1,
      minWidth: 150,
      sortable: false,
      valueGetter: (_v, row) => row.ground?.name || '—',
    },
    {
      field: 'experience_years',
      headerName: 'Experience',
      width: 110,
      sortable: false,
      valueGetter: (_v, row) => (row.coach?.experience_years != null
        ? `${row.coach.experience_years} yr`
        : '—'),
    },
    {
      field: 'rate',
      headerName: 'Their rate',
      width: 130,
      sortable: false,
      valueGetter: (_v, row) => (Number(row.coach?.price_per_slot) > 0
        ? `${rupees(row.coach.price_per_slot)} / 30 min`
        : 'Not set'),
    },
    {
      field: 'requested_at',
      headerName: 'Asked',
      width: 130,
      renderCell: ({ row }) => (row.requested_at ? dayjs(row.requested_at).format('DD MMM YYYY') : '—'),
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 120,
      renderCell: ({ row }) => <StatusChip status={row.status} />,
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 250,
      sortable: false,
      renderCell: ({ row }) => (
        <Stack direction="row" spacing={0.5}>
          {row.status !== 'approved' && (
            <Button
              size="small"
              variant="contained"
              startIcon={<CheckCircleOutlineIcon />}
              onClick={() => { setNote(''); setDecision({ row, action: 'approve' }) }}
            >
              Approve
            </Button>
          )}
          {row.status !== 'rejected' && (
            <Button
              size="small"
              color="error"
              startIcon={<CloseIcon />}
              onClick={() => { setNote(''); setDecision({ row, action: 'reject' }) }}
            >
              Decline
            </Button>
          )}
          <Button size="small" onClick={() => setDetail(row)}>Details</Button>
        </Stack>
      ),
    },
  ]

  return (
    <Box>
      <PageHeader
        title="Coach Requests"
        subtitle="Coaches asking to run sessions at your grounds"
        actions={pendingCount > 0 && tab !== 0
          ? <Chip color="warning" label={`${pendingCount} waiting`} />
          : null}
      />

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>Could not load coach requests.</Alert>
      )}

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }} variant="scrollable" scrollButtons="auto">
        {TABS.map((t) => <Tab key={t.label} label={t.label} />)}
      </Tabs>

      <DataTable rows={rows} columns={columns} loading={isLoading} error={error} />

      <DrawerForm
        open={Boolean(detail)}
        onClose={() => setDetail(null)}
        title="Coach details"
        onSubmit={() => setDetail(null)}
        submitLabel="Close"
      >
        {detail && (
          <Stack spacing={2}>
            <Field label="Name" value={detail.coach?.name} />
            <Field label="Sport" value={detail.coach?.sport_name} />
            <Field label="Level" value={detail.coach?.level} />
            <Field label="Experience" value={detail.coach?.experience_years != null ? `${detail.coach.experience_years} years` : null} />
            <Field label="Email" value={detail.coach?.email} />
            <Field label="Mobile" value={detail.coach?.mobile} />
            <Field label="Rate" value={Number(detail.coach?.price_per_slot) > 0 ? `${rupees(detail.coach.price_per_slot)} per 30 min` : 'Not set'} />
            <Field label="About" value={detail.coach?.about} />
            <Field label="Their message" value={detail.request_note} />
            <Field label="Your note" value={detail.response_note} />
            <Box>
              <Typography variant="caption" color="text.secondary">Playsher approval</Typography>
              <Box mt={0.5}>
                <StatusChip status={detail.coach?.is_approved ? 'approved' : 'pending'} />
              </Box>
            </Box>
          </Stack>
        )}
      </DrawerForm>

      <DrawerForm
        open={Boolean(decision)}
        onClose={() => setDecision(null)}
        title={decision?.action === 'approve' ? 'Approve this coach' : 'Decline this request'}
        onSubmit={() => decide.mutate(decision)}
        loading={decide.isPending}
        submitLabel={decision?.action === 'approve' ? 'Approve' : 'Decline'}
      >
        <Stack spacing={2}>
          <Typography variant="body2" color="text.secondary">
            {decision?.action === 'approve'
              ? `${decision?.row?.coach?.name || 'This coach'} will appear as bookable at ${decision?.row?.ground?.name || 'your ground'}, and players will be able to book sessions with them there.`
              : `${decision?.row?.coach?.name || 'This coach'} will not be able to run sessions at ${decision?.row?.ground?.name || 'your ground'}. They can ask again later.`}
          </Typography>
          <TextField
            label="Note to the coach (optional)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            multiline
            minRows={3}
            fullWidth
          />
        </Stack>
      </DrawerForm>
    </Box>
  )
}

function Field({ label, value }) {
  return (
    <Box>
      <Typography variant="caption" color="text.secondary">{label}</Typography>
      <Typography variant="body2" fontWeight={500}>{value || '—'}</Typography>
    </Box>
  )
}
