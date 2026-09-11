import { useState } from 'react'
import { Box, Button, ButtonBase, Stack, TextField, Typography } from '@mui/material'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'
import PhoneIcon from '@mui/icons-material/Phone'
import WhatsAppIcon from '@mui/icons-material/WhatsApp'
import HourglassTopIcon from '@mui/icons-material/HourglassTop'
import RadioButtonUncheckedIcon from '@mui/icons-material/RadioButtonUnchecked'
import CheckCircleIcon from '@mui/icons-material/CheckCircle'

import ActionSheet from './ActionSheet.jsx'
import { Banner, Card, InfoRow, Pill } from './OwnerBits.jsx'
import {
  BOOKING_STATUS, CANCEL_REASONS, PAYOUT_STATUS, bookingInfo, bookingMoney, clock,
  dayLabel, durationLabel, isUpcoming, prettyPhone, rupee, telHref, whatsappHref,
} from './ownerFormat.js'
import { bookingsApi } from '../../api/bookings.js'
import { useNotify } from '../../hooks/useNotify.js'

/**
 * Everything about one booking, plus the two things an owner does with it:
 * contact the customer, or cancel. Cancelling is a second step with a reason,
 * so it is never one accidental tap.
 */
export default function BookingSheet({ booking, onClose }) {
  const [step, setStep] = useState('details')
  const close = () => { setStep('details'); onClose() }

  if (!booking) return <ActionSheet open={false} onClose={close} title="" />

  return step === 'cancel'
    ? <CancelStep booking={booking} onBack={() => setStep('details')} onDone={close} />
    : <DetailsStep booking={booking} onClose={close} onCancel={() => setStep('cancel')} />
}

function DetailsStep({ booking: b, onClose, onCancel }) {
  const info = bookingInfo(b)
  const money = bookingMoney(b)
  const status = BOOKING_STATUS[b.status] ?? { label: b.status, tone: 'neutral' }
  const payout = PAYOUT_STATUS[b.paymentRecord?.vendor_payout_status]
  const completed = b.status === 'completed'

  return (
    <ActionSheet
      open
      onClose={onClose}
      title="Booking details"
      actions={isUpcoming(b) ? (
        <Button color="error" size="large" onClick={onCancel}>Cancel this booking</Button>
      ) : null}
    >
      <Stack direction="row" spacing={1} alignItems="center" mb={1.5}>
        <Pill tone={status.tone} label={status.label} />
        {b.booking_reference && (
          <Typography variant="body2" color="text.secondary">#{b.booking_reference}</Typography>
        )}
      </Stack>

      <Card sx={{ p: 2 }}>
        <Typography variant="h6" fontWeight={700}>{info.customer}</Typography>
        <Typography variant="body2" color="text.secondary">{prettyPhone(info.mobile)}</Typography>
        {info.email && <Typography variant="body2" color="text.secondary">{info.email}</Typography>}
        {info.mobile && (
          <Stack direction="row" spacing={1.25} mt={1.75}>
            <Button fullWidth variant="contained" startIcon={<PhoneIcon />} href={telHref(info.mobile)}>Call</Button>
            <Button fullWidth variant="outlined" startIcon={<WhatsAppIcon />} href={whatsappHref(info.mobile)} target="_blank" rel="noopener">
              WhatsApp
            </Button>
          </Stack>
        )}
      </Card>

      <Card sx={{ px: 2, py: 0.5, mt: 1.5 }}>
        {info.ground && <InfoRow label="Ground" value={info.ground} />}
        <InfoRow label="Sport" value={info.sport} />
        <InfoRow label="Date" value={`${dayLabel(b.slot_date)}, ${dayjs(b.slot_date).format('D MMM YYYY')}`} />
        <InfoRow label="Time" value={`${clock(b.slot_time_from)} – ${clock(b.slot_time_to)}`} />
        <InfoRow label="Duration" value={durationLabel(b.slot_time_from, b.slot_time_to)} />
        {b.is_game ? <InfoRow label="Open game" value="Other players can join" /> : null}
        <InfoRow label="Booked on" value={(b.created_at || b.createdAt) ? dayjs(b.created_at || b.createdAt).format('D MMM YYYY, h:mm A') : '—'} last />
      </Card>

      <Card sx={{ px: 2, py: 0.5, mt: 1.5 }}>
        <InfoRow label="Total amount" value={rupee(money.total)} />
        <InfoRow label="How they pay" value={b.payment_method === 'online' ? 'Full amount online' : 'Advance online, rest at ground'} />
        <InfoRow label="Paid online" value={rupee(money.paidOnline)} color="primary.dark" />
        {b.status !== 'cancelled' && (
          <InfoRow
            label={completed ? 'Paid at ground' : 'Collect at ground'}
            value={money.balance > 0 ? rupee(money.balance) : 'Nothing'}
            strong
            color={money.balance > 0 && !completed ? 'warning.dark' : 'text.primary'}
          />
        )}
        <InfoRow label="Your payout" value={payout?.label ?? 'Not paid online yet'} color={payout?.tone === 'error' ? 'error.main' : undefined} last />
      </Card>

      <Box mt={1.5}>
        {b.status === 'pending' && (
          <Banner tone="warning" icon={HourglassTopIcon}>
            The customer is still paying. The time is held for them for a few minutes
            {b.hold_expires_at ? `, until ${dayjs(b.hold_expires_at).format('h:mm A')}` : ''}.
          </Banner>
        )}
        {b.status === 'cancelled' && (
          <Banner tone="error">Cancelled: {b.cancellation_reason || 'no reason given'}</Banner>
        )}
      </Box>
    </ActionSheet>
  )
}

function CancelStep({ booking: b, onBack, onDone }) {
  const info = bookingInfo(b)
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [reason, setReason] = useState('')
  const [other, setOther] = useState('')

  const finalReason = reason === 'other' ? other.trim() : reason

  const mutation = useMutation({
    mutationFn: () => bookingsApi.ownerCancel(b.id, finalReason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'bookings'] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'slots'] })
      notify.success('Booking cancelled')
      onDone()
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not cancel the booking'),
  })

  const options = [...CANCEL_REASONS.map((r) => ({ value: r, label: r })), { value: 'other', label: 'Other reason' }]

  return (
    <ActionSheet
      open
      onClose={onBack}
      title="Cancel booking?"
      subtitle={`${info.customer} · ${clock(b.slot_time_from)}, ${dayLabel(b.slot_date)}`}
      actions={(
        <>
          <Button
            variant="contained"
            color="error"
            size="large"
            disabled={!finalReason || mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {mutation.isPending ? 'Cancelling…' : 'Cancel booking'}
          </Button>
          <Button size="large" onClick={onBack}>Keep booking</Button>
        </>
      )}
    >
      <Typography variant="body2" color="text.secondary" mb={1.5}>
        Pick a reason. This cannot be undone. Call the customer so they are not surprised.
      </Typography>
      <Card sx={{ overflow: 'hidden' }}>
        {options.map((o, i) => {
          const on = reason === o.value
          return (
            <ButtonBase
              key={o.value}
              onClick={() => setReason(o.value)}
              sx={{
                width: '100%', justifyContent: 'space-between', px: 2, py: 1.75, textAlign: 'left',
                borderBottom: i === options.length - 1 ? 0 : 1, borderColor: 'divider',
              }}
            >
              <Typography fontWeight={500}>{o.label}</Typography>
              {on ? <CheckCircleIcon color="error" /> : <RadioButtonUncheckedIcon sx={{ color: 'text.disabled' }} />}
            </ButtonBase>
          )
        })}
      </Card>
      {reason === 'other' && (
        <TextField
          label="Reason"
          value={other}
          onChange={(e) => setOther(e.target.value)}
          fullWidth
          multiline
          minRows={2}
          sx={{ mt: 1.5 }}
          autoFocus
        />
      )}
    </ActionSheet>
  )
}
