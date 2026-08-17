import apiClient from './client.js'

export const usersApi = {
  getAll: (params) => apiClient.get('/admin/users', { params }),
  getById: (id) => apiClient.get(`/admin/users/${id}`),
  create: (data) => apiClient.post('/admin/users', data),
  update: (id, data) => apiClient.put(`/users/${id}`, data),
  toggleStatus: (id) => apiClient.patch(`/admin/users/${id}/toggle-status`),
  delete: (id) => apiClient.delete(`/admin/users/${id}`),
}
