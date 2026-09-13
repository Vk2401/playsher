import { useState } from 'react'
import { Avatar, Box, Button, ButtonBase, Skeleton, Stack, TextField, Typography } from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'
import PhoneIcon from '@mui/icons-material/Phone'
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined'

import ActionSheet from '../../components/owner/ActionSheet.jsx'
import { Banner, Card, EmptyNote, FilterChips, InfoRow, Pill, ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { initials, prettyPhone, rupee, telHref } from '../../components/owner/ownerFormat.js'
import { coachesApi } from '../../api/coaches.js'
import { useNotify } from '../../hooks/useNotify.js'

const STATUS = {
  pending: { label: 'Waiting on you', tone: 'warning' },
  approved: { label: 'Approved', tone: 'primary' },
  rejected: { label: 'Declined', tone: 'error' },
}

/**
 * Coaches asking to run sessions at the owner's grounds. Approve or decline
 * with an optional note; a decision can be changed later.
 */
export default function OwnerCoachRequests() {
  const [status, setStatus] = useState('pending')
  const [open, setOpen] = useState(null)

  const q = useQuery({
    queryKey: ['owner', 'coach-requests', 'list'],
    queryFn: () => coachesApi.getOwnerRequests({ limit: 100 }),
    select: (res) => res.data?.data ?? [],
  })
  const all = q.data ?? []
  const rows = status === 'all' ? all : all.filter((r) => r.status === status)
  const options = [
    { value: 'pending', label: 'Waiting', count: all.filter((r) => r.status === 'pending').length },
    { value: 'approved', label: 'Approved', count: all.filter((r) => r.status === 'approved').length },
    { value: 'rejected', label: 'Declined', count: all.filter((r) => r.status === 'rejected').length },
    { value: 'all', label: 'All', count: all.length },
  ]

  return (
    <Box>
      <ScreenHeader title="Coach requests" subtitle="Coaches asking to train players at your grounds" back="/owner/more" />
      <FilterChips options={options} value={status} onChange={setStatus} />
      <Box mt={2}>
        {q.isLoading && [0, 1].map((i) => <Skeleton key={i} variant="rounded" height={140} sx={{ mb: 1.25 }} />)}
        {q.isError && <Banner tone="error">Could not load coach requests.</Banner>}
        {q.isSuccess && rows.length === 0 && (
          <Card>
            <EmptyNote icon={GroupsOutlinedIcon} title={status === 'pending' ? 'All caught up' : 'Nothing here'} text={status === 'pending' ? 'No coach is waiting for your answer.' : undefined} />
          </Card>
        )}
        {rows.map((r) => (
          <ButtonBase key={r.id} onClick={() => setOpen(r)} sx={{ width: '100%', display: 'block', textAlign: 'left', borderRadius: 1, mb: 1.25 }}>
            <Card sx={{ p: 2 }}>
              <Stack direction="row" spacing={1.5} alignItems="center">
                <Avatar src={r.coach?.profile_picture || undefined} sx={{ bgcolor: 'primary.dark', fontWeight: 700 }}>{initials(r.coach?.name)}</Avatar>
                <Box flex={1} minWidth={0}>
                  <Typography fontWeight={700} noWrap>{r.coach?.name || 'Coach'}</Typography>
                  <Typography variant="body2" color="text.secondary" noWrap>
                    {[r.coach?.sport_name, r.coach?.experience_years != null ? `${r.coach.experience_years} yrs` : null, r.ground?.name].filter(Boolean).join(' · ')}
                  </Typography>
                </Box>
                <Pill tone={STATUS[r.status]?.tone} label={STATUS[r.status]?.label ?? r.status} />
              </Stack>
              {r.request_note && (
                <Typography variant="body2" sx={{ mt: 1.5, p: 1.25, bgcolor: 'action.hover', borderRadius: 1 }}>“{r.request_note}”</Typography>
              )}
              {r.status === 'pending' && (
                <Typography variant="body2" fontWeight={600} color="primary.dark" mt={1.25}>Tap to answer</Typography>
              )}
            </Card>
          </ButtonBase>
        ))}
      </Box>

      <RequestSheet request={open} onClose={() => setOpen(null)} />
    </Box>
  )
}

function RequestSheet({ request: r, onClose }) {
  return (
    <ActionSheet open={Boolean(r)} onClose={onClose} title={r?.coach?.name || 'Coach request'} subtitle={r ? `For ${r.ground?.name ?? 'your ground'}` : ''}>
      {r && <RequestBody key={r.id} r={r} onClose={onClose} />}
    </ActionSheet>
  )
}

function RequestBody({ r, onClose }) {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [note, setNote] = useState(r.response_note || '')

  const mutation = useMutation({
    mutationFn: (action) => (action === 'approve'
      ? coachesApi.approveOwnerRequest(r.id, note.trim() || undefined)
      : coachesApi.rejectOwnerRequest(r.id, note.trim() || undefined)),
    onSuccess: (_res, action) => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'coach-requests'] })
      notify.success(action === 'approve' ? `${r.coach?.name ?? 'Coach'} approved` : 'Request declined')
      onClose()
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save your answer'),
  })

  const c = r.coach ?? {}
  return (
    <Box>
      <Pill tone={STATUS[r.status]?.tone} label={STATUS[r.status]?.label ?? r.status} />
      {r.request_note && (
        <Card sx={{ p: 2, mt: 1.5 }}>
          <Typography variant="caption" color="text.secondary">Their message</Typography>
          <Typography>“{r.request_note}”</Typography>
        </Card>
      )}
      <Card sx={{ px: 2, py: 0.5, mt: 1.5 }}>
        <InfoRow label="Sport" value={c.sport_name || 'Not set'} />
        <InfoRow label="Level" value={c.level || '—'} />
        <InfoRow label="Experience" value={c.experience_years != null ? `${c.experience_years} years` : '—'} />
        <InfoRow label="Rate" value={Number(c.price_per_slot) > 0 ? `${rupee(c.price_per_slot)} per 30 min` : 'Not set'} />
        <InfoRow label="Verified by Playsher" value={c.is_approved ? 'Yes' : 'Not yet'} />
        <InfoRow label="Mobile" value={c.mobile ? prettyPhone(c.mobile) : '—'} />
        <InfoRow label="Email" value={c.email || '—'} />
        <InfoRow label="Asked on" value={r.requested_at ? dayjs(r.requested_at).format('D MMM YYYY') : '—'} />
        {c.about && <InfoRow label="About" value={c.about} multiline />}
        {r.response_note && <InfoRow label="Your note" value={r.response_note} multiline last />}
      </Card>
      {c.mobile && (
        <Button fullWidth variant="outlined" startIcon={<PhoneIcon />} href={telHref(c.mobile)} sx={{ mt: 1.5 }}>Call coach</Button>
      )}
      <TextField
        label="Note to the coach (optional)"
        value={note}
        onChange={(e) => setNote(e.target.value)}
        fullWidth
        multiline
        minRows={2}
        sx={{ mt: 2 }}
      />
      <Stack direction="row" spacing={1.25} mt={2}>
        {r.status !== 'rejected' && (
          <Button fullWidth size="large" variant="outlined" color="error" disabled={mutation.isPending} onClick={() => mutation.mutate('reject')}>Decline</Button>
        )}
        {r.status !== 'approved' && (
          <Button fullWidth size="large" variant="contained" disabled={mutation.isPending} onClick={() => mutation.mutate('approve')}>Approve</Button>
        )}
      </Stack>
    </Box>
  )
}
