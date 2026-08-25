import apiClient from './client.js'

export const sportsApi = {
  // Admin: list ALL sports (including unapproved) via /admin/sports
  getAll: (params) => apiClient.get('/admin/sports', { params }),
  getById: (id) => apiClient.get(`/sports/${id}`),

  // The public list, readable by any signed-in role. The coach panel needs the
  // sport names but is not allowed to call /admin/sports.
  getPublic: (params) => apiClient.get('/sports', { params }),

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
