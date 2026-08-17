---
name: playsher-admin-panel
description: Patterns for the Playsher React admin + ground-owner panel in `adminui/` (React 18, Vite, MUI 6, TanStack Query 5, axios). Load before adding or changing a page, table, form, API method, route, or theme value — it carries the reference CRUD page, the query-key scheme, the auth/refresh flow, and the role split.
---

# Playsher admin panel — how this SPA is built

One Vite app, two audiences, one auth context. `/admin/*` (platform admin) and `/owner/*`
(ground owner) share `AppShell`, the primitives, and the axios client; they differ in routes,
sidebar entries, and which API paths they call.

Read `docs/admin-ui-guidelines.md` first — it is the rule set. This skill is the how-to.

## Anatomy

```
src/main.jsx → App.jsx        QueryClient → ThemeContext → MUI Theme → Snackbar → Auth → Router
src/router/index.jsx          all routes, ProtectedRoute, role redirects
src/contexts/                 AuthContext (tokens, role) · ThemeContext (primary color swatch)
src/api/client.js             the ONE axios instance: Bearer header + 401 refresh queue
src/api/<domain>.js           exported object of endpoint functions
src/components/layout/        AppShell · Sidebar · Topbar
src/components/ui/            PageHeader DataTable DrawerForm ConfirmDialog StatusChip StatCard EmptyState
src/pages/admin/*  owner/*    one file per screen
src/hooks/useNotify.js        snackbar wrapper — success/error/warning/info
src/theme/index.js            createAppTheme(primaryColor) + PALETTE_SWATCHES
```

`QueryClient` defaults: `retry: 1`, `refetchOnWindowFocus: false`, `staleTime: 30s`. Don't
override per-query unless the data genuinely differs (e.g. a live dashboard wants a shorter
`staleTime`); say why in a comment.

## The reference CRUD page

`src/pages/admin/Amenities.jsx`. Its shape is the template for every list-and-manage page:

1. `PageHeader` with `title`, `subtitle`, `breadcrumbs`, and an `actions` "Add X" button.
2. A filter `Stack` — search `TextField` with a `SearchIcon` adornment + `Select` filters.
   Filtering that the API doesn't support is done client-side in a `useMemo` over the query data.
3. `DataTable` with a `columns` array defined in the component (`renderCell` for chips,
   avatars, and an actions `Stack` of `Tooltip`-wrapped `IconButton`s).
4. A create `DrawerForm` and a separate edit `DrawerForm`, each with its own form state,
   errors, and preview state — reset on open **and** on close.
5. A `ConfirmDialog` driven by a `deleteTarget` object (`{ id, name }`), `null` when closed.

Keep that ordering and those state names; a reader who knows one page then knows all of them.

## Data access

```js
const { data, isLoading, error } = useQuery({
  queryKey: ['admin', 'amenities'],
  queryFn:  () => amenitiesApi.getAll(),
  select:   (res) => res.data?.data ?? [],      // unwrap the API envelope here
})

const createMutation = useMutation({
  mutationFn: (fd) => amenitiesApi.create(fd),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['admin', 'amenities'] })
    notify.success('Amenity created successfully')
    handleCloseDrawer()
  },
  onError: (err) => notify.error(err?.response?.data?.message || 'Failed to create amenity'),
})
```

- **Query keys start with the role scope**: `['admin', …]` or `['owner', …]`, then the domain,
  then the id. The same concept fetched by both roles hits different endpoints and must not
  share a cache entry.
- The envelope is inconsistent across older endpoints; unwrap defensively in `select`
  (`res.data?.amenities || res.data?.data || res.data || []`) rather than in the JSX.
- `isPending` (v5 name, not `isLoading`) drives every submit button's disabled/spinner state.

## API layer

Every call is a method on the domain object in `src/api/<domain>.js`:

```js
export const amenitiesApi = {
  getAll:  (params) => apiClient.get('/admin/amenities', { params }),
  create:  (data)   => apiClient.post('/admin/amenities', data,
                        { headers: { 'Content-Type': 'multipart/form-data' } }),
  delete:  (id)     => apiClient.delete(`/admin/amenities/${id}`),
}
```

- Admin paths are `/admin/...`; owner paths are `/ground-owner/...`; a few are shared
  (`/grounds/:id/sports`). Group and comment them by role inside the object, as `grounds.js` does.
- Multipart headers belong here, not in the page. The page builds the `FormData`.
- Never inline a URL in a page. Never create a second axios instance.

## Auth

- `AuthContext` exposes `loginAdmin`, `loginOwner`, `logout`, `user`, `isAdmin`, `isOwner`,
  `isAuthenticated`. It tolerates both response shapes (`data.data ?? data`, user under
  `user` or `owner`) and falls back to decoding the JWT for `{ id, role }`.
- Storage keys are `playsher_access_token` / `playsher_refresh_token` / `playsher_user` — the
  same names the interceptor uses. Don't introduce a fourth key.
- `client.js` owns the 401 flow: single-flight refresh with a queue of waiting requests, retry
  of the original, and on failure — clear storage and hard-redirect to `/login`. Never
  duplicate this logic in a page or a context.

## Routing

- Add the page import, the `<Route>` under the correct role's `AppShell` branch, **and** the
  sidebar entry. A route without a sidebar entry is unreachable in practice.
- `ProtectedRoute requiredRole="admin" | "ground_owner"` wraps every authenticated branch;
  wrong-role users are redirected to their own dashboard, not to `/login`.

## Theme

`createAppTheme(primaryColor)` is rebuilt whenever the user picks a swatch, so **anything
derived from the brand color must be derived inside it** via `alpha()` / the local `darken()`.
A page that hard-codes the sage green stops responding to the swatch picker. Global component
looks (button gradient, paper border, table head, chip weight) go in the `components` overrides.

## Checklist

- `npm run lint` clean (max-warnings 0) and `npm run build` succeeds.
- New endpoint added to `src/api/<domain>.js`, not inlined.
- Query key role-scoped; mutation invalidates it; both toasts wired.
- Route + sidebar entry + `requiredRole` all present.
- No hard-coded brand hex, no `alert`/`window.confirm`.
