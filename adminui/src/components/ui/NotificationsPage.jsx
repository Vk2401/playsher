import React from 'react'
import {
  Alert, Box, Button, Chip, CircularProgress, List, ListItemButton,
  ListItemText, Paper, Stack, Typography,
} from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import dayjs from 'dayjs'

import DoneAllIcon from '@mui/icons-material/DoneAll'
import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone'

import PageHeader from './PageHeader.jsx'
import EmptyState from './EmptyState.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { notificationsApi } from '../../api/notifications.js'

/**
 * The notifications inbox, for any panel.
 *
 * `notificationsApi` always reads the recipient from the token — there is no
 * role to pass (CLAUDE.md §9) — so the only thing that differs between panels
 * is the sentence under the title. One screen rather than one per role.
 *
 * Rows navigate by `action_path`, which is a client route the server writes
 * (e.g. `/owner/bookings/12`), not a URL.
 */
export default function NotificationsPage({
  subtitle = 'Everything that happened while you were away',
  emptyMessage = 'Nothing yet.',
}) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const notify = useNotify()

  const { data, isLoading, error } = useQuery({
    queryKey: ['notifications', 'list'],
    queryFn: () => notificationsApi.getAll({ limit: 50 }),
    select: (res) => res.data?.data ?? [],
  })

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['notifications'] })
  }

  const markRead = useMutation({
    mutationFn: (id) => notificationsApi.markRead(id),
    onSuccess: invalidate,
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not mark that as read.'),
  })

  const markAll = useMutation({
    mutationFn: () => notificationsApi.markAllRead(),
    onSuccess: () => { invalidate(); notify.success('All notifications marked as read.') },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not mark them as read.'),
  })

  const rows = data ?? []
  const unread = rows.filter((n) => !n.is_read).length

  const open = (row) => {
    if (!row.is_read) markRead.mutate(row.id)
    if (row.action_path) navigate(row.action_path)
  }

  return (
    <Box>
      <PageHeader
        title="Notifications"
        subtitle={subtitle}
        actions={
          <Button
            variant="outlined"
            startIcon={<DoneAllIcon />}
            onClick={() => markAll.mutate()}
            disabled={markAll.isPending || unread === 0}
          >
            Mark all read
          </Button>
        }
      />

      {error && <Alert severity="error" sx={{ mb: 2 }}>Could not load your notifications.</Alert>}

      <Paper>
        {isLoading && (
          <Box display="flex" justifyContent="center" py={6}><CircularProgress size={26} /></Box>
        )}
        {!isLoading && rows.length === 0 && (
          <EmptyState message={emptyMessage} icon={NotificationsNoneIcon} />
        )}
        <List disablePadding>
          {rows.map((row) => (
            <ListItemButton
              key={row.id}
              onClick={() => open(row)}
              sx={{
                alignItems: 'flex-start',
                borderBottom: '1px solid rgba(0,0,0,0.05)',
                background: row.is_read ? 'transparent' : 'rgba(0,0,0,0.02)',
              }}
            >
              <ListItemText
                primary={
                  <Stack direction="row" spacing={1} alignItems="center">
                    <Typography variant="body2" fontWeight={row.is_read ? 500 : 700}>
                      {row.title}
                    </Typography>
                    {/* Unread is marked with a word as well as a tint — the tint
                        alone is not enough to read as "new". */}
                    {!row.is_read && <Chip label="New" color="primary" size="small" />}
                  </Stack>
                }
                secondary={
                  <>
                    <Typography variant="body2" color="text.secondary" component="span" display="block">
                      {row.message}
                    </Typography>
                    <Typography variant="caption" color="text.disabled">
                      {dayjs(row.created_at).format('DD MMM YYYY, HH:mm')}
                    </Typography>
                  </>
                }
              />
            </ListItemButton>
          ))}
        </List>
      </Paper>
    </Box>
  )
}
