import { Box, Skeleton, Stack, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import dayjs from 'dayjs'
import AccountBalanceOutlinedIcon from '@mui/icons-material/AccountBalanceOutlined'
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'

import { Banner, Card, EmptyNote, Pill, SectionTitle } from '../../components/owner/OwnerBits.jsx'
import { clock, rupee } from '../../components/owner/ownerFormat.js'
import { ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { settlementsApi } from '../../api/settlements.js'

/**
 * How each payment reads to the person waiting for the money.
 *
 * `collected_at_ground` is not a payout state the server stores — it is what
 * the endpoint reports for cash, because the owner already holds it and
 * showing it as "pending" would look like Playsher owed them money twice.
 */
const ROW_STATUS = {
  collected_at_ground: { label: 'You took this', tone: 'neutral' },
  transferred: { label: 'Sent to your bank', tone: 'primary' },
  pending: { label: 'Not sent yet', tone: 'warning' },
  no_bank_details: { label: 'Needs your bank details', tone: 'error' },
  no_vendor: { label: 'Not set up', tone: 'neutral' },
}

/** What this venue has earned, and what Playsher still owes. */
export default function OwnerSettlements() {
  const navigate = useNavigate()

  const q = useQuery({
    queryKey: ['owner', 'settlements'],
    queryFn: () => settlementsApi.getOwnerSettlements(),
    select: (res) => res.data?.data ?? null,
  })

  const summary = q.data?.summary
  const payments = q.data?.payments ?? []

  return (
    <Box>
      <ScreenHeader
        title="Earnings"
        subtitle="What your grounds took, and what is still coming to you"
        back="/owner/more"
      />

      {q.isLoading && <Skeleton variant="rounded" height={300} />}
      {q.isError && <Banner tone="error">Could not load your earnings. Try again.</Banner>}

      {q.isSuccess && summary && (
        <>
          {/* The one thing that needs an action, and only when it does. */}
          {summary.payout_state === 'no_bank_details' && (
            <Banner
              tone="error"
              icon={AccountBalanceOutlinedIcon}
              onClick={() => navigate('/owner/bank-details')}
            >
              {rupee(summary.online_awaiting)} is waiting — add your bank details so it can be sent.
            </Banner>
          )}
          {summary.payout_state === 'settled' && summary.online_total > 0 && (
            <Banner tone="primary" icon={CheckCircleOutlineIcon}>
              Everything paid online has reached your bank.
            </Banner>
          )}

          <Stack direction="row" spacing={1.25} sx={{ mb: 2 }}>
            <Money label="Cash you took" value={summary.cash_collected} hint="At the ground" />
            <Money
              label="Coming to you"
              value={summary.online_awaiting}
              hint="Paid online"
              tone={summary.online_awaiting > 0 ? 'warning' : undefined}
            />
            <Money label="Already sent" value={summary.online_paid_out} hint="To your bank" />
          </Stack>

          <SectionTitle>Every payment</SectionTitle>
          {payments.length === 0 ? (
            <EmptyNote
              icon={PaymentsOutlinedIcon}
              title="Nothing yet"
              text="Payments for your grounds show up here once a booking is paid."
            />
          ) : (
            <Card sx={{ p: 0, overflow: 'hidden' }}>
              {payments.map((p, i) => (
                <PaymentRow key={p.id} payment={p} last={i === payments.length - 1} />
              ))}
            </Card>
          )}
        </>
      )}
    </Box>
  )
}

function Money({ label, value, hint, tone }) {
  return (
    <Card sx={{ flex: 1, p: 1.75, minWidth: 0 }}>
      <Typography variant="caption" color="text.secondary" noWrap>{label}</Typography>
      <Typography
        variant="h6"
        fontWeight={700}
        color={tone === 'warning' && value > 0 ? 'warning.dark' : 'text.primary'}
        sx={{ lineHeight: 1.2, mt: 0.25 }}
      >
        {rupee(value)}
      </Typography>
      <Typography variant="caption" color="text.secondary" noWrap>{hint}</Typography>
    </Card>
  )
}

function PaymentRow({ payment: p, last }) {
  const status = ROW_STATUS[p.vendor_payout_status] ?? { label: p.vendor_payout_status, tone: 'neutral' }
  const when = p.slot_date
    ? `${dayjs(p.slot_date).format('D MMM')}${p.slot_time_from ? `, ${clock(p.slot_time_from)}` : ''}`
    : null

  return (
    <Box sx={{ px: 2, py: 1.5, borderBottom: last ? 0 : '1px solid', borderColor: 'divider' }}>
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1.5}>
        <Box sx={{ minWidth: 0 }}>
          <Typography fontWeight={600} sx={{ lineHeight: 1.3 }}>{rupee(p.amount)}</Typography>
          <Typography variant="body2" color="text.secondary" noWrap>
            {[p.sport_name, when].filter(Boolean).join(' · ')}
          </Typography>
          {p.booking_reference && (
            <Typography variant="caption" color="text.secondary">#{p.booking_reference}</Typography>
          )}
        </Box>
        <Pill tone={status.tone} label={status.label} />
      </Stack>
    </Box>
  )
}
