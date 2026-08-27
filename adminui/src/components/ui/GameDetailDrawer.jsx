import React from 'react'
import {
  Avatar,
  Box,
  Button,
  Chip,
  CircularProgress,
  Divider,
  Drawer,
  IconButton,
  List,
  ListItem,
  ListItemAvatar,
  ListItemText,
  Stack,
  Typography,
  alpha,
} from '@mui/material'
import { useTheme } from '@mui/material/styles'
import dayjs from 'dayjs'

import CloseIcon from '@mui/icons-material/Close'
import EventIcon from '@mui/icons-material/Event'
import PlaceIcon from '@mui/icons-material/Place'
import SportsIcon from '@mui/icons-material/Sports'
import CurrencyRupeeIcon from '@mui/icons-material/CurrencyRupee'
import LockIcon from '@mui/icons-material/Lock'
import PublicIcon from '@mui/icons-material/Public'

import EmptyState from './EmptyState.jsx'
import SeatMeter from './SeatMeter.jsx'
import StatusChip from './StatusChip.jsx'

const LEVEL_LABELS = {
  newbie: 'Newbie',
  beginner: 'Beginner',
  intermediate: 'Intermediate',
  advanced: 'Advanced',
  professional: 'Professional',
  ultra_professional: 'Ultra pro',
}

const clock = (time) => {
  if (!time) return null
  const parsed = dayjs(`2000-01-01T${time}`)
  return parsed.isValid() ? parsed.format('h:mm A') : String(time).slice(0, 5)
}

const initials = (name) =>
  String(name || '?')
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('') || '?'

/**
 * Everything about one open game, read-only.
 *
 * A game is not editable from a panel — the host owns its name, seats and
 * level, and the venue and money live on the booking underneath it. What a
 * platform admin or a ground owner needs is the answer to "who is turning up,
 * when, and is this game still on", so the drawer is a record with one
 * destructive action passed in by the page rather than a form.
 *
 * `DrawerForm` is deliberately not reused: it always renders a submit button,
 * and a Save on a read-only record is a promise the drawer cannot keep.
 */
export default function GameDetailDrawer({
  open,
  onClose,
  game,
  loading = false,
  /** Optional footer action — the admin page passes "Cancel game" here. */
  action = null,
  width = 460,
}) {
  const theme = useTheme()

  const level = game?.game_level ? LEVEL_LABELS[game.game_level] ?? game.game_level : null
  const from = clock(game?.slot_time_from)
  const to = clock(game?.slot_time_to)
  const date = game?.slot_date ? dayjs(game.slot_date) : null

  const participants = Array.isArray(game?.participants) ? game.participants : []
  const seated = participants.filter(
    (p) => p.status === 'joined' || p.status === 'accepted',
  )
  const invited = participants.filter((p) => p.status === 'invited')

  return (
    <Drawer
      anchor="right"
      open={open}
      onClose={onClose}
      PaperProps={{ sx: { width, maxWidth: '95vw' } }}
    >
      <Box
        display="flex"
        alignItems="flex-start"
        justifyContent="space-between"
        gap={1}
        px={3}
        py={2}
      >
        <Box minWidth={0}>
          <Typography variant="h6" noWrap>
            {game?.game_name || 'Game'}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            #{game?.id ?? '—'} · hosted by {game?.host_name || 'a player'}
          </Typography>
        </Box>
        <IconButton onClick={onClose} size="small">
          <CloseIcon />
        </IconButton>
      </Box>
      <Divider />

      <Box flex={1} overflow="auto" px={3} py={2}>
        {loading ? (
          <Box display="flex" justifyContent="center" py={6}>
            <CircularProgress size={28} />
          </Box>
        ) : !game ? (
          <EmptyState message="This game could not be loaded" />
        ) : (
          <Stack spacing={2.5}>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
              <StatusChip status={game.status || 'open'} />
              {game.sport_name && (
                <Chip
                  size="small"
                  icon={<SportsIcon />}
                  label={game.sport_name}
                  sx={{ fontWeight: 600 }}
                />
              )}
              {level && <Chip size="small" label={level} variant="outlined" />}
              <Chip
                size="small"
                variant="outlined"
                icon={game.visibility === 'private' ? <LockIcon /> : <PublicIcon />}
                label={game.visibility === 'private' ? 'Invite only' : 'Public'}
              />
            </Stack>

            <Box
              p={2}
              borderRadius={2}
              sx={{ background: alpha(theme.palette.primary.main, 0.05) }}
            >
              <Stack spacing={1.5}>
                <Row
                  icon={<EventIcon fontSize="small" />}
                  label="When"
                  value={
                    date?.isValid()
                      ? `${date.format('ddd, DD MMM YYYY')}${from ? ` · ${from}` : ''}${to ? ` – ${to}` : ''}`
                      : '—'
                  }
                />
                <Row
                  icon={<PlaceIcon fontSize="small" />}
                  label="Venue"
                  value={
                    [game.ground_name, game.ground_area, game.ground_city]
                      .filter(Boolean)
                      .join(', ') || '—'
                  }
                />
                <Row
                  icon={<CurrencyRupeeIcon fontSize="small" />}
                  label="Per player"
                  value={
                    game.price_per_player > 0
                      ? `₹${Number(game.price_per_player).toLocaleString('en-IN')} · booking total ₹${Number(game.total_amount || 0).toLocaleString('en-IN')}`
                      : 'Price on request — the booking carries no total'
                  }
                />
              </Stack>
            </Box>

            <Box>
              <Typography variant="subtitle2" gutterBottom>
                Seats
              </Typography>
              <SeatMeter
                joined={game.joined_count}
                capacity={game.max_participants}
                spotsLeft={game.spots_left}
              />
            </Box>

            {game.description && (
              <Box>
                <Typography variant="subtitle2" gutterBottom>
                  From the host
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {game.description}
                </Typography>
              </Box>
            )}

            <Box>
              <Typography variant="subtitle2">
                Players ({seated.length})
              </Typography>
              {seated.length === 0 ? (
                <Typography variant="body2" color="text.secondary" mt={1}>
                  Nobody has taken a seat yet.
                </Typography>
              ) : (
                <PlayerList players={seated} />
              )}
            </Box>

            {invited.length > 0 && (
              <Box>
                <Typography variant="subtitle2">
                  Invited, not yet in ({invited.length})
                </Typography>
                <PlayerList players={invited} />
              </Box>
            )}
          </Stack>
        )}
      </Box>

      {action && (
        <>
          <Divider />
          <Box px={3} py={2} display="flex" gap={1.5} justifyContent="flex-end">
            <Button variant="outlined" onClick={onClose}>
              Close
            </Button>
            {action}
          </Box>
        </>
      )}
    </Drawer>
  )
}

function Row({ icon, label, value }) {
  return (
    <Box display="flex" gap={1.5} alignItems="flex-start">
      <Box color="text.secondary" mt={0.25}>
        {icon}
      </Box>
      <Box minWidth={0}>
        <Typography variant="caption" color="text.secondary" display="block">
          {label}
        </Typography>
        <Typography variant="body2" fontWeight={500}>
          {value}
        </Typography>
      </Box>
    </Box>
  )
}

function PlayerList({ players }) {
  return (
    <List dense disablePadding>
      {players.map((p) => (
        <ListItem key={p.id ?? `${p.user_id}`} disableGutters>
          <ListItemAvatar sx={{ minWidth: 44 }}>
            <Avatar
              src={p.user?.profile_picture || undefined}
              sx={{ width: 32, height: 32, fontSize: 13 }}
            >
              {initials(p.user?.name)}
            </Avatar>
          </ListItemAvatar>
          <ListItemText
            primary={p.user?.name || `User #${p.user_id}`}
            secondary={p.is_host ? 'Host' : undefined}
            primaryTypographyProps={{ variant: 'body2', fontWeight: 500 }}
            secondaryTypographyProps={{ variant: 'caption' }}
          />
          <StatusChip status={p.status || 'joined'} />
        </ListItem>
      ))}
    </List>
  )
}
