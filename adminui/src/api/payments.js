import apiClient from './client.js'

export const paymentsApi = {
  getAll: (params) => apiClient.get('/admin/payments', { params }),
  getById: (id) => apiClient.get(`/admin/payments/${id}`),
  // Backend uses payment_status field — send both keys for compatibility
  updateStatus: (id, status) =>
    apiClient.patch(`/admin/payments/${id}/status`, { payment_status: status, status }),
}
