import React from 'react'
import { Box, Typography, Breadcrumbs, Link } from '@mui/material'
import { Link as RouterLink } from 'react-router-dom'
import NavigateNextIcon from '@mui/icons-material/NavigateNext'

/**
 * The title block every page opens with.
 *
 * Breadcrumbs are hidden on a phone: the bottom bar already says where you are,
 * and a wrapping "Admin › Grounds › Green Valley Cricket Ground" cost two lines
 * above the fold to repeat it.
 *
 * Actions sit beside the title on a laptop and go full-width underneath it on a
 * phone, where a right-aligned "Add ground" button ends up in the corner
 * furthest from a thumb.
 */
export default function PageHeader({ title, subtitle, actions, breadcrumbs }) {
  return (
    <Box mb={{ xs: 2.5, md: 3 }}>
      {breadcrumbs && (
        <Breadcrumbs
          separator={<NavigateNextIcon fontSize="small" />}
          sx={{ mb: 0.5, display: { xs: 'none', md: 'flex' } }}
        >
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

      <Box
        sx={{
          display: 'flex',
          flexDirection: { xs: 'column', md: 'row' },
          justifyContent: 'space-between',
          alignItems: { xs: 'stretch', md: 'center' },
          gap: { xs: 1.5, md: 2 },
        }}
      >
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="h5" fontWeight={800} sx={{ letterSpacing: '-0.015em' }}>
            {title}
          </Typography>
          {subtitle && (
            <Typography variant="body2" color="text.secondary" mt={0.25}>
              {subtitle}
            </Typography>
          )}
        </Box>

        {actions && (
          <Box
            sx={{
              display: 'flex',
              gap: 1,
              flexShrink: 0,
              // Stretch to full width on a phone so a lone action reads as the
              // page's primary button rather than a stray chip.
              '& > *': { flex: { xs: 1, md: '0 0 auto' } },
            }}
          >
            {actions}
          </Box>
        )}
      </Box>
    </Box>
  )
}
