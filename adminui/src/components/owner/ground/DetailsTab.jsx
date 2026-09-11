import { useState } from 'react'
import { Box, Button, ButtonBase, Chip, CircularProgress, IconButton, Stack, Typography } from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'
import AddIcon from '@mui/icons-material/Add'
import AddPhotoAlternateOutlinedIcon from '@mui/icons-material/AddPhotoAlternateOutlined'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import EditOutlinedIcon from '@mui/icons-material/EditOutlined'
import MapOutlinedIcon from '@mui/icons-material/MapOutlined'
import StarIcon from '@mui/icons-material/Star'

import ActionSheet from '../ActionSheet.jsx'
import ConfirmSheet from '../ConfirmSheet.jsx'
import GroundFormSheet from '../GroundFormSheet.jsx'
import { Card, InfoRow, Pill } from '../OwnerBits.jsx'
import { prettyPhone, rupee, unwrapList } from '../ownerFormat.js'
import { groundsApi } from '../../../api/grounds.js'
import { amenitiesApi } from '../../../api/amenities.js'
import { useNotify } from '../../../hooks/useNotify.js'
import { useOwnerGround } from '../../../contexts/OwnerGroundContext.jsx'

/**
 * Photos, facilities and everything customers read about the ground — plus
 * editing all of it, and deleting the ground.
 */
export default function DetailsTab({ ground }) {
  const theme = useTheme()
  const queryClient = useQueryClient()
  const notify = useNotify()
  const { setGroundId } = useOwnerGround()
  const [editing, setEditing] = useState(false)
  const [photoToDelete, setPhotoToDelete] = useState(null)
  const [amenityToRemove, setAmenityToRemove] = useState(null)
  const [addingAmenity, setAddingAmenity] = useState(false)
  const [deleting, setDeleting] = useState(false)

  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: ['owner', 'ground', ground.id] })
    queryClient.invalidateQueries({ queryKey: ['owner', 'grounds'] })
  }

  const addPhoto = useMutation({
    mutationFn: (file) => {
      const fd = new FormData()
      fd.append('image', file)
      return groundsApi.addImage(ground.id, fd)
    },
    onSuccess: () => { notify.success('Photo added'); refresh() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not upload the photo'),
  })
  const deletePhoto = useMutation({
    mutationFn: (img) => groundsApi.deleteImage(ground.id, img.id),
    onSuccess: () => { notify.success('Photo deleted'); setPhotoToDelete(null); refresh() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not delete the photo'),
  })
  const removeAmenity = useMutation({
    mutationFn: (a) => groundsApi.removeAmenity(ground.id, a.id),
    onSuccess: () => { notify.success('Facility removed'); setAmenityToRemove(null); refresh() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not remove the facility'),
  })
  const deleteGround = useMutation({
    mutationFn: () => groundsApi.deleteOwner(ground.id),
    onSuccess: () => {
      notify.success('Ground deleted')
      setDeleting(false)
      setGroundId(null)
      queryClient.invalidateQueries({ queryKey: ['owner'] })
    },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not delete the ground'),
  })

  const images = ground.images ?? []
  const amenities = ground.amenities ?? []
  const hasMap = ground.latitude && ground.longitude
  const mapHref = hasMap ? `https://www.google.com/maps?q=${ground.latitude},${ground.longitude}` : null

  return (
    <Box mt={2}>
      {/* Photos */}
      <Typography variant="subtitle1" fontWeight={700} mb={1}>Photos</Typography>
      <Box sx={{ display: 'grid', gridTemplateColumns: { xs: 'repeat(3, 1fr)', sm: 'repeat(4, 1fr)' }, gap: 1 }}>
        {images.map((img) => (
          <Box key={img.id} sx={{ position: 'relative', aspectRatio: '1', borderRadius: 1, overflow: 'hidden', bgcolor: 'action.hover' }}>
            <Box component="img" src={img.image} alt="" loading="lazy" sx={{ width: '100%', height: '100%', objectFit: 'cover' }} />
            {img.is_primary && (
              <Chip size="small" icon={<StarIcon />} label="Cover" sx={{ position: 'absolute', left: 4, bottom: 4, height: 22, bgcolor: alpha(theme.palette.common.black, 0.55), color: 'common.white', '& .MuiChip-icon': { color: 'warning.light' } }} />
            )}
            <IconButton
              size="small"
              aria-label="Delete photo"
              onClick={() => setPhotoToDelete(img)}
              sx={{ position: 'absolute', top: 4, right: 4, bgcolor: alpha(theme.palette.common.black, 0.5), color: 'common.white', '&:hover': { bgcolor: alpha(theme.palette.common.black, 0.7) } }}
            >
              <DeleteOutlineIcon fontSize="small" />
            </IconButton>
          </Box>
        ))}
        <ButtonBase
          component="label"
          sx={{ aspectRatio: '1', borderRadius: 1, border: 1.5, borderStyle: 'dashed', borderColor: 'divider', flexDirection: 'column', color: 'primary.dark', gap: 0.5 }}
        >
          {addPhoto.isPending ? <CircularProgress size={22} /> : <AddPhotoAlternateOutlinedIcon />}
          <Typography variant="caption" fontWeight={600} color="inherit">{addPhoto.isPending ? 'Uploading' : 'Add photo'}</Typography>
          <input
            hidden
            type="file"
            accept="image/*"
            onChange={(e) => { const f = e.target.files?.[0]; if (f) addPhoto.mutate(f); e.target.value = '' }}
          />
        </ButtonBase>
      </Box>

      {/* Facilities */}
      <Typography variant="subtitle1" fontWeight={700} mt={3} mb={1}>Facilities</Typography>
      <Stack direction="row" flexWrap="wrap" gap={1}>
        {amenities.map((a) => (
          <Chip
            key={a.id}
            label={a.name}
            onDelete={() => setAmenityToRemove(a)}
            avatar={a.icon_url || a.image_url ? <Box component="img" src={a.icon_url ?? a.image_url} alt="" /> : undefined}
            sx={{ bgcolor: 'background.paper', border: 1, borderColor: 'divider', fontWeight: 500 }}
          />
        ))}
        <Chip icon={<AddIcon />} label="Add" onClick={() => setAddingAmenity(true)} color="primary" variant="outlined" sx={{ fontWeight: 600, borderStyle: 'dashed' }} />
      </Stack>

      {/* About */}
      <Typography variant="subtitle1" fontWeight={700} mt={3} mb={1}>About the ground</Typography>
      <Card sx={{ px: 2, py: 0.5 }}>
        <InfoRow label="Status" value={<Pill tone={ground.is_approved ? 'primary' : 'warning'} label={ground.is_approved ? 'Approved by Playsher' : 'Waiting for approval'} />} />
        <InfoRow label="Price" value={ground.price_per_slot ? `${rupee(Number(ground.price_per_slot) * 2)} / hour` : 'Not set'} />
        <InfoRow label="Type" value={ground.has_roof ? 'Indoor or covered' : 'Open-air'} />
        <InfoRow label="Contact" value={ground.contact_number ? prettyPhone(ground.contact_number) : 'Not set'} />
        <InfoRow label="Address" value={ground.address || 'Not set'} multiline />
        <InfoRow label="Area" value={ground.area || '—'} />
        <InfoRow label="City" value={ground.city || '—'} />
        <InfoRow
          label="Map location"
          value={hasMap ? (
            <Button size="small" startIcon={<MapOutlinedIcon />} href={mapHref} target="_blank" rel="noopener" sx={{ mr: -1 }}>
              Open in Maps
            </Button>
          ) : 'Not set, customers cannot get directions'}
          color={hasMap ? undefined : 'warning.dark'}
        />
        <InfoRow label="Short description" value={ground.description || 'Not written yet'} multiline />
        <InfoRow label="About" value={ground.about || 'Not written yet'} multiline />
        <InfoRow label="Ground rules" value={ground.venue_rules || 'None'} multiline />
        <InfoRow label="Added on" value={ground.created_at ? dayjs(ground.created_at).format('D MMM YYYY') : '—'} last />
      </Card>

      <Button fullWidth variant="contained" size="large" startIcon={<EditOutlinedIcon />} sx={{ mt: 2 }} onClick={() => setEditing(true)}>
        Edit ground details
      </Button>
      <Button fullWidth color="error" size="large" startIcon={<DeleteOutlineIcon />} sx={{ mt: 1 }} onClick={() => setDeleting(true)}>
        Delete this ground
      </Button>

      <GroundFormSheet open={editing} onClose={() => setEditing(false)} ground={ground} />
      <AmenityPicker open={addingAmenity} onClose={() => setAddingAmenity(false)} ground={ground} onDone={refresh} />
      <ConfirmSheet
        open={Boolean(photoToDelete)}
        onClose={() => setPhotoToDelete(null)}
        title="Delete this photo?"
        text="Customers will no longer see it."
        confirmLabel="Delete photo"
        loading={deletePhoto.isPending}
        onConfirm={() => deletePhoto.mutate(photoToDelete)}
      />
      <ConfirmSheet
        open={Boolean(amenityToRemove)}
        onClose={() => setAmenityToRemove(null)}
        title={`Remove ${amenityToRemove?.name ?? 'facility'}?`}
        text="It will no longer show on your ground in the app."
        confirmLabel="Remove"
        loading={removeAmenity.isPending}
        onConfirm={() => removeAmenity.mutate(amenityToRemove)}
      />
      <ConfirmSheet
        open={deleting}
        onClose={() => setDeleting(false)}
        title={`Delete ${ground.name}?`}
        text="The ground disappears from the app and customers can no longer book it. This cannot be undone from here."
        confirmLabel="Delete ground"
        loading={deleteGround.isPending}
        onConfirm={() => deleteGround.mutate()}
      />
    </Box>
  )
}

function AmenityPicker({ open, onClose, ground, onDone }) {
  const notify = useNotify()
  const allQ = useQuery({
    queryKey: ['amenities', 'public'],
    queryFn: () => amenitiesApi.listPublic({ limit: 100 }),
    select: unwrapList,
    enabled: open,
  })
  const have = new Set((ground.amenities ?? []).map((a) => a.id))
  const choices = (allQ.data ?? []).filter((a) => !have.has(a.id))

  const add = useMutation({
    mutationFn: (a) => groundsApi.addAmenity(ground.id, a.id),
    onSuccess: (_r, a) => { notify.success(`${a.name} added`); onDone() },
    onError: (err) => notify.error(err?.response?.data?.message || 'Could not add the facility'),
  })

  return (
    <ActionSheet open={open} onClose={onClose} title="Add facilities" subtitle="Tap to add. Customers see these on your ground.">
      {allQ.isLoading && <CircularProgress size={24} sx={{ mt: 2 }} />}
      {allQ.isSuccess && choices.length === 0 && (
        <Typography color="text.secondary" mt={1}>Every facility is already added.</Typography>
      )}
      <Stack direction="row" flexWrap="wrap" gap={1} mt={1}>
        {choices.map((a) => (
          <Chip
            key={a.id}
            label={a.name}
            icon={<AddIcon />}
            onClick={() => add.mutate(a)}
            disabled={add.isPending}
            sx={{ bgcolor: 'background.paper', border: 1, borderColor: 'divider', fontWeight: 500, height: 38 }}
          />
        ))}
      </Stack>
    </ActionSheet>
  )
}
