import React from 'react'
import { Box, Typography, Button } from '@mui/material'
import { useNavigate } from 'react-router-dom'
import SentimentDissatisfiedIcon from '@mui/icons-material/SentimentDissatisfied'

export default function NotFound() {
  const navigate = useNavigate()
  return (
    <Box
      sx={{
        minHeight: '100vh', display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', gap: 2,
      }}
    >
      <SentimentDissatisfiedIcon sx={{ fontSize: 72, color: 'text.disabled' }} />
      <Typography variant="h4" fontWeight={700}>404 — Not Found</Typography>
      <Typography variant="body1" color="text.secondary">
        The page you are looking for does not exist.
      </Typography>
      <Button variant="contained" onClick={() => navigate(-1)}>Go Back</Button>
    </Box>
  )
}
