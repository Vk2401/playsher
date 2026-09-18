import { useQuery } from '@tanstack/react-query'
import { notificationsApi } from '../api/notifications.js'

/**
 * Unread count for the signed-in account's inbox.
 *
 * The endpoint always reads the recipient from the token, so there is no role
 * to pass — see CLAUDE.md §9. Polls once a minute because push is not wired
 * (phase 2); without that the badge only moves on a reload.
 *
 * Returns 0 while loading or on failure: a badge that appears late is better
 * than one that appears wrong.
 */
export function useUnreadNotifications() {
  const unread = useQuery({
    queryKey: ['notifications', 'unread-count'],
    queryFn: () => notificationsApi.unreadCount(),
    select: (res) => res.data?.data?.unread ?? 0,
    refetchInterval: 60_000,
  })

  return unread.data ?? 0
}
