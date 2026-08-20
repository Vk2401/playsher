import React from 'react'
import {
  Avatar, Box, Chip, Divider, Grid, Paper, TextField, Typography,
} from '@mui/material'
import { useTheme } from '@mui/material/styles'
import dayjs from 'dayjs'

import PersonIcon from '@mui/icons-material/Person'
import EmailIcon from '@mui/icons-material/Email'
import BadgeIcon from '@mui/icons-material/Badge'

import PageHeader from '../../components/ui/PageHeader.jsx'
import { useAuth } from '../../contexts/AuthContext.jsx'

function getInitials(name) {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase()
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase()
}

function SectionLabel({ icon: Icon, label }) {
  return (
    <Box display="flex" alignItems="center" gap={1} mb={2}>
      <Icon sx={{ fontSize: 20, color: 'text.secondary' }} />
      <Typography
        variant="subtitle2" color="text.secondary" fontWeight={700}
        sx={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}
      >
        {label}
      </Typography>
    </Box>
  )
}

function ReadField({ label, value }) {
  return (
    <TextField
      label={label}
      value={value ?? '—'}
      size="small"
      fullWidth
      InputProps={{ readOnly: true }}
      sx={{ '& .MuiInputBase-root': { background: 'rgba(0,0,0,0.02)' } }}
    />
  )
}

export default function AdminProfile() {
  const theme = useTheme()
  const primary = theme.palette.primary.main
  const { user } = useAuth()

  const displayName = user?.name ?? user?.full_name ?? 'Administrator'
  const initials = getInitials(displayName)

  return (
    <Box>
      <PageHeader title="My Profile" subtitle="Administrator account information" />

      <Grid container spacing={3}>
        {/* Left: Avatar card */}
        <Grid item xs={12} md={4}>
          <Paper sx={{ p: 3, textAlign: 'center' }}>
            <Avatar
              sx={{
                width: 96, height: 96,
                fontSize: 36, fontWeight: 700,
                bgcolor: primary, mx: 'auto', mb: 2,
                boxShadow: `0 4px 20px ${primary}40`,
              }}
            >
              {initials}
            </Avatar>

            <Typography variant="h6" fontWeight={700}>{displayName}</Typography>
            <Typography variant="body2" color="text.secondary" mb={2}>
              {user?.email ?? '—'}
            </Typography>

            <Box display="flex" justifyContent="center" gap={1} flexWrap="wrap">
              <Chip
                label="Administrator"
                size="small"
                color="primary"
                variant="outlined"
                sx={{ fontWeight: 600 }}
              />
            </Box>
          </Paper>
        </Grid>

        {/* Right: Detail fields */}
        <Grid item xs={12} md={8}>
          <Paper sx={{ p: 3 }}>
            <SectionLabel icon={PersonIcon} label="Personal Information" />
            <Grid container spacing={2} mb={3}>
              <Grid item xs={12} sm={6}>
                <ReadField label="Full Name" value={displayName} />
              </Grid>
              <Grid item xs={12} sm={6}>
                <ReadField
                  label="Mobile"
                  value={user?.mobile ?? user?.phone ?? user?.contact_number}
                />
              </Grid>
            </Grid>

            <Divider sx={{ mb: 3 }} />

            <SectionLabel icon={EmailIcon} label="Contact" />
            <Grid container spacing={2} mb={3}>
              <Grid item xs={12}>
                <ReadField label="Email Address" value={user?.email} />
              </Grid>
            </Grid>

            <Divider sx={{ mb: 3 }} />

            <SectionLabel icon={BadgeIcon} label="Account Information" />
            <Grid container spacing={2}>
              <Grid item xs={12} sm={6}>
                <ReadField label="Role" value="Administrator" />
              </Grid>
              <Grid item xs={12} sm={6}>
                <ReadField label="User ID" value={user?.id ? String(user.id) : null} />
              </Grid>
              {user?.created_at && (
                <Grid item xs={12} sm={6}>
                  <ReadField
                    label="Member Since"
                    value={dayjs(user.created_at).format('DD MMMM YYYY')}
                  />
                </Grid>
              )}
            </Grid>
          </Paper>
        </Grid>
      </Grid>
    </Box>
  )
}
