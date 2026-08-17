import React from 'react'
import { Chip } from '@mui/material'

const STATUS_CONFIG = {
  // Booking / Payment
  pending:   { label: 'Pending',   color: 'warning' },
  confirmed: { label: 'Confirmed', color: 'info' },
  completed: { label: 'Completed', color: 'success' },
  cancelled: { label: 'Cancelled', color: 'error' },
  failed:    { label: 'Failed',    color: 'error' },
  success:   { label: 'Success',   color: 'success' },
  refunded:  { label: 'Refunded',  color: 'secondary' },

  // Entity
  active:    { label: 'Active',    color: 'success' },
  inactive:  { label: 'Inactive',  color: 'default' },
  approved:  { label: 'Approved',  color: 'success' },
  rejected:  { label: 'Rejected',  color: 'error' },
  suspended: { label: 'Suspended', color: 'warning' },
  open:      { label: 'Open',      color: 'success' },
  closed:    { label: 'Closed',    color: 'default' },
  full:      { label: 'Full',      color: 'warning' },

  // Settlement / Payout
  transferred:       { label: 'Transferred',     color: 'success' },
  'pending manual':  { label: 'Pending Manual',  color: 'warning' },
  'no vendor':       { label: 'No Vendor',       color: 'default' },
  'no bank details': { label: 'No Bank Details', color: 'error' },
}

export default function StatusChip({ status, size = 'small', sx }) {
  const key = String(status).toLowerCase()
  const cfg = STATUS_CONFIG[key] || { label: status, color: 'default' }

  return (
    <Chip
      label={cfg.label}
      color={cfg.color}
      size={size}
      sx={{ fontWeight: 600, fontSize: '0.72rem', ...sx }}
    />
  )
}
