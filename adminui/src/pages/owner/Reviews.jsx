import { useQuery } from '@tanstack/react-query'
import { Box, CircularProgress, Rating, Stack, Typography } from '@mui/material'
import dayjs from 'dayjs'
import StarOutlineIcon from '@mui/icons-material/StarOutline'

import { Card, EmptyNote, ScreenHeader, SectionTitle } from '../../components/owner/OwnerBits.jsx'
import { ownerReviewsApi } from '../../api/reviews.owner.js'
import { useOwnerGround } from '../../contexts/OwnerGroundContext.jsx'

/**
 * What players said about this owner's grounds.
 *
 * Read-only. An owner seeing their reviews is feedback; an owner able to edit
 * them is not, so there is no action here and the server offers none either.
 */
export default function OwnerReviews() {
  const { groundId } = useOwnerGround()

  const { data, isLoading, error } = useQuery({
    queryKey: ['owner', 'reviews', { ground_id: groundId }],
    queryFn: () => ownerReviewsApi.list({ ground_id: groundId, limit: 50 }),
    select: (res) => res.data?.data ?? { reviews: [], summary: { count: 0, average: null } },
  })

  const reviews = data?.reviews ?? []
  const summary = data?.summary ?? { count: 0, average: null }

  return (
    <Box>
      <ScreenHeader title="Reviews" subtitle="What players said about your grounds" back="/owner/more" />

      {isLoading && (
        <Box display="flex" justifyContent="center" py={6}><CircularProgress size={26} /></Box>
      )}

      {error && (
        <EmptyNote icon={StarOutlineIcon} title="Could not load reviews" text="Please try again in a moment." />
      )}

      {!isLoading && !error && (
        <>
          {summary.count > 0 && (
            <Card sx={{ px: 2, py: 2, mb: 2 }}>
              <Stack direction="row" spacing={2} alignItems="center">
                <Typography variant="h3" fontWeight={800} sx={{ fontVariantNumeric: 'tabular-nums' }}>
                  {summary.average ?? '—'}
                </Typography>
                <Box>
                  {/* The average is over every review, not the page shown. */}
                  <Rating value={Number(summary.average) || 0} precision={0.1} readOnly size="small" />
                  <Typography variant="body2" color="text.secondary">
                    {summary.count} {summary.count === 1 ? 'review' : 'reviews'}
                  </Typography>
                </Box>
              </Stack>
            </Card>
          )}

          <SectionTitle>Every review</SectionTitle>

          {reviews.length === 0 ? (
            <EmptyNote
              icon={StarOutlineIcon}
              title="No reviews yet"
              text="Once players review a booking at your ground, it shows up here."
            />
          ) : (
            <Card sx={{ px: 2, py: 0.5 }}>
              {reviews.map((r, i) => (
                <Box
                  key={r.id}
                  sx={{
                    py: 1.75,
                    borderBottom: i === reviews.length - 1 ? 0 : 1,
                    borderColor: 'divider',
                  }}
                >
                  <Stack direction="row" spacing={1} alignItems="center" mb={0.5}>
                    <Rating value={r.rating} readOnly size="small" />
                    <Typography variant="caption" color="text.secondary">
                      {dayjs(r.created_at).format('D MMM YYYY')}
                    </Typography>
                  </Stack>
                  {r.comment && (
                    <Typography variant="body2" sx={{ mb: 0.5 }}>{r.comment}</Typography>
                  )}
                  <Typography variant="caption" color="text.secondary">
                    {r.reviewer_name}{r.ground_name ? ` · ${r.ground_name}` : ''}
                  </Typography>
                </Box>
              ))}
            </Card>
          )}
        </>
      )}
    </Box>
  )
}
