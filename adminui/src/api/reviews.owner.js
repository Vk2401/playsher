import apiClient from './client.js'

/**
 * Reviews a ground owner can read about their own venues. Read-only by design:
 * moderation belongs to admins, and the server scopes by ownership rather than
 * trusting a ground_id from here.
 */
export const ownerReviewsApi = {
  list: (params) => apiClient.get('/ground-owner/reviews', { params }),
}
