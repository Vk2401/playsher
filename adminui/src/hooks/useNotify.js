import { useSnackbar } from 'notistack'
import { useCallback } from 'react'

export function useNotify() {
  const { enqueueSnackbar } = useSnackbar()

  const notify = useCallback((message, variant = 'default', options = {}) => {
    enqueueSnackbar(message, { variant, ...options })
  }, [enqueueSnackbar])

  return {
    notify,
    success: (msg, opts) => notify(msg, 'success', opts),
    error: (msg, opts) => notify(msg, 'error', opts),
    warning: (msg, opts) => notify(msg, 'warning', opts),
    info: (msg, opts) => notify(msg, 'info', opts),
  }
}
