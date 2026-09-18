import React from 'react'
import {
  Alert, Box, Chip, CircularProgress, Divider, Paper, Stack, Typography,
} from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined'

import PageHeader from '../../components/ui/PageHeader.jsx'
import EmptyState from '../../components/ui/EmptyState.jsx'
import { coachEarningsApi } from '../../api/coachEarnings.js'

const rupee = (n) => `₹${Number(n || 0).toLocaleString('en-IN')}`

function MoneyRow({ label, hint, value, last }) {
  return (
    <Box sx={{ py: 1.5, borderBottom: last ? 0 : 1, borderColor: 'divider' }}>
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={2}>
        <Box>
          <Typography variant="body2" fontWeight={600}>{label}</Typography>
          {hint && <Typography variant="caption" color="text.secondary">{hint}</Typography>}
        </Box>
        <Typography fontWeight={700} sx={{ fontVariantNumeric: 'tabular-nums' }}>
          {rupee(value)}
        </Typography>
      </Stack>
    </Box>
  )
}

/**
 * A coach's earnings.
 *
 * Sessions are paid at the venue, so nothing here is owed by Playsher and there
 * is no payout to wait for. The banner says so outright — an "earnings" screen
 * that looks like the ground owner's would otherwise imply money is on its way.
 */
export default function CoachEarnings() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['coach', 'earnings'],
    queryFn: () => coachEarningsApi.list({ limit: 50 }),
    select: (res) => res.data?.data ?? null,
  })

  const summary = data?.summary ?? { collected: 0, upcoming: 0, session_count: 0 }
  const sessions = data?.sessions ?? []

  return (
    <Box>
      <PageHeader title="Earnings" subtitle="What your sessions have brought in" />

      {error && <Alert severity="error" sx={{ mb: 2 }}>Could not load your earnings.</Alert>}

      {isLoading ? (
        <Box display="flex" justifyContent="center" py={6}><CircularProgress size={26} /></Box>
      ) : (
        <>
          <Alert severity="info" sx={{ mb: 2 }}>
            Players pay you directly at the ground. Playsher does not hold this money,
            so there is nothing to pay out.
          </Alert>

          <Paper sx={{ px: 2, py: 0.5, mb: 3 }}>
            <MoneyRow
              label="Collected"
              hint={`${summary.completed_count ?? 0} ${summary.completed_count === 1 ? 'session' : 'sessions'} completed`}
              value={summary.collected}
            />
            <MoneyRow
              label="Upcoming"
              hint="Confirmed, not played yet"
              value={summary.upcoming}
              last
            />
          </Paper>

          <Typography variant="subtitle2" fontWeight={700} mb={1}>Every session</Typography>

          {sessions.length === 0 ? (
            <Paper><EmptyState message="No sessions yet." icon={PaymentsOutlinedIcon} /></Paper>
          ) : (
            <Paper sx={{ px: 2, py: 0.5 }}>
              {sessions.map((s, i) => (
                <Box key={s.id}>
                  {i > 0 && <Divider />}
                  <Stack direction="row" justifyContent="space-between" alignItems="center" spacing={2} py={1.5}>
                    <Box sx={{ minWidth: 0 }}>
                      <Typography variant="body2" fontWeight={600} noWrap>{s.player_name}</Typography>
                      <Typography variant="caption" color="text.secondary" noWrap display="block">
                        {dayjs(s.session_date).format('D MMM YYYY')}
                        {s.time_from ? ` · ${String(s.time_from).slice(0, 5)}` : ''}
                        {s.ground_name ? ` · ${s.ground_name}` : ''}
                      </Typography>
                    </Box>
                    <Stack direction="row" spacing={1} alignItems="center" flexShrink={0}>
                      <Chip
                        size="small"
                        label={s.status}
                        color={s.status === 'completed' ? 'success' : 'default'}
                        sx={{ textTransform: 'capitalize' }}
                      />
                      <Typography fontWeight={700} sx={{ fontVariantNumeric: 'tabular-nums' }}>
                        {rupee(s.total_amount)}
                      </Typography>
                    </Stack>
                  </Stack>
                </Box>
              ))}
            </Paper>
          )}
        </>
      )}
    </Box>
  )
}
