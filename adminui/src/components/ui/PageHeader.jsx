import React from 'react'
import { Box, Typography, Breadcrumbs, Link } from '@mui/material'
import { Link as RouterLink } from 'react-router-dom'
import NavigateNextIcon from '@mui/icons-material/NavigateNext'

export default function PageHeader({ title, subtitle, actions, breadcrumbs }) {
  return (
    <Box mb={3}>
      {breadcrumbs && (
        <Breadcrumbs separator={<NavigateNextIcon fontSize="small" />} sx={{ mb: 0.5 }}>
          {breadcrumbs.map((crumb, i) =>
            crumb.href
              ? <Link key={i} component={RouterLink} to={crumb.href} underline="hover"
                  color="text.secondary" variant="caption" fontWeight={500}>
                  {crumb.label}
                </Link>
              : <Typography key={i} variant="caption" color="text.primary" fontWeight={500}>
                  {crumb.label}
                </Typography>
          )}
        </Breadcrumbs>
      )}
      <Box display="flex" justifyContent="space-between" alignItems="center" flexWrap="wrap" gap={2}>
        <Box>
          <Typography variant="h5">{title}</Typography>
          {subtitle && (
            <Typography variant="body2" color="text.secondary" mt={0.25}>{subtitle}</Typography>
          )}
        </Box>
        {actions && <Box display="flex" gap={1}>{actions}</Box>}
      </Box>
    </Box>
  )
}
