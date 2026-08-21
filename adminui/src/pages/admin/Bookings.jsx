import React, { useState, useMemo } from 'react'
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Select,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import CancelIcon from '@mui/icons-material/Cancel'
import SearchIcon from '@mui/icons-material/Search'
import FilterListIcon from '@mui/icons-material/FilterList'
import VisibilityOutlinedIcon from '@mui/icons-material/VisibilityOutlined'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { bookingsApi } from '../../api/bookings.js'

const BOOKING_STATUSES = ['pending', 'confirmed', 'completed', 'cancelled']
const CANCELLABLE_STATUSES = ['pending', 'confirmed']

const DEFAULT_CANCEL_REASON = 'Cancelled by admin'

// Status chip color map for the detail modal select
const STATUS_COLORS = {
  pending: 'warning',
  confirmed: 'success',
  completed: 'info',
  cancelled: 'error',
}

// ── Booking Detail Modal ──────────────────────────────────────────────────────

function BookingDetailModal({ booking, onClose, onStatusUpdated }) {
  const notify = useNotify()
  const [newStatus, setNewStatus] = useState(booking?.status ?? '')

  const updateStatusMutation = useMutation({
    mutationFn: ({ id, status }) => bookingsApi.updateStatus(id, status),
    onSuccess: () => {
      notify.success('Booking status updated')
      onStatusUpdated()
      onClose()
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to update status'),
  })

  if (!booking) return null

  const customer = booking.user ?? {}
  const ground = booking.ground ?? {}
  const payment = booking.payment ?? {}
  const date = booking.slot_date || booking.booked_slot?.date || booking.date
  const startTime = booking.slot_time || booking.booked_slot?.start_time || booking.start_time
  const endTime = booking.booked_slot?.end_time || booking.end_time
  const amount = payment.amount ?? booking.total_amount ?? booking.amount

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
          <DetailRow label="Name" value={customer.name} />
          <DetailRow label="Email" value={customer.email} />
          <DetailRow label="Phone" value={customer.phone} />

          <Divider sx={{ my: 1.5 }} />
          <SectionLabel>Ground & Slot</SectionLabel>
          <DetailRow label="Ground" value={ground.name ?? booking.ground_name} />
          <DetailRow label="Slot Date" value={date ? dayjs(date).format('DD MMM YYYY') : '—'} />
          <DetailRow label="Start Time" value={startTime ?? '—'} />
          <DetailRow label="End Time" value={endTime ?? '—'} />

          <Divider sx={{ my: 1.5 }} />
          <SectionLabel>Payment</SectionLabel>
          <DetailRow
            label="Amount"
            value={amount != null ? `₹ ${Number(amount).toLocaleString()}` : '—'}
          />
          <DetailRow label="Booked On" value={booking.created_at ? dayjs(booking.created_at).format('DD MMM YYYY, hh:mm A') : '—'} />

          <Divider sx={{ my: 1.5 }} />
          <SectionLabel>Update Status</SectionLabel>
          <Box mt={1}>
            <FormControl size="small" fullWidth>
              <InputLabel>Status</InputLabel>
              <Select
                value={newStatus}
                label="Status"
                onChange={(e) => setNewStatus(e.target.value)}
              >
                {BOOKING_STATUSES.map((s) => (
                  <MenuItem key={s} value={s} sx={{ textTransform: 'capitalize' }}>
                    {s.charAt(0).toUpperCase() + s.slice(1)}
                  </MenuItem>
                ))}
              </Select>
            </FormControl>
          </Box>
        </Stack>
      </DialogContent>
      <DialogActions sx={{ px: 3, py: 1.5 }}>
        <Button onClick={onClose}>Close</Button>
        <Button
          variant="contained"
          disabled={!newStatus || newStatus === booking.status || updateStatusMutation.isPending}
          onClick={() => updateStatusMutation.mutate({ id: booking.id, status: newStatus })}
          startIcon={updateStatusMutation.isPending ? <CircularProgress size={16} color="inherit" /> : null}
        >
          Update Status
        </Button>
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

// ── Main Bookings Page ────────────────────────────────────────────────────────

export default function Bookings() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [cancelTarget, setCancelTarget] = useState(null) // { id, userLabel }
  const [cancelReason, setCancelReason] = useState(DEFAULT_CANCEL_REASON)
  const [detailBooking, setDetailBooking] = useState(null)

  // Bookings arrive with the ground nested under groundSport; older admin
  // endpoints occasionally flatten it, so accept both.
  const groundNameOf = (row) =>
    row.groundSport?.ground?.name || row.ground?.name || row.ground_name || '—'

  // ── Query ──────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'bookings'],
    queryFn: () => bookingsApi.getAll(),
    select: (res) => res.data?.bookings || res.data?.data || res.data || [],
  })

  const rows = useMemo(() => {
    const list = Array.isArray(data) ? data : []
    return list.filter((r) => {
      const matchStatus = statusFilter === 'all' || r.status === statusFilter
      const q = search.trim().toLowerCase()
      if (!q) return matchStatus
      const userName = `${r.user?.name || ''} ${r.user?.email || ''}`.toLowerCase()
      const groundName = groundNameOf(r).toLowerCase()
      return matchStatus && (userName.includes(q) || groundName.includes(q))
    })
  }, [data, search, statusFilter])

  // ── Mutations ──────────────────────────────────────────────────────────────
  const cancelMutation = useMutation({
    mutationFn: ({ id, reason }) => bookingsApi.cancel(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'bookings'] })
      notify.success('Booking cancelled successfully')
      setCancelTarget(null)
      setCancelReason(DEFAULT_CANCEL_REASON)
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to cancel booking')
    },
  })

  const handleCancelConfirm = () => {
    if (!cancelTarget) return
    cancelMutation.mutate({ id: cancelTarget.id, reason: cancelReason || DEFAULT_CANCEL_REASON })
  }

  const handleCancelOpen = (row) => {
    const userLabel = row.user?.name || row.user?.mobile || `#${row.id}`
    setCancelTarget({ id: row.id, userLabel })
    setCancelReason(DEFAULT_CANCEL_REASON)
  }

  // ── Columns ────────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
      renderCell: ({ value }) => (
        <Typography variant="body2" color="text.secondary">#{value}</Typography>
      ),
    },
    {
      field: 'user',
      headerName: 'Customer',
      flex: 1,
      minWidth: 170,
      valueGetter: ({ row }) => row.user?.name || row.user?.mobile || '—',
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2" fontWeight={600} noWrap>{row.user?.name || '—'}</Typography>
          <Typography variant="caption" color="text.secondary" noWrap>{row.user?.mobile || ''}</Typography>
        </Box>
      ),
    },
    {
      field: 'ground',
      headerName: 'Ground',
      flex: 1,
      minWidth: 150,
      valueGetter: ({ row }) => groundNameOf(row),
      renderCell: ({ row }) => (
        <Typography variant="body2" fontWeight={500} noWrap>
          {groundNameOf(row)}
        </Typography>
      ),
    },
    {
      field: 'slot_date',
      headerName: 'Slot Date / Time',
      width: 170,
      renderCell: ({ row }) => {
        const date = row.slot_date
        const from = (row.slot_time_from || '').slice(0, 5)
        const to = (row.slot_time_to || '').slice(0, 5)
        const time = from && to ? `${from} – ${to}` : from
        return (
          <Box>
            <Typography variant="body2" fontWeight={500}>
              {date ? dayjs(date).format('DD MMM YYYY') : '—'}
            </Typography>
            <Typography variant="caption" color="text.secondary">{time || ''}</Typography>
          </Box>
        )
      },
    },
    {
      field: 'amount',
      headerName: 'Amount (INR)',
      width: 130,
      renderCell: ({ row }) => {
        const amt = row.total_amount ?? row.payment?.amount ?? null
        return (
          <Typography variant="body2" fontWeight={600} color="primary.main">
            {amt != null ? `₹ ${Number(amt).toLocaleString()}` : '—'}
          </Typography>
        )
      },
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 120,
      renderCell: ({ value }) => <StatusChip status={value || 'pending'} />,
    },
    {
      field: 'created_at',
      headerName: 'Booked On',
      width: 140,
      renderCell: ({ value }) => (
        <Typography variant="body2" color="text.secondary">
          {value ? dayjs(value).format('DD MMM YYYY') : '—'}
        </Typography>
      ),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 110,
      sortable: false,
      align: 'center',
      headerAlign: 'center',
      renderCell: ({ row }) => {
        const canCancel = CANCELLABLE_STATUSES.includes(row.status)
        return (
          <Box display="flex" alignItems="center" gap={0.5}>
            <Tooltip title="View details">
              <IconButton size="small" color="primary" onClick={() => setDetailBooking(row)}>
                <VisibilityOutlinedIcon fontSize="small" />
              </IconButton>
            </Tooltip>
            {canCancel ? (
              <Tooltip title="Cancel Booking">
                <IconButton size="small" color="error" onClick={() => handleCancelOpen(row)}>
                  <CancelIcon fontSize="small" />
                </IconButton>
              </Tooltip>
            ) : (
              <Box sx={{ width: 28 }} />
            )}
          </Box>
        )
      },
    },
  ]

  return (
    <Box>
      <PageHeader
        title="Bookings"
        subtitle="All platform bookings"
        breadcrumbs={[
          { label: 'Admin', href: '/admin' },
          { label: 'Bookings' },
        ]}
      />

      {/* Filters row */}
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} mb={2} alignItems="flex-start">
        <TextField
          size="small"
          placeholder="Search by customer or ground…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ width: 320 }}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <SearchIcon fontSize="small" />
              </InputAdornment>
            ),
          }}
        />

        <FormControl size="small" sx={{ minWidth: 180 }}>
          <InputLabel>
            <Box component="span" display="flex" alignItems="center" gap={0.5}>
              <FilterListIcon sx={{ fontSize: 16 }} />
              Status
            </Box>
          </InputLabel>
          <Select
            value={statusFilter}
            label="Status"
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <MenuItem value="all">All Statuses</MenuItem>
            {BOOKING_STATUSES.map((s) => (
              <MenuItem key={s} value={s} sx={{ textTransform: 'capitalize' }}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        <Typography variant="body2" color="text.secondary" alignSelf="center">
          {rows.length} booking{rows.length !== 1 ? 's' : ''}
        </Typography>
      </Stack>

      {/* Data table */}
      <DataTable
        rows={rows}
        columns={columns}
        loading={isLoading}
        error={error}
        getRowHeight={() => 56}
      />

      {/* ── Detail Modal ───────────────────────────────────────────────────── */}
      {detailBooking && (
        <BookingDetailModal
          booking={detailBooking}
          onClose={() => setDetailBooking(null)}
          onStatusUpdated={() => queryClient.invalidateQueries({ queryKey: ['admin', 'bookings'] })}
        />
      )}

      {/* ── Cancel Confirm Dialog ─────────────────────────────────────────── */}
      <ConfirmDialog
        open={!!cancelTarget}
        onClose={() => {
          setCancelTarget(null)
          setCancelReason(DEFAULT_CANCEL_REASON)
        }}
        onConfirm={handleCancelConfirm}
        loading={cancelMutation.isPending}
        title="Cancel Booking"
        message={
          <Stack spacing={1.5}>
            <Typography variant="body2">
              Cancel booking for <strong>{cancelTarget?.userLabel}</strong>?
            </Typography>
            <TextField
              label="Cancellation Reason"
              size="small"
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
              multiline
              rows={2}
              fullWidth
            />
          </Stack>
        }
        confirmLabel="Cancel Booking"
        confirmColor="error"
      />
    </Box>
  )
}
