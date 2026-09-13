import { useState } from 'react'
import { Box, Button, ButtonBase, Stack, Typography } from '@mui/material'
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown'
import CheckIcon from '@mui/icons-material/Check'
import AddIcon from '@mui/icons-material/Add'
import StadiumOutlinedIcon from '@mui/icons-material/StadiumOutlined'

import ActionSheet from './ActionSheet.jsx'
import GroundFormSheet from './GroundFormSheet.jsx'
import { Card, Pill } from './OwnerBits.jsx'
import { useOwnerGround } from '../../contexts/OwnerGroundContext.jsx'

/**
 * The ground name at the top of a screen. Tap it to pick another ground or
 * add a new one. With a single ground it still opens, so "add a ground" is
 * always one tap away.
 */
export default function GroundSwitcher({ greeting }) {
  const { grounds, ground, setGroundId } = useOwnerGround()
  const [open, setOpen] = useState(false)
  const [adding, setAdding] = useState(false)

  const place = [ground?.area, ground?.city].filter(Boolean).join(', ')

  return (
    <>
      {/* Two lines, never more. A venue called "Green Valley Cricket Ground"
          wrapped an h5 onto three lines and pushed the actual screen below the
          fold, with the chevron stranded beside the second line. The name is
          the heading; the greeting and the city are one quiet line under it. */}
      <Box mb={2} sx={{ flex: 1, minWidth: 0 }}>
        <ButtonBase
          onClick={() => setOpen(true)}
          sx={{
            maxWidth: '100%', borderRadius: 1, textAlign: 'left', gap: 0.25,
            px: 0.5, ml: -0.5, py: 0.25,
          }}
        >
          <Typography
            variant="h6"
            fontWeight={700}
            noWrap
            sx={{ fontSize: { xs: 20, sm: 23 }, letterSpacing: '-0.01em', minWidth: 0 }}
          >
            {ground?.name ?? 'Your ground'}
          </Typography>
          <KeyboardArrowDownIcon sx={{ color: 'text.disabled', fontSize: 20, flexShrink: 0 }} />
        </ButtonBase>
        {(greeting || place) && (
          <Typography variant="body2" color="text.secondary" noWrap>
            {[greeting, place].filter(Boolean).join(' · ')}
          </Typography>
        )}
      </Box>

      <ActionSheet open={open} onClose={() => setOpen(false)} title="Your grounds">
        <Card sx={{ overflow: 'hidden' }}>
          {grounds.map((g, i) => (
            <ButtonBase
              key={g.id}
              onClick={() => { setGroundId(g.id); setOpen(false) }}
              sx={{
                width: '100%', justifyContent: 'space-between', px: 2, py: 1.5, gap: 1.5, textAlign: 'left',
                borderBottom: i === grounds.length - 1 ? 0 : 1, borderColor: 'divider',
              }}
            >
              <Stack direction="row" spacing={1.5} alignItems="center" minWidth={0}>
                <StadiumOutlinedIcon color="primary" />
                <Box minWidth={0}>
                  <Typography fontWeight={600} noWrap>{g.name}</Typography>
                  <Typography variant="body2" color="text.secondary" noWrap>
                    {[g.area, g.city].filter(Boolean).join(', ') || 'No address yet'}
                  </Typography>
                </Box>
              </Stack>
              <Stack direction="row" spacing={1} alignItems="center" flexShrink={0}>
                {!g.is_approved && <Pill tone="warning" label="In review" />}
                {g.id === ground?.id && <CheckIcon color="primary" />}
              </Stack>
            </ButtonBase>
          ))}
        </Card>
        <Button fullWidth startIcon={<AddIcon />} variant="outlined" size="large" sx={{ mt: 1.5, borderStyle: 'dashed' }} onClick={() => { setOpen(false); setAdding(true) }}>
          Add a new ground
        </Button>
      </ActionSheet>

      <GroundFormSheet open={adding} onClose={() => setAdding(false)} onCreated={(id) => id && setGroundId(id)} />
    </>
  )
}
