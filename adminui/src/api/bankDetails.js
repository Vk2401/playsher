import apiClient from './client.js'

export const bankDetailsApi = {
  get: () => apiClient.get('/bank-details'),
  save: (data) => apiClient.post('/add-bank-details', data),
}
