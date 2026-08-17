import React, { useState, useMemo } from 'react'
import {
  Box,
  Button,
  TextField,
  IconButton,
  Tooltip,
  Typography,
  Stack,
  InputAdornment,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Paper,
  Grid,
  Divider,
  Chip,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import EditIcon from '@mui/icons-material/Edit'
import SearchIcon from '@mui/icons-material/Search'
import FilterListIcon from '@mui/icons-material/FilterList'
import AttachMoneyIcon from '@mui/icons-material/AttachMoney'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import HourglassEmptyIcon from '@mui/icons-material/HourglassEmpty'
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline'
import ReplayIcon from '@mui/icons-material/Replay'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { paymentsApi } from '../../api/payments.js'

const PAYMENT_STATUSES = ['pending', 'success', 'failed', 'refunded']

const SUMMARY_CONFIG = [
  {
    key: 'success',
    label: 'Successful',
    color: '#6B9E7A',
    bgColor: 'rgba(107,158,122,0.08)',
    icon: CheckCircleOutlineIcon,
  },
  {
    key: 'pending',
    label: 'Pending',
    color: '#F4A261',
    bgColor: 'rgba(244,162,97,0.08)',
    icon: HourglassEmptyIcon,
  },
  {
    key: 'failed',
    label: 'Failed',
    color: '#E76F51',
    bgColor: 'rgba(231,111,81,0.08)',
    icon: ErrorOutlineIcon,
  },
  {
    key: 'refunded',
    label: 'Refunded',
    color: '#5B7FA6',
    bgColor: 'rgba(91,127,166,0.08)',
    icon: ReplayIcon,
  },
]

export default function Payments() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')

  // Edit-status drawer
  const [editTarget, setEditTarget] = useState(null) // { id, currentStatus, label }
  const [newStatus, setNewStatus] = useState('')

  // ── Query ──────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'payments'],
    queryFn: () => paymentsApi.getAll(),
    select: (res) => res.data?.payments || res.data?.data || res.data || [],
  })

  const allPayments = useMemo(() => (Array.isArray(data) ? data : []), [data])

  const rows = useMemo(() => {
    return allPayments.filter((r) => {
      const matchStatus = statusFilter === 'all' || r.status === statusFilter
      const q = search.trim().toLowerCase()
      if (!q) return matchStatus
      const userName = `${r.user?.name || ''} ${r.user?.email || ''}`.toLowerCase()
      const bookingId = String(r.booking_id || r.booking?.id || '').toLowerCase()
      return matchStatus && (userName.includes(q) || bookingId.includes(q))
    })
  }, [allPayments, search, statusFilter])

  // ── Summary totals ─────────────────────────────────────────────────────────
  const summary = useMemo(() => {
    const result = {}
    PAYMENT_STATUSES.forEach((s) => { result[s] = 0 })
    allPayments.forEach((p) => {
      const s = p.status
      if (s in result) result[s] += parseFloat(p.amount || 0)
    })
    return result
  }, [allPayments])

  const grandTotal = useMemo(
    () => Object.values(summary).reduce((a, b) => a + b, 0),
    [summary]
  )

  // ── Mutations ──────────────────────────────────────────────────────────────
  const updateStatusMutation = useMutation({
    mutationFn: ({ id, status }) => paymentsApi.updateStatus(id, status),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'payments'] })
      notify.success('Payment status updated')
      setEditTarget(null)
      setNewStatus('')
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to update payment status')
    },
  })

  const handleOpenEdit = (row) => {
    const label = `Payment #${row.id}`
    setEditTarget({ id: row.id, currentStatus: row.status, label })
    setNewStatus(row.status || 'pending')
  }

  const handleSubmitStatus = () => {
    if (!editTarget || !newStatus) return
    updateStatusMutation.mutate({ id: editTarget.id, status: newStatus })
  }

  // ── Columns ────────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
      renderCell: ({ value }) => (
        <Typography variant="body2" color="text.secondary">
          #{value}
        </Typography>
      ),
    },
    {
      field: 'booking_id',
      headerName: 'Booking',
      width: 100,
      renderCell: ({ row }) => {
        const bid = row.booking_id || row.booking?.id
        return (
          <Typography variant="body2" color="text.secondary">
            {bid ? `#${bid}` : '—'}
          </Typography>
        )
      },
    },
    {
      field: 'user',
      headerName: 'Customer',
      flex: 1,
      minWidth: 170,
      valueGetter: ({ row }) => row.user?.name || row.user?.email || '—',
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2" fontWeight={600} noWrap>
            {row.user?.name || '—'}
          </Typography>
          <Typography variant="caption" color="text.secondary" noWrap>
            {row.user?.email || ''}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'amount',
      headerName: 'Amount (PKR)',
      width: 140,
      renderCell: ({ value }) => (
        <Typography variant="body2" fontWeight={700} color="primary.main">
          {value != null ? `₨ ${Number(value).toLocaleString()}` : '—'}
        </Typography>
      ),
    },
    {
      field: 'payment_method',
      headerName: 'Method',
      width: 120,
      renderCell: ({ value }) => (
        <Chip
          label={value || 'N/A'}
          size="small"
          variant="outlined"
          sx={{ textTransform: 'capitalize', fontSize: '0.72rem' }}
        />
      ),
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 120,
      renderCell: ({ value }) => <StatusChip status={value || 'pending'} />,
    },
    {
      field: 'created_at',
      headerName: 'Date',
      width: 130,
      renderCell: ({ value }) => (
        <Typography variant="body2" color="text.secondary">
          {value ? dayjs(value).format('DD MMM YYYY') : '—'}
        </Typography>
      ),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 80,
      sortable: false,
      align: 'center',
      headerAlign: 'center',
      renderCell: ({ row }) => (
        <Tooltip title="Update Status">
          <IconButton
            size="small"
            color="primary"
            onClick={() => handleOpenEdit(row)}
          >
            <EditIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      ),
    },
  ]

  return (
    <Box>
      <PageHeader
        title="Payments"
        subtitle="All platform payments"
        breadcrumbs={[
          { label: 'Admin', href: '/admin' },
          { label: 'Payments' },
        ]}
      />

      {/* ── Summary Cards ──────────────────────────────────────────────────── */}
      <Grid container spacing={2} mb={3}>
        {SUMMARY_CONFIG.map(({ key, label, color, bgColor, icon: Icon }) => (
          <Grid item xs={6} sm={3} key={key}>
            <Paper
              sx={{
                p: 2,
                bgcolor: bgColor,
                border: '1px solid',
                borderColor: `${color}30`,
                borderRadius: 2,
              }}
            >
              <Stack direction="row" alignItems="center" spacing={1.5}>
                <Box
                  sx={{
                    width: 38,
                    height: 38,
                    borderRadius: 1.5,
                    bgcolor: `${color}18`,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <Icon sx={{ fontSize: 20, color }} />
                </Box>
                <Box>
                  <Typography variant="caption" color="text.secondary" display="block">
                    {label}
                  </Typography>
                  <Typography variant="subtitle2" fontWeight={700} color={color}>
                    ₨ {summary[key].toLocaleString()}
                  </Typography>
                </Box>
              </Stack>
            </Paper>
          </Grid>
        ))}
      </Grid>

      {/* Grand total bar */}
      <Paper
        sx={{
          px: 3,
          py: 1.5,
          mb: 2.5,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          borderLeft: '4px solid',
          borderColor: 'primary.main',
          borderRadius: 1,
        }}
      >
        <Stack direction="row" alignItems="center" spacing={1}>
          <AttachMoneyIcon color="primary" fontSize="small" />
          <Typography variant="body2" fontWeight={600} color="text.secondary">
            Total Payments Processed
          </Typography>
        </Stack>
        <Typography variant="h6" fontWeight={700} color="primary.main">
          ₨ {grandTotal.toLocaleString()}
        </Typography>
      </Paper>

      <Divider sx={{ mb: 2 }} />

      {/* Filters row */}
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} mb={2} alignItems="flex-start">
        <TextField
          size="small"
          placeholder="Search by customer or booking ID…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          sx={{ width: 340 }}
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
            {PAYMENT_STATUSES.map((s) => (
              <MenuItem key={s} value={s} sx={{ textTransform: 'capitalize' }}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        <Typography variant="body2" color="text.secondary" alignSelf="center">
          {rows.length} payment{rows.length !== 1 ? 's' : ''}
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

      {/* ── Edit Status Drawer ─────────────────────────────────────────────── */}
      <DrawerForm
        open={!!editTarget}
        onClose={() => {
          setEditTarget(null)
          setNewStatus('')
        }}
        title="Update Payment Status"
        onSubmit={handleSubmitStatus}
        loading={updateStatusMutation.isPending}
        submitLabel="Save Status"
        width={380}
      >
        <Stack spacing={3}>
          {editTarget && (
            <Box
              sx={{
                p: 2,
                borderRadius: 1.5,
                bgcolor: 'action.hover',
                border: '1px solid',
                borderColor: 'divider',
              }}
            >
              <Typography variant="caption" color="text.secondary" display="block">
                Payment
              </Typography>
              <Typography variant="body1" fontWeight={600}>
                {editTarget.label}
              </Typography>
              <Stack direction="row" spacing={1} alignItems="center" mt={0.5}>
                <Typography variant="caption" color="text.secondary">
                  Current:
                </Typography>
                <StatusChip status={editTarget.currentStatus} />
              </Stack>
            </Box>
          )}

          <FormControl fullWidth required>
            <InputLabel>New Status</InputLabel>
            <Select
              value={newStatus}
              label="New Status"
              onChange={(e) => setNewStatus(e.target.value)}
            >
              {PAYMENT_STATUSES.map((s) => (
                <MenuItem key={s} value={s}>
                  <Stack direction="row" alignItems="center" spacing={1}>
                    <StatusChip status={s} />
                  </Stack>
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          {newStatus && newStatus !== editTarget?.currentStatus && (
            <Box
              sx={{
                p: 1.5,
                borderRadius: 1,
                bgcolor: 'warning.light',
                border: '1px solid',
                borderColor: 'warning.main',
              }}
            >
              <Typography variant="caption" color="warning.dark">
                You are changing the status from{' '}
                <strong>{editTarget?.currentStatus}</strong> to{' '}
                <strong>{newStatus}</strong>. This change will be saved immediately.
              </Typography>
            </Box>
          )}
        </Stack>
      </DrawerForm>
    </Box>
  )
}
