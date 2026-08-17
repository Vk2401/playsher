import React, { useState, useEffect } from 'react'
import {
  Box,
  Button,
  Grid,
  Paper,
  TextField,
  Typography,
  CircularProgress,
  Alert,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

import AccountBalanceIcon from '@mui/icons-material/AccountBalance'
import SaveIcon from '@mui/icons-material/Save'

import PageHeader from '../../components/ui/PageHeader.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { bankDetailsApi } from '../../api/bankDetails.js'

function SectionLabel({ icon: Icon, label }) {
  return (
    <Box display="flex" alignItems="center" gap={1} mb={2}>
      <Icon sx={{ fontSize: 20, color: 'text.secondary' }} />
      <Typography
        variant="subtitle2"
        color="text.secondary"
        fontWeight={700}
        sx={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}
      >
        {label}
      </Typography>
    </Box>
  )
}

const INITIAL_FORM = {
  account_holder_name: '',
  account_number: '',
  ifsc_code: '',
  bank_name: '',
  upi_id: '',
}

export default function OwnerBankDetails() {
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [form, setForm] = useState(INITIAL_FORM)

  const { data: bankDetails, isLoading, error } = useQuery({
    queryKey: ['owner', 'bank-details'],
    queryFn: () => bankDetailsApi.get(),
    select: (res) => res.data?.bank_details || res.data?.data || null,
  })

  useEffect(() => {
    if (bankDetails) {
      setForm({
        account_holder_name: bankDetails.account_holder_name || '',
        account_number: bankDetails.account_number || '',
        ifsc_code: bankDetails.ifsc_code || '',
        bank_name: bankDetails.bank_name || '',
        upi_id: bankDetails.upi_id || '',
      })
    }
  }, [bankDetails])

  const saveMutation = useMutation({
    mutationFn: (data) => bankDetailsApi.save(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'bank-details'] })
      notify.success('Bank details saved successfully')
    },
    onError: (err) => {
      notify.error(err?.response?.data?.message || 'Failed to save bank details')
    },
  })

  const handleChange = (field) => (e) => {
    setForm((prev) => ({ ...prev, [field]: e.target.value }))
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    saveMutation.mutate(form)
  }

  if (isLoading) {
    return (
      <Box>
        <PageHeader title="Bank Details" subtitle="Manage your payout account" />
        <Box display="flex" justifyContent="center" py={8}>
          <CircularProgress />
        </Box>
      </Box>
    )
  }

  return (
    <Box>
      <PageHeader
        title="Bank Details"
        subtitle="Manage your payout account"
        breadcrumbs={[
          { label: 'Owner', href: '/owner' },
          { label: 'Bank Details' },
        ]}
      />

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          Failed to load bank details. Please try again.
        </Alert>
      )}

      {!bankDetails && !error && (
        <Alert severity="info" sx={{ mb: 2 }}>
          No bank details yet. Fill in the form below to add your payout account.
        </Alert>
      )}

      <Paper sx={{ p: 3 }}>
        <SectionLabel icon={AccountBalanceIcon} label="Bank Account Information" />

        <form onSubmit={handleSubmit}>
          <Grid container spacing={2} mb={3}>
            <Grid item xs={12} sm={6}>
              <TextField
                label="Account Holder Name"
                value={form.account_holder_name}
                onChange={handleChange('account_holder_name')}
                size="small"
                fullWidth
                required
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                label="Account Number"
                value={form.account_number}
                onChange={handleChange('account_number')}
                size="small"
                fullWidth
                required
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                label="IFSC Code"
                value={form.ifsc_code}
                onChange={handleChange('ifsc_code')}
                size="small"
                fullWidth
                required
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                label="Bank Name"
                value={form.bank_name}
                onChange={handleChange('bank_name')}
                size="small"
                fullWidth
              />
            </Grid>
            <Grid item xs={12} sm={6}>
              <TextField
                label="UPI ID"
                value={form.upi_id}
                onChange={handleChange('upi_id')}
                size="small"
                fullWidth
              />
            </Grid>
          </Grid>

          <Button
            type="submit"
            variant="contained"
            startIcon={
              saveMutation.isPending ? (
                <CircularProgress size={18} color="inherit" />
              ) : (
                <SaveIcon />
              )
            }
            disabled={saveMutation.isPending}
          >
            {saveMutation.isPending ? 'Saving...' : 'Save Bank Details'}
          </Button>
        </form>
      </Paper>
    </Box>
  )
}
