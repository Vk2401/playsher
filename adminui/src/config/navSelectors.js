/**
 * Pure reads over a panel's navigation config.
 *
 * Kept apart from `navigation.jsx` because that file imports two dozen icon
 * components: this one imports nothing, so the rules below can be exercised
 * without pulling MUI into the process. `navigation.jsx` re-exports these, and
 * callers import from there.
 */

/** Tabs that are actually shown, in order. `hidden` items drop out here. */
export const visibleTabs = (panel) => panel.tabs.filter((t) => !t.hidden)

/**
 * More-screen groups with hidden items removed, empty groups dropped, and
 * super-admin-only items filtered out for anyone who is not one.
 */
export function visibleGroups(panel, { isSuperAdmin = false } = {}) {
  return panel.groups
    .map((g) => ({
      ...g,
      items: g.items.filter((i) => !i.hidden && (!i.superAdminOnly || isSuperAdmin)),
    }))
    .filter((g) => g.items.length > 0)
}

/**
 * Every path reachable from More. Hidden items stay in this list on purpose:
 * their route still works, so a direct link should still light the More tab
 * rather than falling through and lighting the first one.
 */
export const moreChildPaths = (panel) =>
  panel.groups.flatMap((g) => g.items.map((i) => i.path))

/**
 * Which tab a pathname belongs to. A page opened from More keeps More lit, and
 * a detail route (/admin/grounds/12) keeps its parent tab lit.
 *
 * Matching on a `/` boundary rather than a bare prefix: without it
 * `/admin/ground-owners` would light the `/admin/grounds` tab.
 */
export function activeTabIndex(panel, pathname) {
  const tabs = visibleTabs(panel)

  const direct = tabs.findIndex(
    (t) => !t.isMore && (pathname === t.path || pathname.startsWith(`${t.path}/`)),
  )
  if (direct >= 0) return direct

  const moreIndex = tabs.findIndex((t) => t.isMore)
  if (moreIndex < 0) return 0

  const onMore =
    pathname === tabs[moreIndex].path ||
    moreChildPaths(panel).some((p) => pathname === p || pathname.startsWith(`${p}/`))

  return onMore ? moreIndex : 0
}
