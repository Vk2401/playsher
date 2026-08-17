import React from 'react'
import { Card, CardContent, Box, Typography, Skeleton, alpha } from '@mui/material'
import { useTheme } from '@mui/material/styles'
import TrendingUpIcon from '@mui/icons-material/TrendingUp'
import TrendingDownIcon from '@mui/icons-material/TrendingDown'

export default function StatCard({ title, value, icon: Icon, trend, trendLabel, loading, color }) {
  const theme = useTheme()
  const primary = color || theme.palette.primary.main
  const isPositive = trend >= 0

  if (loading) {
    return (
      <Card sx={{ height: 130 }}>
        <CardContent>
          <Skeleton variant="text" width="60%" />
          <Skeleton variant="text" width="40%" height={40} />
          <Skeleton variant="text" width="50%" />
        </CardContent>
      </Card>
    )
  }

  return (
    <Card
      sx={{
        height: 130,
        position: 'relative',
        overflow: 'hidden',
        background: `rgba(255,255,255,0.88)`,
        '&::before': {
          content: '""',
          position: 'absolute',
          top: 0, left: 0,
          width: 4, height: '100%',
          background: primary,
          borderRadius: '14px 0 0 14px',
        },
      }}
    >
      <CardContent sx={{ pb: '12px !important' }}>
        <Box display="flex" justifyContent="space-between" alignItems="flex-start">
          <Box>
            <Typography variant="caption" color="text.secondary" fontWeight={600}
              sx={{ textTransform: 'uppercase', letterSpacing: '0.05em' }}>
              {title}
            </Typography>
            <Typography variant="h4" fontWeight={700} color="text.primary" sx={{ mt: 0.5 }}>
              {value ?? '—'}
            </Typography>
          </Box>
          {Icon && (
            <Box sx={{
              width: 48, height: 48,
              borderRadius: 3,
              background: alpha(primary, 0.12),
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Icon sx={{ color: primary, fontSize: 24 }} />
            </Box>
          )}
        </Box>
        {trend !== undefined && (
          <Box display="flex" alignItems="center" gap={0.5} mt={1}>
            {isPositive
              ? <TrendingUpIcon sx={{ fontSize: 16, color: 'success.main' }} />
              : <TrendingDownIcon sx={{ fontSize: 16, color: 'error.main' }} />
            }
            <Typography variant="caption" color={isPositive ? 'success.main' : 'error.main'} fontWeight={600}>
              {isPositive ? '+' : ''}{trend}%
            </Typography>
            {trendLabel && (
              <Typography variant="caption" color="text.secondary"> {trendLabel}</Typography>
            )}
          </Box>
        )}
      </CardContent>
    </Card>
  )
}
