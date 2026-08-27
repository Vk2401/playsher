import React from 'react'
import { Box, LinearProgress, Tooltip, Typography, alpha } from '@mui/material'
import { useTheme } from '@mui/material/styles'

/**
 * How full a game is: "7 / 10" over a bar.
 *
 * A number alone does not say whether a game is about to close, and a bar
 * alone does not say by how much, so the cell carries both. The bar turns
 * warning-coloured only once the game is down to its last seats, and the
 * tooltip spells that out in words — the state is never signalled by the
 * colour by itself.
 *
 * Reads the counts the API derives (`joined_count`, `max_participants`,
 * `spots_left`); the panel never recomputes them from the participant array,
 * which a list row may have trimmed.
 */
export default function SeatMeter({ joined = 0, capacity = 0, spotsLeft, size = 'medium' }) {
  const theme = useTheme()

  const seats = Number(capacity) || 0
  const taken = Math.min(Number(joined) || 0, seats || Number(joined) || 0)
  const left = spotsLeft ?? Math.max(0, seats - taken)
  const ratio = seats > 0 ? Math.min(1, taken / seats) : 0

  const full = seats > 0 && left === 0
  const tight = !full && left > 0 && left <= 2

  const tone = full
    ? theme.palette.text.disabled
    : tight
      ? theme.palette.warning.main
      : theme.palette.primary.main

  const label = seats === 0
    ? 'No seat limit set'
    : full
      ? 'Full — no seats left'
      : `${left} ${left === 1 ? 'seat' : 'seats'} left`

  return (
    <Tooltip title={label}>
      <Box width="100%" minWidth={72}>
        <Typography
          variant="body2"
          fontWeight={600}
          color={tight ? 'warning.main' : 'text.primary'}
          lineHeight={1.3}
        >
          {taken} / {seats || '—'}
        </Typography>
        <LinearProgress
          variant="determinate"
          value={ratio * 100}
          sx={{
            mt: 0.5,
            height: size === 'small' ? 4 : 6,
            borderRadius: 3,
            backgroundColor: alpha(theme.palette.text.primary, 0.08),
            '& .MuiLinearProgress-bar': {
              borderRadius: 3,
              backgroundColor: tone,
            },
          }}
        />
      </Box>
    </Tooltip>
  )
}
