/**
 * Every panel's navigation, in one place.
 *
 * The rail (desktop), the bottom bar (phone) and the More screen are all
 * rendered from this file — there is no second list to keep in step, which is
 * what let the old Sidebar drift from the routes it pointed at.
 *
 * To hide a page from navigation, set `hidden: true` on its item. The route
 * still exists and a direct link still works; it simply stops being advertised.
 * Nothing is deleted, so hiding is reversible and costs one line.
 *
 * Shape:
 *   tabs    the 3–4 destinations that earn a bottom-bar slot, plus More
 *   groups  everything else, gathered into titled sections on the More screen
 */

import DashboardOutlinedIcon from '@mui/icons-material/DashboardOutlined'
import EventNoteOutlinedIcon from '@mui/icons-material/EventNoteOutlined'
import StadiumOutlinedIcon from '@mui/icons-material/StadiumOutlined'
import MenuIcon from '@mui/icons-material/Menu'
import PeopleOutlineIcon from '@mui/icons-material/PeopleOutline'
import BusinessOutlinedIcon from '@mui/icons-material/BusinessOutlined'
import SportsSoccerOutlinedIcon from '@mui/icons-material/SportsSoccerOutlined'
import FitnessCenterOutlinedIcon from '@mui/icons-material/FitnessCenterOutlined'
import PaymentOutlinedIcon from '@mui/icons-material/PaymentOutlined'
import AccountBalanceWalletOutlinedIcon from '@mui/icons-material/AccountBalanceWalletOutlined'
import SportsOutlinedIcon from '@mui/icons-material/SportsOutlined'
import DirectionsRunOutlinedIcon from '@mui/icons-material/DirectionsRunOutlined'
import SportsHandballOutlinedIcon from '@mui/icons-material/SportsHandballOutlined'
import StarOutlineIcon from '@mui/icons-material/StarOutline'
import SystemUpdateOutlinedIcon from '@mui/icons-material/SystemUpdateAltOutlined'
import ShieldOutlinedIcon from '@mui/icons-material/ShieldOutlined'
import StorageOutlinedIcon from '@mui/icons-material/StorageOutlined'
import PersonOutlineIcon from '@mui/icons-material/PersonOutline'
import NotificationsNoneIcon from '@mui/icons-material/NotificationsNone'
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined'

/** Admin — 17 pages, four of which earn a tab. The rest group under More. */
const admin = {
  role: 'admin',
  title: 'Playsher',
  subtitle: 'Admin',
  home: '/admin/dashboard',
  tabs: [
    { label: 'Dashboard', path: '/admin/dashboard', icon: DashboardOutlinedIcon },
    { label: 'Bookings', path: '/admin/bookings', icon: EventNoteOutlinedIcon },
    { label: 'Grounds', path: '/admin/grounds', icon: StadiumOutlinedIcon },
    { label: 'More', path: '/admin/more', icon: MenuIcon, isMore: true },
  ],
  groups: [
    {
      title: 'People',
      items: [
        { label: 'Users', path: '/admin/users', icon: PeopleOutlineIcon, caption: 'Customers on the platform' },
        { label: 'Ground Owners', path: '/admin/ground-owners', icon: BusinessOutlinedIcon, caption: 'Venue partners and approvals' },
        { label: 'Coaches', path: '/admin/coaches', icon: DirectionsRunOutlinedIcon, caption: 'Coach accounts and approvals' },
      ],
    },
    {
      title: 'Catalogue',
      items: [
        { label: 'Sports', path: '/admin/sports', icon: SportsSoccerOutlinedIcon, caption: 'What can be played' },
        { label: 'Amenities', path: '/admin/amenities', icon: FitnessCenterOutlinedIcon, caption: 'What a venue can offer' },
      ],
    },
    {
      title: 'Money',
      items: [
        { label: 'Payments', path: '/admin/payments', icon: PaymentOutlinedIcon, caption: 'Every transaction' },
        { label: 'Settlements', path: '/admin/settlements', icon: AccountBalanceWalletOutlinedIcon, caption: 'What is owed to owners' },
      ],
    },
    {
      title: 'Activity',
      items: [
        { label: 'Games', path: '/admin/games', icon: SportsOutlinedIcon, caption: 'Open games and participants' },
        { label: 'Coach Sessions', path: '/admin/coach-sessions', icon: SportsHandballOutlinedIcon, caption: 'Training booked with coaches' },
        { label: 'Reviews', path: '/admin/reviews', icon: StarOutlineIcon, caption: 'Moderate what customers wrote' },
      ],
    },
    {
      title: 'System',
      items: [
        { label: 'App Versions', path: '/admin/app-versions', icon: SystemUpdateOutlinedIcon, caption: 'Force-update the mobile app' },
        { label: 'Admins', path: '/admin/admins', icon: ShieldOutlinedIcon, caption: 'Who can administer', superAdminOnly: true },
        { label: 'Database Schema', path: '/admin/database-schema', icon: StorageOutlinedIcon, caption: 'Apply schema changes' },
      ],
    },
    {
      title: 'Account',
      items: [
        { label: 'Profile', path: '/admin/profile', icon: PersonOutlineIcon, caption: 'Your details and password' },
      ],
    },
  ],
}

/** Coach — a small panel, so three real tabs and a short More. */
const coach = {
  role: 'coach',
  title: 'Playsher',
  subtitle: 'Coach',
  home: '/coach/dashboard',
  tabs: [
    { label: 'Today', path: '/coach/dashboard', icon: DashboardOutlinedIcon },
    { label: 'Sessions', path: '/coach/bookings', icon: EventNoteOutlinedIcon },
    { label: 'Availability', path: '/coach/availability', icon: EventAvailableOutlinedIcon },
    { label: 'More', path: '/coach/more', icon: MenuIcon, isMore: true },
  ],
  groups: [
    {
      title: 'Where you coach',
      items: [
        { label: 'Grounds', path: '/coach/grounds', icon: StadiumOutlinedIcon, caption: 'Venues you are approved at' },
      ],
    },
    {
      title: 'Account',
      items: [
        { label: 'Notifications', path: '/coach/notifications', icon: NotificationsNoneIcon, caption: 'What happened while you were away' },
        { label: 'Profile', path: '/coach/profile', icon: PersonOutlineIcon, caption: 'Your rate, sport and details' },
      ],
    },
  ],
}

export const PANELS = { admin, coach }

// The pure reads live in navSelectors.js (no icon imports, so they can be
// exercised on their own). Re-exported here so callers have one import.
export { visibleTabs, visibleGroups, moreChildPaths, activeTabIndex } from './navSelectors.js'
