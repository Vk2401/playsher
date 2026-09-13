import { useState } from 'react'
import { Box, Button, InputAdornment, Stack, Switch, TextField, Typography } from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import AddIcon from '@mui/icons-material/Add'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import ScheduleIcon from '@mui/icons-material/Schedule'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import SportsSoccerOutlinedIcon from '@mui/icons-material/SportsSoccerOutlined'

import ActionSheet from '../ActionSheet.jsx'
import ConfirmSheet from '../ConfirmSheet.jsx'
import SportSheet from './SportSheet.jsx'
import ScheduleSheet from './ScheduleSheet.jsx'
import { Card, EmptyNote, InfoRow } from '../OwnerBits.jsx'
import { lengthLabel, rupee } from '../ownerFormat.js'
import { groundsApi } from '../../../api/grounds.js'
import { schedulesApi } from '../../../api/schedules.js'
import { useNotify } from '../../../hooks/useNotify.js'

const DAY_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

function hoursSummary(schedules = []) {
  const open = schedules.filter((s) => !s.is_closed)
  if (!open.length) return 'No opening hours set'
  const t = (v) => String(v).slice(0, 5)
  const same = open.every((s) => t(s.start_time) === t(open[0].start_time) && t(s.end_time) === t(open[0].end_time))
  const range = `${t(open[0].start_time)} – ${t(open[0].end_time)}`
  if (open.length === 7 && same) return `Every day, ${range}`
  const closed = schedules.filter((s) => s.is_closed).map((s) => DAY_SHORT[s.day_of_week])
  return same ? `${range}${closed.length ? ` · closed ${closed.join(', ')}` : ''}` : `${open.length} days open, different hours`
}

/**
 * The ground's price and each sport it offers. Price is one number for the
 * whole ground (per 30 minutes); each sport sets how long one booking can be,
 * players, cancellation policy, opening hours, and can be paused.
 */
export default function SportsTab({ ground, openAdd, setOpenAdd }) {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [editing, setEditing] = useState(null)
  const [hoursFor, setHoursFor] = useState(null)
  const [removing, setRemoving] = useState(null)
  const [priceOpen, setPriceOpen] = useState(false)

  const sports = ground?.groundSports ?? []
  const scheduleQ = useQuery({
    queryKey: ['owner', 'schedule', ground.id],
    queryFn: () => schedulesApi.getSchedule(ground.id),
    select: (res) => res.data?.data?.ground_sports ?? [],
  })
  const scheduleOf = (gsId) => (scheduleQ.data ?? []).find((g) => g.id === gsId)?.schedules ?? []

  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: ['owner', 'ground', ground.id] })
    queryClient.invalidateQueries({ queryKey: ['owner', 'slots', ground.id] })
  }

  const toggle = useMutation({
    mutationFn: (gs) => groundsApi.updateSport(ground.id, gs.id, { is_active: !gs.is_active }),
    onSuccess: (_r, gs) => { notify.success(`${gs.sport?.name ?? 'Sport'} ${gs.is_active ? 'paused' : 'is taking bookings'}`); refresh() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not change the sport'),
  })
  const remove = useMutation({
    mutationFn: (gs) => groundsApi.removeSport(ground.id, gs.id),
    onSuccess: () => { notify.success('Sport removed'); setRemoving(null); refresh() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not remove the sport'),
  })

  const price = Number(ground?.price_per_slot || 0)

  return (
    <Box mt={2}>
      <Card sx={{ p: 2 }}>
        <Stack direction="row" justifyContent="space-between" alignItems="center">
          <Box>
            <Typography variant="body2" color="text.secondary">Price</Typography>
            <Typography fontWeight={800} fontSize={22}>
              {price ? `${rupee(price * 2)} / hour` : 'Not set'}
            </Typography>
            {price > 0 && <Typography variant="body2" color="text.secondary">{rupee(price)} for every 30 minutes, all sports</Typography>}
          </Box>
          <Button variant="outlined" startIcon={<EditOutlinedIcon />} onClick={() => setPriceOpen(true)}>Change</Button>
        </Stack>
      </Card>

      <Typography variant="subtitle1" fontWeight={700} mt={3} mb={1.25}>Sports</Typography>

      {sports.length === 0 && (
        <Card><EmptyNote icon={SportsSoccerOutlinedIcon} title="No sports yet" text="Add the sports customers can play here." /></Card>
      )}

      {sports.map((gs) => (
        <Card key={gs.id} sx={{ p: 2, mb: 1.25 }}>
          <Stack direction="row" justifyContent="space-between" alignItems="center">
            <Box>
              <Typography fontWeight={700} fontSize={17}>{gs.sport?.name ?? 'Sport'}</Typography>
              <Typography variant="body2" color={gs.is_active ? 'primary.dark' : 'text.disabled'} fontWeight={500}>
                {gs.is_active ? 'Taking bookings' : 'Paused, customers cannot book'}
              </Typography>
            </Box>
            <Switch checked={Boolean(gs.is_active)} onChange={() => toggle.mutate(gs)} disabled={toggle.isPending} inputProps={{ 'aria-label': `${gs.sport?.name} taking bookings` }} />
          </Stack>
          <Box mt={1}>
            <InfoRow label="One booking" value={`${lengthLabel(gs.min_slots)} to ${lengthLabel(gs.max_slots)}`} />
            <InfoRow label="Opening hours" value={scheduleQ.isSuccess ? hoursSummary(scheduleOf(gs.id)) : '…'} color={scheduleQ.isSuccess && !scheduleOf(gs.id).some((s) => !s.is_closed) ? 'warning.dark' : undefined} />
            <InfoRow label="Players" value={gs.player_counts || 'Not set'} />
            <InfoRow label="Cancellation" value={gs.cancellation_policy || 'Not set'} last />
          </Box>
          <Stack direction="row" spacing={1} mt={1.5} flexWrap="wrap" useFlexGap>
            <Button size="small" variant="outlined" startIcon={<EditOutlinedIcon />} onClick={() => setEditing(gs)}>Edit</Button>
            <Button size="small" variant="outlined" startIcon={<ScheduleIcon />} onClick={() => setHoursFor(gs)}>Hours</Button>
            <Button size="small" color="error" startIcon={<DeleteOutlineIcon />} onClick={() => setRemoving(gs)}>Remove</Button>
          </Stack>
        </Card>
      ))}

      <Button fullWidth variant="outlined" size="large" startIcon={<AddIcon />} sx={{ borderStyle: 'dashed', mt: 0.5 }} onClick={() => setOpenAdd(true)}>
        Add a sport
      </Button>

      <SportSheet open={openAdd} onClose={() => setOpenAdd(false)} groundId={ground.id} existingSportIds={sports.map((s) => s.sport_id)} />
      <SportSheet open={Boolean(editing)} onClose={() => setEditing(null)} groundId={ground.id} groundSport={editing} />
      <ScheduleSheet open={Boolean(hoursFor)} onClose={() => setHoursFor(null)} groundId={ground.id} groundSport={hoursFor} schedules={scheduleOf(hoursFor?.id)} />
      <ConfirmSheet
        open={Boolean(removing)}
        onClose={() => setRemoving(null)}
        title={`Remove ${removing?.sport?.name ?? 'this sport'}?`}
        text="Its opening hours and all its future times are deleted. Existing bookings stay. You can add the sport again later."
        confirmLabel="Remove sport"
        loading={remove.isPending}
        onConfirm={() => remove.mutate(removing)}
      />
      <PriceSheet open={priceOpen} onClose={() => setPriceOpen(false)} ground={ground} />
    </Box>
  )
}

function PriceSheet({ open, onClose, ground }) {
  return (
    <ActionSheet open={open} onClose={onClose} title="Change price">
      {open && <PriceForm key={ground.id} ground={ground} onClose={onClose} />}
    </ActionSheet>
  )
}

function PriceForm({ ground, onClose }) {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [hourly, setHourly] = useState(ground?.price_per_slot ? String(Number(ground.price_per_slot) * 2) : '')
  const [error, setError] = useState('')
  const half = Number(hourly) > 0 ? Number(hourly) / 2 : 0

  const mutation = useMutation({
    mutationFn: () => {
      const fd = new FormData()
      fd.append('price_per_slot', String(Math.round(half * 100) / 100))
      return groundsApi.update(ground.id, fd)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', ground.id] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'grounds'] })
      notify.success('Price saved. New bookings use it.')
      onClose()
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save the price'),
  })

  const submit = () => {
    if (!half) { setError('Enter the price for one hour'); return }
    mutation.mutate()
  }

  return (
    <Box>
      <TextField
        label="Price for one hour"
        value={hourly}
        onChange={(e) => { setHourly(e.target.value); setError('') }}
        inputMode="numeric"
        autoFocus
        fullWidth
        error={!!error}
        helperText={error || (half ? `Customers pay ${rupee(half)} for each 30 minutes` : 'Same price for every sport at this ground')}
        InputProps={{ startAdornment: <InputAdornment position="start">₹</InputAdornment> }}
        sx={{ mt: 1 }}
      />
      <Typography variant="body2" color="text.secondary" mt={1.5}>
        Bookings already made keep the price they were booked at.
      </Typography>
      <Stack spacing={1} mt={3}>
        <Button variant="contained" size="large" onClick={submit} disabled={mutation.isPending}>{mutation.isPending ? 'Saving…' : 'Save price'}</Button>
        <Button size="large" onClick={onClose}>Cancel</Button>
      </Stack>
    </Box>
  )
}
