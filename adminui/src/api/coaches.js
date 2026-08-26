import apiClient from './client.js'

export const coachesApi = {
  // ── Admin — /admin/coaches ────────────────────────────────────────────────
  getAll: (params) => apiClient.get('/admin/coaches', { params }),
  getById: (id) => apiClient.get(`/admin/coaches/${id}`),
  create: (data) => apiClient.post('/admin/coaches', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  update: (id, data) => apiClient.put(`/admin/coaches/${id}`, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  approve: (id) => apiClient.patch(`/admin/coaches/${id}/approve`),
  reject: (id, reason) => apiClient.patch(`/admin/coaches/${id}/reject`, { reason }),
  // Issues or resets the coach's login password and signs them out everywhere.
  setPassword: (id, password) => apiClient.patch(`/admin/coaches/${id}/password`, { password }),
  delete: (id) => apiClient.delete(`/admin/coaches/${id}`),

  // Admin oversight of the coaching module as a whole
  getAllSessions: (params) => apiClient.get('/admin/coach-bookings', { params }),
  getAllGroundLinks: (params) => apiClient.get('/admin/coach-grounds', { params }),

  // ── Ground owner — /ground-owner/... ──────────────────────────────────────
  // Coaches asking to work at this owner's grounds, and the owner's answer.
  getOwnerRequests: (params) => apiClient.get('/ground-owner/coach-requests', { params }),
  approveOwnerRequest: (id, response_note) =>
    apiClient.patch(`/ground-owner/coach-requests/${id}/approve`, { response_note }),
  rejectOwnerRequest: (id, response_note) =>
    apiClient.patch(`/ground-owner/coach-requests/${id}/reject`, { response_note }),
  getOwnerCoaches: () => apiClient.get('/ground-owner/coaches'),
  getOwnerSessions: (params) => apiClient.get('/ground-owner/coach-sessions', { params }),

  // ── Coach's own panel — /coach/... ────────────────────────────────────────
  getProfile: () => apiClient.get('/coach/profile'),
  updateProfile: (data) => apiClient.put('/coach/profile', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  getDashboard: () => apiClient.get('/coach/dashboard'),

  getAvailability: () => apiClient.get('/coach/availability'),
  setAvailability: (days) => apiClient.put('/coach/availability', { days }),
  getSlots: (date) => apiClient.get('/coach/slots', { params: { date } }),
  blockSlot: (id) => apiClient.patch(`/coach/slots/${id}/block`),
  unblockSlot: (id) => apiClient.patch(`/coach/slots/${id}/unblock`),

  getMyGrounds: (params) => apiClient.get('/coach/grounds', { params }),
  getJoinableGrounds: (params) => apiClient.get('/coach/grounds/available', { params }),
  requestGround: (ground_id, request_note) =>
    apiClient.post('/coach/grounds', { ground_id, request_note }),
  withdrawGround: (id) => apiClient.delete(`/coach/grounds/${id}`),

  getMySessions: (params) => apiClient.get('/coach/bookings', { params }),
  getMySession: (id) => apiClient.get(`/coach/bookings/${id}`),
  confirmSession: (id, coach_note) =>
    apiClient.patch(`/coach/bookings/${id}/confirm`, { coach_note }),
  rejectSession: (id, reason) => apiClient.patch(`/coach/bookings/${id}/reject`, { reason }),
  completeSession: (id) => apiClient.patch(`/coach/bookings/${id}/complete`),
}
