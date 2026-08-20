import { useEffect, useState } from 'react'
import { Alert, AlertTitle, Button, Snackbar } from '@mui/material'
import {
  applyUpdate,
  dismissOfflineReady,
  dismissUpdate,
  onPwaState,
} from '@/pwa/registerSW'

/**
 * Tells the user when a new build is waiting, and when the app is first ready
 * to run offline.
 *
 * Without this an installed SPA can sit on a cached build indefinitely: the new
 * service worker installs but never activates while a tab stays open, so an
 * admin keeps using yesterday's bundle against today's API.
 */
export default function PwaUpdatePrompt() {
  const [{ needRefresh, offlineReady }, setState] = useState({
    needRefresh: false,
    offlineReady: false,
  })

  useEffect(() => onPwaState(setState), [])

  return (
    <>
      <Snackbar
        open={needRefresh}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          severity="info"
          variant="filled"
          sx={{ alignItems: 'center' }}
          action={
            <>
              <Button color="inherit" size="small" onClick={applyUpdate}>
                Reload
              </Button>
              <Button color="inherit" size="small" onClick={dismissUpdate}>
                Later
              </Button>
            </>
          }
        >
          <AlertTitle sx={{ mb: 0 }}>A new version is available</AlertTitle>
          Reload when you have finished what you are working on.
        </Alert>
      </Snackbar>

      <Snackbar
        open={offlineReady}
        autoHideDuration={4000}
        onClose={dismissOfflineReady}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert severity="success" variant="filled" onClose={dismissOfflineReady}>
          Playsher Admin is installed and ready to open offline.
        </Alert>
      </Snackbar>
    </>
  )
}
