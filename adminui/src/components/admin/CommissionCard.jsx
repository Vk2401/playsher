import React, { useState, useEffect } from 'react'
import {
  Box, Paper, Stack, Typography, TextField, Button, Chip, InputAdornment,
  CircularProgress, Tooltip,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import EditIcon from '@mui/icons-material/Edit'
import LockIcon from '@mui/icons-material/Lock'

import { settingsApi } from '../../api/payments.js'
import { useIsSuperAdmin } from '../../hooks/useIsSuperAdmin.js'
import { useNotify } from '../../hooks/useNotify.js'

/**
 * The platform commission rate — what Playsher keeps from every online payment.
 *
 * Every admin can see it, because it explains every figure on this page. Only a
 * super admin can change it, which the server enforces too; the lock here is
 * the explanation, not the control.
 *
 * The warning below is the point of the card. A rate change is invisible until
 * the next booking settles, so it is easy to assume it restated the numbers
 * already on screen. It does not — each payment keeps the fee frozen onto it at
 * capture — and saying so is what stops someone "fixing" a rate twice.
 */
export default function CommissionCard() {
  const isSuperAdmin = useIsSuperAdmin()
  const notify = useNotify()
  const queryClient = useQueryClient()

  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState('')

  const commission = useQuery({
    queryKey: ['admin', 'settings', 'commission'],
    queryFn: () => settingsApi.getCommission(),
    select: (res) => res.data?.data ?? null,
  })

  const percent = commission.data?.percent
  const source = commission.data?.source

  useEffect(() => {
    if (percent !== undefined && !editing) setDraft(String(percent))
  }, [percent, editing])

  const save = useMutation({
    mutationFn: (value) => settingsApi.setCommission(value),
    onSuccess: (res) => {
      notify.success(`Commission set to ${res.data?.data?.percent}%. Applies to new payments.`)
      setEditing(false)
      queryClient.invalidateQueries({ queryKey: ['admin', 'settings', 'commission'] })
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Could not update the commission.'),
  })

  const parsed = Number(draft)
  const valid = Number.isFinite(parsed) && parsed >= 0 && parsed < 100

  return (
    <Paper sx={{ p: 2.5, mb: 3, borderRadius: 2 }}>
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={2}
        alignItems={{ xs: 'stretch', sm: 'center' }}
        justifyContent="space-between"
      >
        <Box sx={{ minWidth: 0 }}>
          <Stack direction="row" spacing={1} alignItems="center" mb={0.25}>
            <Typography variant="subtitle1" fontWeight={700}>Platform commission</Typography>
            {source && (
              <Tooltip
                title={
                  source === 'database' ? 'Set here by a super admin'
                    : source === 'environment' ? 'Coming from PLATFORM_COMMISSION_RATE on the server'
                      : 'No rate configured — using the built-in default'
                }
              >
                <Chip size="small" label={source} sx={{ height: 20, textTransform: 'capitalize' }} />
              </Tooltip>
            )}
          </Stack>
          <Typography variant="body2" color="text.secondary">
            Kept from every online payment. Changing it affects payments from now on —
            past payouts keep the rate they were settled at.
          </Typography>
        </Box>

        <Stack direction="row" spacing={1.5} alignItems="center" sx={{ flexShrink: 0 }}>
          {commission.isLoading ? (
            <CircularProgress size={22} />
          ) : editing ? (
            <>
              <TextField
                size="small"
                type="number"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                error={draft !== '' && !valid}
                helperText={draft !== '' && !valid ? '0 to 99' : ' '}
                sx={{ width: 120 }}
                inputProps={{ min: 0, max: 99, step: 0.5 }}
                InputProps={{ endAdornment: <InputAdornment position="end">%</InputAdornment> }}
              />
              <Button
                variant="contained"
                disabled={!valid || save.isPending}
                onClick={() => save.mutate(parsed)}
              >
                Save
              </Button>
              <Button
                variant="outlined"
                disabled={save.isPending}
                onClick={() => { setEditing(false); setDraft(String(percent ?? '')) }}
              >
                Cancel
              </Button>
            </>
          ) : (
            <>
              <Typography variant="h4" fontWeight={800} sx={{ fontVariantNumeric: 'tabular-nums' }}>
                {percent ?? '—'}%
              </Typography>
              {isSuperAdmin ? (
                <Button startIcon={<EditIcon />} onClick={() => setEditing(true)}>
                  Change
                </Button>
              ) : (
                <Tooltip title="Only a super admin can change the commission">
                  <span>
                    <Button startIcon={<LockIcon />} disabled>Change</Button>
                  </span>
                </Tooltip>
              )}
            </>
          )}
        </Stack>
      </Stack>
    </Paper>
  )
}
