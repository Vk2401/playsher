import React from 'react'
import {
  Drawer, Box, Typography, IconButton, Divider,
  Button, CircularProgress,
} from '@mui/material'
import CloseIcon from '@mui/icons-material/Close'

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
  return (
    <Drawer
      anchor="right"
      open={open}
      onClose={onClose}
      PaperProps={{ sx: { width, maxWidth: '95vw' } }}
    >
      <Box display="flex" alignItems="center" justifyContent="space-between" px={3} py={2}>
        <Typography variant="h6">{title}</Typography>
        <IconButton onClick={onClose} size="small">
          <CloseIcon />
        </IconButton>
      </Box>
      <Divider />
      <Box flex={1} overflow="auto" px={3} py={2}>
        {children}
      </Box>
      <Divider />
      <Box px={3} py={2} display="flex" gap={1.5} justifyContent="flex-end">
        <Button variant="outlined" onClick={onClose} disabled={loading}>
          Cancel
        </Button>
        <Button
          variant="contained"
          onClick={onSubmit}
          disabled={loading}
          startIcon={loading ? <CircularProgress size={16} color="inherit" /> : null}
        >
          {submitLabel}
        </Button>
      </Box>
    </Drawer>
  )
}
