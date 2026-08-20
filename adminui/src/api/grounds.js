import apiClient from './client.js'

export const groundsApi = {
  // ── Admin ─────────────────────────────────────────────────────────────────
  getAll: (params) => apiClient.get('/admin/grounds', { params }),
  getById: (id) => apiClient.get(`/admin/grounds/${id}`),
  adminCreate: (data) => apiClient.post('/grounds', data),
  // Admin-scoped update: wider whitelist than the owner's own (approval state
  // and owner reassignment included).
  adminUpdate: (id, data) => apiClient.put(`/admin/grounds/${id}`, data),
  approve: (id) => apiClient.patch(`/admin/grounds/${id}/approve`),
  toggleStatus: (id) => apiClient.patch(`/admin/grounds/${id}/toggle-status`),
  delete: (id) => apiClient.delete(`/admin/grounds/${id}`),

  // ── Owner ─────────────────────────────────────────────────────────────────
  getOwnerGrounds: (params) => apiClient.get('/ground-owner/grounds', { params }),
  getOwnerGround: (id) => apiClient.get(`/ground-owner/grounds/${id}`),
  create: (data) => apiClient.post('/ground-owner/grounds', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  update: (id, data) => apiClient.put(`/ground-owner/grounds/${id}`, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  deleteOwner: (id) => apiClient.delete(`/ground-owner/grounds/${id}`),

  // Ground Images
  addImage: (groundId, formData) =>
    apiClient.post(`/ground-owner/grounds/${groundId}/images`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  deleteImage: (groundId, imageId) =>
    apiClient.delete(`/ground-owner/grounds/${groundId}/images/${imageId}`),

  // Ground Sports (ground_sports mapping) — sportId here is the ground_sport row id
  addSport: (groundId, data) =>
    apiClient.post(`/ground-owner/grounds/${groundId}/sports`, data),
  // Edit price / slot limits / availability in place. Without this the only
  // way to change a price was to remove the sport and re-add it, which
  // cascade-deletes its weekly schedule and every generated slot.
  updateSport: (groundId, groundSportId, data) =>
    apiClient.put(`/ground-owner/grounds/${groundId}/sports/${groundSportId}`, data),
  removeSport: (groundId, groundSportId) =>
    apiClient.delete(`/ground-owner/grounds/${groundId}/sports/${groundSportId}`),

  // Ground Amenities mapping — requires { amenity_ids: [...] }
  addAmenity: (groundId, amenityIds) =>
    apiClient.post(`/ground-owner/grounds/${groundId}/amenities`, { amenity_ids: Array.isArray(amenityIds) ? amenityIds : [amenityIds] }),
  removeAmenity: (groundId, amenityId) =>
    apiClient.delete(`/ground-owner/grounds/${groundId}/amenities/${amenityId}`),

  // ── Admin Ground Sports/Amenities ──────────────────────────────────────────
  adminAddSport: (groundId, data) =>
    apiClient.post(`/grounds/${groundId}/sports`, data),
  adminRemoveSport: (groundId, sportId) =>
    apiClient.delete(`/grounds/${groundId}/sports/${sportId}`),
  adminAddAmenity: (groundId, amenityIds) =>
    apiClient.post(`/grounds/${groundId}/amenities`, { amenity_ids: Array.isArray(amenityIds) ? amenityIds : [amenityIds] }),
  adminRemoveAmenity: (groundId, amenityId) =>
    apiClient.delete(`/grounds/${groundId}/amenities/${amenityId}`),
}
