import React from 'react'
import {
  DialogTitle, DialogContent, DialogContentText,
  DialogActions, Button, CircularProgress, useMediaQuery, useTheme,
} from '@mui/material'
import WarningAmberIcon from '@mui/icons-material/WarningAmber'
import ResponsiveDialog from './ResponsiveDialog.jsx'

/**
 * The gate in front of every destructive action. Never `window.confirm`.
 *
 * Rises from the bottom on a phone, matching DrawerForm and the owner panel's
 * ConfirmSheet, and the confirm button is the one that sits under the thumb.
 * The cancel button is ordered last in the DOM but reversed visually, so the
 * destructive option is never the one a rushed tap lands on first.
 */
export default function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title = 'Confirm Action',
  message = 'Are you sure you want to proceed?',
  confirmLabel = 'Confirm',
  confirmColor = 'error',
  loading = false,
}) {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))

  return (
    <ResponsiveDialog open={open} onClose={onClose} maxWidth="xs">
      <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <WarningAmberIcon color="warning" />
        {title}
      </DialogTitle>

      <DialogContent>
        <DialogContentText>{message}</DialogContentText>
      </DialogContent>

      <DialogActions
        sx={{
          px: 3, pb: 2, gap: 1,
          flexDirection: { xs: 'column-reverse', md: 'row' },
          '& > :not(style) ~ :not(style)': { ml: { xs: 0, md: 1 } },
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
          color={confirmColor}
          onClick={onConfirm}
          disabled={loading}
          fullWidth={isMobile}
          sx={{ py: { xs: 1.25, md: 'auto' } }}
          startIcon={loading ? <CircularProgress size={16} color="inherit" /> : null}
        >
          {confirmLabel}
        </Button>
      </DialogActions>
    </ResponsiveDialog>
  )
}
