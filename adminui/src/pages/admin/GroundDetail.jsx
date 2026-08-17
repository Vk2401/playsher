import React, { useState } from 'react'
import {
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  FormControlLabel,
  Grid,
  IconButton,
  ImageList,
  ImageListItem,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Skeleton,
  Stack,
  Switch,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useParams } from 'react-router-dom'
import dayjs from 'dayjs'

import LocationOnIcon from '@mui/icons-material/LocationOn'
import PersonIcon from '@mui/icons-material/Person'
import SportsIcon from '@mui/icons-material/Sports'
import CheckCircleIcon from '@mui/icons-material/CheckCircle'
import CancelIcon from '@mui/icons-material/Cancel'
import AddIcon from '@mui/icons-material/Add'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import EditIcon from '@mui/icons-material/Edit'

import { groundOwnersApi } from '../../api/groundOwners.js'
import PageHeader from '../../components/ui/PageHeader.jsx'
import StatusChip from '../../components/ui/StatusChip.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import DrawerForm from '../../components/ui/DrawerForm.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { groundsApi } from '../../api/grounds.js'
import { sportsApi } from '../../api/sports.js'
import { amenitiesApi } from '../../api/amenities.js'

// ── Small helpers ─────────────────────────────────────────────────────────────

function TabPanel({ children, value, index }) {
  return (
    <Box role="tabpanel" hidden={value !== index} pt={3}>
      {value === index && children}
    </Box>
  )
}

function DetailRow({ label, value }) {
  return (
    <Box py={1.25} display="flex" alignItems="flex-start" gap={2}>
      <Typography
        variant="body2"
        color="text.secondary"
        sx={{ minWidth: 140, flexShrink: 0, fontWeight: 500 }}
      >
        {label}
      </Typography>
      <Typography variant="body2" sx={{ wordBreak: 'break-word' }}>
        {value ?? '—'}
      </Typography>
    </Box>
  )
}

function BoolChip({ value }) {
  return value ? (
    <Chip
      icon={<CheckCircleIcon fontSize="small" />}
      label="Yes"
      color="success"
      size="small"
      sx={{ fontWeight: 600 }}
    />
  ) : (
    <Chip
      icon={<CancelIcon fontSize="small" />}
      label="No"
      color="default"
      size="small"
      sx={{ fontWeight: 600 }}
    />
  )
}

function SkeletonDetail() {
  return (
    <Box>
      <Box mb={3}>
        <Skeleton width={240} height={32} />
        <Skeleton width={160} height={20} sx={{ mt: 0.5 }} />
      </Box>
      <Paper sx={{ p: 3 }}>
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} height={36} sx={{ mb: 0.5 }} />
        ))}
      </Paper>
    </Box>
  )
}

const EMPTY_SPORT_FORM = { sport_id: '', price_per_half_hour: '', min_slots: 1, max_slots: 4 }

// ── Main component ─────────────────────────────────────────────────────────────

export default function AdminGroundDetail() {
  const { id } = useParams()
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [tab, setTab] = useState(0)

  // Sports dialog state
  const [addSportOpen, setAddSportOpen] = useState(false)
  const [sportForm, setSportForm] = useState(EMPTY_SPORT_FORM)
  const [deleteSportTarget, setDeleteSportTarget] = useState(null)

  // Amenities dialog state
  const [addAmenityOpen, setAddAmenityOpen] = useState(false)
  const [selectedAmenityId, setSelectedAmenityId] = useState('')
  const [deleteAmenityTarget, setDeleteAmenityTarget] = useState(null)

  // Edit ground drawer state
  const [editDrawerOpen, setEditDrawerOpen] = useState(false)
  const [editForm, setEditForm] = useState({
    name: '', description: '', about: '', venue_rules: '',
    address: '', latitude: '', longitude: '', contact_number: '', open_for_booking: true, owner_id: '',
  })

  const { data: ground, isLoading, error } = useQuery({
    queryKey: ['admin', 'ground', id],
    queryFn: () => groundsApi.getById(id),
    select: (res) => res.data?.data ?? res.data,
    enabled: Boolean(id),
  })

  const { data: ownersData } = useQuery({
    queryKey: ['admin', 'ground-owners'],
    queryFn: () => groundOwnersApi.getAll(),
    select: (res) => res.data,
  })
  const owners = ownersData?.owners ?? ownersData?.ground_owners ?? ownersData?.data ?? ownersData ?? []

  // Sports list for dropdown
  const { data: allSportsData } = useQuery({
    queryKey: ['sports', 'public'],
    queryFn: () => sportsApi.listPublic({ limit: 100 }),
    select: (res) => res.data,
    enabled: addSportOpen,
  })
  const allSports = allSportsData?.data ?? []

  // Amenities list for dropdown
  const { data: allAmenitiesData } = useQuery({
    queryKey: ['amenities', 'public'],
    queryFn: () => amenitiesApi.listPublic({ limit: 100 }),
    select: (res) => res.data,
    enabled: addAmenityOpen,
  })
  const allAmenities = allAmenitiesData?.data ?? []

  // ── Mutations ─────────────────────────────────────────────────────────────
  const addSportMutation = useMutation({
    mutationFn: (data) => groundsApi.adminAddSport(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground', id] })
      notify.success('Sport added to ground')
      setAddSportOpen(false)
      setSportForm(EMPTY_SPORT_FORM)
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to add sport'),
  })

  const removeSportMutation = useMutation({
    mutationFn: (sportId) => groundsApi.adminRemoveSport(id, sportId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground', id] })
      notify.success('Sport removed')
      setDeleteSportTarget(null)
    },
    onError: () => notify.error('Failed to remove sport'),
  })

  const addAmenityMutation = useMutation({
    mutationFn: (amenityId) => groundsApi.adminAddAmenity(id, amenityId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground', id] })
      notify.success('Amenity added')
      setAddAmenityOpen(false)
      setSelectedAmenityId('')
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to add amenity'),
  })

  const removeAmenityMutation = useMutation({
    mutationFn: (amenityId) => groundsApi.adminRemoveAmenity(id, amenityId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground', id] })
      notify.success('Amenity removed')
      setDeleteAmenityTarget(null)
    },
    onError: () => notify.error('Failed to remove amenity'),
  })

  const updateGroundMutation = useMutation({
    mutationFn: (fd) => groundsApi.adminUpdate(id, fd),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'ground', id] })
      notify.success('Ground updated successfully')
      setEditDrawerOpen(false)
    },
    onError: (e) => notify.error(e?.response?.data?.message || 'Failed to update ground'),
  })

  // ── Handlers ──────────────────────────────────────────────────────────────
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
      open_for_booking: ground?.open_for_booking ?? ground?.is_booking_open ?? true,
      owner_id: ground?.owner_id ?? ground?.user_id ?? '',
    })
    setEditDrawerOpen(true)
  }

  const handleEditSubmit = () => {
    if (!editForm.name.trim()) {
      notify.warning('Ground name is required')
      return
    }
    const payload = {}
    Object.entries(editForm).forEach(([k, v]) => {
      if (v !== '' && v != null) {
        if (k === 'latitude' || k === 'longitude') payload[k] = parseFloat(v)
        else if (k === 'owner_id') payload[k] = Number(v)
        else payload[k] = v
      }
    })
    updateGroundMutation.mutate(payload)
  }

  if (isLoading) return <SkeletonDetail />

  if (error) {
    return (
      <Paper sx={{ p: 4, textAlign: 'center' }}>
        <Typography color="error">
          Failed to load ground details: {error.message}
        </Typography>
      </Paper>
    )
  }

  const owner = ground?.owner ?? {}
  const groundSports = ground?.groundSports ?? []
  const amenities = ground?.amenities ?? []
  const images = ground?.images ?? ground?.slider_images ?? []

  const availableAmenities = allAmenities.filter(
    (a) => !amenities.some((ga) => ga.id === a.id)
  )

  return (
    <Box>
      <PageHeader
        title={ground?.name ?? 'Ground Detail'}
        subtitle={ground?.city ?? ground?.location ?? undefined}
        breadcrumbs={[
          { label: 'Grounds', href: '/admin/grounds' },
          { label: ground?.name ?? `Ground #${id}` },
        ]}
      />

      {/* ── Tabs ──────────────────────────────────────────────────────────── */}
      <Paper sx={{ mb: 3 }}>
        <Tabs
          value={tab}
          onChange={(_, v) => setTab(v)}
          sx={{
            px: 2,
            borderBottom: '1px solid',
            borderColor: 'divider',
            '& .MuiTab-root': { textTransform: 'none', fontWeight: 600 },
          }}
        >
          <Tab label="Overview" />
          <Tab label={`Sports (${groundSports.length})`} />
          <Tab label={`Amenities (${amenities.length})`} />
          <Tab label={`Images (${images.length})`} />
        </Tabs>

        {/* ── OVERVIEW TAB ──────────────────────────────────────────────── */}
        <TabPanel value={tab} index={0}>
          <Box display="flex" justifyContent="flex-end" mb={2} px={3} pt={1}>
            <Button variant="outlined" startIcon={<EditIcon />} onClick={handleOpenEdit}>
              Edit Ground
            </Button>
          </Box>
          <Grid container spacing={3} px={3} pb={3}>
            {/* Ground info card */}
            <Grid item xs={12} md={6}>
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                <Box display="flex" alignItems="center" gap={1} mb={1.5}>
                  <SportsIcon color="primary" fontSize="small" />
                  <Typography variant="subtitle2" fontWeight={700}>
                    Ground Information
                  </Typography>
                </Box>
                <Divider sx={{ mb: 1.5 }} />

                <DetailRow label="Ground ID" value={ground?.id} />
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow label="Name" value={ground?.name} />
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow label="Description" value={ground?.description} />
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow label="City" value={ground?.city} />
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow label="Address" value={ground?.address} />
                <Divider sx={{ opacity: 0.4 }} />
                <Box py={1.25} display="flex" alignItems="center" gap={2}>
                  <Typography
                    variant="body2"
                    color="text.secondary"
                    sx={{ minWidth: 140, flexShrink: 0, fontWeight: 500 }}
                  >
                    Status
                  </Typography>
                  <StatusChip status={ground?.status ?? 'inactive'} />
                </Box>
                <Divider sx={{ opacity: 0.4 }} />
                <Box py={1.25} display="flex" alignItems="center" gap={2}>
                  <Typography
                    variant="body2"
                    color="text.secondary"
                    sx={{ minWidth: 140, flexShrink: 0, fontWeight: 500 }}
                  >
                    Approved
                  </Typography>
                  <BoolChip value={ground?.is_approved} />
                </Box>
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow
                  label="Price / Hour"
                  value={
                    ground?.price_per_hour
                      ? `₨ ${Number(ground.price_per_hour).toLocaleString()}`
                      : undefined
                  }
                />
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow
                  label="Created"
                  value={
                    ground?.created_at
                      ? dayjs(ground.created_at).format('DD MMM YYYY, hh:mm A')
                      : undefined
                  }
                />
              </Paper>
            </Grid>

            {/* Owner info card */}
            <Grid item xs={12} md={6}>
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2 }}>
                <Box display="flex" alignItems="center" gap={1} mb={1.5}>
                  <PersonIcon color="primary" fontSize="small" />
                  <Typography variant="subtitle2" fontWeight={700}>
                    Owner Information
                  </Typography>
                </Box>
                <Divider sx={{ mb: 1.5 }} />

                <DetailRow
                  label="Owner Name"
                  value={owner.name ?? owner.full_name ?? ground?.owner_name}
                />
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow label="Email" value={owner.email ?? ground?.owner_email} />
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow label="Phone" value={owner.phone ?? ground?.owner_phone} />
                <Divider sx={{ opacity: 0.4 }} />
                <Box py={1.25} display="flex" alignItems="center" gap={2}>
                  <Typography
                    variant="body2"
                    color="text.secondary"
                    sx={{ minWidth: 140, flexShrink: 0, fontWeight: 500 }}
                  >
                    Owner Status
                  </Typography>
                  {owner.status ? (
                    <StatusChip status={owner.status} />
                  ) : (
                    <Typography variant="body2">—</Typography>
                  )}
                </Box>
              </Paper>

              {/* Location card */}
              <Paper variant="outlined" sx={{ p: 2.5, borderRadius: 2, mt: 2.5 }}>
                <Box display="flex" alignItems="center" gap={1} mb={1.5}>
                  <LocationOnIcon color="primary" fontSize="small" />
                  <Typography variant="subtitle2" fontWeight={700}>
                    Location & Booking
                  </Typography>
                </Box>
                <Divider sx={{ mb: 1.5 }} />

                <DetailRow label="Direction URI" value={ground?.direction_uri} />
                <Divider sx={{ opacity: 0.4 }} />
                <Box py={1.25} display="flex" alignItems="center" gap={2}>
                  <Typography
                    variant="body2"
                    color="text.secondary"
                    sx={{ minWidth: 140, flexShrink: 0, fontWeight: 500 }}
                  >
                    Open for Bookings
                  </Typography>
                  <BoolChip value={ground?.is_booking_open ?? ground?.open_for_booking} />
                </Box>
                <Divider sx={{ opacity: 0.4 }} />
                <DetailRow
                  label="Updated"
                  value={
                    ground?.updated_at
                      ? dayjs(ground.updated_at).format('DD MMM YYYY, hh:mm A')
                      : undefined
                  }
                />
              </Paper>
            </Grid>
          </Grid>
        </TabPanel>

        {/* ── SPORTS TAB ──────────────────────────────────────────────────── */}
        <TabPanel value={tab} index={1}>
          <Box px={3} pb={3}>
            <Box display="flex" justifyContent="flex-end" mb={2}>
              <Button variant="contained" startIcon={<AddIcon />}
                onClick={() => { setSportForm(EMPTY_SPORT_FORM); setAddSportOpen(true) }}>
                Add Sport
              </Button>
            </Box>
            {groundSports.length === 0 ? (
              <Typography variant="body2" color="text.secondary" py={4} textAlign="center">
                No sports assigned to this ground yet.
              </Typography>
            ) : (
              <TableContainer component={Paper} variant="outlined">
                <Table size="small">
                  <TableHead>
                    <TableRow sx={{ '& th': { fontWeight: 700, bgcolor: 'rgba(107,158,122,0.06)' } }}>
                      <TableCell>#</TableCell>
                      <TableCell>Sport Name</TableCell>
                      <TableCell>Icon</TableCell>
                      <TableCell>Price / Half Hour</TableCell>
                      <TableCell>Min Slots</TableCell>
                      <TableCell>Max Slots</TableCell>
                      <TableCell align="center">Actions</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {groundSports.map((gs, idx) => {
                      const sport = gs.sport ?? {}
                      return (
                        <TableRow key={gs.id ?? idx} hover sx={{ '&:last-child td': { border: 0 } }}>
                          <TableCell sx={{ color: 'text.secondary', width: 50 }}>{idx + 1}</TableCell>
                          <TableCell>
                            <Typography variant="body2" fontWeight={600}>{sport.name ?? '—'}</Typography>
                          </TableCell>
                          <TableCell>
                            {sport.image ? (
                              <Box component="img" src={sport.image} alt={sport.name}
                                sx={{ width: 36, height: 36, objectFit: 'cover', borderRadius: 1 }} />
                            ) : (
                              <Typography variant="body2" color="text.disabled">—</Typography>
                            )}
                          </TableCell>
                          <TableCell>
                            {gs.price_per_half_hour != null
                              ? `₨ ${Number(gs.price_per_half_hour).toLocaleString()}`
                              : '—'}
                          </TableCell>
                          <TableCell>{gs.min_slots ?? '—'}</TableCell>
                          <TableCell>{gs.max_slots ?? '—'}</TableCell>
                          <TableCell align="center">
                            <Tooltip title="Remove sport">
                              <IconButton size="small" color="error"
                                onClick={() => setDeleteSportTarget({ id: gs.id, name: sport.name })}>
                                <DeleteOutlineIcon fontSize="small" />
                              </IconButton>
                            </Tooltip>
                          </TableCell>
                        </TableRow>
                      )
                    })}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </Box>
        </TabPanel>

        {/* ── AMENITIES TAB ───────────────────────────────────────────────── */}
        <TabPanel value={tab} index={2}>
          <Box px={3} pb={3}>
            <Box display="flex" justifyContent="flex-end" mb={2}>
              <Button variant="contained" startIcon={<AddIcon />}
                onClick={() => { setSelectedAmenityId(''); setAddAmenityOpen(true) }}>
                Add Amenity
              </Button>
            </Box>
            {amenities.length === 0 ? (
              <Typography variant="body2" color="text.secondary" py={4} textAlign="center">
                No amenities listed for this ground.
              </Typography>
            ) : (
              <TableContainer component={Paper} variant="outlined">
                <Table size="small">
                  <TableHead>
                    <TableRow sx={{ '& th': { fontWeight: 700, bgcolor: 'rgba(107,158,122,0.06)' } }}>
                      <TableCell>#</TableCell>
                      <TableCell>Amenity Name</TableCell>
                      <TableCell>Icon</TableCell>
                      <TableCell>Description</TableCell>
                      <TableCell align="center">Actions</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {amenities.map((amenity, idx) => (
                      <TableRow key={amenity.id ?? idx} hover sx={{ '&:last-child td': { border: 0 } }}>
                        <TableCell sx={{ color: 'text.secondary', width: 50 }}>{idx + 1}</TableCell>
                        <TableCell>
                          <Typography variant="body2" fontWeight={600}>{amenity.name ?? '—'}</Typography>
                        </TableCell>
                        <TableCell>
                          {amenity.icon_url || amenity.image_url ? (
                            <Box component="img" src={amenity.icon_url ?? amenity.image_url} alt={amenity.name}
                              sx={{ width: 36, height: 36, objectFit: 'cover', borderRadius: 1 }} />
                          ) : (
                            <Typography variant="body2" color="text.disabled">—</Typography>
                          )}
                        </TableCell>
                        <TableCell sx={{ color: 'text.secondary' }}>{amenity.description ?? '—'}</TableCell>
                        <TableCell align="center">
                          <Tooltip title="Remove amenity">
                            <IconButton size="small" color="error"
                              onClick={() => setDeleteAmenityTarget({ id: amenity.id, name: amenity.name })}>
                              <DeleteOutlineIcon fontSize="small" />
                            </IconButton>
                          </Tooltip>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </TableContainer>
            )}
          </Box>
        </TabPanel>

        {/* ── IMAGES TAB ──────────────────────────────────────────────────── */}
        <TabPanel value={tab} index={3}>
          <Box px={3} pb={3}>
            {images.length === 0 ? (
              <Typography variant="body2" color="text.secondary" py={4} textAlign="center">
                No images uploaded for this ground.
              </Typography>
            ) : (
              <ImageList cols={3} gap={12} sx={{ mt: 0 }}>
                {images.map((img, idx) => {
                  const src = img.image_url ?? img.url ?? img.path ?? img
                  return (
                    <ImageListItem
                      key={img.id ?? idx}
                      sx={{ borderRadius: 2, overflow: 'hidden', border: '1px solid', borderColor: 'divider' }}
                    >
                      <img
                        src={src}
                        alt={`Ground image ${idx + 1}`}
                        loading="lazy"
                        style={{ width: '100%', height: 200, objectFit: 'cover', display: 'block' }}
                        onError={(e) => { e.currentTarget.style.display = 'none' }}
                      />
                    </ImageListItem>
                  )
                })}
              </ImageList>
            )}
          </Box>
        </TabPanel>
      </Paper>

      {/* ── Add Sport Dialog ─────────────────────────────────────────────── */}
      <Dialog open={addSportOpen} onClose={() => setAddSportOpen(false)} maxWidth="sm" fullWidth>
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
                {allSports.length === 0 && <MenuItem disabled>Loading…</MenuItem>}
              </Select>
            </FormControl>
            <TextField label="Price per Half Hour (PKR)" type="number" size="small" fullWidth
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
          <Button onClick={() => setAddSportOpen(false)}>Cancel</Button>
          <Button variant="contained"
            disabled={!sportForm.sport_id || addSportMutation.isPending}
            onClick={() => addSportMutation.mutate({
              sport_id: Number(sportForm.sport_id),
              price_per_half_hour: Number(sportForm.price_per_half_hour) || 0,
              min_slots: Number(sportForm.min_slots) || 1,
              max_slots: Number(sportForm.max_slots) || 4,
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
        message={`Remove "${deleteSportTarget?.name}" from this ground? Associated slots may be affected.`}
        confirmLabel="Remove"
        loading={removeSportMutation.isPending}
      />

      {/* ── Add Amenity Dialog ───────────────────────────────────────────── */}
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

      {/* ── Edit Ground DrawerForm ───────────────────────────────────────── */}
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
            onChange={(e) => setEditForm((p) => ({ ...p, about: e.target.value }))} />
          <TextField label="Venue Rules" value={editForm.venue_rules} size="small" fullWidth multiline rows={3}
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
          <FormControl fullWidth size="small">
            <InputLabel>Ground Owner (optional)</InputLabel>
            <Select
              value={editForm.owner_id}
              label="Ground Owner (optional)"
              onChange={(e) => setEditForm((p) => ({ ...p, owner_id: e.target.value }))}
            >
              <MenuItem value=""><em>None</em></MenuItem>
              {owners.map((o) => (
                <MenuItem key={o.id} value={o.id}>
                  {o.name ?? o.full_name ?? o.email} {o.email ? `(${o.email})` : ''}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <FormControlLabel
            control={
              <Switch
                checked={editForm.open_for_booking}
                onChange={(e) => setEditForm((p) => ({ ...p, open_for_booking: e.target.checked }))}
              />
            }
            label="Open for Booking"
          />
        </Stack>
      </DrawerForm>
    </Box>
  )
}
