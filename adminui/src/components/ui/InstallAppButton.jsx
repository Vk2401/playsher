import { useState } from 'react'
import {
  Button,
  Dialog,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  Tooltip,
  Typography,
} from '@mui/material'
import InstallMobileIcon from '@mui/icons-material/InstallMobile'
import IosShareIcon from '@mui/icons-material/IosShare'
import AddBoxOutlinedIcon from '@mui/icons-material/AddBoxOutlined'
import { useInstallPrompt } from '@/pwa/useInstallPrompt'

/**
 * "Install app" affordance.
 *
 * Renders nothing when the app is already installed, or when the browser has
 * not offered installation. On iOS — which has no `beforeinstallprompt` — it
 * opens the manual Share-sheet instructions instead, because otherwise iPhone
 * users have no way to discover that the panel is installable at all.
 *
 * @param {'button'|'icon'} variant  compact icon for the Topbar, full button
 *                                   for the login screen.
 */
export default function InstallAppButton({ variant = 'button' }) {
  const { canInstall, needsIosInstructions, installed, install } = useInstallPrompt()
  const [iosOpen, setIosOpen] = useState(false)

  if (installed) return null
  if (!canInstall && !needsIosInstructions) return null

  const handleClick = () => {
    if (canInstall) {
      install()
      return
    }
    setIosOpen(true)
  }

  return (
    <>
      {variant === 'icon' ? (
        <Tooltip title="Install Playsher Admin">
          <IconButton
            onClick={handleClick}
            size="small"
            sx={{ color: 'text.secondary' }}
            aria-label="Install Playsher Admin"
          >
            <InstallMobileIcon fontSize="small" />
          </IconButton>
        </Tooltip>
      ) : (
        <Button
          onClick={handleClick}
          variant="outlined"
          size="small"
          startIcon={<InstallMobileIcon />}
        >
          Install app
        </Button>
      )}

      <Dialog open={iosOpen} onClose={() => setIosOpen(false)} maxWidth="xs" fullWidth>
        <DialogTitle>Install on iPhone or iPad</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Safari installs web apps from the Share menu rather than a prompt.
          </Typography>
          <Stack spacing={1.5}>
            <Stack direction="row" spacing={1.5} alignItems="center">
              <IosShareIcon color="primary" />
              <Typography variant="body2">
                Tap <strong>Share</strong> in the Safari toolbar.
              </Typography>
            </Stack>
            <Stack direction="row" spacing={1.5} alignItems="center">
              <AddBoxOutlinedIcon color="primary" />
              <Typography variant="body2">
                Choose <strong>Add to Home Screen</strong>, then{' '}
                <strong>Add</strong>.
              </Typography>
            </Stack>
          </Stack>
        </DialogContent>
      </Dialog>
    </>
  )
}
