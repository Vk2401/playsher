import apiClient from './client.js'

export const settlementsApi = {
  // Owner — their own earnings only; scoped server-side by the token.
  getOwnerSettlements: (params) => apiClient.get('/ground-owner/settlements', { params }),

  // Admin
  getVendors: (params) => apiClient.get('/admin/vendors', { params }),
  getVendorBookings: (vendorId, params) =>
    apiClient.get(`/admin/vendors/${vendorId}/bookings`, { params }),
  getVendorStats: (vendorId) =>
    apiClient.get(`/admin/vendors/${vendorId}/stats`),
  updatePayoutStatus: (paymentId, data) =>
    apiClient.patch(`/admin/payments/${paymentId}/status`, data),
}
