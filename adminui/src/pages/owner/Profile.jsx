import dayjs from 'dayjs'
import { useEffect, useRef } from 'react'
import { Avatar, Box, Stack, Typography } from '@mui/material'
import { useLocation } from 'react-router-dom'

import ChangePasswordCard from '../../components/ui/ChangePasswordCard.jsx'
import { Card, InfoRow, ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { initials, prettyPhone } from '../../components/owner/ownerFormat.js'
import { useAuth } from '../../contexts/AuthContext.jsx'

/**
 * The owner's account. The login response carries name, email and mobile only
 * — there is no owner profile endpoint — so this shows those, and the
 * password change.
 */
export default function OwnerProfile() {
  const { user } = useAuth()
  const { hash } = useLocation()
  const passwordRef = useRef(null)

  useEffect(() => {
    if (hash === '#password') passwordRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }, [hash])

  return (
    <Box>
      <ScreenHeader title="My profile" back="/owner/more" />
      <Card sx={{ p: 2, mb: 2 }}>
        <Stack direction="row" spacing={2} alignItems="center">
          <Avatar sx={{ width: 60, height: 60, bgcolor: 'primary.dark', fontSize: 22, fontWeight: 700 }}>{initials(user?.name || user?.email)}</Avatar>
          <Box minWidth={0}>
            <Typography variant="h6" fontWeight={700} noWrap>{user?.name || 'Ground owner'}</Typography>
            <Typography variant="body2" color="text.secondary">Ground owner</Typography>
          </Box>
        </Stack>
      </Card>
      <Card sx={{ px: 2, py: 0.5 }}>
        <InfoRow label="Name" value={user?.name} />
        <InfoRow label="Mobile" value={user?.mobile ? prettyPhone(user.mobile) : '—'} />
        <InfoRow label="Email" value={user?.email} />
        <InfoRow label="Account status" value={user?.status ? user.status[0].toUpperCase() + user.status.slice(1) : '—'} />
        <InfoRow label="Member since" value={user?.created_at ? dayjs(user.created_at).format('D MMMM YYYY') : '—'} />
        <InfoRow label="Account ID" value={user?.id != null ? String(user.id) : '—'} last />
      </Card>
      <Typography variant="body2" color="text.secondary" mt={1.5}>
        Your name, mobile and email are managed by Playsher. Ask them if something is wrong.
      </Typography>
      <Box ref={passwordRef} mt={3} sx={{ scrollMarginTop: 16 }}>
        <ChangePasswordCard />
      </Box>
    </Box>
  )
}
