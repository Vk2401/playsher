import apiClient from './client.js'

/**
 * The signed-in account's inbox. Same endpoints for every role — the server
 * reads the recipient from the token, so there is no role in any path here.
 */
export const notificationsApi = {
  getAll: (params) => apiClient.get('/notifications', { params }),
  unreadCount: () => apiClient.get('/notifications/unread-count'),
  markRead: (id) => apiClient.patch(`/notifications/${id}/read`),
  markAllRead: () => apiClient.patch('/notifications/read-all'),
  delete: (id) => apiClient.delete(`/notifications/${id}`),
}
