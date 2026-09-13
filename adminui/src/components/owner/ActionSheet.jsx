import { Box, Drawer, IconButton, Stack, Typography, useMediaQuery } from '@mui/material'
import { useTheme } from '@mui/material/styles'
import CloseIcon from '@mui/icons-material/Close'

/**
 * The owner panel's one pop-up: a sheet that rises from the bottom on a phone
 * and slides in from the right on a laptop. Details, confirmations and forms
 * all use it, so every "open something" looks and closes the same way.
 */
export default function ActionSheet({ open, onClose, title, subtitle, children, actions }) {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))

  return (
    <Drawer
      anchor={isMobile ? 'bottom' : 'right'}
      open={open}
      onClose={onClose}
      PaperProps={{
        sx: {
          bgcolor: 'background.default',
          width: isMobile ? '100%' : 440,
          maxHeight: isMobile ? '92vh' : '100%',
          borderTopLeftRadius: isMobile ? theme.shape.borderRadius * 1.5 : 0,
          borderTopRightRadius: isMobile ? theme.shape.borderRadius * 1.5 : 0,
          display: 'flex',
          flexDirection: 'column',
        },
      }}
    >
      {isMobile && (
        <Box sx={{ display: 'flex', justifyContent: 'center', pt: 1.25 }}>
          <Box sx={{ width: 40, height: 5, borderRadius: 1, bgcolor: 'divider' }} />
        </Box>
      )}
      <Stack direction="row" alignItems="flex-start" justifyContent="space-between" sx={{ px: 2.5, pt: 1.5, pb: 1 }}>
        <Box>
          <Typography variant="h6" fontWeight={700}>
            {title}
          </Typography>
          {subtitle && (
            <Typography variant="body2" color="text.secondary">
              {subtitle}
            </Typography>
          )}
        </Box>
        <IconButton onClick={onClose} aria-label="Close" size="small" sx={{ bgcolor: 'action.hover', mt: 0.25 }}>
          <CloseIcon fontSize="small" />
        </IconButton>
      </Stack>
      <Box sx={{ px: 2.5, pb: actions ? 1 : 3, overflowY: 'auto', flex: 1 }}>{children}</Box>
      {actions && (
        <Stack spacing={1} sx={{ px: 2.5, pt: 1.5, pb: 'calc(16px + env(safe-area-inset-bottom))', borderTop: 1, borderColor: 'divider' }}>
          {actions}
        </Stack>
      )}
    </Drawer>
  )
}
