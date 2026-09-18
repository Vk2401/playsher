/**
 * Self-check for the navigation rules. No framework: run it directly.
 *
 *   node src/config/navSelectors.test.js
 *
 * Covers the three things that are easy to get wrong and silent when wrong:
 * hiding a page, the `/` boundary when one path prefixes another, and keeping
 * the More tab lit for a page opened from it.
 */
import assert from 'node:assert/strict'
import { visibleTabs, visibleGroups, moreChildPaths, activeTabIndex, hasInbox } from './navSelectors.js'

const panel = {
  tabs: [
    { label: 'Dashboard', path: '/admin/dashboard' },
    { label: 'Bookings', path: '/admin/bookings' },
    { label: 'Grounds', path: '/admin/grounds' },
    { label: 'More', path: '/admin/more', isMore: true },
  ],
  groups: [
    {
      title: 'People',
      items: [
        { label: 'Users', path: '/admin/users' },
        { label: 'Ground Owners', path: '/admin/ground-owners' },
      ],
    },
    {
      title: 'System',
      items: [
        { label: 'Admins', path: '/admin/admins', superAdminOnly: true },
        { label: 'Database Schema', path: '/admin/database-schema' },
      ],
    },
  ],
}

// ── tabs ──────────────────────────────────────────────────────────────────
assert.equal(visibleTabs(panel).length, 4)
{
  const withHidden = { ...panel, tabs: panel.tabs.map((t) => (t.label === 'Grounds' ? { ...t, hidden: true } : t)) }
  const labels = visibleTabs(withHidden).map((t) => t.label)
  assert.deepEqual(labels, ['Dashboard', 'Bookings', 'More'])
}

// ── groups ────────────────────────────────────────────────────────────────
{
  // A plain admin never sees the super-admin-only entry.
  const groups = visibleGroups(panel)
  assert.deepEqual(groups.map((g) => g.title), ['People', 'System'])
  assert.deepEqual(groups[1].items.map((i) => i.label), ['Database Schema'])

  // A super-admin does.
  const asSuper = visibleGroups(panel, { isSuperAdmin: true })
  assert.deepEqual(asSuper[1].items.map((i) => i.label), ['Admins', 'Database Schema'])
}
{
  // Hiding every item in a group drops the group, not just its rows — an empty
  // titled section on the More screen looks like a loading bug.
  const hidden = {
    ...panel,
    groups: panel.groups.map((g) =>
      g.title === 'People' ? { ...g, items: g.items.map((i) => ({ ...i, hidden: true })) } : g),
  }
  assert.deepEqual(visibleGroups(hidden).map((g) => g.title), ['System'])
}

// ── active tab ────────────────────────────────────────────────────────────
assert.equal(activeTabIndex(panel, '/admin/dashboard'), 0)
assert.equal(activeTabIndex(panel, '/admin/bookings'), 1)
assert.equal(activeTabIndex(panel, '/admin/grounds'), 2)

// A detail route keeps its parent tab lit.
assert.equal(activeTabIndex(panel, '/admin/grounds/12'), 2)

// The regression this boundary check exists for: /admin/ground-owners must NOT
// light the /admin/grounds tab just because one is a prefix of the other.
assert.equal(activeTabIndex(panel, '/admin/ground-owners'), 3)

// Anything opened from More keeps More lit.
assert.equal(activeTabIndex(panel, '/admin/more'), 3)
assert.equal(activeTabIndex(panel, '/admin/users'), 3)
assert.equal(activeTabIndex(panel, '/admin/database-schema'), 3)

// A hidden page is still reachable by direct link, and still lights More.
{
  const hidden = {
    ...panel,
    groups: panel.groups.map((g) =>
      g.title === 'People' ? { ...g, items: g.items.map((i) => ({ ...i, hidden: true })) } : g),
  }
  assert.equal(activeTabIndex(hidden, '/admin/users'), 3)
}

// An unknown path falls back to the first tab rather than lighting nothing.
assert.equal(activeTabIndex(panel, '/admin/nonsense'), 0)

// ── misc ──────────────────────────────────────────────────────────────────
assert.equal(moreChildPaths(panel).length, 4)

// ── inbox ─────────────────────────────────────────────────────────────────
// This panel has no notifications page, so nothing should badge the More tab.
assert.equal(hasInbox(panel), false)
{
  const withInbox = {
    ...panel,
    groups: [...panel.groups, { title: 'Account', items: [{ label: 'Notifications', path: '/coach/notifications' }] }],
  }
  assert.equal(hasInbox(withInbox), true)

  // Hiding the page hides the badge with it — otherwise the dot points nowhere.
  const hiddenInbox = {
    ...withInbox,
    groups: withInbox.groups.map((g) =>
      g.title === 'Account' ? { ...g, items: g.items.map((i) => ({ ...i, hidden: true })) } : g),
  }
  assert.equal(hasInbox(hiddenInbox), false)
}

console.log('navSelectors: all checks passed')
