import apiClient from './client.js'

export const amenitiesApi = {
  // Admin: list ALL amenities via /admin/amenities
  getAll: (params) => apiClient.get('/admin/amenities', { params }),
  getById: (id) => apiClient.get(`/amenities/${id}`),

  // Admin CRUD — /admin/amenities
  create: (data) => apiClient.post('/admin/amenities', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  update: (id, data) => apiClient.put(`/admin/amenities/${id}`, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  delete: (id) => apiClient.delete(`/admin/amenities/${id}`),

  // Public list (for dropdowns — returns only active amenities)
  listPublic: (params) => apiClient.get('/amenities', { params }),
}
