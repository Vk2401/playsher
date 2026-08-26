import React, { useEffect, useMemo, useState } from 'react'
import {
  Alert, Box, Button, Chip, CircularProgress, Divider, Grid, Paper,
  Stack, Switch, TextField, Typography,
} from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import SaveIcon from '@mui/icons-material/Save'
import BlockIcon from '@mui/icons-material/Block'
import LockOpenIcon from '@mui/icons-material/LockOpen'

import PageHeader from '../../components/ui/PageHeader.jsx'
import EmptyState from '../../components/ui/EmptyState.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { coachesApi } from '../../api/coaches.js'

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

const DEFAULT_DAY = { start_time: '07:00', end_time: '21:00', is_closed: true }

const hhmm = (t) => String(t ?? '').slice(0, 5)

export default function CoachAvailability() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [week, setWeek] = useState(() => DAYS.map(() => ({ ...DEFAULT_DAY })))
  const [formErrors, setFormErrors] = useState({})
  const [date, setDate] = useState(dayjs().format('YYYY-MM-DD'))

  const availability = useQuery({
    queryKey: ['coach', 'availability'],
    queryFn: () => coachesApi.getAvailability(),
    select: (res) => res.data?.data ?? [],
  })

  // Seed the editor from the server once, keeping every weekday present even
  // when the coach has only saved a few — a missing row is a closed day, and
  // the form has to show it as one rather than leave a gap.
  useEffect(() => {
    if (!availability.data) return
    const next = DAYS.map(() => ({ ...DEFAULT_DAY }))
    availability.data.forEach((row) => {
      next[row.day_of_week] = {
        start_time: hhmm(row.start_time) || DEFAULT_DAY.start_time,
        end_time: hhmm(row.end_time) || DEFAULT_DAY.end_time,
        is_closed: Boolean(row.is_closed),
      }
    })
    setWeek(next)
  }, [availability.data])

  const slots = useQuery({
    queryKey: ['coach', 'slots', date],
    queryFn: () => coachesApi.getSlots(date),
    select: (res) => res.data?.data ?? [],
  })

  const saveMutation = useMutation({
    mutationFn: (days) => coachesApi.setAvailability(days),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['coach', 'availability'] })
      queryClient.invalidateQueries({ queryKey: ['coach', 'slots'] })
      queryClient.invalidateQueries({ queryKey: ['coach', 'dashboard'] })
      notify.success('Availability saved.')
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save your availability.'),
  })

  const blockMutation = useMutation({
    mutationFn: ({ id, blocked }) => (blocked ? coachesApi.unblockSlot(id) : coachesApi.blockSlot(id)),
    onSuccess: (_res, vars) => {
      queryClient.invalidateQueries({ queryKey: ['coach', 'slots'] })
      notify.success(vars.blocked ? 'Slot reopened.' : 'Slot blocked.')
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not change that slot.'),
  })

  const setDay = (index, patch) =>
    setWeek((prev) => prev.map((d, i) => (i === index ? { ...d, ...patch } : d)))

  const validate = () => {
    const errors = {}
    week.forEach((day, i) => {
      if (day.is_closed) return
      if (!day.start_time || !day.end_time) {
        errors[i] = 'Both times are required.'
      } else if (toMinutes(day.end_time) - toMinutes(day.start_time) < 30) {
        errors[i] = 'An open day needs at least 30 minutes.'
      }
    })
    setFormErrors(errors)
    return Object.keys(errors).length === 0
  }

  const handleSave = () => {
    if (!validate()) {
      notify.warning('Fix the highlighted days before saving.')
      return
    }
    saveMutation.mutate(week.map((day, i) => ({
      day_of_week: i,
      start_time: day.is_closed ? undefined : day.start_time,
      end_time: day.is_closed ? undefined : day.end_time,
      is_closed: day.is_closed,
    })))
  }

  const openDays = useMemo(() => week.filter((d) => !d.is_closed).length, [week])

  return (
    <Box>
      <PageHeader
        title="Availability"
        subtitle="The hours you work. Players can only book inside them."
        actions={
          <Button
            variant="contained"
            startIcon={<SaveIcon />}
            onClick={handleSave}
            disabled={saveMutation.isPending}
          >
            {saveMutation.isPending ? 'Saving…' : 'Save week'}
          </Button>
        }
      />

      {openDays === 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>
          Every day is closed, so nobody can book you. Open at least one day.
        </Alert>
      )}

      <Grid container spacing={3}>
        <Grid item xs={12} md={7}>
          <Paper sx={{ p: { xs: 2, sm: 3 } }}>
            <Typography variant="subtitle1" fontWeight={700} mb={2}>Weekly hours</Typography>
            <Stack divider={<Divider flexItem />} spacing={1.5}>
              {week.map((day, i) => (
                <Stack
                  key={DAYS[i]}
                  direction={{ xs: 'column', sm: 'row' }}
                  spacing={1.5}
                  alignItems={{ xs: 'stretch', sm: 'center' }}
                  pt={i === 0 ? 0 : 1.5}
                >
                  <Box width={{ xs: '100%', sm: 130 }} display="flex" alignItems="center" gap={1}>
                    <Switch
                      checked={!day.is_closed}
                      onChange={(e) => setDay(i, { is_closed: !e.target.checked })}
                      inputProps={{ 'aria-label': `${DAYS[i]} open` }}
                    />
                    <Typography variant="body2" fontWeight={600}>{DAYS[i]}</Typography>
                  </Box>
                  <TextField
                    label="Opens"
                    type="time"
                    size="small"
                    value={day.start_time}
                    disabled={day.is_closed}
                    onChange={(e) => setDay(i, { start_time: e.target.value })}
                    error={Boolean(formErrors[i])}
                    InputLabelProps={{ shrink: true }}
                    inputProps={{ step: 1800 }}
                    sx={{ width: { xs: '100%', sm: 140 } }}
                  />
                  <TextField
                    label="Closes"
                    type="time"
                    size="small"
                    value={day.end_time}
                    disabled={day.is_closed}
                    onChange={(e) => setDay(i, { end_time: e.target.value })}
                    error={Boolean(formErrors[i])}
                    helperText={formErrors[i]}
                    InputLabelProps={{ shrink: true }}
                    inputProps={{ step: 1800 }}
                    sx={{ width: { xs: '100%', sm: 140 } }}
                  />
                </Stack>
              ))}
            </Stack>
            <Typography variant="caption" color="text.secondary" display="block" mt={2}>
              Saving rebuilds your free slots from these hours. Slots that are already
              booked are left exactly as they are.
            </Typography>
          </Paper>
        </Grid>

        <Grid item xs={12} md={5}>
          <Paper sx={{ p: { xs: 2, sm: 3 } }}>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ sm: 'center' }} mb={2}>
              <Typography variant="subtitle1" fontWeight={700} flex={1}>Slots for a day</Typography>
              <TextField
                type="date"
                size="small"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                InputLabelProps={{ shrink: true }}
              />
            </Stack>

            {slots.isLoading && (
              <Box display="flex" justifyContent="center" py={4}><CircularProgress size={24} /></Box>
            )}
            {slots.error && (
              <Alert severity="error">Could not load that day&rsquo;s slots.</Alert>
            )}
            {!slots.isLoading && !slots.error && (slots.data ?? []).length === 0 && (
              <EmptyState message="No slots on this day — it is closed, or already past." />
            )}

            <Box display="flex" flexWrap="wrap" gap={1}>
              {(slots.data ?? []).map((slot) => {
                const label = `${hhmm(slot.slot_start_time)}–${hhmm(slot.slot_end_time)}`
                if (slot.is_booked) {
                  return <Chip key={slot.id} label={`${label} · booked`} color="info" size="small" />
                }
                return (
                  <Chip
                    key={slot.id}
                    label={slot.is_blocked ? `${label} · blocked` : label}
                    size="small"
                    color={slot.is_blocked ? 'default' : 'success'}
                    variant={slot.is_blocked ? 'outlined' : 'filled'}
                    icon={slot.is_blocked ? <LockOpenIcon /> : <BlockIcon />}
                    onClick={() => blockMutation.mutate({ id: slot.id, blocked: slot.is_blocked })}
                    disabled={blockMutation.isPending}
                  />
                )
              })}
            </Box>

            <Typography variant="caption" color="text.secondary" display="block" mt={2}>
              Tap a free slot to block it out for the day; tap a blocked one to reopen it.
              Booked slots can only change by declining the session.
            </Typography>
          </Paper>
        </Grid>
      </Grid>
    </Box>
  )
}

function toMinutes(value) {
  const [h, m] = String(value).split(':').map(Number)
  return (h || 0) * 60 + (m || 0)
}
