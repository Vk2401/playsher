import { useState } from 'react'
import {
  Box, Button, Chip, FormControl, InputLabel, MenuItem, Paper,
  Select, Stack, TextField, Tooltip, Typography, CircularProgress,
} from '@mui/material'
import { alpha } from '@mui/material/styles'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import BlockIcon from '@mui/icons-material/Block'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import EventBusyIcon from '@mui/icons-material/EventBusy'

import { slotsApi } from '@/api/slots.js'
import { useNotify } from '@/hooks/useNotify.js'
import EmptyState from '@/components/ui/EmptyState.jsx'

/**
 * Day view of a ground's bookable slots, with per-slot open/close.
 *
 * The slot API has existed all along but no page used it, so owners had no way
 * to see their slots or close one for maintenance — the only controls were
 * add-a-single-slot and delete. Slots themselves are generated from the weekly
 * schedule when a date is first requested, which is why this lists a day rather
 * than offering slot-by-slot creation.
 */
export default function SlotManager({ groundId }) {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [date, setDate] = useState(dayjs().format('YYYY-MM-DD'))
  const [sportFilter, setSportFilter] = useState('all')

  const queryKey = ['owner', 'slots', groundId, date]

  const { data, isLoading, error } = useQuery({
    queryKey,
    queryFn: () => slotsApi.getGroundSlots(groundId, { date }),
    select: (res) => res.data?.data ?? res.data ?? {},
    enabled: Boolean(groundId && date),
  })

  const slots = data?.slots ?? []
  const groundSports = data?.ground_sports ?? []

  const toggleMutation = useMutation({
    mutationFn: (slotId) => slotsApi.toggleStatus(groundId, slotId),
    // Optimistic: a whole-day refetch per tap makes closing several slots feel
    // broken. Roll back and refetch if the server disagrees.
    onMutate: async (slotId) => {
      await queryClient.cancelQueries({ queryKey })
      const previous = queryClient.getQueryData(queryKey)
      queryClient.setQueryData(queryKey, (old) => {
        const payload = old?.data?.data ?? old?.data ?? {}
        const next = {
          ...payload,
          slots: (payload.slots ?? []).map((s) =>
            s.id === slotId ? { ...s, is_available: !s.is_available } : s,
          ),
        }
        return old?.data?.data
          ? { ...old, data: { ...old.data, data: next } }
          : { ...old, data: next }
      })
      return { previous }
    },
    onError: (err, _slotId, context) => {
      if (context?.previous) queryClient.setQueryData(queryKey, context.previous)
      notify.error(err?.response?.data?.message || 'Could not change that slot')
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey }),
  })

  const visible =
    sportFilter === 'all'
      ? slots
      : slots.filter((s) => String(s.ground_sport_id) === String(sportFilter))

  const openCount = visible.filter((s) => s.is_available).length
  const isPast = dayjs(date).isBefore(dayjs().format('YYYY-MM-DD'))

  return (
    <Stack spacing={2}>
      <Paper sx={{ p: 2 }}>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }}>
          <TextField
            label="Date"
            type="date"
            size="small"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            InputLabelProps={{ shrink: true }}
            sx={{ minWidth: 180 }}
          />
          <FormControl size="small" sx={{ minWidth: 180 }}>
            <InputLabel>Sport</InputLabel>
            <Select
              label="Sport"
              value={sportFilter}
              onChange={(e) => setSportFilter(e.target.value)}
            >
              <MenuItem value="all">All sports</MenuItem>
              {groundSports.map((gs) => (
                <MenuItem key={gs.id} value={String(gs.id)}>
                  {gs.sport?.name ?? `Sport #${gs.sport_id}`}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <Box flexGrow={1} />
          <Stack direction="row" spacing={1}>
            <Button size="small" onClick={() => setDate(dayjs().format('YYYY-MM-DD'))}>
              Today
            </Button>
            <Button
              size="small"
              onClick={() => setDate(dayjs(date).add(1, 'day').format('YYYY-MM-DD'))}
            >
              Next day
            </Button>
          </Stack>
        </Stack>

        <Typography variant="caption" color="text.secondary" sx={{ mt: 1.5, display: 'block' }}>
          {isLoading
            ? 'Loading…'
            : `${openCount} of ${visible.length} slots open on ${dayjs(date).format('ddd D MMM YYYY')}. `}
          {!isLoading && !isPast && 'Tap a slot to open or close it for booking.'}
        </Typography>
      </Paper>

      {isLoading ? (
        <Paper sx={{ p: 4, display: 'flex', justifyContent: 'center' }}>
          <CircularProgress size={28} />
        </Paper>
      ) : error ? (
        <Paper sx={{ p: 4 }}>
          <EmptyState
            icon={EventBusyIcon}
            message={error?.response?.data?.message || 'Could not load slots for this date'}
          />
        </Paper>
      ) : visible.length === 0 ? (
        <Paper sx={{ p: 4 }}>
          <EmptyState
            icon={EventBusyIcon}
            message={
              isPast
                ? 'No slots were generated for this past date.'
                : 'No slots for this date — the sport has no open day in its weekly schedule. Set the schedule under Sports & Pricing.'
            }
          />
        </Paper>
      ) : (
        <Paper sx={{ p: 2 }}>
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: {
                xs: 'repeat(2, 1fr)',
                sm: 'repeat(3, 1fr)',
                md: 'repeat(5, 1fr)',
              },
              gap: 1,
            }}
          >
            {visible.map((slot) => {
              const open = slot.is_available
              return (
                <Tooltip
                  key={slot.id}
                  title={
                    isPast
                      ? 'Past date — not editable'
                      : open
                        ? 'Open for booking — tap to close'
                        : 'Closed — tap to open'
                  }
                >
                  <span>
                    <Chip
                      label={`${String(slot.slot_start_time).slice(0, 5)} – ${String(slot.slot_end_time).slice(0, 5)}`}
                      // State is carried by the icon and the tooltip as well as
                      // the fill, so it survives greyscale.
                      icon={open ? <CheckCircleOutlineIcon /> : <BlockIcon />}
                      onClick={isPast ? undefined : () => toggleMutation.mutate(slot.id)}
                      disabled={isPast}
                      sx={(theme) => ({
                        width: '100%',
                        height: 40,
                        justifyContent: 'flex-start',
                        fontWeight: 600,
                        cursor: isPast ? 'default' : 'pointer',
                        bgcolor: open
                          ? alpha(theme.palette.success.main, 0.12)
                          : alpha(theme.palette.text.disabled, 0.12),
                        color: open ? theme.palette.success.dark : theme.palette.text.disabled,
                        border: `1px solid ${
                          open
                            ? alpha(theme.palette.success.main, 0.4)
                            : alpha(theme.palette.text.disabled, 0.3)
                        }`,
                        textDecoration: open ? 'none' : 'line-through',
                      })}
                    />
                  </span>
                </Tooltip>
              )
            })}
          </Box>
        </Paper>
      )}
    </Stack>
  )
}
