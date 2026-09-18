import { useQuery } from '@tanstack/react-query'
import { adminsApi } from '../api/admins.js'
import { useAuth } from '../contexts/AuthContext.jsx'

/**
 * Whether the signed-in admin holds the `super_admin` tier.
 *
 * The tier is read from the row on each request rather than from the token, so
 * a demotion takes effect at once — see CLAUDE.md §1. Shares the Admins page's
 * query key, so the panel asks once no matter how many places need the answer.
 *
 * Returns false for every non-admin role, and while the query is in flight, so
 * a caller never briefly offers a link that would answer 403.
 */
export function useIsSuperAdmin() {
  const { isAdmin } = useAuth()

  const me = useQuery({
    queryKey: ['admin', 'admins', 'me'],
    queryFn: () => adminsApi.me(),
    select: (res) => res.data?.data ?? null,
    enabled: isAdmin,
  })

  return me.data?.is_super_admin === true
}
