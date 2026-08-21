import React, { useState, useMemo, useEffect, useRef } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Box, Paper, Stack, Typography, Button, Chip, Alert, AlertTitle, Divider,
  Table, TableBody, TableCell, TableHead, TableRow, LinearProgress, Skeleton,
  Accordion, AccordionSummary, AccordionDetails, FormControlLabel, Checkbox,
  Dialog, DialogTitle, DialogContent, DialogActions, CircularProgress, Tooltip,
} from '@mui/material'
import { alpha, useTheme } from '@mui/material/styles'
import ExpandMoreIcon from '@mui/icons-material/ExpandMore'
import StorageIcon from '@mui/icons-material/Storage'
import RefreshIcon from '@mui/icons-material/Refresh'
import PlayArrowIcon from '@mui/icons-material/PlayArrow'
import CheckCircleIcon from '@mui/icons-material/CheckCircle'
import WarningAmberIcon from '@mui/icons-material/WarningAmber'
import BlockIcon from '@mui/icons-material/Block'
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline'
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined'

import PageHeader from '../../components/ui/PageHeader.jsx'
import EmptyState from '../../components/ui/EmptyState.jsx'
import { schemaApi } from '../../api/schema.js'
import { useNotify } from '../../hooks/useNotify.js'

const RISK_META = {
  safe: { label: 'Safe', color: 'success', help: 'Cannot lose data or fail on existing rows.' },
  risky: {
    label: 'Needs review',
    color: 'warning',
    help: 'Succeeds, but changes or constrains values that already exist.',
  },
}

/** Per-step icon for the progress list — never colour alone. */
function StepIcon({ status }) {
  if (status === 'done') return <CheckCircleIcon color="success" fontSize="small" />
  if (status === 'failed') return <ErrorOutlineIcon color="error" fontSize="small" />
  if (status === 'skipped') return <WarningAmberIcon color="warning" fontSize="small" />
  if (status === 'running') return <CircularProgress size={16} />
  return <InfoOutlinedIcon color="disabled" fontSize="small" />
}

export default function DatabaseSchema() {
  const theme = useTheme()
  const notify = useNotify()
  const queryClient = useQueryClient()

  const [confirmOpen, setConfirmOpen] = useState(false)
  const [includeRisky, setIncludeRisky] = useState(false)
  const [jobId, setJobId] = useState(null)

  const definition = useQuery({
    queryKey: ['admin', 'schema', 'definition'],
    queryFn: () => schemaApi.getDefinition(),
    select: (res) => res.data?.data ?? null,
  })

  const plan = useQuery({
    queryKey: ['admin', 'schema', 'plan'],
    queryFn: () => schemaApi.getPlan(),
    select: (res) => res.data?.data ?? null,
    // The plan compares against the live database, so a cached copy is
    // misleading the moment anything changes it.
    staleTime: 0,
  })

  // Polls only while a sync is actually running; stops the moment it settles.
  const job = useQuery({
    queryKey: ['admin', 'schema', 'job', jobId],
    queryFn: () => schemaApi.getJob(jobId),
    select: (res) => res.data?.data ?? null,
    enabled: jobId !== null,
    refetchInterval: (query) => {
      const status = query.state.data?.data?.data?.status
      return status === 'running' ? 900 : false
    },
  })

  const jobData = job.data
  const isRunning = jobData?.status === 'running'

  const applyMutation = useMutation({
    mutationFn: (risky) => schemaApi.apply(risky),
    onSuccess: (res) => {
      const data = res.data?.data
      setConfirmOpen(false)
      if (!data?.job_id) {
        notify.info('Nothing to apply — the database already matches schema.json')
        plan.refetch()
        return
      }
      setJobId(data.job_id)
      notify.success(`Schema sync started — ${data.total_steps} step(s)`)
    },
    onError: (err) =>
      notify.error(err?.response?.data?.message || 'Failed to start the schema sync'),
  })

  // When a run finishes, refresh the plan so the page reflects the new reality.
  // Keyed on the job id so a still-polling render cannot fire it twice.
  const settledJobRef = useRef(null)
  useEffect(() => {
    if (!jobData || jobData.status === 'running') return
    if (settledJobRef.current === jobData.id) return
    settledJobRef.current = jobData.id

    queryClient.invalidateQueries({ queryKey: ['admin', 'schema', 'plan'] })
    queryClient.invalidateQueries({ queryKey: ['admin', 'schema', 'definition'] })
    if (jobData.status === 'failed') notify.error(jobData.error_message || 'Schema sync failed')
    else notify.success('Schema sync completed')
  }, [jobData, queryClient, notify])

  const summary = plan.data?.summary
  const blocked = plan.data?.blocked ?? []
  const extras = plan.data?.extras ?? []

  // Derived from plan.data directly so the fallback array is not a fresh
  // reference on every render.
  const operations = useMemo(() => plan.data?.operations ?? [], [plan.data])
  const grouped = useMemo(() => ({
    safe: operations.filter((op) => op.risk === 'safe'),
    risky: operations.filter((op) => op.risk === 'risky'),
  }), [operations])

  const applicableCount = grouped.safe.length + (includeRisky ? grouped.risky.length : 0)

  const openConfirm = () => {
    setIncludeRisky(false)
    setConfirmOpen(true)
  }

  return (
    <Box>
      <PageHeader
        title="Database Schema"
        subtitle="database/schema.json is the source of truth. Edit it, preview the difference, then apply."
        breadcrumbs={[{ label: 'Admin', href: '/admin/dashboard' }, { label: 'Database Schema' }]}
        actions={
          <Stack direction="row" gap={1}>
            <Button
              variant="outlined"
              startIcon={<RefreshIcon />}
              onClick={() => plan.refetch()}
              disabled={plan.isFetching || isRunning}
            >
              Re-check
            </Button>
            <Button
              variant="contained"
              startIcon={<PlayArrowIcon />}
              onClick={openConfirm}
              disabled={plan.isLoading || isRunning || !operations.length}
            >
              Apply schema
            </Button>
          </Stack>
        }
      />

      {/* ── Live run progress ──────────────────────────────────────────────── */}
      {jobData && (
        <Paper sx={{ p: { xs: 2, sm: 3 }, mb: 3 }}>
          <Stack direction="row" alignItems="center" justifyContent="space-between" mb={1.5}>
            <Typography variant="subtitle1" fontWeight={600}>
              {isRunning ? 'Applying schema…' : `Sync #${jobData.id} ${jobData.status}`}
            </Typography>
            <Chip
              size="small"
              label={`${jobData.completed_steps}/${jobData.total_steps} steps`}
              color={jobData.status === 'failed' ? 'error'
                : jobData.status === 'completed' ? 'success' : 'default'}
            />
          </Stack>

          <LinearProgress
            variant="determinate"
            value={jobData.percent ?? 0}
            color={jobData.status === 'failed' ? 'error' : 'primary'}
            sx={{ height: 8, borderRadius: 4, mb: 1.5 }}
          />

          {isRunning && jobData.current_step && (
            <Typography variant="body2" color="text.secondary" mb={1.5}>
              {jobData.current_step}
            </Typography>
          )}

          {jobData.error_message && (
            <Alert severity="error" sx={{ mb: 1.5 }}>
              <AlertTitle>Sync stopped</AlertTitle>
              {jobData.error_message}
              <Typography variant="caption" display="block" mt={0.5}>
                Steps that already succeeded stay applied. Fix the cause and apply again — the
                plan is rebuilt from the current database each time.
              </Typography>
            </Alert>
          )}

          <Stack gap={0.75}>
            {(jobData.steps ?? []).map((step, i) => (
              <Stack key={i} direction="row" gap={1} alignItems="flex-start">
                <Box sx={{ mt: '2px' }}><StepIcon status={step.status} /></Box>
                <Box flex={1}>
                  <Typography
                    variant="body2"
                    color={step.status === 'pending' ? 'text.disabled' : 'text.primary'}
                  >
                    {step.description}
                  </Typography>
                  {step.message && (
                    <Typography variant="caption" color="text.secondary">
                      {step.message}
                    </Typography>
                  )}
                </Box>
                <Typography variant="caption" color="text.secondary">{step.status}</Typography>
              </Stack>
            ))}
          </Stack>
        </Paper>
      )}

      {/* ── Summary ────────────────────────────────────────────────────────── */}
      {plan.isLoading ? (
        <Skeleton variant="rounded" height={120} sx={{ mb: 3 }} />
      ) : plan.error ? (
        <Alert
          severity="error"
          sx={{ mb: 3 }}
          action={<Button size="small" onClick={() => plan.refetch()}>Retry</Button>}
        >
          <AlertTitle>Could not compare the schema</AlertTitle>
          {plan.error?.response?.data?.message || 'The database could not be inspected.'}
        </Alert>
      ) : summary?.in_sync ? (
        <Alert severity="success" icon={<CheckCircleIcon />} sx={{ mb: 3 }}>
          <AlertTitle>Database matches schema.json</AlertTitle>
          {definition.data?.table_count} tables and {definition.data?.column_count} columns,
          all present and matching. Nothing to apply.
        </Alert>
      ) : (
        <Paper sx={{ p: { xs: 2, sm: 3 }, mb: 3 }}>
          <Stack direction={{ xs: 'column', sm: 'row' }} gap={2} flexWrap="wrap">
            {[
              { label: 'Safe changes', value: summary?.safe ?? 0, color: 'success' },
              { label: 'Need review', value: summary?.risky ?? 0, color: 'warning' },
              { label: 'Blocked', value: summary?.blocked ?? 0, color: 'error' },
              { label: 'Untracked in JSON', value: summary?.extras ?? 0, color: 'info' },
            ].map((tile) => (
              <Box
                key={tile.label}
                sx={{
                  flex: 1, minWidth: 140, p: 2, borderRadius: 2,
                  bgcolor: alpha(theme.palette[tile.color].main, 0.08),
                  border: `1px solid ${alpha(theme.palette[tile.color].main, 0.24)}`,
                }}
              >
                <Typography variant="h4" fontWeight={700}>{tile.value}</Typography>
                <Typography variant="body2" color="text.secondary">{tile.label}</Typography>
              </Box>
            ))}
          </Stack>
        </Paper>
      )}

      {/* ── Pending operations ─────────────────────────────────────────────── */}
      {['safe', 'risky'].map((risk) => grouped[risk].length > 0 && (
        <Accordion key={risk} defaultExpanded sx={{ mb: 1.5 }}>
          <AccordionSummary expandIcon={<ExpandMoreIcon />}>
            <Stack direction="row" gap={1} alignItems="center" flexWrap="wrap">
              <Chip
                size="small"
                label={RISK_META[risk].label}
                color={RISK_META[risk].color}
                variant="outlined"
              />
              <Typography fontWeight={600}>
                {grouped[risk].length} {grouped[risk].length === 1 ? 'change' : 'changes'}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                — {RISK_META[risk].help}
              </Typography>
            </Stack>
          </AccordionSummary>
          <AccordionDetails sx={{ p: 0 }}>
            <Box sx={{ overflowX: 'auto' }}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Table</TableCell>
                    <TableCell>Change</TableCell>
                    <TableCell>SQL</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {grouped[risk].map((op) => (
                    <TableRow key={op.index}>
                      <TableCell sx={{ whiteSpace: 'nowrap', verticalAlign: 'top' }}>
                        <Typography variant="body2" fontWeight={600}>{op.table}</Typography>
                      </TableCell>
                      <TableCell sx={{ verticalAlign: 'top', minWidth: 240 }}>
                        <Typography variant="body2">{op.description}</Typography>
                      </TableCell>
                      <TableCell>
                        <Stack gap={0.5}>
                          {op.pre_sql?.map((sql, i) => (
                            <Typography
                              key={i}
                              variant="caption"
                              component="pre"
                              sx={{
                                m: 0, fontFamily: 'monospace', whiteSpace: 'pre-wrap',
                                color: 'warning.main',
                              }}
                            >
                              {sql}
                            </Typography>
                          ))}
                          <Typography
                            variant="caption"
                            component="pre"
                            sx={{
                              m: 0, fontFamily: 'monospace', whiteSpace: 'pre-wrap',
                              color: 'text.secondary',
                            }}
                          >
                            {op.sql}
                          </Typography>
                        </Stack>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Box>
          </AccordionDetails>
        </Accordion>
      ))}

      {/* ── Blocked ────────────────────────────────────────────────────────── */}
      {blocked.length > 0 && (
        <Accordion defaultExpanded sx={{ mb: 1.5 }}>
          <AccordionSummary expandIcon={<ExpandMoreIcon />}>
            <Stack direction="row" gap={1} alignItems="center">
              <BlockIcon color="error" fontSize="small" />
              <Typography fontWeight={600}>{blocked.length} blocked</Typography>
              <Typography variant="body2" color="text.secondary">
                — cannot be applied without losing data. Never run.
              </Typography>
            </Stack>
          </AccordionSummary>
          <AccordionDetails>
            <Stack gap={1.5}>
              {blocked.map((item, i) => (
                <Alert severity="error" variant="outlined" key={i}>
                  <AlertTitle sx={{ mb: 0.25 }}>{item.description}</AlertTitle>
                  <Typography variant="body2">{item.reason}</Typography>
                </Alert>
              ))}
            </Stack>
          </AccordionDetails>
        </Accordion>
      )}

      {/* ── Extras ─────────────────────────────────────────────────────────── */}
      {extras.length > 0 && (
        <Accordion sx={{ mb: 1.5 }}>
          <AccordionSummary expandIcon={<ExpandMoreIcon />}>
            <Stack direction="row" gap={1} alignItems="center">
              <InfoOutlinedIcon color="info" fontSize="small" />
              <Typography fontWeight={600}>{extras.length} in the database, not in the JSON</Typography>
              <Typography variant="body2" color="text.secondary">
                — left untouched
              </Typography>
            </Stack>
          </AccordionSummary>
          <AccordionDetails>
            <Stack gap={1}>
              {extras.map((item, i) => (
                <Typography variant="body2" color="text.secondary" key={i}>
                  {item.description}
                </Typography>
              ))}
            </Stack>
          </AccordionDetails>
        </Accordion>
      )}

      {/* ── Declared tables ────────────────────────────────────────────────── */}
      <Accordion>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Stack direction="row" gap={1} alignItems="center">
            <StorageIcon fontSize="small" color="action" />
            <Typography fontWeight={600}>
              Declared schema
              {definition.data ? ` — ${definition.data.table_count} tables, `
                + `${definition.data.column_count} columns` : ''}
            </Typography>
          </Stack>
        </AccordionSummary>
        <AccordionDetails sx={{ p: 0 }}>
          {definition.isLoading ? (
            <Box p={2}><Skeleton height={200} /></Box>
          ) : !definition.data?.tables?.length ? (
            <EmptyState title="No tables declared" description="schema.json contains no tables." />
          ) : (
            <Box sx={{ overflowX: 'auto' }}>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Table</TableCell>
                    <TableCell align="right">Columns</TableCell>
                    <TableCell align="right">Indexes</TableCell>
                    <TableCell align="right">Foreign keys</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {definition.data.tables.map((t) => (
                    <TableRow key={t.name}>
                      <TableCell>{t.name}</TableCell>
                      <TableCell align="right">{t.columns}</TableCell>
                      <TableCell align="right">{t.indexes}</TableCell>
                      <TableCell align="right">{t.foreign_keys}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Box>
          )}
        </AccordionDetails>
      </Accordion>

      {/* ── Confirmation ───────────────────────────────────────────────────── */}
      <Dialog open={confirmOpen} onClose={() => setConfirmOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          <WarningAmberIcon color="warning" />
          Apply schema to the database?
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" mb={2}>
            This runs DDL against the live database. Nothing is ever dropped — no table, no
            column — so existing data is preserved; new columns take their default value on
            rows that already exist.
          </Typography>

          <Divider sx={{ my: 2 }} />

          <Stack gap={1}>
            <Stack direction="row" justifyContent="space-between">
              <Typography variant="body2">Safe changes</Typography>
              <Chip size="small" color="success" label={grouped.safe.length} />
            </Stack>
            <Stack direction="row" justifyContent="space-between" alignItems="center">
              <Typography variant="body2">Changes needing review</Typography>
              <Chip
                size="small"
                color={grouped.risky.length ? 'warning' : 'default'}
                label={grouped.risky.length}
              />
            </Stack>
          </Stack>

          {grouped.risky.length > 0 && (
            <Alert severity="warning" sx={{ mt: 2 }}>
              <AlertTitle>{grouped.risky.length} change(s) touch existing values</AlertTitle>
              <Stack component="ul" sx={{ pl: 2, m: 0 }} gap={0.5}>
                {grouped.risky.map((op) => (
                  <Typography component="li" variant="body2" key={op.index}>
                    {op.description}
                  </Typography>
                ))}
              </Stack>
              <FormControlLabel
                sx={{ mt: 1 }}
                control={
                  <Checkbox
                    checked={includeRisky}
                    onChange={(e) => setIncludeRisky(e.target.checked)}
                  />
                }
                label="Include these as well"
              />
            </Alert>
          )}

          {blocked.length > 0 && (
            <Alert severity="info" sx={{ mt: 2 }}>
              {blocked.length} blocked change(s) will be skipped — they cannot be applied
              without losing data.
            </Alert>
          )}

          <Typography variant="body2" mt={2} fontWeight={600}>
            {applicableCount} operation(s) will run.
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button
            variant="outlined"
            onClick={() => setConfirmOpen(false)}
            disabled={applyMutation.isPending}
          >
            Cancel
          </Button>
          <Tooltip title={applicableCount ? '' : 'Nothing selected to apply'}>
            <span>
              <Button
                variant="contained"
                color="warning"
                onClick={() => applyMutation.mutate(includeRisky)}
                disabled={applyMutation.isPending || applicableCount === 0}
                startIcon={applyMutation.isPending
                  ? <CircularProgress size={16} color="inherit" />
                  : <PlayArrowIcon />}
              >
                {applyMutation.isPending ? 'Starting…' : `Apply ${applicableCount} change(s)`}
              </Button>
            </span>
          </Tooltip>
        </DialogActions>
      </Dialog>
    </Box>
  )
}
