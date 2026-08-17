import apiClient from './client.js'

export const groundOwnersApi = {
  getAll: (params) => apiClient.get('/admin/ground-owners', { params }),
  getById: (id) => apiClient.get(`/admin/ground-owners/${id}`),
  create: (data) => apiClient.post('/admin/ground-owners', data),
  approve: (id) => apiClient.patch(`/admin/ground-owners/${id}/approve`),
  toggleStatus: (id) => apiClient.patch(`/admin/ground-owners/${id}/toggle-status`),
  delete: (id) => apiClient.delete(`/admin/ground-owners/${id}`),
}
