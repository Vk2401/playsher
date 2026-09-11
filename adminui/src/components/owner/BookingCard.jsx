import { Box, ButtonBase, Stack, Typography } from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import ChevronRightIcon from '@mui/icons-material/ChevronRight'

import { Pill } from './OwnerBits.jsx'
import { BOOKING_STATUS, bookingInfo, bookingMoney, clock, dayLabel, durationLabel } from './ownerFormat.js'

/**
 * One booking as a card: when, who, what, and the one money fact that matters
 * at the gate — how much cash to collect. Tapping it opens the full details.
 */
export default function BookingCard({ booking: b, onOpen, dim, showDate }) {
  const theme = useTheme()
  const info = bookingInfo(b)
  const money = bookingMoney(b)
  const cancelled = b.status === 'cancelled'

  let moneyLine
  if (cancelled) {
    moneyLine = <Typography variant="body2" color="text.secondary">{b.cancellation_reason || 'Cancelled'}</Typography>
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
        width: '100%', display: 'flex', alignItems: 'stretch', textAlign: 'left', mb: 1.25,
        bgcolor: 'background.paper', border: 1, borderColor: 'divider', borderRadius: 1, overflow: 'hidden',
        opacity: dim ? 0.6 : 1,
      }}
    >
      <Stack
        alignItems="center"
        justifyContent="center"
        sx={{
          width: 84, flexShrink: 0, py: 1.5,
          bgcolor: cancelled ? alpha(theme.palette.text.primary, 0.04) : alpha(theme.palette.primary.main, 0.12),
        }}
      >
        <Typography fontWeight={700} fontSize={14} color={cancelled ? 'text.disabled' : 'primary.dark'} noWrap>
          {clock(b.slot_time_from)}
        </Typography>
        <Typography variant="caption" color="text.secondary">
          {durationLabel(b.slot_time_from, b.slot_time_to)}
        </Typography>
      </Stack>
      <Box sx={{ flex: 1, minWidth: 0, px: 1.75, py: 1.25 }}>
        <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={1}>
          <Typography fontWeight={600} noWrap>{info.customer}</Typography>
          {b.status !== 'confirmed' && <Pill tone={BOOKING_STATUS[b.status]?.tone} label={BOOKING_STATUS[b.status]?.label ?? b.status} />}
        </Stack>
        <Typography variant="body2" color="text.secondary" noWrap>
          {[info.sport, showDate ? dayLabel(b.slot_date) : null, b.is_game ? 'Open game' : null].filter(Boolean).join(' · ')}
        </Typography>
        <Box mt={0.5}>{moneyLine}</Box>
      </Box>
      <Stack justifyContent="center" pr={1}>
        <ChevronRightIcon sx={{ color: 'text.disabled' }} />
      </Stack>
    </ButtonBase>
  )
}
