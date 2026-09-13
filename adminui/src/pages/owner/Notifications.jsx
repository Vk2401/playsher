import { Box, Button, ButtonBase, Skeleton, Stack, Typography } from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import dayjs from 'dayjs'
import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone'

import { Banner, Card, EmptyNote, Pill, ScreenHeader } from '../../components/owner/OwnerBits.jsx'
import { notificationsApi } from '../../api/notifications.js'
import { useNotify } from '../../hooks/useNotify.js'

/** The owner's inbox. The top bar's bell used to lead nowhere for owners. */
export default function OwnerNotifications() {
  const theme = useTheme()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const notify = useNotify()

  const q = useQuery({
    queryKey: ['notifications', 'list'],
    queryFn: () => notificationsApi.getAll({ limit: 50 }),
    select: (res) => res.data?.data ?? [],
  })
  const rows = q.data ?? []
  const unread = rows.filter((n) => !n.is_read).length

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['notifications'] })
  const markRead = useMutation({ mutationFn: (id) => notificationsApi.markRead(id), onSuccess: refresh })
  const markAll = useMutation({
    mutationFn: () => notificationsApi.markAllRead(),
    onSuccess: () => { refresh(); notify.success('All marked as read') },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not mark them as read'),
  })

  const open = (n) => {
    if (!n.is_read) markRead.mutate(n.id)
    if (n.action_path && n.action_path.startsWith('/owner')) navigate(n.action_path)
  }

  return (
    <Box>
      <ScreenHeader
        title="Notifications"
        back="/owner/more"
        right={unread > 0 && <Button onClick={() => markAll.mutate()} disabled={markAll.isPending}>Mark all read</Button>}
      />
      {q.isLoading && [0, 1, 2].map((i) => <Skeleton key={i} variant="rounded" height={72} sx={{ mb: 1 }} />)}
      {q.isError && <Banner tone="error">Could not load notifications.</Banner>}
      {q.isSuccess && rows.length === 0 && (
        <Card><EmptyNote icon={NotificationsNoneIcon} title="Nothing yet" text="Booking and account updates show up here." /></Card>
      )}
      {rows.length > 0 && (
        <Card sx={{ overflow: 'hidden' }}>
          {rows.map((n, i) => (
            <ButtonBase
              key={n.id}
              onClick={() => open(n)}
              sx={{
                width: '100%', textAlign: 'left', display: 'block', px: 2, py: 1.5,
                borderBottom: i === rows.length - 1 ? 0 : 1, borderColor: 'divider',
                bgcolor: n.is_read ? 'transparent' : alpha(theme.palette.primary.main, 0.05),
              }}
            >
              <Stack direction="row" spacing={1} alignItems="center">
                <Typography fontWeight={n.is_read ? 500 : 700}>{n.title}</Typography>
                {!n.is_read && <Pill label="New" />}
              </Stack>
              {n.message && <Typography variant="body2" color="text.secondary">{n.message}</Typography>}
              <Typography variant="caption" color="text.disabled">{dayjs(n.created_at).format('D MMM, h:mm A')}</Typography>
            </ButtonBase>
          ))}
        </Card>
      )}
    </Box>
  )
}
