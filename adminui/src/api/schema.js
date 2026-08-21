import apiClient from './client.js'

export const schemaApi = {
  // Admin: the declared schema (backend-api/database/schema.json)
  getDefinition: () => apiClient.get('/admin/schema'),

  // Admin: dry run — what would change if the schema were applied. Read-only.
  getPlan: () => apiClient.get('/admin/schema/plan'),

  // Admin: start the sync. Risky operations are opted into explicitly.
  apply: (includeRisky = false) =>
    apiClient.post('/admin/schema/apply', { include_risky: includeRisky }),

  // Admin: poll a running sync for progress
  getJob: (id) => apiClient.get(`/admin/schema/jobs/${id}`),
}
