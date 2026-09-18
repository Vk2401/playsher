import apiClient from './client.js'

export const paymentsApi = {
  getAll: (params) => apiClient.get('/admin/payments', { params }),
  getById: (id) => apiClient.get(`/admin/payments/${id}`),
  // Backend uses payment_status field — send both keys for compatibility
  updateStatus: (id, status) =>
    apiClient.patch(`/admin/payments/${id}/status`, { payment_status: status, status }),
  // Re-runs the Route transfer for a payout that never went through. The
  // server refuses a payment that already carries a transfer_id, so pressing
  // this twice cannot send the money twice.
  retryPayout: (id) => apiClient.post(`/admin/payments/${id}/retry-payout`),
  // Reverses the ground owner's share before refunding the customer. Answers
  // 409 without refunding if that share cannot be recovered; `force` refunds
  // anyway and has the platform absorb it. Super admin only, server-enforced.
  refund: (id, body) => apiClient.post(`/admin/payments/${id}/refund`, body),
}

/**
 * Platform-wide settings. Reading the commission is open to any admin; changing
 * it is gated on the super-admin tier by the server, not by this client.
 */
export const settingsApi = {
  getCommission: () => apiClient.get('/admin/settings/commission'),
  setCommission: (percent) => apiClient.put('/admin/settings/commission', { percent }),
}
