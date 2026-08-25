import React, { useMemo, useState } from 'react'
import {
  Box, Button, Chip, Stack, Tab, Tabs, TextField, Typography,
} from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import CloseIcon from '@mui/icons-material/Close'
import TaskAltIcon from '@mui/icons-material/TaskAlt'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { coachesApi } from '../../api/coaches.js'

const FILTERS = [
  { label: 'Awaiting reply', status: 'pending' },
  { label: 'Confirmed', status: 'confirmed' },
  { label: 'Completed', status: 'completed' },
  { label: 'Declined / cancelled', status: 'cancelled' },
  { label: 'All', status: '' },
]

const time = (t) => String(t ?? '').slice(0, 5)
const rupees = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`

export default function CoachBookings() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [tab, setTab] = useState(0)
  const [detail, setDetail] = useState(null)      // the row shown in the drawer
  const [confirmTarget, setConfirmTarget] = useState(null)
  const [declineTarget, setDeclineTarget] = useState(null)
  const [declineReason, setDeclineReason] = useState('')
  const [completeTarget, setCompleteTarget] = useState(null)

  const status = FILTERS[tab].status

  const { data, isLoading, error } = useQuery({
    queryKey: ['coach', 'bookings', status],
    queryFn: () => coachesApi.getMySessions(status ? { status, limit: 100 } : { limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })

  // The "declined / cancelled" tab covers two statuses; the API filters on one,
  // so that tab asks for everything and narrows here.
  const rows = useMemo(() => {
    const list = data ?? []
    if (FILTERS[tab].label !== 'Declined / cancelled') return list
    return list.filter((r) => r.status === 'cancelled' || r.status === 'rejected')
  }, [data, tab])

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['coach', 'bookings'] })
    queryClient.invalidateQueries({ queryKey: ['coach', 'dashboard'] })
    queryClient.invalidateQueries({ queryKey: ['notifications'] })
  }

  const confirmMutation = useMutation({
    mutationFn: (id) => coachesApi.confirmSession(id),
    onSuccess: () => {
      invalidate()
      notify.success('Session confirmed. The player has been told.')
      setConfirmTarget(null)
      setDetail(null)
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not confirm this session.'),
  })

  const declineMutation = useMutation({
    mutationFn: (id) => coachesApi.rejectSession(id, declineReason.trim() || undefined),
    onSuccess: () => {
      invalidate()
      notify.success('Session declined and its time released.')
      setDeclineTarget(null)
      setDeclineReason('')
      setDetail(null)
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not decline this session.'),
  })

  const completeMutation = useMutation({
    mutationFn: (id) => coachesApi.completeSession(id),
    onSuccess: () => {
      invalidate()
      notify.success('Session marked complete.')
      setCompleteTarget(null)
      setDetail(null)
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not complete this session.'),
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
      field: 'player',
      headerName: 'Player',
      flex: 1,
      minWidth: 160,
      sortable: false,
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2">{row.user?.name || '—'}</Typography>
          <Typography variant="caption" color="text.secondary">{row.user?.mobile || ''}</Typography>
        </Box>
      ),
    },
    {
      field: 'ground',
      headerName: 'Venue',
      flex: 1,
      minWidth: 150,
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
    {
      field: 'actions',
      headerName: 'Actions',
      width: 240,
      sortable: false,
      renderCell: ({ row }) => (
        <Stack direction="row" spacing={0.5}>
          {row.status === 'pending' && (
            <>
              <Button
                size="small"
                variant="contained"
                startIcon={<CheckCircleOutlineIcon />}
                onClick={() => setConfirmTarget(row)}
              >
                Accept
              </Button>
              <Button
                size="small"
                color="error"
                startIcon={<CloseIcon />}
                onClick={() => { setDeclineReason(''); setDeclineTarget(row) }}
              >
                Decline
              </Button>
            </>
          )}
          {row.status === 'confirmed' && (
            <>
              <Button
                size="small"
                variant="outlined"
                startIcon={<TaskAltIcon />}
                onClick={() => setCompleteTarget(row)}
              >
                Complete
              </Button>
              <Button size="small" color="error" onClick={() => { setDeclineReason(''); setDeclineTarget(row) }}>
                Cancel
              </Button>
            </>
          )}
          <Button size="small" onClick={() => setDetail(row)}>Details</Button>
        </Stack>
      ),
    },
  ]

  const pendingCount = (data ?? []).filter((r) => r.status === 'pending').length

  return (
    <Box>
      <PageHeader
        title="My Sessions"
        subtitle="Players who booked you — accept, decline or mark a session done"
        actions={pendingCount > 0 && tab !== 0
          ? <Chip color="warning" label={`${pendingCount} awaiting reply`} />
          : null}
      />

      <Tabs
        value={tab}
        onChange={(_, v) => setTab(v)}
        variant="scrollable"
        scrollButtons="auto"
        sx={{ mb: 2 }}
      >
        {FILTERS.map((f) => <Tab key={f.label} label={f.label} />)}
      </Tabs>

      <DataTable rows={rows} columns={columns} loading={isLoading} error={error} />

      {/* Detail drawer — read-only, so it uses the drawer's submit as a Close. */}
      <DrawerForm
        open={Boolean(detail)}
        onClose={() => setDetail(null)}
        title="Session details"
        onSubmit={() => setDetail(null)}
        submitLabel="Close"
      >
        {detail && (
          <Stack spacing={2}>
            <Field label="Reference" value={detail.booking_reference} />
            <Field label="Date" value={dayjs(detail.session_date).format('dddd, DD MMM YYYY')} />
            <Field label="Time" value={`${time(detail.time_from)} – ${time(detail.time_to)}`} />
            <Field label="Player" value={detail.user?.name} />
            <Field label="Player mobile" value={detail.user?.mobile} />
            <Field label="Venue" value={detail.ground?.name || 'No venue chosen'} />
            <Field label="Amount" value={rupees(detail.total_amount)} />
            <Field label="Paid" value={detail.payment_method === 'pay_at_venue' ? 'At the venue' : detail.payment_method} />
            <Box>
              <Typography variant="caption" color="text.secondary">Status</Typography>
              <Box mt={0.5}><StatusChip status={detail.status} /></Box>
            </Box>
            {detail.customer_note && <Field label="Note from the player" value={detail.customer_note} />}
            {detail.coach_note && <Field label="Your note" value={detail.coach_note} />}
            {detail.cancellation_reason && <Field label="Reason" value={detail.cancellation_reason} />}
          </Stack>
        )}
      </DrawerForm>

      <ConfirmDialog
        open={Boolean(confirmTarget)}
        onClose={() => setConfirmTarget(null)}
        onConfirm={() => confirmMutation.mutate(confirmTarget.id)}
        title="Accept this session?"
        message={confirmTarget
          ? `Confirm ${confirmTarget.user?.name || 'this player'} for ${dayjs(confirmTarget.session_date).format('DD MMM')} at ${time(confirmTarget.time_from)}. They will be notified.`
          : ''}
        confirmLabel="Accept"
        confirmColor="primary"
        loading={confirmMutation.isPending}
      />

      {/* Declining is destructive for the player's plan, so it asks for a reason
          in the same step rather than sending a bare refusal. */}
      <DrawerForm
        open={Boolean(declineTarget)}
        onClose={() => setDeclineTarget(null)}
        title={declineTarget?.status === 'confirmed' ? 'Cancel this session' : 'Decline this session'}
        onSubmit={() => declineMutation.mutate(declineTarget.id)}
        loading={declineMutation.isPending}
        submitLabel={declineTarget?.status === 'confirmed' ? 'Cancel session' : 'Decline'}
      >
        <Stack spacing={2}>
          <Typography variant="body2" color="text.secondary">
            The time is given back to your calendar and the player is told. Adding a
            reason is optional but it is what they will read.
          </Typography>
          <TextField
            label="Reason (optional)"
            value={declineReason}
            onChange={(e) => setDeclineReason(e.target.value)}
            multiline
            minRows={3}
            fullWidth
            inputProps={{ maxLength: 500 }}
          />
        </Stack>
      </DrawerForm>

      <ConfirmDialog
        open={Boolean(completeTarget)}
        onClose={() => setCompleteTarget(null)}
        onConfirm={() => completeMutation.mutate(completeTarget.id)}
        title="Mark this session complete?"
        message="Use this once the session has actually taken place."
        confirmLabel="Mark complete"
        confirmColor="primary"
        loading={completeMutation.isPending}
      />
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
