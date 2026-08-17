import apiClient from './client.js'

export const slotsApi = {
  // Owner: slots under a specific ground
  // GET returns { slots: [...], ground_sports: [...] }
  getGroundSlots: (groundId, params) =>
    apiClient.get(`/ground-owner/grounds/${groundId}/slots`, { params }),

  // body: { ground_sport_id, slot_date, slot_start_time, slot_end_time }
  create: (groundId, data) =>
    apiClient.post(`/ground-owner/grounds/${groundId}/slots`, data),

  update: (groundId, slotId, data) =>
    apiClient.put(`/ground-owner/grounds/${groundId}/slots/${slotId}`, data),

  delete: (groundId, slotId) =>
    apiClient.delete(`/ground-owner/grounds/${groundId}/slots/${slotId}`),

  toggleStatus: (groundId, slotId) =>
    apiClient.patch(`/ground-owner/grounds/${groundId}/slots/${slotId}/toggle`),
}
