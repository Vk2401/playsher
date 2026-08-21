import apiClient from './client.js'

export const adminsApi = {
  // Any admin: who am I, and am I a super admin? Drives whether the Admins
  // screen is offered at all.
  me: () => apiClient.get('/admin/admins/me'),

  // Super admin only — /admin/admins
  getAll: (params) => apiClient.get('/admin/admins', { params }),
  getById: (id) => apiClient.get(`/admin/admins/${id}`),
  create: (data) => apiClient.post('/admin/admins', data),
  update: (id, data) => apiClient.put(`/admin/admins/${id}`, data),
  toggleStatus: (id) => apiClient.patch(`/admin/admins/${id}/toggle-status`),
  resetPassword: (id, newPassword) =>
    apiClient.patch(`/admin/admins/${id}/password`, { new_password: newPassword }),
}
