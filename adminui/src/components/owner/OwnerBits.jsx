import { Box, ButtonBase, Chip, IconButton, Stack, Typography } from '@mui/material'
import { useTheme } from '@mui/material/styles'
import { toneColors } from './ownerFormat.js'
import { useNavigate } from 'react-router-dom'
import ChevronRightIcon from '@mui/icons-material/ChevronRight'
import ArrowBackIosNewIcon from '@mui/icons-material/ArrowBackIosNew'

/**
 * Small building blocks for the ground-owner screens.
 *
 * The owner panel is used on a phone at the venue by people who are not
 * software users, so these favour big tap targets, plain words and one idea
 * per card. Every colour comes from the theme so the runtime colour switch
 * still works.
 */

function useTone() {
  const theme = useTheme()
  return (tone) => toneColors(theme, tone)
}

export function Pill({ tone = 'primary', label, icon }) {
  const tones = useTone()
  const [bg, fg] = tones(tone)
  return (
    <Chip
      size="small"
      icon={icon}
      label={label}
      sx={{ bgcolor: bg, color: fg, height: 24, '& .MuiChip-icon': { color: fg, fontSize: 15 } }}
    />
  )
}

/** A white card on the grey page. */
export function Card({ children, sx, ...rest }) {
  return (
    <Box
      sx={{
        bgcolor: 'background.paper',
        border: 1,
        borderColor: 'divider',
        borderRadius: 1,
        ...sx,
      }}
      {...rest}
    >
      {children}
    </Box>
  )
}

/** Page title for the owner screens, with an optional back arrow. */
export function ScreenHeader({ title, subtitle, back, right, children }) {
  const navigate = useNavigate()
  return (
    // The back arrow sits on the title's own line rather than beside the whole
    // block: with a subtitle under it, centring against both lines floated the
    // arrow into the gap between them and read as a rendering fault.
    <Box mb={2}>
      <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={1}>
        <Stack direction="row" alignItems="center" spacing={0.25} minWidth={0}>
          {back && (
            <IconButton
              onClick={() => (typeof back === 'string' ? navigate(back) : navigate(-1))}
              aria-label="Back"
              size="small"
              sx={{ ml: -0.5, mr: 0.25, flexShrink: 0 }}
            >
              <ArrowBackIosNewIcon sx={{ fontSize: 17 }} />
            </IconButton>
          )}
          {children ?? (
            <Typography
              variant="h6"
              fontWeight={700}
              noWrap
              sx={{ fontSize: { xs: 20, sm: 23 }, letterSpacing: '-0.01em', minWidth: 0 }}
            >
              {title}
            </Typography>
          )}
        </Stack>
        {right}
      </Stack>
      {subtitle && (
        <Typography
          variant="body2"
          color="text.secondary"
          sx={{ mt: 0.25, ml: back ? 3.5 : 0 }}
        >
          {subtitle}
        </Typography>
      )}
    </Box>
  )
}

export function SectionTitle({ children, action, onAction }) {
  return (
    <Stack direction="row" alignItems="center" justifyContent="space-between" mt={3} mb={1.25}>
      <Typography variant="subtitle1" fontWeight={700}>
        {children}
      </Typography>
      {action && (
        <ButtonBase onClick={onAction} sx={{ borderRadius: 1, px: 1, py: 0.5 }}>
          <Typography variant="body2" fontWeight={600} color="primary.dark">
            {action}
          </Typography>
        </ButtonBase>
      )}
    </Stack>
  )
}

/** Tappable row inside a Card: icon, label, optional value/badge, chevron. */
export function ListRow({ icon: Icon, label, hint, value, badge, onClick, tone, last, chevron = true }) {
  const tones = useTone()
  const [bg, fg] = tones(tone === 'error' ? 'error' : 'primary')
  return (
    <ButtonBase
      onClick={onClick}
      sx={{
        width: '100%',
        justifyContent: 'space-between',
        textAlign: 'left',
        px: 2,
        py: 1.5,
        gap: 1.5,
        borderBottom: last ? 0 : 1,
        borderColor: 'divider',
      }}
    >
      <Stack direction="row" alignItems="center" spacing={1.5} minWidth={0}>
        {Icon && (
          <Box
            sx={{
              width: 36, height: 36, borderRadius: 1, flexShrink: 0,
              display: 'grid', placeItems: 'center', bgcolor: bg, color: fg,
            }}
          >
            <Icon fontSize="small" />
          </Box>
        )}
        <Box minWidth={0}>
          <Typography fontWeight={500} color={tone === 'error' ? 'error.main' : 'text.primary'}>
            {label}
          </Typography>
          {hint && (
            <Typography variant="caption" color="text.secondary" display="block">
              {hint}
            </Typography>
          )}
        </Box>
      </Stack>
      <Stack direction="row" alignItems="center" spacing={1} flexShrink={0}>
        {value && (
          <Typography variant="body2" color="text.secondary">
            {value}
          </Typography>
        )}
        {badge ? <Pill tone="warning" label={badge} /> : null}
        {chevron && tone !== 'error' && <ChevronRightIcon sx={{ color: 'text.disabled' }} />}
      </Stack>
    </ButtonBase>
  )
}

/** Label on the left, value on the right. */
export function InfoRow({ label, value, strong, color, last, multiline }) {
  return (
    <Stack
      direction={multiline ? 'column' : 'row'}
      justifyContent="space-between"
      spacing={multiline ? 0.5 : 2}
      sx={{ py: 1.25, borderBottom: last ? 0 : 1, borderColor: 'divider' }}
    >
      <Typography variant="body2" color="text.secondary" flexShrink={0}>
        {label}
      </Typography>
      <Typography
        variant="body2"
        fontWeight={strong ? 700 : 500}
        color={color || 'text.primary'}
        textAlign={multiline ? 'left' : 'right'}
        sx={{ wordBreak: 'break-word', whiteSpace: multiline ? 'pre-line' : 'normal' }}
      >
        {value ?? '—'}
      </Typography>
    </Stack>
  )
}

/** A coloured note: under review, payouts on hold, and so on. */
export function Banner({ tone = 'warning', icon: Icon, children, onClick, action }) {
  const tones = useTone()
  const [bg, fg] = tones(tone)
  const Wrapper = onClick ? ButtonBase : Box
  return (
    <Wrapper
      onClick={onClick}
      sx={{
        width: '100%', display: 'flex', alignItems: 'center', gap: 1.5, textAlign: 'left',
        px: 2, py: 1.5, borderRadius: 1, bgcolor: bg, color: fg, mb: 1,
      }}
    >
      {Icon && <Icon fontSize="small" sx={{ flexShrink: 0 }} />}
      <Typography variant="body2" fontWeight={600} sx={{ flex: 1, color: 'inherit' }}>
        {children}
      </Typography>
      {action}
      {onClick && <ChevronRightIcon fontSize="small" />}
    </Wrapper>
  )
}

export function EmptyNote({ icon: Icon, title, text, action }) {
  const tones = useTone()
  const [bg, fg] = tones('primary')
  return (
    <Stack alignItems="center" textAlign="center" spacing={1} py={5} px={3}>
      {Icon && (
        <Box sx={{ width: 56, height: 56, borderRadius: '50%', display: 'grid', placeItems: 'center', bgcolor: bg, color: fg }}>
          <Icon />
        </Box>
      )}
      <Typography fontWeight={600}>{title}</Typography>
      {text && (
        <Typography variant="body2" color="text.secondary" maxWidth={320}>
          {text}
        </Typography>
      )}
      {action}
    </Stack>
  )
}

/** Horizontal chip filter with counts. */
export function FilterChips({ options, value, onChange }) {
  return (
    <Stack direction="row" spacing={1} sx={{ overflowX: 'auto', pb: 0.5, '&::-webkit-scrollbar': { display: 'none' } }}>
      {options.map((o) => (
        <Chip
          key={o.value}
          label={o.count != null ? `${o.label} ${o.count}` : o.label}
          onClick={() => onChange(o.value)}
          color={value === o.value ? 'primary' : 'default'}
          variant={value === o.value ? 'filled' : 'outlined'}
          sx={{ flexShrink: 0, fontWeight: 600, bgcolor: value === o.value ? undefined : 'background.paper' }}
        />
      ))}
    </Stack>
  )
}
