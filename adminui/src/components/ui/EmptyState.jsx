import React from 'react'
import { Box, Typography } from '@mui/material'
import InboxIcon from '@mui/icons-material/Inbox'

export default function EmptyState({ message = 'No data available', icon: Icon = InboxIcon, hint, action }) {
  return (
    <Box
      display="flex"
      flexDirection="column"
      alignItems="center"
      justifyContent="center"
      py={6}
      gap={1}
    >
      <Icon sx={{ fontSize: 44, color: 'text.disabled' }} />
      <Typography variant="body2" color="text.secondary" textAlign="center">{message}</Typography>
      {hint && (
        <Typography variant="caption" color="text.disabled" textAlign="center" sx={{ maxWidth: 320 }}>
          {hint}
        </Typography>
      )}
      {action && <Box mt={1}>{action}</Box>}
    </Box>
  )
}
