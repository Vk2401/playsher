import apiClient from './client.js'

export const gamesApi = {
  // ── Admin ──────────────────────────────────────────────────────────────────
  // Rows come back whole: the venue and schedule live on the booking the game
  // runs on, and the seats, per-player share and status are derived server-side
  // (`backend-api/src/utils/gameView.js`) so the panel and the app agree.
  // Params: page, limit, visibility, is_active
  getAll: (params) => apiClient.get('/admin/games', { params }),
  getById: (id) => apiClient.get(`/admin/games/${id}`),
  delete: (id) => apiClient.delete(`/admin/games/${id}`),

  // Calling a game off is the shared host/admin action on the public resource,
  // not an `/admin/*` route. Prefer it over `delete`: it notifies everyone who
  // joined, leaves the booking intact, and keeps the row for the record.
  cancel: (id) => apiClient.patch(`/games/${id}/cancel`),

  // ── Owner ──────────────────────────────────────────────────────────────────
  // Scoped by venue, not by who published the game — nearly every game is
  // opened by a customer on their own booking.
  // Params: page, limit, visibility
  getOwnerGames: (params) => apiClient.get('/ground-owner/games', { params }),
}
