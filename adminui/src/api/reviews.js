import apiClient from './client.js'

export const reviewsApi = {
  getAll: (params) => apiClient.get('/admin/reviews', { params }),
  getById: (id) => apiClient.get(`/admin/reviews/${id}`),
  delete: (id) => apiClient.delete(`/admin/reviews/${id}`),
}
