import { useState } from 'react'
import { Box, Skeleton, Stack, Switch, Tab, Tabs, Typography } from '@mui/material'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined'

import GroundSwitcher from '../../components/owner/GroundSwitcher.jsx'
import SlotsTab from '../../components/owner/ground/SlotsTab.jsx'
import SportsTab from '../../components/owner/ground/SportsTab.jsx'
import DetailsTab from '../../components/owner/ground/DetailsTab.jsx'
import { Banner, Card } from '../../components/owner/OwnerBits.jsx'
import { useOwnerGround } from '../../contexts/OwnerGroundContext.jsx'
import { groundsApi } from '../../api/grounds.js'
import { useNotify } from '../../hooks/useNotify.js'

/**
 * My Ground — everything about the ground in one place, in three tabs:
 * Slots (what is free, booked or closed), Sports & price, and Details.
 * Replaces the old grounds table and the five-tab ground page.
 */
export default function OwnerMyGround() {
  const { groundId } = useOwnerGround()
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [tab, setTab] = useState(0)
  const [addSport, setAddSport] = useState(false)

  const groundQ = useQuery({
    queryKey: ['owner', 'ground', groundId],
    queryFn: () => groundsApi.getOwnerGround(groundId),
    select: (res) => res.data?.data ?? null,
    enabled: Boolean(groundId),
  })
  const ground = groundQ.data

  const openToggle = useMutation({
    mutationFn: (next) => {
      const fd = new FormData()
      fd.append('is_active', next ? 'true' : 'false')
      return groundsApi.update(groundId, fd)
    },
    onSuccess: (_r, next) => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', groundId] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'grounds'] })
      notify.success(next ? 'Ground is open for booking' : 'Ground closed for booking')
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not change that'),
  })

  return (
    <Box>
      <GroundSwitcher />

      {!groundId || groundQ.isLoading ? (
        <Stack spacing={1.5}>
          <Skeleton variant="rounded" height={72} />
          <Skeleton variant="rounded" height={44} />
          <Skeleton variant="rounded" height={240} />
        </Stack>
      ) : groundQ.isError || !ground ? (
        <Banner tone="error">Could not load this ground. Check your internet and try again.</Banner>
      ) : (
        <>
          {!ground.is_approved && (
            <Banner tone="warning" icon={InfoOutlinedIcon}>
              Playsher is reviewing this ground. It shows in the app once approved.
            </Banner>
          )}

          <Card sx={{ px: 2, py: 1.5 }}>
            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Box>
                <Typography fontWeight={600}>{ground.is_active ? 'Open for booking' : 'Closed for booking'}</Typography>
                <Typography variant="body2" color="text.secondary">
                  {ground.is_active ? 'Customers can book in the app' : 'Customers cannot make new bookings'}
                </Typography>
              </Box>
              <Switch
                checked={Boolean(ground.is_active)}
                disabled={openToggle.isPending}
                onChange={(e) => openToggle.mutate(e.target.checked)}
                inputProps={{ 'aria-label': 'Open for booking' }}
              />
            </Stack>
          </Card>

          <Tabs
            value={tab}
            onChange={(_e, v) => setTab(v)}
            variant="fullWidth"
            sx={{
              mt: 2, minHeight: 44, bgcolor: 'action.hover', borderRadius: 1, p: 0.5,
              '& .MuiTabs-indicator': { height: '100%', borderRadius: 1, bgcolor: 'background.paper', zIndex: 0, boxShadow: 1 },
              '& .MuiTab-root': { zIndex: 1, minHeight: 36, fontWeight: 600, textTransform: 'none' },
            }}
          >
            <Tab label="Slots" />
            <Tab label="Sports & price" />
            <Tab label="Details" />
          </Tabs>

          {tab === 0 && <SlotsTab groundId={groundId} onAddSport={() => { setTab(1); setAddSport(true) }} />}
          {tab === 1 && <SportsTab ground={ground} openAdd={addSport} setOpenAdd={setAddSport} />}
          {tab === 2 && <DetailsTab ground={ground} />}
        </>
      )}
    </Box>
  )
}
