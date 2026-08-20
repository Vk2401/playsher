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

  // Admin + ground owner. Customers sign in by OTP and have no password.
  // Succeeding here revokes every refresh token for the account, this
  // session's included — the caller must sign the user out afterwards.
  changePassword: (current_password, new_password) =>
    apiClient.patch('/auth/change-password', { current_password, new_password }),
}
