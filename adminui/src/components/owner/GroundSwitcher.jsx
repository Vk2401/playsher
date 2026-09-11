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
      <Box mb={2}>
        {greeting && (
          <Typography variant="body2" color="text.secondary" fontWeight={500}>
            {greeting}
          </Typography>
        )}
        <ButtonBase onClick={() => setOpen(true)} sx={{ borderRadius: 1, textAlign: 'left', gap: 0.5 }}>
          <Typography variant="h5" fontWeight={800}>
            {ground?.name ?? 'Your ground'}
          </Typography>
          <KeyboardArrowDownIcon sx={{ color: 'text.secondary' }} />
        </ButtonBase>
        {place && (
          <Typography variant="body2" color="text.secondary">
            {place}
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
