import apiClient from './client.js'

export const coachesApi = {
  // Admin: list ALL coaches (including unapproved) via /admin/coaches
  getAll: (params) => apiClient.get('/admin/coaches', { params }),
  getById: (id) => apiClient.get(`/admin/coaches/${id}`),

  // Admin CRUD — /admin/coaches
  create: (data) => apiClient.post('/admin/coaches', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  update: (id, data) => apiClient.put(`/admin/coaches/${id}`, data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  }),
  approve: (id) => apiClient.patch(`/admin/coaches/${id}/approve`),
  delete: (id) => apiClient.delete(`/admin/coaches/${id}`),
}
