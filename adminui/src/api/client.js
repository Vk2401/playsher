import axios from 'axios'

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1'

const apiClient = axios.create({
  baseURL: BASE_URL,
  headers: { 'Content-Type': 'application/json' },
  timeout: 30_000,
})

let isRefreshing = false
let refreshQueue = []

function processQueue(error, token = null) {
  refreshQueue.forEach((p) => (error ? p.reject(error) : p.resolve(token)))
  refreshQueue = []
}

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('playsher_access_token')
  if (token && !config.headers['Authorization']) {
    config.headers['Authorization'] = `Bearer ${token}`
  }
  return config
})

apiClient.interceptors.response.use(
  (res) => res,
  async (error) => {
    const original = error.config

    if (error.response?.status === 401 && !original._retry) {
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          refreshQueue.push({ resolve, reject })
        }).then((token) => {
          original.headers['Authorization'] = `Bearer ${token}`
          return apiClient(original)
        })
      }

      original._retry = true
      isRefreshing = true

      try {
        const refreshToken = localStorage.getItem('playsher_refresh_token')
        if (!refreshToken) throw new Error('No refresh token')

        const { data } = await axios.post(`${BASE_URL}/auth/refresh-token`, {
          refresh_token: refreshToken,
        })

        const newAccess = data.data?.access_token || data.access_token
        const newRefresh = data.data?.refresh_token || data.refresh_token

        localStorage.setItem('playsher_access_token', newAccess)
        if (newRefresh) localStorage.setItem('playsher_refresh_token', newRefresh)

        apiClient.defaults.headers.common['Authorization'] = `Bearer ${newAccess}`
        processQueue(null, newAccess)

        original.headers['Authorization'] = `Bearer ${newAccess}`
        return apiClient(original)
      } catch (err) {
        processQueue(err, null)
        localStorage.removeItem('playsher_access_token')
        localStorage.removeItem('playsher_refresh_token')
        localStorage.removeItem('playsher_user')
        window.location.href = '/login'
        return Promise.reject(err)
      } finally {
        isRefreshing = false
      }
    }

    return Promise.reject(error)
  }
)

export default apiClient
