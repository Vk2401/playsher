import apiClient from './client.js'

export const schedulesApi = {
  getSchedule: (groundId) =>
    apiClient.get(`/ground-owner/grounds/${groundId}/schedule`),

  upsertSchedule: (groundId, data) =>
    apiClient.put(`/ground-owner/grounds/${groundId}/schedule`, data),
}
