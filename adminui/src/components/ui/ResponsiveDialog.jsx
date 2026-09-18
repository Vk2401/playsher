import React from 'react'
import { Box, Dialog, useMediaQuery, useTheme } from '@mui/material'

/**
 * A Dialog that becomes a bottom sheet on a phone.
 *
 * A centred MUI dialog on a 390px screen is a box floating in a dimmed field
 * with its actions somewhere near the middle. Rising from the bottom edge puts
 * them under the thumb and matches DrawerForm, so every modal surface in the
 * panel behaves the same way.
 *
 * Takes everything Dialog takes. `maxWidth` and `fullWidth` still apply on a
 * laptop and are ignored on a phone, where the sheet is always full width.
 */
export default function ResponsiveDialog({ children, PaperProps = {}, sx, ...props }) {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))

  const mobilePaper = {
    position: 'fixed', bottom: 0, left: 0, right: 0, m: 0,
    width: '100%', maxWidth: '100%', maxHeight: '92vh',
    borderRadius: '20px 20px 0 0',
    pb: 'env(safe-area-inset-bottom)',
  }

  return (
    <Dialog
      fullWidth
      {...props}
      PaperProps={{
        ...PaperProps,
        sx: { ...(isMobile ? mobilePaper : { borderRadius: 3 }), ...PaperProps.sx },
      }}
      sx={sx}
    >
      {/* Tells a thumb the sheet is dismissable, the same handle DrawerForm uses. */}
      {isMobile && (
        <Box sx={{ display: 'flex', justifyContent: 'center', pt: 1.25, pb: 0.25, flexShrink: 0 }}>
          <Box sx={{ width: 40, height: 4, borderRadius: 2, bgcolor: 'divider' }} />
        </Box>
      )}
      {children}
    </Dialog>
  )
}
