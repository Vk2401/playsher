import { useEffect, useState } from 'react'
import { Box, Typography } from '@mui/material'
import CloudOffIcon from '@mui/icons-material/CloudOff'
import { alpha } from '@mui/material/styles'

/**
 * Persistent bar shown while the browser reports no connection.
 *
 * The app shell loads from cache when offline, so without this the panel looks
 * fully functional right up until a save fails with a network error. Naming the
 * cause up front is the difference between "the app is broken" and "I am
 * offline".
 */
export default function OfflineBanner() {
  const [offline, setOffline] = useState(!navigator.onLine)

  useEffect(() => {
    const goOffline = () => setOffline(true)
    const goOnline = () => setOffline(false)
    window.addEventListener('offline', goOffline)
    window.addEventListener('online', goOnline)
    return () => {
      window.removeEventListener('offline', goOffline)
      window.removeEventListener('online', goOnline)
    }
  }, [])

  if (!offline) return null

  return (
    <Box
      role="status"
      aria-live="polite"
      sx={(theme) => ({
        position: 'sticky',
        top: 0,
        zIndex: theme.zIndex.appBar + 1,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 1,
        px: 2,
        py: 0.75,
        bgcolor: alpha(theme.palette.warning.main, 0.15),
        borderBottom: `1px solid ${alpha(theme.palette.warning.main, 0.4)}`,
        color: theme.palette.warning.dark,
      })}
    >
      <CloudOffIcon fontSize="small" />
      <Typography variant="body2" fontWeight={600}>
        You are offline — changes cannot be saved until the connection returns.
      </Typography>
    </Box>
  )
}
