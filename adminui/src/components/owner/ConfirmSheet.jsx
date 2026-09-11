import { Button, Typography } from '@mui/material'
import ActionSheet from './ActionSheet.jsx'

/** Yes/no question in the owner panel's sheet style. */
export default function ConfirmSheet({ open, onClose, title, text, confirmLabel, onConfirm, loading, danger = true }) {
  return (
    <ActionSheet
      open={open}
      onClose={onClose}
      title={title}
      actions={(
        <>
          <Button variant="contained" color={danger ? 'error' : 'primary'} size="large" onClick={onConfirm} disabled={loading}>
            {loading ? 'Please wait…' : confirmLabel}
          </Button>
          <Button size="large" onClick={onClose}>Go back</Button>
        </>
      )}
    >
      <Typography color="text.secondary">{text}</Typography>
    </ActionSheet>
  )
}
