import { createContext, useContext, useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { groundsApi } from '../api/grounds.js'
import { unwrapList } from '../components/owner/ownerFormat.js'

/**
 * Which of the owner's grounds the panel is looking at.
 *
 * Most owners have one ground; some have two or three. Every owner screen —
 * Today, Bookings, My Ground — works on one ground at a time, and the switcher
 * in the header changes it everywhere at once.
 */
const OwnerGroundContext = createContext(null)

export function OwnerGroundProvider({ children }) {
  const [selectedId, setSelectedId] = useState(null)

  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'grounds'],
    queryFn: () => groundsApi.getOwnerGrounds({ limit: 100 }),
    select: unwrapList,
  })

  const value = useMemo(() => {
    const grounds = Array.isArray(data) ? data : []
    const ground = grounds.find((g) => g.id === selectedId) ?? grounds[0] ?? null
    return {
      grounds,
      ground,
      groundId: ground?.id ?? null,
      setGroundId: setSelectedId,
      isLoading,
      error,
    }
  }, [data, selectedId, isLoading, error])

  return <OwnerGroundContext.Provider value={value}>{children}</OwnerGroundContext.Provider>
}

export function useOwnerGround() {
  const ctx = useContext(OwnerGroundContext)
  if (!ctx) throw new Error('useOwnerGround must be used within OwnerGroundProvider')
  return ctx
}
