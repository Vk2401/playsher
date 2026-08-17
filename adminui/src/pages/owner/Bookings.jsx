import React, { useMemo, useState } from 'react'
import {
  Box,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Button,
  Chip,
  Divider,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import CancelOutlinedIcon from '@mui/icons-material/CancelOutlined'
import VisibilityOutlinedIcon from '@mui/icons-material/VisibilityOutlined'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { bookingsApi } from '../../api/bookings.js'

const CANCELLABLE_STATUSES = new Set(['pending', 'confirmed'])

const STATUS_OPTIONS = [
  { value: 'all', label: 'All Statuses' },
  { value: 'pending', label: 'Pending' },
  { value: 'confirmed', label: 'Confirmed' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
]

const STATUS_COLORS = {
  pending: 'warning',
  confirmed: 'success',
  completed: 'info',
  cancelled: 'error',
}

// ── Booking Detail Modal ──────────────────────────────────────────────────────

function BookingDetailModal({ booking, onClose }) {
  if (!booking) return null

  const customer = booking.user ?? {}
  const ground = booking.ground ?? {}
  const payment = booking.payment ?? {}
  const date = booking.booking_date ?? booking.slot?.date ?? booking.date
  const start = booking.slot?.start_time ?? booking.start_time ?? ''
  const end = booking.slot?.end_time ?? booking.end_time ?? ''
  const amount = payment.amount ?? booking.amount

  return (
    <Dialog open onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>
        Booking #{booking.id}
        <Chip
          label={booking.status}
          color={STATUS_COLORS[booking.status] ?? 'default'}
          size="small"
          sx={{ ml: 1.5, fontWeight: 600, textTransform: 'capitalize' }}
        />
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={0}>
          <SectionLabel>Customer</SectionLabel>
          <DetailRow label="Name" value={customer.name ?? booking.user_name} />
          <DetailRow label="Email" value={customer.email ?? booking.user_email} />
          <DetailRow label="Phone" value={customer.phone} />

          <Divider sx={{ my: 1.5 }} />
          <SectionLabel>Ground & Slot</SectionLabel>
          <DetailRow label="Ground" value={ground.name ?? booking.ground_name} />
          <DetailRow label="Slot Date" value={date ? dayjs(date).format('DD MMM YYYY') : '—'} />
          <DetailRow label="Start Time" value={start || '—'} />
          <DetailRow label="End Time" value={end || '—'} />

          <Divider sx={{ my: 1.5 }} />
          <SectionLabel>Payment</SectionLabel>
          <DetailRow
            label="Amount"
            value={amount != null ? `₨ ${Number(amount).toLocaleString()}` : '—'}
          />
          <DetailRow
            label="Booked On"
            value={booking.created_at ? dayjs(booking.created_at).format('DD MMM YYYY, hh:mm A') : '—'}
          />
        </Stack>
      </DialogContent>
      <DialogActions sx={{ px: 3, py: 1.5 }}>
        <Button onClick={onClose} variant="outlined">Close</Button>
      </DialogActions>
    </Dialog>
  )
}

function SectionLabel({ children }) {
  return (
    <Typography variant="caption" color="text.secondary" fontWeight={700}
      sx={{ textTransform: 'uppercase', letterSpacing: 0.5, mb: 0.5, mt: 0.5 }}>
      {children}
    </Typography>
  )
}

function DetailRow({ label, value }) {
  return (
    <Box display="flex" alignItems="flex-start" gap={2} py={0.75}>
      <Typography variant="body2" color="text.secondary" sx={{ minWidth: 110, flexShrink: 0 }}>
        {label}
      </Typography>
      <Typography variant="body2" sx={{ wordBreak: 'break-word' }}>
        {value ?? '—'}
      </Typography>
    </Box>
  )
}

// ── Main Page ─────────────────────────────────────────────────────────────────

export default function OwnerBookings() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [statusFilter, setStatusFilter] = useState('all')
  const [cancelTarget, setCancelTarget] = useState(null) // { id }
  const [detailBooking, setDetailBooking] = useState(null)

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'bookings'],
    queryFn: () => bookingsApi.getOwnerBookings(),
    select: (res) => res.data,
  })

  const bookings = useMemo(() => {
    const raw = data?.bookings ?? data?.data ?? data ?? []
    if (statusFilter === 'all') return raw
    return raw.filter((b) => b.status === statusFilter)
  }, [data, statusFilter])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const cancelMutation = useMutation({
    mutationFn: (id) => bookingsApi.ownerCancel(id, 'Cancelled by owner'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'bookings'] })
      notify.success('Booking cancelled successfully')
      setCancelTarget(null)
    },
    onError: () => notify.error('Failed to cancel booking'),
  })

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
    },
    {
      field: 'user_name',
      headerName: 'Customer',
      flex: 1,
      minWidth: 160,
      renderCell: ({ row }) => {
        const name = row.user?.name ?? row.user_name ?? '—'
        const email = row.user?.email ?? row.user_email ?? ''
        return (
          <Box>
            <Typography variant="body2" fontWeight={500} lineHeight={1.3}>{name}</Typography>
            {email && (
              <Typography variant="caption" color="text.secondary">{email}</Typography>
            )}
          </Box>
        )
      },
    },
    {
      field: 'ground_name',
      headerName: 'Ground',
      flex: 1,
      minWidth: 140,
      renderCell: ({ row }) => row.ground?.name ?? row.ground_name ?? '—',
    },
    {
      field: 'slot_datetime',
      headerName: 'Slot Date & Time',
      width: 180,
      renderCell: ({ row }) => {
        const date = row.booking_date ?? row.slot?.date ?? row.date
        const start = row.slot?.start_time ?? row.start_time ?? ''
        const end = row.slot?.end_time ?? row.end_time ?? ''
        if (!date) return '—'
        const formatted = dayjs(date).format('DD MMM YYYY')
        return (
          <Box>
            <Typography variant="body2">{formatted}</Typography>
            {(start || end) && (
              <Typography variant="caption" color="text.secondary">
                {start}{start && end ? ' – ' : ''}{end}
              </Typography>
            )}
          </Box>
        )
      },
    },
    {
      field: 'amount',
      headerName: 'Amount (PKR)',
      width: 130,
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
      headerName: 'Booked On',
      width: 130,
      renderCell: ({ value }) =>
        value ? dayjs(value).format('DD MMM YYYY') : '—',
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 100,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => {
        const canCancel = CANCELLABLE_STATUSES.has(String(row.status).toLowerCase())
        return (
          <Box display="flex" alignItems="center" gap={0.5}>
            <Tooltip title="View details">
              <span>
                <IconButton size="small" color="primary" onClick={() => setDetailBooking(row)}>
                  <VisibilityOutlinedIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
            {canCancel ? (
              <Tooltip title="Cancel booking">
                <span>
                  <IconButton size="small" color="error"
                    onClick={() => setCancelTarget({ id: row.id })}>
                    <CancelOutlinedIcon fontSize="small" />
                  </IconButton>
                </span>
              </Tooltip>
            ) : (
              <Box sx={{ width: 28 }} />
            )}
          </Box>
        )
      },
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title="Bookings"
        subtitle="Bookings on your grounds"
      />

      {/* Status filter */}
      <Box mb={2}>
        <FormControl size="small" sx={{ minWidth: 180 }}>
          <InputLabel>Status</InputLabel>
          <Select
            value={statusFilter}
            label="Status"
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            {STATUS_OPTIONS.map((opt) => (
              <MenuItem key={opt.value} value={opt.value}>
                {opt.label}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      <DataTable
        rows={bookings}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* Detail Modal */}
      {detailBooking && (
        <BookingDetailModal
          booking={detailBooking}
          onClose={() => setDetailBooking(null)}
        />
      )}

      {/* Cancel confirmation */}
      <ConfirmDialog
        open={Boolean(cancelTarget)}
        onClose={() => setCancelTarget(null)}
        onConfirm={() => cancelMutation.mutate(cancelTarget.id)}
        loading={cancelMutation.isPending}
        title="Cancel Booking"
        message="Are you sure you want to cancel this booking? The customer will be notified."
        confirmLabel="Cancel Booking"
        confirmColor="error"
      />
    </Box>
  )
}
