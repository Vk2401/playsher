import { useQuery } from '@tanstack/react-query'
import { coachesApi } from '../api/coaches.js'
import { notificationsApi } from '../api/notifications.js'

/** How many coach requests are waiting on the owner. Shared by nav + Today. */
export function usePendingCoachRequests() {
  const q = useQuery({
    queryKey: ['owner', 'coach-requests', 'pending-count'],
    queryFn: () => coachesApi.getOwnerRequests({ status: 'pending', limit: 1 }),
    select: (res) => res.data?.pagination?.total ?? (res.data?.data?.length || 0),
    refetchInterval: 120_000,
  })
  return q.data ?? 0
}

/** Unread notifications for the signed-in account (same inbox for every role). */
export function useUnreadNotifications() {
  const q = useQuery({
    queryKey: ['notifications', 'unread-count'],
    queryFn: () => notificationsApi.unreadCount(),
    select: (res) => res.data?.data?.unread ?? 0,
    refetchInterval: 60_000,
  })
  return q.data ?? 0
}
