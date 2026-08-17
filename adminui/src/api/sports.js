import apiClient from './client.js'

export const sportsApi = {
  // Admin: list ALL sports (including unapproved) via /admin/sports
  getAll: (params) => apiClient.get('/admin/sports', { params }),
  getById: (id) => apiClient.get(`/sports/${id}`),

  // Admin CRUD — /admin/sports
  create: (data) => apiClient.post('/admin/sports', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  update: (id, data) => apiClient.put(`/admin/sports/${id}`, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  approve: (id) => apiClient.patch(`/admin/sports/${id}/approve`),
  delete: (id) => apiClient.delete(`/admin/sports/${id}`),

  // Public list (for dropdowns etc.)
  listPublic: (params) => apiClient.get('/sports', { params }),
}
