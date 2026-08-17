import apiClient from './client.js'

export const settlementsApi = {
  getVendors: (params) => apiClient.get('/admin/vendors', { params }),
  getVendorBookings: (vendorId, params) =>
    apiClient.get(`/admin/vendors/${vendorId}/bookings`, { params }),
  getVendorStats: (vendorId) =>
    apiClient.get(`/admin/vendors/${vendorId}/stats`),
  updatePayoutStatus: (paymentId, data) =>
    apiClient.patch(`/admin/payments/${paymentId}/status`, data),
}
