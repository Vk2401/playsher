import apiClient from './client.js'

export const authApi = {
  adminLogin: (email, password) =>
    apiClient.post('/auth/admin/login', { email, password }),

  ownerLogin: (email, password) =>
    apiClient.post('/auth/ground-owner/login', { email, password }),

  refreshToken: (refresh_token) =>
    apiClient.post('/auth/refresh-token', { refresh_token }),

  logout: (refresh_token) =>
    apiClient.post('/auth/logout', { refresh_token }),
}
