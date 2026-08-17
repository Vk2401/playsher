import React, { useMemo, useState } from 'react'
import {
  Box,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Select,
  Tooltip,
  Typography,
} from '@mui/material'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import dayjs from 'dayjs'

import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import StarIcon from '@mui/icons-material/Star'
import StarBorderIcon from '@mui/icons-material/StarBorder'

import PageHeader from '../../components/ui/PageHeader.jsx'
import DataTable from '../../components/ui/DataTable.jsx'
import ConfirmDialog from '../../components/ui/ConfirmDialog.jsx'
import { useNotify } from '../../hooks/useNotify.js'
import { reviewsApi } from '../../api/reviews.js'

// Render rating as filled/empty stars
function StarRating({ value }) {
  const count = Math.round(Number(value) || 0)
  return (
    <Box display="flex" alignItems="center" gap={0.25}>
      {Array.from({ length: 5 }, (_, i) =>
        i < count ? (
          <StarIcon key={i} sx={{ fontSize: 16, color: '#F4A261' }} />
        ) : (
          <StarBorderIcon key={i} sx={{ fontSize: 16, color: 'text.disabled' }} />
        ),
      )}
      <Typography variant="caption" ml={0.5} color="text.secondary">
        {count}/5
      </Typography>
    </Box>
  )
}

export default function AdminReviews() {
  const queryClient = useQueryClient()
  const notify = useNotify()

  const [ratingFilter, setRatingFilter] = useState('all')
  const [deleteTarget, setDeleteTarget] = useState(null) // { id }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  const { data, isLoading, error } = useQuery({
    queryKey: ['admin', 'reviews'],
    queryFn: () => reviewsApi.getAll(),
    select: (res) => res.data,
  })

  const reviews = useMemo(() => {
    const raw = data?.reviews ?? data?.data ?? data ?? []
    if (ratingFilter === 'all') return raw
    return raw.filter((r) => String(r.rating) === String(ratingFilter))
  }, [data, ratingFilter])

  // ── Mutations ─────────────────────────────────────────────────────────────
  const deleteMutation = useMutation({
    mutationFn: (id) => reviewsApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'reviews'] })
      notify.success('Review deleted successfully')
      setDeleteTarget(null)
    },
    onError: () => notify.error('Failed to delete review'),
  })

  // ── Columns ───────────────────────────────────────────────────────────────
  const columns = [
    {
      field: 'id',
      headerName: 'ID',
      width: 70,
    },
    {
      field: 'user_name',
      headerName: 'User',
      flex: 1,
      minWidth: 160,
      renderCell: ({ row }) => {
        const name = row.user?.name ?? row.user_name ?? '—'
        const email = row.user?.email ?? row.user_email ?? ''
        return (
          <Box>
            <Typography variant="body2" fontWeight={500} lineHeight={1.3}>
              {name}
            </Typography>
            {email && (
              <Typography variant="caption" color="text.secondary">
                {email}
              </Typography>
            )}
          </Box>
        )
      },
    },
    {
      field: 'ground_name',
      headerName: 'Ground',
      flex: 1,
      minWidth: 140,
      renderCell: ({ row }) =>
        row.ground?.name ?? row.ground_name ?? '—',
    },
    {
      field: 'rating',
      headerName: 'Rating',
      width: 160,
      renderCell: ({ value }) => <StarRating value={value} />,
    },
    {
      field: 'comment',
      headerName: 'Comment',
      flex: 1.5,
      minWidth: 200,
      renderCell: ({ value }) => {
        if (!value) return <Typography variant="body2" color="text.disabled">—</Typography>
        const truncated = value.length > 80 ? `${value.slice(0, 80)}…` : value
        return (
          <Tooltip title={value.length > 80 ? value : ''} placement="top">
            <Typography variant="body2" color="text.secondary" sx={{ cursor: value.length > 80 ? 'help' : 'default' }}>
              {truncated}
            </Typography>
          </Tooltip>
        )
      },
    },
    {
      field: 'created_at',
      headerName: 'Date',
      width: 130,
      renderCell: ({ value }) =>
        value ? dayjs(value).format('DD MMM YYYY') : '—',
    },
    {
      field: '_actions',
      headerName: 'Actions',
      width: 80,
      sortable: false,
      filterable: false,
      renderCell: ({ row }) => (
        <Box display="flex" alignItems="center">
          <Tooltip title="Delete review">
            <span>
              <IconButton
                size="small"
                color="error"
                onClick={() => setDeleteTarget({ id: row.id })}
              >
                <DeleteOutlineIcon fontSize="small" />
              </IconButton>
            </span>
          </Tooltip>
        </Box>
      ),
    },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <Box>
      <PageHeader title="Reviews" subtitle="User reviews for grounds" />

      {/* Rating filter */}
      <Box mb={2}>
        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Rating</InputLabel>
          <Select
            value={ratingFilter}
            label="Rating"
            onChange={(e) => setRatingFilter(e.target.value)}
          >
            <MenuItem value="all">All Ratings</MenuItem>
            {[5, 4, 3, 2, 1].map((r) => (
              <MenuItem key={r} value={String(r)}>
                {r} Star{r !== 1 ? 's' : ''}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
      </Box>

      <DataTable
        rows={reviews}
        columns={columns}
        loading={isLoading}
        error={error}
      />

      {/* Delete confirmation */}
      <ConfirmDialog
        open={Boolean(deleteTarget)}
        onClose={() => setDeleteTarget(null)}
        onConfirm={() => deleteMutation.mutate(deleteTarget.id)}
        loading={deleteMutation.isPending}
        title="Delete Review"
        message="Are you sure you want to permanently delete this review? This action cannot be undone."
        confirmLabel="Delete"
        confirmColor="error"
      />
    </Box>
  )
}
