import apiClient from './client.js'

/**
 * App version gating — admin only.
 *
 * These values decide whether every installed mobile app prompts to update or
 * is blocked outright, so the endpoints sit behind the admin role on the server.
 * The public read the app itself uses is `/app-version` and is not exposed here.
 */
export const appVersionsApi = {
  // Admin — /admin/app-versions
  getAll: () => apiClient.get('/admin/app-versions'),
  update: (platform, data) => apiClient.put(`/admin/app-versions/${platform}`, data),
}
