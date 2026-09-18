import React from 'react'
import NotificationsPage from '../../components/ui/NotificationsPage.jsx'

/**
 * The admin inbox. It existed server-side all along — `notifications` is
 * polymorphic on recipient_type and `admin` is one of the four — but the panel
 * had no page for it, so the old top bar's bell pointed at the dashboard.
 */
export default function AdminNotifications() {
  return (
    <NotificationsPage
      subtitle="Platform events that need an administrator"
      emptyMessage="Nothing yet — platform events that need you will appear here."
    />
  )
}
