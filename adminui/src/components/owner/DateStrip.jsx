import { useEffect, useRef } from 'react'
import { Box, ButtonBase, Stack, Typography } from '@mui/material'
import dayjs from 'dayjs'
import { ymd } from './ownerFormat.js'

/**
 * A row of day tiles — the owner's calendar. Tap a day instead of typing a
 * date. `counts` (keyed by YYYY-MM-DD) puts a dot under days that have bookings.
 */
export default function DateStrip({ value, onChange, from = -1, to = 6, counts = {} }) {
  const activeRef = useRef(null)
  // Keep the chosen day in view — a strip that starts a week back would
  // otherwise open with today scrolled off the right edge of a phone.
  useEffect(() => {
    activeRef.current?.scrollIntoView({ block: 'nearest', inline: 'center' })
  }, [value])
  const days = []
  for (let i = from; i <= to; i += 1) days.push(dayjs().add(i, 'day'))

  return (
    <Stack
      direction="row"
      spacing={1}
      sx={{ overflowX: 'auto', pb: 0.5, mx: -0.5, px: 0.5, '&::-webkit-scrollbar': { display: 'none' } }}
    >
      {days.map((d) => {
        const key = ymd(d)
        const active = key === value
        const isToday = key === ymd(dayjs())
        return (
          <ButtonBase
            key={key}
            ref={active ? activeRef : undefined}
            onClick={() => onChange(key)}
            aria-pressed={active}
            sx={{
              flexShrink: 0,
              width: 56,
              py: 1,
              borderRadius: 1,
              flexDirection: 'column',
              border: 1,
              borderColor: active ? 'primary.dark' : 'divider',
              bgcolor: active ? 'primary.dark' : 'background.paper',
              color: active ? 'primary.contrastText' : 'text.primary',
            }}
          >
            <Typography variant="caption" fontWeight={600} sx={{ color: active ? 'inherit' : 'text.secondary', opacity: active ? 0.85 : 1 }}>
              {isToday ? 'Today' : d.format('ddd')}
            </Typography>
            <Typography fontWeight={700} fontSize={18} lineHeight={1.3} color="inherit">
              {d.date()}
            </Typography>
            <Box
              sx={{
                width: 5, height: 5, borderRadius: '50%', mt: 0.25,
                bgcolor: counts[key] ? (active ? 'primary.contrastText' : 'primary.main') : 'transparent',
              }}
            />
          </ButtonBase>
        )
      })}
    </Stack>
  )
}
