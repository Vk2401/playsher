import { Avatar, Box, ButtonBase, Stack, Typography } from '@mui/material'
import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import AccountBalanceOutlinedIcon from '@mui/icons-material/AccountBalanceOutlined'
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined'
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined'
import SportsOutlinedIcon from '@mui/icons-material/SportsOutlined'
import EmojiEventsOutlinedIcon from '@mui/icons-material/EmojiEventsOutlined'
import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone'
import PersonOutlineIcon from '@mui/icons-material/PersonOutline'
import LockOutlinedIcon from '@mui/icons-material/LockOutlined'
import LogoutIcon from '@mui/icons-material/Logout'
import CheckIcon from '@mui/icons-material/Check'
import ChevronRightIcon from '@mui/icons-material/ChevronRight'

import InstallAppButton from '../../components/ui/InstallAppButton.jsx'
import { Card, ListRow, ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { initials, prettyPhone } from '../../components/owner/ownerFormat.js'
import { useAuth } from '../../contexts/AuthContext.jsx'
import { useThemeContext } from '../../contexts/ThemeContext.jsx'
import { PALETTE_SWATCHES } from '../../theme/index.js'
import { usePendingCoachRequests, useUnreadNotifications } from '../../hooks/useOwnerCounts.js'
import { bankDetailsApi } from '../../api/bankDetails.js'

function Group({ title, children }) {
  return (
    <Box mt={3}>
      <Typography variant="body2" fontWeight={600} color="text.secondary" px={0.5} mb={1}>{title}</Typography>
      <Card sx={{ overflow: 'hidden' }}>{children}</Card>
    </Box>
  )
}

/** Everything that is not a daily task, in one plain list. */
export default function OwnerMore() {
  const navigate = useNavigate()
  const { user, logout } = useAuth()
  const { primaryColor, setPrimaryColor } = useThemeContext()
  const pendingCoach = usePendingCoachRequests()
  const unread = useUnreadNotifications()

  const bankQ = useQuery({
    queryKey: ['owner', 'bank-details'],
    queryFn: () => bankDetailsApi.get(),
    select: (res) => res.data?.bank_details || res.data?.data || null,
  })

  const handleLogout = async () => {
    await logout()
    navigate('/login', { replace: true })
  }

  return (
    <Box>
      <ScreenHeader title="More" />

      <ButtonBase onClick={() => navigate('/owner/profile')} sx={{ width: '100%', borderRadius: 1, textAlign: 'left' }}>
        <Card sx={{ p: 2, width: '100%', display: 'flex', alignItems: 'center', gap: 2 }}>
          <Avatar sx={{ width: 52, height: 52, bgcolor: 'primary.dark', fontWeight: 700 }}>{initials(user?.name || user?.email)}</Avatar>
          <Box flex={1} minWidth={0}>
            <Typography fontWeight={700} noWrap>{user?.name || 'Ground owner'}</Typography>
            <Typography variant="body2" color="text.secondary" noWrap>{user?.mobile ? prettyPhone(user.mobile) : user?.email}</Typography>
          </Box>
          <ChevronRightIcon sx={{ color: 'text.disabled' }} />
        </Card>
      </ButtonBase>

      <Group title="Money">
        <ListRow
          icon={PaymentsOutlinedIcon}
          label="Earnings & payouts"
          onClick={() => navigate('/owner/settlements')}
        />
        <ListRow
          icon={AccountBalanceOutlinedIcon}
          label="Bank & UPI for payouts"
          value={bankQ.isSuccess ? (bankQ.data ? 'Added' : 'Not added') : undefined}
          badge={bankQ.isSuccess && !bankQ.data ? '!' : undefined}
          onClick={() => navigate('/owner/bank-details')}
          last
        />
      </Group>

      <Group title="Coaches & games">
        <ListRow icon={GroupsOutlinedIcon} label="Coach requests" badge={pendingCoach || undefined} onClick={() => navigate('/owner/coach-requests')} />
        <ListRow icon={SportsOutlinedIcon} label="Coach sessions" onClick={() => navigate('/owner/coach-sessions')} />
        <ListRow icon={EmojiEventsOutlinedIcon} label="Games at your grounds" onClick={() => navigate('/owner/games')} last />
      </Group>

      <Group title="Account">
        <ListRow icon={NotificationsNoneIcon} label="Notifications" badge={unread || undefined} onClick={() => navigate('/owner/notifications')} />
        <ListRow icon={PersonOutlineIcon} label="My profile" onClick={() => navigate('/owner/profile')} />
        <ListRow icon={LockOutlinedIcon} label="Change password" onClick={() => navigate('/owner/profile#password')} last />
      </Group>

      <Box mt={3}>
        <Typography variant="body2" fontWeight={600} color="text.secondary" px={0.5} mb={1}>App colour</Typography>
        <Card sx={{ p: 2 }}>
          <Stack direction="row" spacing={1.5} flexWrap="wrap" useFlexGap>
            {PALETTE_SWATCHES.map((s) => (
              <ButtonBase
                key={s.hex}
                onClick={() => setPrimaryColor(s.hex)}
                aria-label={s.name}
                sx={{ width: 40, height: 40, borderRadius: '50%', bgcolor: s.hex, color: 'common.white', outline: primaryColor === s.hex ? 3 : 0, outlineColor: 'text.primary', outlineOffset: 2 }}
              >
                {primaryColor === s.hex && <CheckIcon fontSize="small" />}
              </ButtonBase>
            ))}
          </Stack>
        </Card>
      </Box>

      <Box mt={3}><InstallAppButton /></Box>

      <Card sx={{ mt: 3, overflow: 'hidden' }}>
        <ListRow icon={LogoutIcon} label="Log out" tone="error" onClick={handleLogout} last />
      </Card>
    </Box>
  )
}
