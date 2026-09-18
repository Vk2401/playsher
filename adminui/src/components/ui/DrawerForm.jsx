import React from 'react'
import {
  Drawer, Box, Typography, IconButton, Divider,
  Button, CircularProgress, useMediaQuery, useTheme,
} from '@mui/material'
import CloseIcon from '@mui/icons-material/Close'

/**
 * The create/edit surface for every admin form.
 *
 * On a laptop it is a right-hand drawer, as before. On a phone a 440px drawer
 * became a 95vw slab anchored to the right edge with its actions off at the
 * bottom of a tall scroll — so below `md` it is a bottom sheet instead, the
 * shape the owner panel uses (see components/owner/GroundFormSheet).
 *
 * The actions stay pinned outside the scrolling body in both shapes. A form
 * whose Save button scrolls away is a form people abandon half-filled.
 */
export default function DrawerForm({
  open,
  onClose,
  title,
  children,
  onSubmit,
  loading = false,
  submitLabel = 'Save',
  width = 440,
}) {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))

  return (
    <Drawer
      anchor={isMobile ? 'bottom' : 'right'}
      open={open}
      onClose={onClose}
      PaperProps={{
        sx: isMobile
          ? {
              width: '100%',
              maxHeight: '92vh',
              borderTopLeftRadius: 20,
              borderTopRightRadius: 20,
              display: 'flex',
              flexDirection: 'column',
            }
          : { width, maxWidth: '95vw', display: 'flex', flexDirection: 'column' },
      }}
    >
      {/* The grab handle is what tells a thumb this sheet can be dismissed. */}
      {isMobile && (
        <Box sx={{ display: 'flex', justifyContent: 'center', pt: 1.25, pb: 0.5 }}>
          <Box sx={{ width: 40, height: 4, borderRadius: 2, bgcolor: 'divider' }} />
        </Box>
      )}

      <Box
        display="flex"
        alignItems="center"
        justifyContent="space-between"
        px={3}
        py={isMobile ? 1.5 : 2}
      >
        <Typography variant="h6" noWrap>{title}</Typography>
        <IconButton onClick={onClose} size="small" aria-label="Close">
          <CloseIcon />
        </IconButton>
      </Box>
      <Divider />

      <Box flex={1} overflow="auto" px={3} py={2}>
        {children}
      </Box>

      <Divider />
      <Box
        sx={{
          px: 3, py: 2, display: 'flex', gap: 1.5,
          justifyContent: 'flex-end',
          // Full-width stacked buttons on a phone: a 90px button in the corner
          // of a sheet is a hard target, and Save is the whole point of being here.
          flexDirection: { xs: 'column-reverse', md: 'row' },
          pb: { xs: 'calc(16px + env(safe-area-inset-bottom))', md: 2 },
        }}
      >
        <Button
          variant="outlined"
          onClick={onClose}
          disabled={loading}
          fullWidth={isMobile}
          sx={{ py: { xs: 1.25, md: 'auto' } }}
        >
          Cancel
        </Button>
        <Button
          variant="contained"
          onClick={onSubmit}
          disabled={loading}
          fullWidth={isMobile}
          sx={{ py: { xs: 1.25, md: 'auto' } }}
          startIcon={loading ? <CircularProgress size={16} color="inherit" /> : null}
        >
          {submitLabel}
        </Button>
      </Box>
    </Drawer>
  )
}
