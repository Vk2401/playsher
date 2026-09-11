import dayjs from 'dayjs'
import { alpha } from '@mui/material/styles'

// ── Formatting helpers shared by the ground-owner screens ────────────────────
// Everything here reads the API's snake_case rows as they arrive; nothing is
// renamed on the way in, so a field can be grepped across all three codebases.

export const rupee = (n) =>
  `₹${Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`

export const ymd = (d) => dayjs(d).format('YYYY-MM-DD')
export const todayYmd = () => ymd(dayjs())

/** "18:30:00" → minutes after midnight. */
export const toMinutes = (t) => {
  if (!t) return null
  const [h, m] = String(t).split(':').map(Number)
  return h * 60 + (m || 0)
}

/** "18:30:00" → "6:30 PM" */
export const clock = (t) => {
  const m = toMinutes(t)
  if (m == null) return '—'
  return dayjs().startOf('day').add(m, 'minute').format('h:mm A')
}

/** "18:00:00" → "6 PM", "18:30:00" → "6:30 PM" */
export const clockShort = (t) => {
  const m = toMinutes(t)
  if (m == null) return '—'
  return dayjs().startOf('day').add(m, 'minute').format(m % 60 ? 'h:mm A' : 'h A')
}

export const durationLabel = (from, to) => {
  const a = toMinutes(from)
  const b = toMinutes(to)
  if (a == null || b == null) return ''
  const mins = (b > a ? b : b + 24 * 60) - a
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (!h) return `${m} min`
  return m ? `${h} hr ${m} min` : `${h} hr`
}

export const dayLabel = (date) => {
  const diff = dayjs(date).startOf('day').diff(dayjs().startOf('day'), 'day')
  if (diff === 0) return 'Today'
  if (diff === 1) return 'Tomorrow'
  if (diff === -1) return 'Yesterday'
  return dayjs(date).format('ddd, D MMM')
}

/** Unwrap a list from the envelope, whatever shape an endpoint uses. */
export const unwrapList = (res) => {
  const d = res?.data?.data
  if (Array.isArray(d)) return d
  return d?.rows ?? d?.data ?? d?.items ?? []
}

// ── Bookings ─────────────────────────────────────────────────────────────────

export const bookingInfo = (b) => ({
  customer: b?.user?.name || 'Customer',
  mobile: b?.user?.mobile || '',
  email: b?.user?.email || '',
  sport: b?.groundSport?.sport?.name || 'Sport',
  ground: b?.groundSport?.ground?.name || '',
})

/**
 * What the owner has been paid and still has to collect.
 * advance_amount is what the customer pays in the app (the whole amount for an
 * online booking, the advance for pay-at-ground); balance_due is the cash the
 * venue takes in person. A pending booking has not paid anything yet.
 */
export const bookingMoney = (b) => {
  const total = Number(b?.total_amount || 0)
  const advance = Number(b?.advance_amount ?? total)
  const paidOnline = b?.status === 'pending' ? 0 : advance
  const balance = b?.status === 'cancelled'
    ? 0
    : Number(b?.balance_due ?? Math.max(total - advance, 0))
  return { total, paidOnline, balance }
}

export const bookingStart = (b) =>
  dayjs(`${ymd(b.slot_date)}T${String(b.slot_time_from || '00:00').slice(0, 5)}`)
export const bookingEnd = (b) =>
  dayjs(`${ymd(b.slot_date)}T${String(b.slot_time_to || '23:59').slice(0, 5)}`)

export const isUpcoming = (b) =>
  (b.status === 'confirmed' || b.status === 'pending') && bookingEnd(b).isAfter(dayjs())

export const BOOKING_STATUS = {
  pending: { label: 'Awaiting payment', tone: 'warning' },
  confirmed: { label: 'Confirmed', tone: 'primary' },
  completed: { label: 'Completed', tone: 'neutral' },
  cancelled: { label: 'Cancelled', tone: 'error' },
}

export const PAYOUT_STATUS = {
  transferred: { label: 'Sent to your bank', tone: 'primary' },
  pending: { label: 'Sent after the game', tone: 'neutral' },
  no_bank_details: { label: 'On hold: add bank details', tone: 'error' },
  no_vendor: { label: 'Not set up yet', tone: 'neutral' },
}

export const CANCEL_REASONS = [
  'Ground not available',
  'Rain or bad weather',
  'Maintenance work',
  'Customer asked to cancel',
]

// ── Contact links ────────────────────────────────────────────────────────────

export const phoneDigits = (m) => String(m || '').replace(/\D/g, '').slice(-10)
export const telHref = (m) => `tel:+91${phoneDigits(m)}`
export const whatsappHref = (m) => `https://wa.me/91${phoneDigits(m)}`
export const prettyPhone = (m) => {
  const d = phoneDigits(m)
  return d.length === 10 ? `+91 ${d.slice(0, 5)} ${d.slice(5)}` : m || '—'
}

export const initials = (name) =>
  String(name || '?')
    .split(' ')
    .filter(Boolean)
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase()

/** tone → [background, foreground], always from the live theme palette. */
export const toneColors = (theme, tone = 'primary') => {
  const p = theme.palette
  switch (tone) {
    case 'warning': return [alpha(p.warning.main, 0.14), p.warning.dark]
    case 'error': return [alpha(p.error.main, 0.1), p.error.main]
    case 'neutral': return [alpha(p.text.primary, 0.06), p.text.secondary]
    default: return [alpha(p.primary.main, 0.14), p.primary.dark]
  }
}

/** A count of 30-minute slots as the owner says it: 3 → "1½ hr". */
export const lengthLabel = (slots) => {
  const mins = Number(slots || 0) * 30
  const h = Math.floor(mins / 60)
  const m = mins % 60
  if (!h) return `${m} min`
  return m ? `${h}½ hr` : `${h} hr`
}
