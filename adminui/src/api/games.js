import apiClient from './client.js'

export const gamesApi = {
  // Admin
  getAll: (params) => apiClient.get('/admin/games', { params }),
  getById: (id) => apiClient.get(`/admin/games/${id}`),
  delete: (id) => apiClient.delete(`/admin/games/${id}`),

  // Owner
  getOwnerGames: (params) => apiClient.get('/ground-owner/games', { params }),
}
