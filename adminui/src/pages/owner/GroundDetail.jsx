import React, { useRef, useState } from 'react'
import {
  Box, Button, Chip, CircularProgress, Dialog, DialogActions, DialogContent,
  DialogTitle, FormControl, FormControlLabel, Grid, IconButton,
  ImageList, ImageListItem, ImageListItemBar, InputLabel, MenuItem, Paper,
  Select, Stack, Switch, Tab, Tabs, TextField, Tooltip, Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useParams } from 'react-router-dom'
import dayjs from 'dayjs'

import AddIcon from '@mui/icons-material/Add'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import EditIcon from '@mui/icons-material/Edit'
import ContentCopyIcon from '@mui/icons-material/ContentCopy'
import ScheduleIcon from '@mui/icons-material/Schedule'

import PageHeader from '../../components/ui/PageHeader.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import EmptyState from '../../components/ui/EmptyState.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { groundsApi } from '../../api/grounds.js'
import { schedulesApi } from '../../api/schedules.js'
import { sportsApi } from '../../api/sports.js'
import { amenitiesApi } from '../../api/amenities.js'

// ── Helpers ───────────────────────────────────────────────────────────────────
function TabPanel({ children, value, index }) {
  return <Box sx={{ display: value === index ? 'block' : 'none', pt: 3 }}>{children}</Box>
}

function InfoField({ label, value }) {
  return (
    <TextField
      label={label} value={value ?? '—'} size="small" fullWidth
      InputProps={{ readOnly: true }} sx={{ mb: 2 }}
    />
  )
}

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

const DEFAULT_DAY_SCHEDULE = { start_time: '06:00', end_time: '22:00', is_closed: false }
const EMPTY_SPORT = { sport_id: '', price_per_half_hour: '', min_slots: 1, max_slots: 8 }
const EMPTY_GROUND_FORM = {
  name: '', description: '', about: '', venue_rules: '',
  address: '', latitude: '', longitude: '', contact_number: '', open_for_booking: true,
}

export default function GroundDetail() {
  const { id } = useParams()
  const queryClient = useQueryClient()
  const notify = useNotify()
  const imageInputRef = useRef(null)
  const editFileRef = useRef(null)

  const [tab, setTab] = useState(0)

  // Sport state
  const [sportDialogOpen, setSportDialogOpen] = useState(false)
  const [sportForm, setSportForm] = useState(EMPTY_SPORT)
  const [deleteSportTarget, setDeleteSportTarget] = useState(null)

  // Edit sport + schedule drawer state
  const [editSportDrawerOpen, setEditSportDrawerOpen] = useState(false)
  const [editSportGsId, setEditSportGsId] = useState(null)
  const [editSportName, setEditSportName] = useState('')
  const [weekSchedule, setWeekSchedule] = useState(
    DAYS.map((_, i) => ({ day_of_week: i, ...DEFAULT_DAY_SCHEDULE }))
  )

  // Amenity state
  const [addAmenityOpen, setAddAmenityOpen] = useState(false)
  const [selectedAmenityId, setSelectedAmenityId] = useState('')
  const [deleteAmenityTarget, setDeleteAmenityTarget] = useState(null)

  // Edit ground state
  const [editDrawerOpen, setEditDrawerOpen] = useState(false)
  const [editForm, setEditForm] = useState(EMPTY_GROUND_FORM)
  const [editImageFile, setEditImageFile] = useState(null)

  // Image state
  const [deleteImageTarget, setDeleteImageTarget] = useState(null)

  // ── Queries ───────────────────────────────────────────────────────────────
  const { data: groundData, isLoading: gLoad } = useQuery({
    queryKey: ['owner', 'ground', id],
    queryFn: () => groundsApi.getOwnerGround(id),
    select: (res) => res.data,
    enabled: Boolean(id),
  })
  const ground = groundData?.ground ?? groundData?.data ?? groundData

  const { data: scheduleData } = useQuery({
    queryKey: ['owner', 'schedule', id],
    queryFn: () => schedulesApi.getSchedule(id),
    select: (res) => res.data,
    enabled: Boolean(id) && tab === 1,
  })
  const scheduleGroundSports = scheduleData?.ground_sports ?? scheduleData?.data?.ground_sports ?? []
  const groundSportsList = ground?.groundSports ?? []

  // Public sports list for "add sport" dialog
  const { data: allSportsData } = useQuery({
    queryKey: ['sports', 'public'],
    queryFn: () => sportsApi.listPublic({ limit: 100 }),
    select: (res) => res.data,
    enabled: sportDialogOpen,
  })
  const allSports = allSportsData?.sports ?? allSportsData?.data ?? []

  // Public amenities list for "add amenity" dialog
  const { data: allAmenitiesData } = useQuery({
    queryKey: ['amenities', 'public'],
    queryFn: () => amenitiesApi.listPublic({ limit: 100 }),
    select: (res) => res.data,
    enabled: addAmenityOpen,
  })
  const allAmenities = allAmenitiesData?.amenities ?? allAmenitiesData?.data ?? []
  const groundAmenities = ground?.amenities ?? []

  // ── Schedule mutation ─────────────────────────────────────────────────────
  const upsertScheduleMutation = useMutation({
    mutationFn: (data) => schedulesApi.upsertSchedule(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'schedule', id] })
      notify.success('Weekly schedule saved')
      setEditSportDrawerOpen(false)
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to save schedule'),
  })

  // ── Sport mutations ───────────────────────────────────────────────────────
  const addSportMutation = useMutation({
    mutationFn: (data) => groundsApi.addSport(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', id] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'slots', id] })
      notify.success('Sport added to ground')
      setSportDialogOpen(false)
      setSportForm(EMPTY_SPORT)
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to add sport'),
  })

  const removeSportMutation = useMutation({
    mutationFn: (groundSportId) => groundsApi.removeSport(id, groundSportId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', id] })
      queryClient.invalidateQueries({ queryKey: ['owner', 'slots', id] })
      notify.success('Sport removed')
      setDeleteSportTarget(null)
    },
    onError: () => notify.error('Failed to remove sport'),
  })

  // ── Amenity mutations ─────────────────────────────────────────────────────
  const addAmenityMutation = useMutation({
    mutationFn: (amenityId) => groundsApi.addAmenity(id, amenityId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', id] })
      notify.success('Amenity added')
      setAddAmenityOpen(false)
      setSelectedAmenityId('')
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to add amenity'),
  })

  const removeAmenityMutation = useMutation({
    mutationFn: (amenityId) => groundsApi.removeAmenity(id, amenityId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', id] })
      notify.success('Amenity removed')
      setDeleteAmenityTarget(null)
    },
    onError: () => notify.error('Failed to remove amenity'),
  })

  // ── Image mutations ───────────────────────────────────────────────────────
  const addImageMutation = useMutation({
    mutationFn: (fd) => groundsApi.addImage(id, fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', id] })
      notify.success('Image uploaded')
      if (imageInputRef.current) imageInputRef.current.value = ''
    },
    onError: () => notify.error('Failed to upload image'),
  })

  const deleteImageMutation = useMutation({
    mutationFn: (imageId) => groundsApi.deleteImage(id, imageId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', id] })
      notify.success('Image deleted')
      setDeleteImageTarget(null)
    },
    onError: () => notify.error('Failed to delete image'),
  })

  // ── Edit ground mutation ───────────────────────────────────────────────────
  const updateGroundMutation = useMutation({
    mutationFn: (fd) => groundsApi.update(id, fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['owner', 'ground', id] })
      notify.success('Ground updated successfully')
      setEditDrawerOpen(false)
      setEditImageFile(null)
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to update ground'),
  })

  // ── Handlers ──────────────────────────────────────────────────────────────

  const handleOpenSportEdit = (gs) => {
    setEditSportGsId(gs.id)
    setEditSportName(gs.sport?.name ?? `Sport #${gs.sport_id}`)
    // Populate schedule from existing data
    const scheduleGs = scheduleGroundSports.find((g) => g.id === gs.id)
    const existingSchedules = scheduleGs?.schedules ?? []
    setWeekSchedule(
      DAYS.map((_, i) => {
        const existing = existingSchedules.find((s) => s.day_of_week === i)
        if (existing) {
          return {
            day_of_week: i,
            start_time: (existing.start_time || '06:00:00').slice(0, 5),
            end_time: (existing.end_time || '22:00:00').slice(0, 5),
            is_closed: existing.is_closed || false,
          }
        }
        return { day_of_week: i, ...DEFAULT_DAY_SCHEDULE }
      })
    )
    setEditSportDrawerOpen(true)
  }

  const handleDayChange = (dayIndex, field, value) => {
    setWeekSchedule((prev) =>
      prev.map((d, i) => (i === dayIndex ? { ...d, [field]: value } : d))
    )
  }

  const handleCopyToAll = () => {
    const firstOpen = weekSchedule.find((d) => !d.is_closed)
    if (!firstOpen) {
      notify.warning('No open day to copy from')
      return
    }
    setWeekSchedule((prev) =>
      prev.map((d) => ({
        ...d,
        start_time: firstOpen.start_time,
        end_time: firstOpen.end_time,
      }))
    )
  }

  const handleSaveSchedule = () => {
    if (!editSportGsId) return
    upsertScheduleMutation.mutate({
      ground_sport_id: Number(editSportGsId),
      schedules: weekSchedule.map((d) => ({
        day_of_week: d.day_of_week,
        start_time: d.start_time + ':00',
        end_time: d.end_time + ':00',
        is_closed: d.is_closed,
      })),
    })
  }

  const handleOpenEdit = () => {
    setEditForm({
      name: ground?.name ?? '',
      description: ground?.description ?? '',
      about: ground?.about ?? '',
      venue_rules: ground?.venue_rules ?? '',
      address: ground?.address ?? '',
      latitude: ground?.latitude ?? '',
      longitude: ground?.longitude ?? '',
      contact_number: ground?.contact_number ?? '',
      open_for_booking: ground?.open_for_booking ?? true,
    })
    setEditImageFile(null)
    setEditDrawerOpen(true)
  }

  const handleEditSubmit = () => {
    if (!editForm.name.trim()) {
      notify.warning('Ground name is required')
      return
    }
    const fd = new FormData()
    Object.entries(editForm).forEach(([k, v]) => {
      if (k === 'open_for_booking') {
        fd.append(k, v ? 'true' : 'false')
      } else if (v !== '') {
        fd.append(k, v)
      }
    })
    if (editImageFile) fd.append('cover_image', editImageFile)
    updateGroundMutation.mutate(fd)
  }

  const images = ground?.images ?? []
  const availableAmenities = allAmenities.filter(
    (a) => !groundAmenities.some((ga) => (ga.id ?? ga.amenity_id) === a.id)
  )

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader
        title={gLoad ? 'Loading…' : (ground?.name ?? 'Ground Detail')}
        breadcrumbs={[
          { label: 'My Grounds', href: '/owner/grounds' },
          { label: ground?.name ?? `Ground #${id}` },
        ]}
      />

      <Paper sx={{ px: 1, mb: 3 }}>
        <Tabs value={tab} onChange={(_, v) => setTab(v)} variant="scrollable">
          <Tab label="Details" />
          <Tab label="Sports & Pricing" />
          <Tab label="Amenities" />
          <Tab label="Images" />
        </Tabs>
      </Paper>

      {/* ── Tab 0: Details ──────────────────────────────────────────────── */}
      <TabPanel value={tab} index={0}>
        <Paper sx={{ p: 3 }}>
          <Box display="flex" justifyContent="flex-end" mb={2}>
            <Button variant="outlined" startIcon={<EditIcon />} onClick={handleOpenEdit}
              disabled={gLoad}>
              Edit Ground
            </Button>
          </Box>
          {gLoad ? (
            <Typography color="text.secondary">Loading ground details…</Typography>
          ) : (
            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <InfoField label="Name" value={ground?.name} />
                <InfoField label="Address" value={ground?.address} />
                <InfoField label="Contact Number" value={ground?.contact_number} />
              </Grid>
              <Grid item xs={12} md={6}>
                <InfoField label="Latitude" value={ground?.latitude} />
                <InfoField label="Longitude" value={ground?.longitude} />
                <InfoField label="Created At"
                  value={ground?.created_at ? dayjs(ground.created_at).format('DD MMM YYYY') : null} />
                <Box display="flex" gap={1} flexWrap="wrap" mt={1}>
                  <StatusChip status={ground?.is_active ? 'active' : 'inactive'} />
                  <Chip
                    label={ground?.is_approved ? 'Approved' : 'Pending Approval'}
                    color={ground?.is_approved ? 'success' : 'warning'}
                    size="small" sx={{ fontWeight: 600 }}
                  />
                  <Chip
                    label={ground?.open_for_booking ? 'Open for Booking' : 'Closed'}
                    color={ground?.open_for_booking ? 'info' : 'default'}
                    size="small" sx={{ fontWeight: 600 }}
                  />
                </Box>
              </Grid>
              {ground?.description && (
                <Grid item xs={12} md={6}>
                  <Typography variant="caption" color="text.secondary" fontWeight={600} display="block" mb={0.5}>
                    Description
                  </Typography>
                  <Typography variant="body2">{ground.description}</Typography>
                </Grid>
              )}
              {ground?.about && (
                <Grid item xs={12} md={6}>
                  <Typography variant="caption" color="text.secondary" fontWeight={600} display="block" mb={0.5}>
                    About
                  </Typography>
                  <Typography variant="body2">{ground.about}</Typography>
                </Grid>
              )}
              {ground?.venue_rules && (
                <Grid item xs={12}>
                  <Typography variant="caption" color="text.secondary" fontWeight={600} display="block" mb={0.5}>
                    Venue Rules
                  </Typography>
                  <Typography variant="body2">{ground.venue_rules}</Typography>
                </Grid>
              )}
            </Grid>
          )}
        </Paper>
      </TabPanel>

      {/* ── Tab 1: Sports & Pricing ──────────────────────────────────────── */}
      <TabPanel value={tab} index={1}>
        <Box display="flex" justifyContent="flex-end" mb={2}>
          <Button variant="contained" startIcon={<AddIcon />}
            onClick={() => { setSportForm(EMPTY_SPORT); setSportDialogOpen(true) }}>
            Add Sport
          </Button>
        </Box>

        {groundSportsList.length === 0 ? (
          <Paper sx={{ p: 4 }}>
            <EmptyState message="No sports configured for this ground yet." />
          </Paper>
        ) : (
          <Stack spacing={1.5}>
            {groundSportsList.map((gs) => (
              <Paper key={gs.id} sx={{ p: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box>
                  <Typography fontWeight={600}>{gs.sport?.name ?? `Sport #${gs.sport_id}`}</Typography>
                  <Typography variant="caption" color="text.secondary">
                    ₨{gs.price_per_half_hour}/30min · min {gs.min_slots} slot · max {gs.max_slots} slots
                    {gs.player_counts ? ` · ${gs.player_counts} players` : ''}
                  </Typography>
                </Box>
                <Box display="flex" alignItems="center" gap={1}>
                  <StatusChip status={gs.is_active ? 'active' : 'inactive'} />
                  <Tooltip title="Edit schedule & slots">
                    <IconButton size="small" color="primary"
                      onClick={() => handleOpenSportEdit(gs)}>
                      <ScheduleIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                  <Tooltip title="Remove sport">
                    <IconButton size="small" color="error"
                      onClick={() => setDeleteSportTarget({ id: gs.id, name: gs.sport?.name })}>
                      <DeleteOutlineIcon fontSize="small" />
                    </IconButton>
                  </Tooltip>
                </Box>
              </Paper>
            ))}
          </Stack>
        )}

        {/* Add sport dialog */}
        <Dialog open={sportDialogOpen} onClose={() => setSportDialogOpen(false)} maxWidth="sm" fullWidth>
          <DialogTitle>Add Sport to Ground</DialogTitle>
          <DialogContent>
            <Stack spacing={2.5} mt={1}>
              <FormControl size="small" fullWidth required>
                <InputLabel>Sport</InputLabel>
                <Select
                  value={sportForm.sport_id}
                  onChange={(e) => setSportForm((p) => ({ ...p, sport_id: e.target.value }))}
                  label="Sport"
                >
                  {allSports.map((s) => (
                    <MenuItem key={s.id} value={s.id}>{s.name}</MenuItem>
                  ))}
                  {allSports.length === 0 && (
                    <MenuItem disabled>Loading sports…</MenuItem>
                  )}
                </Select>
              </FormControl>
              <TextField label="Price per 30 min (PKR)" type="number" size="small" fullWidth
                value={sportForm.price_per_half_hour}
                onChange={(e) => setSportForm((p) => ({ ...p, price_per_half_hour: e.target.value }))}
              />
              <Grid container spacing={2}>
                <Grid item xs={6}>
                  <TextField label="Min Slots" type="number" size="small" fullWidth
                    value={sportForm.min_slots}
                    onChange={(e) => setSportForm((p) => ({ ...p, min_slots: e.target.value }))}
                  />
                </Grid>
                <Grid item xs={6}>
                  <TextField label="Max Slots" type="number" size="small" fullWidth
                    value={sportForm.max_slots}
                    onChange={(e) => setSportForm((p) => ({ ...p, max_slots: e.target.value }))}
                  />
                </Grid>
              </Grid>
            </Stack>
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2 }}>
            <Button onClick={() => setSportDialogOpen(false)}>Cancel</Button>
            <Button variant="contained"
              disabled={!sportForm.sport_id || addSportMutation.isPending}
              onClick={() => addSportMutation.mutate({
                sport_id: Number(sportForm.sport_id),
                price_per_half_hour: Number(sportForm.price_per_half_hour) || 0,
                min_slots: Number(sportForm.min_slots) || 1,
                max_slots: Number(sportForm.max_slots) || 8,
              })}
              startIcon={addSportMutation.isPending ? <CircularProgress size={16} color="inherit" /> : null}
            >
              Add
            </Button>
          </DialogActions>
        </Dialog>

        <ConfirmDialog
          open={Boolean(deleteSportTarget)}
          onClose={() => setDeleteSportTarget(null)}
          onConfirm={() => removeSportMutation.mutate(deleteSportTarget?.id)}
          title="Remove Sport"
          message={`Remove "${deleteSportTarget?.name}" from this ground? Associated slots will be affected.`}
          confirmLabel="Remove"
          loading={removeSportMutation.isPending}
        />
      </TabPanel>

      {/* ── Tab 2: Amenities ─────────────────────────────────────────────── */}
      <TabPanel value={tab} index={2}>
        <Box display="flex" justifyContent="flex-end" mb={2}>
          <Button variant="contained" startIcon={<AddIcon />}
            onClick={() => { setSelectedAmenityId(''); setAddAmenityOpen(true) }}>
            Add Amenity
          </Button>
        </Box>

        {groundAmenities.length === 0 ? (
          <Paper sx={{ p: 4 }}>
            <EmptyState message="No amenities configured for this ground yet." />
          </Paper>
        ) : (
          <Stack spacing={1.5}>
            {groundAmenities.map((a) => (
              <Paper key={a.id} sx={{ p: 2, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Box display="flex" alignItems="center" gap={1.5}>
                  {(a.icon_url || a.image_url) && (
                    <Box component="img" src={a.icon_url ?? a.image_url} alt={a.name}
                      sx={{ width: 32, height: 32, objectFit: 'cover', borderRadius: 1 }} />
                  )}
                  <Box>
                    <Typography fontWeight={600}>{a.name ?? '—'}</Typography>
                    {a.description && (
                      <Typography variant="caption" color="text.secondary">{a.description}</Typography>
                    )}
                  </Box>
                </Box>
                <Tooltip title="Remove amenity">
                  <IconButton size="small" color="error"
                    onClick={() => setDeleteAmenityTarget({ id: a.id, name: a.name })}>
                    <DeleteOutlineIcon fontSize="small" />
                  </IconButton>
                </Tooltip>
              </Paper>
            ))}
          </Stack>
        )}

        {/* Add amenity dialog */}
        <Dialog open={addAmenityOpen} onClose={() => setAddAmenityOpen(false)} maxWidth="xs" fullWidth>
          <DialogTitle>Add Amenity</DialogTitle>
          <DialogContent>
            <FormControl size="small" fullWidth sx={{ mt: 1 }}>
              <InputLabel>Amenity</InputLabel>
              <Select
                value={selectedAmenityId}
                onChange={(e) => setSelectedAmenityId(e.target.value)}
                label="Amenity"
              >
                {availableAmenities.map((a) => (
                  <MenuItem key={a.id} value={a.id}>{a.name}</MenuItem>
                ))}
                {availableAmenities.length === 0 && (
                  <MenuItem disabled>No amenities available to add</MenuItem>
                )}
              </Select>
            </FormControl>
          </DialogContent>
          <DialogActions sx={{ px: 3, pb: 2 }}>
            <Button onClick={() => setAddAmenityOpen(false)}>Cancel</Button>
            <Button variant="contained"
              disabled={!selectedAmenityId || addAmenityMutation.isPending}
              onClick={() => addAmenityMutation.mutate(selectedAmenityId)}
              startIcon={addAmenityMutation.isPending ? <CircularProgress size={16} color="inherit" /> : null}
            >
              Add
            </Button>
          </DialogActions>
        </Dialog>

        <ConfirmDialog
          open={Boolean(deleteAmenityTarget)}
          onClose={() => setDeleteAmenityTarget(null)}
          onConfirm={() => removeAmenityMutation.mutate(deleteAmenityTarget?.id)}
          title="Remove Amenity"
          message={`Remove "${deleteAmenityTarget?.name}" from this ground?`}
          confirmLabel="Remove"
          loading={removeAmenityMutation.isPending}
        />
      </TabPanel>

      {/* ── Tab 3: Images ───────────────────────────────────────────────── */}
      <TabPanel value={tab} index={3}>
        <Box display="flex" justifyContent="flex-end" mb={2} gap={2}>
          <Button
            variant="contained" startIcon={<AddIcon />}
            component="label"
            disabled={addImageMutation.isPending}
          >
            {addImageMutation.isPending ? 'Uploading…' : 'Upload Image'}
            <input
              hidden ref={imageInputRef} type="file" accept="image/*"
              onChange={(e) => {
                const file = e.target.files[0]
                if (!file) return
                const fd = new FormData()
                fd.append('image', file)
                addImageMutation.mutate(fd)
              }}
            />
          </Button>
        </Box>

        {images.length === 0 ? (
          <Paper sx={{ p: 4 }}>
            <EmptyState message="No images uploaded yet." />
          </Paper>
        ) : (
          <ImageList cols={3} gap={12}>
            {images.map((img) => (
              <ImageListItem key={img.id} sx={{ borderRadius: 2, overflow: 'hidden', border: '1px solid rgba(0,0,0,0.08)' }}>
                <img
                  src={img.image}
                  alt={`ground-${img.id}`}
                  style={{ width: '100%', height: 180, objectFit: 'cover', display: 'block' }}
                  onError={(e) => { e.target.style.display = 'none' }}
                />
                <ImageListItemBar
                  position="top"
                  actionIcon={
                    <IconButton size="small" sx={{ color: '#fff', mr: 0.5 }}
                      onClick={() => setDeleteImageTarget({ id: img.id })}>
                      <DeleteOutlineIcon fontSize="small" />
                    </IconButton>
                  }
                  sx={{ background: 'linear-gradient(rgba(0,0,0,0.5),transparent)' }}
                  title={img.is_primary ? '⭐ Primary' : ''}
                />
              </ImageListItem>
            ))}
          </ImageList>
        )}

        <ConfirmDialog
          open={Boolean(deleteImageTarget)}
          onClose={() => setDeleteImageTarget(null)}
          onConfirm={() => deleteImageMutation.mutate(deleteImageTarget?.id)}
          title="Delete Image"
          message="Delete this image permanently?"
          confirmLabel="Delete"
          loading={deleteImageMutation.isPending}
        />
      </TabPanel>

      {/* ── Edit Ground Drawer ───────────────────────────────────────────── */}
      <DrawerForm
        open={editDrawerOpen}
        onClose={() => setEditDrawerOpen(false)}
        title="Edit Ground"
        onSubmit={handleEditSubmit}
        loading={updateGroundMutation.isPending}
        submitLabel="Save Changes"
        width={500}
      >
        <Stack spacing={2.5}>
          <TextField label="Ground Name" value={editForm.name} size="small" fullWidth required
            onChange={(e) => setEditForm((p) => ({ ...p, name: e.target.value }))} />
          <TextField label="Description" value={editForm.description} size="small" fullWidth multiline rows={3}
            onChange={(e) => setEditForm((p) => ({ ...p, description: e.target.value }))} />
          <TextField label="About" value={editForm.about} size="small" fullWidth multiline rows={3}
            placeholder="Detailed info about the ground…"
            onChange={(e) => setEditForm((p) => ({ ...p, about: e.target.value }))} />
          <TextField label="Venue Rules" value={editForm.venue_rules} size="small" fullWidth multiline rows={3}
            placeholder="Rules for players at this venue…"
            onChange={(e) => setEditForm((p) => ({ ...p, venue_rules: e.target.value }))} />
          <TextField label="Address" value={editForm.address} size="small" fullWidth
            onChange={(e) => setEditForm((p) => ({ ...p, address: e.target.value }))} />
          <Stack direction="row" spacing={2}>
            <TextField label="Latitude" type="number" value={editForm.latitude} size="small" fullWidth
              inputProps={{ step: 'any' }}
              onChange={(e) => setEditForm((p) => ({ ...p, latitude: e.target.value }))} />
            <TextField label="Longitude" type="number" value={editForm.longitude} size="small" fullWidth
              inputProps={{ step: 'any' }}
              onChange={(e) => setEditForm((p) => ({ ...p, longitude: e.target.value }))} />
          </Stack>
          <TextField label="Contact Number" value={editForm.contact_number} size="small" fullWidth
            onChange={(e) => setEditForm((p) => ({ ...p, contact_number: e.target.value }))} />
          <FormControlLabel
            control={
              <Switch
                checked={editForm.open_for_booking}
                onChange={(e) => setEditForm((p) => ({ ...p, open_for_booking: e.target.checked }))}
              />
            }
            label="Open for Booking"
          />
          <Box>
            <Typography variant="caption" color="text.secondary" mb={0.5} display="block">
              Cover Image (optional — leave blank to keep current)
            </Typography>
            <input
              ref={editFileRef}
              type="file"
              accept="image/*"
              style={{ display: 'block', fontSize: 14 }}
              onChange={(e) => setEditImageFile(e.target.files?.[0] ?? null)}
            />
            {editImageFile && (
              <Typography variant="caption" color="text.secondary" mt={0.5} display="block">
                Selected: {editImageFile.name}
              </Typography>
            )}
          </Box>
        </Stack>
      </DrawerForm>

      {/* ── Edit Sport Schedule Drawer ─────────────────────────────────────── */}
      <DrawerForm
        open={editSportDrawerOpen}
        onClose={() => setEditSportDrawerOpen(false)}
        title={`Schedule — ${editSportName}`}
        onSubmit={handleSaveSchedule}
        loading={upsertScheduleMutation.isPending}
        submitLabel="Save Schedule"
        width={600}
      >
        <Stack spacing={2.5}>
          <Typography variant="subtitle2" color="text.secondary">
            Set operating hours for each day. 30-min slots are auto-generated when users browse a date.
          </Typography>

          {weekSchedule.map((day, i) => (
            <Paper key={i} variant="outlined" sx={{ p: 1.5 }}>
              <Grid container spacing={1.5} alignItems="center">
                <Grid item xs={3}>
                  <Typography variant="body2" fontWeight={600} color={day.is_closed ? 'text.disabled' : 'text.primary'}>
                    {DAYS[i].slice(0, 3)}
                  </Typography>
                </Grid>
                <Grid item xs={3}>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={!day.is_closed}
                        onChange={(e) => handleDayChange(i, 'is_closed', !e.target.checked)}
                        size="small"
                      />
                    }
                    label={day.is_closed ? 'Closed' : 'Open'}
                    componentsProps={{ typography: { variant: 'caption' } }}
                    sx={{ m: 0 }}
                  />
                </Grid>
                <Grid item xs={3}>
                  <TextField
                    type="time" size="small" fullWidth
                    value={day.start_time}
                    onChange={(e) => handleDayChange(i, 'start_time', e.target.value)}
                    InputLabelProps={{ shrink: true }}
                    disabled={day.is_closed}
                  />
                </Grid>
                <Grid item xs={3}>
                  <TextField
                    type="time" size="small" fullWidth
                    value={day.end_time}
                    onChange={(e) => handleDayChange(i, 'end_time', e.target.value)}
                    InputLabelProps={{ shrink: true }}
                    disabled={day.is_closed}
                  />
                </Grid>
              </Grid>
            </Paper>
          ))}

          <Button variant="outlined" size="small" startIcon={<ContentCopyIcon />}
            onClick={handleCopyToAll} sx={{ alignSelf: 'flex-start' }}>
            Copy first open day to all
          </Button>
        </Stack>
      </DrawerForm>
    </Box>
  )
}
