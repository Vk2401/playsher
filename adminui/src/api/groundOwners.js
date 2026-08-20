import apiClient from './client.js'

export const groundOwnersApi = {
  getAll: (params) => apiClient.get('/admin/ground-owners', { params }),
  getById: (id) => apiClient.get(`/admin/ground-owners/${id}`),
  create: (data) => apiClient.post('/admin/ground-owners', data),
  // Edit an owner's profile and moderation flags. Until this endpoint existed
  // an administrator could only approve, toggle or delete an owner.
  update: (id, data) => apiClient.put(`/admin/ground-owners/${id}`, data),
  // Sets a new password and signs the owner out of every device.
  resetPassword: (id, password) =>
    apiClient.patch(`/admin/ground-owners/${id}/password`, { password }),
  approve: (id) => apiClient.patch(`/admin/ground-owners/${id}/approve`),
  toggleStatus: (id) => apiClient.patch(`/admin/ground-owners/${id}/toggle-status`),
  delete: (id) => apiClient.delete(`/admin/ground-owners/${id}`),
}
