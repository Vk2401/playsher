import { useState } from 'react'
import { Box, Button, Skeleton, Stack, TextField, Typography } from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline'
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'

import { Banner, Card, InfoRow, ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { bankDetailsApi } from '../../api/bankDetails.js'
import { useNotify } from '../../hooks/useNotify.js'

const FIELDS = ['account_holder_name', 'account_number', 'ifsc_code', 'bank_name', 'upi_id']
const mask = (n) => (n ? `•••• ${String(n).slice(-4)}` : '—')

/** Where online payments for bookings are sent. */
export default function OwnerBankDetails() {
  const [editing, setEditing] = useState(false)

  const q = useQuery({
    queryKey: ['owner', 'bank-details'],
    queryFn: () => bankDetailsApi.get(),
    select: (res) => res.data?.bank_details || res.data?.data || null,
  })
  const bank = q.data

  return (
    <Box>
      <ScreenHeader title="Bank & UPI" subtitle="Online payments for your bookings are sent here" back="/owner/more" />
      {q.isLoading && <Skeleton variant="rounded" height={260} />}
      {q.isError && <Banner tone="error">Could not load your bank details. Try again.</Banner>}

      {q.isSuccess && (editing || !bank) && (
        <BankForm key={bank?.id ?? 'new'} bank={bank} onDone={() => setEditing(false)} canCancel={Boolean(bank)} />
      )}

      {q.isSuccess && bank && !editing && (
        <>
          <Banner tone="primary" icon={CheckCircleOutlineIcon}>Payouts are set up</Banner>
          <Card sx={{ px: 2, py: 0.5 }}>
            <InfoRow label="Account holder" value={bank.account_holder_name} />
            <InfoRow label="Bank" value={bank.bank_name} />
            <InfoRow label="Account number" value={mask(bank.account_number)} />
            <InfoRow label="IFSC" value={bank.ifsc_code} />
            <InfoRow label="UPI ID" value={bank.upi_id || 'Not added'} last />
          </Card>
          <Button fullWidth variant="outlined" size="large" startIcon={<EditOutlinedIcon />} sx={{ mt: 2 }} onClick={() => setEditing(true)}>
            Change bank details
          </Button>
        </>
      )}
    </Box>
  )
}

function BankForm({ bank, onDone, canCancel }) {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [form, setForm] = useState(() => Object.fromEntries(FIELDS.map((f) => [f, bank?.[f] || ''])))
  const [errors, setErrors] = useState({})
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: k === 'ifsc_code' ? e.target.value.toUpperCase() : e.target.value }))

  const mutation = useMutation({
    mutationFn: () => bankDetailsApi.save(Object.fromEntries(Object.entries(form).map(([k, v]) => [k, String(v).trim()]))),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'bank-details'] })
      notify.success('Bank details saved')
      onDone()
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not save bank details'),
  })

  const submit = () => {
    const e = {}
    if (!form.account_holder_name.trim()) e.account_holder_name = 'Name as printed on the passbook'
    if (!/^\d{9,18}$/.test(form.account_number.trim())) e.account_number = 'Enter the account number (9 to 18 digits)'
    if (!/^[A-Z]{4}0[A-Z0-9]{6}$/.test(form.ifsc_code.trim())) e.ifsc_code = 'IFSC looks like SBIN0001234'
    if (form.upi_id && !/^[\w.-]+@[\w.-]+$/.test(form.upi_id.trim())) e.upi_id = 'UPI ID looks like name@bank'
    setErrors(e)
    if (Object.keys(e).length === 0) mutation.mutate()
  }

  return (
    <Box>
      {!bank && (
        <Banner tone="warning" icon={InfoOutlinedIcon}>
          No bank details yet. Online payments wait until you add them.
        </Banner>
      )}
      <Card sx={{ p: 2 }}>
        <Stack spacing={1.75}>
          <TextField label="Account holder name" value={form.account_holder_name} onChange={set('account_holder_name')} error={!!errors.account_holder_name} helperText={errors.account_holder_name} fullWidth />
          <TextField label="Account number" value={form.account_number} onChange={set('account_number')} error={!!errors.account_number} helperText={errors.account_number} inputMode="numeric" fullWidth />
          <TextField label="IFSC code" value={form.ifsc_code} onChange={set('ifsc_code')} error={!!errors.ifsc_code} helperText={errors.ifsc_code || 'Printed on your cheque book or passbook'} fullWidth />
          <TextField label="Bank name" value={form.bank_name} onChange={set('bank_name')} fullWidth />
          <TextField label="UPI ID (optional)" value={form.upi_id} onChange={set('upi_id')} error={!!errors.upi_id} helperText={errors.upi_id} fullWidth />
        </Stack>
      </Card>
      <Typography variant="body2" color="text.secondary" mt={1.5}>
        Check the account number twice. Money sent to a wrong account is hard to get back.
      </Typography>
      <Stack spacing={1} mt={2}>
        <Button variant="contained" size="large" onClick={submit} disabled={mutation.isPending}>{mutation.isPending ? 'Saving…' : 'Save bank details'}</Button>
        {canCancel && <Button size="large" onClick={onDone}>Cancel</Button>}
      </Stack>
    </Box>
  )
}
