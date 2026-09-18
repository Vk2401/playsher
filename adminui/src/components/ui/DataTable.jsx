import React, { useState } from 'react'
import { DataGrid } from '@mui/x-data-grid'
import {
  Box, Paper, Typography, alpha, useMediaQuery, useTheme,
  Divider, Stack, Button,
} from '@mui/material'
import EmptyState from './EmptyState.jsx'

/** Columns that only exist to carry a row's controls, not a value. */
const isActionColumn = (col) =>
  col.type === 'actions' || col.field === 'actions' || /^actions?$/i.test(col.headerName || '')

/**
 * Render one column's content for a row, honouring the same hooks the grid uses
 * so a card shows exactly what its table cell would: `renderCell` first, then
 * `valueGetter`, then the raw field.
 */
function cellContent(col, row) {
  if (col.renderCell) return col.renderCell({ row, value: row[col.field], field: col.field })
  if (col.valueGetter) return col.valueGetter(row[col.field], row, col, null)
  const v = row[col.field]
  return v === null || v === undefined || v === '' ? '—' : String(v)
}

/**
 * A phone cannot use a 9-column grid: the columns collapse to slivers and the
 * row scrolls sideways past the actions. Below `md` each row becomes a card —
 * the first column as its heading, the rest as label/value lines, the action
 * column pinned to the bottom. Same columns, same renderers, no second
 * definition for a page to keep in step.
 */
function CardList({ rows, columns, loading, pageSize }) {
  const [shown, setShown] = useState(pageSize)

  if (loading) {
    return (
      <Box sx={{ p: 3, textAlign: 'center' }}>
        <Typography color="text.secondary" variant="body2">Loading…</Typography>
      </Box>
    )
  }
  if (!rows.length) {
    return <Box sx={{ p: 3 }}><EmptyState message="No records found" /></Box>
  }

  const visible = columns.filter((c) => !c.hideOnMobile)
  const [lead, ...rest] = visible.filter((c) => !isActionColumn(c))
  const actions = visible.filter(isActionColumn)
  const page = rows.slice(0, shown)

  return (
    <Box>
      {page.map((row, i) => (
        <Box key={row.id ?? i}>
          {i > 0 && <Divider />}
          <Box sx={{ p: 2 }}>
            {lead && (
              <Box sx={{ fontWeight: 700, fontSize: '0.95rem', mb: 1.25 }}>
                {cellContent(lead, row)}
              </Box>
            )}

            <Stack spacing={0.75}>
              {rest.map((col) => (
                <Stack
                  key={col.field}
                  direction="row"
                  spacing={2}
                  justifyContent="space-between"
                  alignItems="flex-start"
                >
                  <Typography
                    variant="caption"
                    sx={{ color: 'text.secondary', flexShrink: 0, pt: 0.25 }}
                  >
                    {col.headerName || col.field}
                  </Typography>
                  <Box sx={{ textAlign: 'right', fontSize: '0.85rem', minWidth: 0 }}>
                    {cellContent(col, row)}
                  </Box>
                </Stack>
              ))}
            </Stack>

            {actions.length > 0 && (
              <Box sx={{ mt: 1.5, display: 'flex', justifyContent: 'flex-end', gap: 0.5 }}>
                {actions.map((col) => (
                  <Box key={col.field}>{cellContent(col, row)}</Box>
                ))}
              </Box>
            )}
          </Box>
        </Box>
      ))}

      {shown < rows.length && (
        <>
          <Divider />
          <Box sx={{ p: 1.5, textAlign: 'center' }}>
            <Button size="small" onClick={() => setShown((n) => n + pageSize)}>
              Show more ({rows.length - shown} left)
            </Button>
          </Box>
        </>
      )}
    </Box>
  )
}

export default function DataTable({
  rows = [],
  columns = [],
  loading = false,
  error = null,
  pageSize = 10,
  pageSizeOptions = [10, 25, 50],
  sx = {},
  ...props
}) {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))

  if (error) {
    return (
      <Paper sx={{ p: 4, textAlign: 'center' }}>
        <Typography color="error">Failed to load data: {error.message}</Typography>
      </Paper>
    )
  }

  if (isMobile) {
    return (
      <Paper sx={{ width: '100%', overflow: 'hidden', ...sx }}>
        <CardList rows={rows} columns={columns} loading={loading} pageSize={pageSize} />
      </Paper>
    )
  }

  return (
    <Paper sx={{ width: '100%', overflow: 'hidden', ...sx }}>
      <DataGrid
        rows={rows}
        columns={columns}
        loading={loading}
        initialState={{ pagination: { paginationModel: { pageSize } } }}
        pageSizeOptions={pageSizeOptions}
        disableRowSelectionOnClick
        autoHeight
        slots={{
          noRowsOverlay: () => (
            <Box display="flex" justifyContent="center" alignItems="center" height="100%">
              <EmptyState message="No records found" />
            </Box>
          ),
        }}
        sx={{
          border: 'none',
          // Tints, not a fixed hex: the primary colour is switchable at runtime,
          // and this header stayed green under every other swatch.
          '& .MuiDataGrid-columnHeaders': {
            background: (t) => alpha(t.palette.primary.main, 0.06),
            borderRadius: 0,
          },
          '& .MuiDataGrid-row:hover': {
            background: (t) => alpha(t.palette.primary.main, 0.04),
          },
          '& .MuiDataGrid-cell': { borderColor: 'divider' },
          '& .MuiDataGrid-columnSeparator': { display: 'none' },
        }}
        {...props}
      />
    </Paper>
  )
}
