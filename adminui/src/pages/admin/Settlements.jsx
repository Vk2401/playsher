import React, { useState, useMemo } from 'react'
import {
  Box,
  Typography,
  Stack,
  TextField,
  InputAdornment,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Paper,
  Grid,
  Divider,
  IconButton,
  Tooltip,
  Button,
  List,
  ListItem,
  ListItemText,
  Chip,
  CircularProgress,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import SearchIcon from '@mui/icons-material/Search'
import FilterListIcon from '@mui/icons-material/FilterList'
import VisibilityIcon from '@mui/icons-material/Visibility'
import AttachMoneyIcon from '@mui/icons-material/AttachMoney'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import HourglassEmptyIcon from '@mui/icons-material/HourglassEmpty'
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline'
import AccountBalanceIcon from '@mui/icons-material/AccountBalance'
import CheckIcon from '@mui/icons-material/Check'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { settlementsApi } from '../../api/settlements.js'

const PAYOUT_STATUSES = ['Transferred', 'Pending Manual', 'No Bank Details', 'No Vendor']

const SUMMARY_CONFIG = [
  {
    key: 'transferred',
    label: 'Total Transferred',
    color: '#6B9E7A',
    bgColor: 'rgba(107,158,122,0.08)',
    icon: CheckCircleOutlineIcon,
  },
  {
    key: 'pending_manual',
    label: 'Pending Manual',
    color: '#F4A261',
    bgColor: 'rgba(244,162,97,0.08)',
    icon: HourglassEmptyIcon,
  },
  {
    key: 'no_bank_details',
    label: 'No Bank Details',
    color: '#E76F51',
    bgColor: 'rgba(231,111,81,0.08)',
    icon: ErrorOutlineIcon,
  },
  {
    key: 'platform_revenue',
    label: 'Platform Revenue',
    color: '#5B7FA6',
    bgColor: 'rgba(91,127,166,0.08)',
    icon: AccountBalanceIcon,
  },
]

export default function Settlements() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [selectedVendor, setSelectedVendor] = useState(null)

  // -- Fetch all vendors
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'settlements-vendors'],
    queryFn: () => settlementsApi.getVendors({ per_page: 999 }),
    select: (res) => res.data?.vendors || res.data?.data || res.data || [],
  })

  const vendors = useMemo(() => (Array.isArray(data) ? data : []), [data])

  // -- Fetch vendor bookings when drawer is open
  const {
    data: vendorBookings,
    isLoading: bookingsLoading,
  } = useQuery({
    queryKey: ['admin', 'vendor-bookings', selectedVendor?.id],
    queryFn: () => settlementsApi.getVendorBookings(selectedVendor.id, { per_page: 999 }),
    select: (res) => res.data?.bookings || res.data?.data || res.data || [],
    enabled: !!selectedVendor,
  })

  const bookings = useMemo(
    () => (Array.isArray(vendorBookings) ? vendorBookings : []),
    [vendorBookings]
  )

  // -- Compute summary from vendor bookings data across all vendors
  // We use the vendor list and approximate from available data
  const summary = useMemo(() => {
    const result = {
      transferred: 0,
      pending_manual: 0,
      no_bank_details: 0,
      platform_revenue: 0,
      grand_total: 0,
    }
    // We'll compute these when we have all vendor data
    // For now, use vendor stats if available
    vendors.forEach((v) => {
      const revenue = parseFloat(v.total_revenue || v.stats?.total_revenue || 0)
      result.grand_total += revenue
    })
    return result
  }, [vendors])

  // -- Filter vendors
  const rows = useMemo(() => {
    return vendors.filter((v) => {
      const q = search.trim().toLowerCase()
      if (!q) return true
      const name = (v.name || '').toLowerCase()
      const email = (v.email || '').toLowerCase()
      const phone = (v.phone || v.contact_number || '').toLowerCase()
      return name.includes(q) || email.includes(q) || phone.includes(q)
    })
  }, [vendors, search])

  // -- Mark transferred mutation
  const markTransferredMutation = useMutation({
    mutationFn: ({ paymentId }) =>
      settlementsApi.updatePayoutStatus(paymentId, {
        vendor_payout_status: 'Transferred',
        status: 'success',
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'vendor-bookings', selectedVendor?.id] })
      notify.success('Payment marked as transferred')
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to update payout status')
    },
  })

  // -- Columns
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
      field: 'name',
      headerName: 'Vendor Name',
      flex: 1,
      minWidth: 170,
      renderCell: ({ row }) => (
        <Box>
          <Typography variant="body2" fontWeight={600} noWrap>
            {row.name || '---'}
          </Typography>
          <Typography variant="caption" color="text.secondary" noWrap>
            {row.email || ''}
          </Typography>
        </Box>
      ),
    },
    {
      field: 'phone',
      headerName: 'Phone',
      width: 140,
      renderCell: ({ row }) => (
        <Typography variant="body2" color="text.secondary">
          {row.phone || row.contact_number || '---'}
        </Typography>
      ),
    },
    {
      field: 'total_grounds',
      headerName: 'Grounds',
      width: 90,
      align: 'center',
      headerAlign: 'center',
      renderCell: ({ row }) => (
        <Typography variant="body2">
          {row.ground_count ?? row.total_grounds ?? 0}
        </Typography>
      ),
    },
    {
      field: 'total_revenue',
      headerName: 'Total Earned (Rs)',
      width: 160,
      renderCell: ({ row }) => {
        const revenue = row.total_revenue || row.stats?.total_revenue || 0
        return (
          <Typography variant="body2" fontWeight={700} color="primary.main">
            Rs {Number(revenue).toLocaleString()}
          </Typography>
        )
      },
    },
    {
      field: 'status',
      headerName: 'Status',
      width: 120,
      renderCell: ({ value }) => <StatusChip status={value || 'active'} />,
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 80,
      sortable: false,
      align: 'center',
      headerAlign: 'center',
      renderCell: ({ row }) => (
        <Tooltip title="View Settlements">
          <IconButton
            size="small"
            color="primary"
            onClick={() => setSelectedVendor(row)}
          >
            <VisibilityIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      ),
    },
  ]

  return (
    <Box>
      <PageHeader
        title="Settlements"
        subtitle="Vendor payout tracking"
        breadcrumbs={[
          { label: 'Admin', href: '/admin' },
          { label: 'Settlements' },
        ]}
      />

      {/* -- Summary Cards */}
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
                    Rs {(summary[key] || 0).toLocaleString()}
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
            Total Vendor Earnings
          </Typography>
        </Stack>
        <Typography variant="h6" fontWeight={700} color="primary.main">
          Rs {summary.grand_total.toLocaleString()}
        </Typography>
      </Paper>

      <Divider sx={{ mb: 2 }} />

      {/* Filters row */}
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} mb={2} alignItems="flex-start">
        <TextField
          size="small"
          placeholder="Search by vendor name, email or phone..."
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

        <FormControl size="small" sx={{ minWidth: 200 }}>
          <InputLabel>
            <Box component="span" display="flex" alignItems="center" gap={0.5}>
              <FilterListIcon sx={{ fontSize: 16 }} />
              Payout Status
            </Box>
          </InputLabel>
          <Select
            value={statusFilter}
            label="Payout Status"
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <MenuItem value="all">All Statuses</MenuItem>
            {PAYOUT_STATUSES.map((s) => (
              <MenuItem key={s} value={s}>
                {s}
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        <Typography variant="body2" color="text.secondary" alignSelf="center">
          {rows.length} vendor{rows.length !== 1 ? 's' : ''}
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

      {/* -- Vendor Detail Drawer */}
      <DrawerForm
        open={!!selectedVendor}
        onClose={() => setSelectedVendor(null)}
        title={`Settlements — ${selectedVendor?.name || 'Vendor'}`}
        submitLabel={null}
        width={520}
      >
        {selectedVendor && (
          <Stack spacing={3}>
            {/* Vendor info header */}
            <Box
              sx={{
                p: 2,
                borderRadius: 1.5,
                bgcolor: 'action.hover',
                border: '1px solid',
                borderColor: 'divider',
              }}
            >
              <Typography variant="body1" fontWeight={600}>
                {selectedVendor.name}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {selectedVendor.email}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {selectedVendor.phone || selectedVendor.contact_number || '---'}
              </Typography>
              <Stack direction="row" spacing={1} mt={1}>
                <StatusChip status={selectedVendor.status || 'active'} />
              </Stack>
            </Box>

            {/* Bookings / Payments list */}
            <Box>
              <Typography variant="subtitle2" fontWeight={700} mb={1}>
                Payment Settlements
              </Typography>

              {bookingsLoading ? (
                <Box display="flex" justifyContent="center" py={4}>
                  <CircularProgress size={28} />
                </Box>
              ) : bookings.length === 0 ? (
                <Typography variant="body2" color="text.secondary" py={2}>
                  No bookings found for this vendor.
                </Typography>
              ) : (
                <List disablePadding>
                  {bookings.map((booking) => {
                    const payment = booking.payment || booking
                    const vendorAmount = payment.vendor_amount || 0
                    const platformFee = payment.platform_fee || 0
                    const payoutStatus = payment.vendor_payout_status || 'N/A'
                    const transferId = payment.vendor_transfer_id

                    return (
                      <ListItem
                        key={booking.id}
                        sx={{
                          border: '1px solid',
                          borderColor: 'divider',
                          borderRadius: 1.5,
                          mb: 1,
                          flexDirection: 'column',
                          alignItems: 'flex-start',
                          px: 2,
                          py: 1.5,
                        }}
                      >
                        <Stack
                          direction="row"
                          justifyContent="space-between"
                          width="100%"
                          alignItems="center"
                        >
                          <Typography variant="body2" fontWeight={600}>
                            Booking #{booking.id}
                          </Typography>
                          <StatusChip status={payoutStatus} />
                        </Stack>

                        <Stack direction="row" spacing={2} mt={1} flexWrap="wrap">
                          <Typography variant="caption" color="text.secondary">
                            Amount:{' '}
                            <strong>Rs {Number(payment.amount || 0).toLocaleString()}</strong>
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            Vendor:{' '}
                            <strong>Rs {Number(vendorAmount).toLocaleString()}</strong>
                          </Typography>
                          <Typography variant="caption" color="text.secondary">
                            Fee:{' '}
                            <strong>Rs {Number(platformFee).toLocaleString()}</strong>
                          </Typography>
                        </Stack>

                        {transferId && (
                          <Typography variant="caption" color="text.secondary" mt={0.5}>
                            Transfer ID: {transferId}
                          </Typography>
                        )}

                        {booking.created_at && (
                          <Typography variant="caption" color="text.secondary" mt={0.5}>
                            {dayjs(booking.created_at).format('DD MMM YYYY')}
                          </Typography>
                        )}

                        {payoutStatus === 'Pending Manual' && (
                          <Button
                            size="small"
                            variant="outlined"
                            color="success"
                            startIcon={
                              markTransferredMutation.isPending ? (
                                <CircularProgress size={14} color="inherit" />
                              ) : (
                                <CheckIcon />
                              )
                            }
                            onClick={() =>
                              markTransferredMutation.mutate({
                                paymentId: payment.id,
                              })
                            }
                            disabled={markTransferredMutation.isPending}
                            sx={{ mt: 1 }}
                          >
                            Mark Transferred
                          </Button>
                        )}
                      </ListItem>
                    )
                  })}
                </List>
              )}
            </Box>
          </Stack>
        )}
      </DrawerForm>
    </Box>
  )
}
