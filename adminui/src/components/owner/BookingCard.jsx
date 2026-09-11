import { Box, ButtonBase, Stack, Typography } from '@mui/material'
import ChevronRightIcon from '@mui/icons-material/ChevronRight'

import { Pill } from './OwnerBits.jsx'
import { BOOKING_STATUS, bookingInfo, bookingMoney, clock, dayLabel, durationLabel } from './ownerFormat.js'

/**
 * One booking as a row: when, who, what, and the one money fact that matters
 * at the gate — how much cash to collect. Tapping it opens the full details.
 *
 * A row inside a shared Card rather than a bordered card of its own. Six
 * separate cards down a phone screen is six borders, six shadows and six gaps
 * arguing with each other; a day's bookings are one list, so they read as one
 * object with hairlines between. `last` drops the final divider.
 *
 * The time column carries no fill. Tinting each one made a list of six read as
 * six unrelated blocks, and the tint had to change colour for cancelled rows,
 * which put two competing status signals on the same row. Alignment alone does
 * the grouping, and the status pill is left to say the status.
 */
export default function BookingCard({ booking: b, onOpen, dim, showDate, last }) {
  const info = bookingInfo(b)
  const money = bookingMoney(b)
  const cancelled = b.status === 'cancelled'

  let moneyLine
  if (cancelled) {
    moneyLine = <Typography variant="body2" color="text.secondary" noWrap>{b.cancellation_reason || 'Cancelled'}</Typography>
  } else if (money.balance > 0 && b.status === 'completed') {
    moneyLine = <Typography variant="body2" color="text.secondary">₹{money.balance.toLocaleString('en-IN')} paid at ground</Typography>
  } else if (money.balance > 0) {
    moneyLine = <Typography variant="body2" fontWeight={700} color="warning.dark">Collect ₹{money.balance.toLocaleString('en-IN')} at ground</Typography>
  } else if (b.status === 'pending') {
    moneyLine = <Typography variant="body2" fontWeight={600} color="warning.dark">Customer is paying now</Typography>
  } else {
    moneyLine = <Typography variant="body2" fontWeight={600} color="primary.dark">Fully paid online</Typography>
  }

  return (
    <ButtonBase
      onClick={() => onOpen(b)}
      sx={{
        width: '100%', display: 'flex', alignItems: 'center', textAlign: 'left',
        px: 1.75, py: 1.5, gap: 1.5,
        borderBottom: last ? 0 : '1px solid', borderColor: 'divider',
        opacity: dim || cancelled ? 0.55 : 1,
        '&:hover': { bgcolor: 'action.hover' },
      }}
    >
      {/* 70px, not 62: "10:00 AM" clipped to "10:00 …" at the narrower width
          while "6:00 PM" fit, so only mid-morning bookings looked broken. */}
      <Stack sx={{ width: 70, flexShrink: 0 }}>
        <Typography
          fontWeight={700}
          fontSize={13.5}
          color={cancelled ? 'text.disabled' : 'text.primary'}
          sx={{ fontVariantNumeric: 'tabular-nums', textDecoration: cancelled ? 'line-through' : 'none' }}
          noWrap
        >
          {clock(b.slot_time_from)}
        </Typography>
        <Typography variant="caption" color="text.secondary" noWrap>
          {durationLabel(b.slot_time_from, b.slot_time_to)}
        </Typography>
      </Stack>

      <Box sx={{ flex: 1, minWidth: 0 }}>
        <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={1}>
          <Typography fontWeight={600} noWrap>{info.customer}</Typography>
          {b.status !== 'confirmed' && (
            <Pill tone={BOOKING_STATUS[b.status]?.tone} label={BOOKING_STATUS[b.status]?.label ?? b.status} />
          )}
        </Stack>
        <Typography variant="body2" color="text.secondary" noWrap>
          {[info.sport, showDate ? dayLabel(b.slot_date) : null, b.is_game ? 'Open game' : null].filter(Boolean).join(' · ')}
        </Typography>
        <Box mt={0.25}>{moneyLine}</Box>
      </Box>

      <ChevronRightIcon sx={{ color: 'text.disabled', flexShrink: 0 }} />
    </ButtonBase>
  )
}
