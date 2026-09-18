import apiClient from './client.js'

/**
 * A coach's own earnings. Derived from their sessions, not from `payments` —
 * coaching is pay-at-venue and never touches the gateway.
 */
export const coachEarningsApi = {
  list: (params) => apiClient.get('/coach/earnings', { params }),
}
