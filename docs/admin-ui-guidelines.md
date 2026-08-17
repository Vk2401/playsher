# Admin & Owner panel UI guidelines — `adminui/`

**Read this before writing or editing any page in `adminui/`.** One SPA serves two audiences,
gated by role: `/admin/*` (platform admin, 14 pages) and `/owner/*` (ground owner, 7 pages).

---

## 1. Use the shared primitives — never re-roll a table, form, or dialog

`src/components/ui/` is the design system. A page composes it; it does not rebuild it.

| Primitive       | Use for                                                                   |
| --------------- | ------------------------------------------------------------------------- |
| `PageHeader`    | Every page's title + subtitle + breadcrumbs + right-side actions. Always.  |
| `DataTable`     | Every list. Wraps `@mui/x-data-grid` with loading, error and empty states. |
| `DrawerForm`    | Every create/edit form — right drawer, Cancel + submit with spinner.       |
| `ConfirmDialog` | Every destructive action. No `window.confirm`, ever.                       |
| `StatusChip`    | Every status value. Add new statuses to its `STATUS_CONFIG` map, not inline.|
| `StatCard`      | Dashboard metric tiles.                                                    |
| `EmptyState`    | Anything that can be empty outside a `DataTable`.                          |

`src/pages/admin/Amenities.jsx` is the **reference page** — search + filter row, `DataTable`,
create `DrawerForm`, edit `DrawerForm`, `ConfirmDialog`. Copy its shape for a new CRUD page.

A new reusable widget goes in `src/components/ui/` with a default export, not inline in a page.

## 2. Data flow — TanStack Query, never bare axios in a page

- **Read** with `useQuery`, **write** with `useMutation`. A page never calls `apiClient` directly
  and never puts server data in `useState`.
- Query keys are arrays, scoped by role first: `['admin', 'amenities']`, `['owner', 'grounds', id]`.
  A mutation's `onSuccess` invalidates the exact key it dirtied.
- Unwrap in `select`, not in the component body — the envelope varies by endpoint:
  `select: (res) => res.data?.data ?? []`.
- Every mutation has **both** `onSuccess` → `notify.success(...)` and `onError` →
  `notify.error(err?.response?.data?.message || 'Fallback sentence')`. Use `useNotify()`;
  never `alert()` and never a bare `console.error` as the user-facing outcome.
- Endpoints live in `src/api/<domain>.js` as a single exported object of functions. Adding a
  call means adding a method there — never an inline `apiClient.get('/some/path')` in a page.
  Keep the admin (`/admin/...`) and owner (`/ground-owner/...`) method pairs clearly commented,
  as `grounds.js` does; they hit different paths for the same concept.

## 3. Auth & routing

- `AuthContext` owns tokens and role. `isAdmin` / `isOwner` / `isAuthenticated` come from it —
  never read `localStorage` in a page.
- `src/api/client.js` is the **only** HTTP path: it attaches the Bearer token and owns the
  401 → refresh → replay-queue → redirect-to-login flow. Do not add a second axios instance
  and do not set `Authorization` by hand.
- Every route is wrapped in `ProtectedRoute` with an explicit `requiredRole`. Adding a page
  means adding it to `src/router/index.jsx` **and** to `Sidebar`'s nav list for that role.
- An admin-only action must be gated on the server too — the client gate is UX, not security.

## 4. Styling

- **MUI theme only.** Colors come from `theme.palette.*` and the `sx` prop; the primary color is
  user-switchable at runtime (`ThemeContext` + `PALETTE_SWATCHES`), so a hard-coded brand hex in
  a component breaks theming. Use `alpha(theme.palette.primary.main, x)` for tints.
  **GAP**: `DataTable` hard-codes `rgba(107,158,122,…)` for its header/hover; move it to
  `theme.palette` if you touch that file.
- Spacing is the MUI scale (`p={2}`, `gap={1.5}`), not raw px. Radius comes from
  `shape.borderRadius` (14) or the component override — don't invent a third value.
- Component-wide style belongs in `createAppTheme`'s `components` overrides, not repeated `sx`.
- Responsive: pages must work at 1280px and at tablet width. Use
  `Stack direction={{ xs: 'column', sm: 'row' }}` for filter rows, and `p={{ xs: 2, sm: 3 }}`
  for page padding, as `AppShell` does. The sidebar already collapses to a drawer under `md`.

## 5. Forms

- Controlled inputs + a local `formErrors` object + a `validate()` that returns a boolean and
  sets errors. Show the message via `error` / `helperText` on the field — never a snackbar for
  a field-level problem.
- Reset form state in **both** the open and close handlers so a reopened drawer is never stale.
- Multipart uploads (icons, ground images) go through `FormData` with an explicit
  `'Content-Type': 'multipart/form-data'` header on the api-layer method — see `amenities.js`.
  Preview with `URL.createObjectURL(file)`.
- Submit buttons disable while `mutation.isPending` (`DrawerForm`'s `loading` prop does this).

## 6. Before you call admin UI work "done"

- `npm run lint` is clean (`--max-warnings 0`) and `npm run build` succeeds.
- No inline axios, no `window.confirm`/`alert`, no hard-coded brand hex.
- Every list has loading + empty + error; every mutation has success + error toasts.
- Checked at 1280px and tablet width, and against **both** roles if the page exists for both.
