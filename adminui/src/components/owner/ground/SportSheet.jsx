import { useState } from 'react'
import { Box, Button, FormControlLabel, MenuItem, Stack, Switch, TextField, Typography } from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import ActionSheet from '../ActionSheet.jsx'
import { lengthLabel, unwrapList } from '../ownerFormat.js'
import { groundsApi } from '../../../api/grounds.js'
import { sportsApi } from '../../../api/sports.js'
import { useNotify } from '../../../hooks/useNotify.js'

// min_slots / max_slots are counted in 30-minute slots; owners think in hours.
const LENGTHS = Array.from({ length: 16 }, (_, i) => i + 1)

/** Add a sport to the ground, or change an existing one's booking rules. */
export default function SportSheet({ open, onClose, groundId, groundSport, existingSportIds = [] }) {
  const editing = Boolean(groundSport)
  return (
    <ActionSheet open={open} onClose={onClose} title={editing ? `${groundSport.sport?.name ?? 'Sport'} settings` : 'Add a sport'}>
      {open && (
        <SportForm key={groundSport?.id ?? 'new'} groundId={groundId} groundSport={groundSport} existingSportIds={existingSportIds} onClose={onClose} />
      )}
    </ActionSheet>
  )
}

function SportForm({ groundId, groundSport, existingSportIds, onClose }) {
  const editing = Boolean(groundSport)
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [form, setForm] = useState({
    sport_id: '',
    min_slots: groundSport?.min_slots ?? 2,
    max_slots: groundSport?.max_slots ?? 6,
    player_counts: groundSport?.player_counts ?? '',
    cancellation_policy: groundSport?.cancellation_policy ?? '',
    is_active: groundSport?.is_active ?? true,
  })
  const [errors, setErrors] = useState({})
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }))

  const sportsQ = useQuery({
    queryKey: ['sports', 'public'],
    queryFn: () => sportsApi.listPublic({ limit: 100 }),
    select: unwrapList,
    enabled: !editing,
  })
  const choices = (sportsQ.data ?? []).filter((s) => !existingSportIds.includes(s.id))

  const done = (msg) => {
    queryClient.invalidateQueries({ queryKey: ['owner', 'ground', groundId] })
    queryClient.invalidateQueries({ queryKey: ['owner', 'slots', groundId] })
    queryClient.invalidateQueries({ queryKey: ['owner', 'schedule', groundId] })
    notify.success(msg)
    onClose()
  }

  const mutation = useMutation({
    mutationFn: () => {
      const min = Number(form.min_slots)
      const max = Number(form.max_slots)
      return editing
        ? groundsApi.updateSport(groundId, groundSport.id, {
          min_slots: min,
          max_slots: max,
          player_counts: String(form.player_counts).trim(),
          cancellation_policy: String(form.cancellation_policy).trim(),
          is_active: form.is_active,
        })
        : groundsApi.addSport(groundId, { sport_id: Number(form.sport_id), min_slots: min, max_slots: max })
    },
    onSuccess: () => done(editing ? 'Sport settings saved' : 'Sport added. Set its opening hours next.'),
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save the sport'),
  })

  const submit = () => {
    const e = {}
    if (!editing && !form.sport_id) e.sport_id = 'Pick a sport'
    if (Number(form.min_slots) > Number(form.max_slots)) e.max_slots = 'Longest must be at least the shortest'
    setErrors(e)
    if (Object.keys(e).length === 0) mutation.mutate()
  }

  return (
    <Box>
      <Stack spacing={1.75} mt={1}>
        {!editing && (
          <TextField
            select
            label="Sport"
            value={form.sport_id}
            onChange={set('sport_id')}
            error={!!errors.sport_id}
            helperText={errors.sport_id || (sportsQ.isSuccess && choices.length === 0 ? 'Every sport is already added' : '')}
            fullWidth
          >
            {choices.map((s) => <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>)}
          </TextField>
        )}
        <Typography variant="subtitle2" fontWeight={700} color="text.secondary">How long can one booking be?</Typography>
        <Stack direction="row" spacing={1.5}>
          <TextField select label="Shortest" value={form.min_slots} onChange={set('min_slots')} fullWidth>
            {LENGTHS.map((n) => <MenuItem key={n} value={n}>{lengthLabel(n)}</MenuItem>)}
          </TextField>
          <TextField select label="Longest" value={form.max_slots} onChange={set('max_slots')} error={!!errors.max_slots} helperText={errors.max_slots} fullWidth>
            {LENGTHS.map((n) => <MenuItem key={n} value={n}>{lengthLabel(n)}</MenuItem>)}
          </TextField>
        </Stack>
        {editing && (
          <>
            <TextField label="Players (optional)" value={form.player_counts} onChange={set('player_counts')} placeholder="e.g. 5 vs 5, 7 vs 7" fullWidth />
            <TextField label="Cancellation policy (optional)" value={form.cancellation_policy} onChange={set('cancellation_policy')} placeholder="e.g. Free cancellation up to 6 hours before" multiline minRows={2} fullWidth />
            <FormControlLabel control={<Switch checked={form.is_active} onChange={set('is_active')} />} label="Taking bookings for this sport" />
          </>
        )}
      </Stack>
      <Stack spacing={1} mt={3}>
        <Button variant="contained" size="large" onClick={submit} disabled={mutation.isPending}>
          {mutation.isPending ? 'Saving…' : editing ? 'Save' : 'Add sport'}
        </Button>
        <Button size="large" onClick={onClose}>Cancel</Button>
      </Stack>
    </Box>
  )
}
