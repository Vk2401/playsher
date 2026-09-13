import apiClient from './client.js'

export const bookingsApi = {
  // Admin
  getAll: (params) => apiClient.get('/admin/bookings', { params }),
  getById: (id) => apiClient.get(`/admin/bookings/${id}`),
  cancel: (id, reason) =>
    apiClient.patch(`/admin/bookings/${id}/cancel`, { reason, cancellation_reason: reason }),

  updateStatus: (id, status) => apiClient.put(`/bookings/${id}`, { status }),

  // Owner
  getOwnerBookings: (params) => apiClient.get('/ground-owner/bookings', { params }),
  getOwnerBooking: (id) => apiClient.get(`/ground-owner/bookings/${id}`),
  ownerCancel: (id, reason) =>
    apiClient.patch(`/ground-owner/bookings/${id}/cancel`, { reason, cancellation_reason: reason }),
  // Records the balance taken in cash at the gate. Owner-only and additive —
  // the customer app has no equivalent call. Answers 409 on a second attempt
  // rather than writing a second payment row.
  ownerCollect: (id) => apiClient.post(`/ground-owner/bookings/${id}/collect`),
}
