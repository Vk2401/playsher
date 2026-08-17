import React from 'react'
import { DataGrid } from '@mui/x-data-grid'
import { Box, Paper, Typography } from '@mui/material'
import EmptyState from './EmptyState.jsx'

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
  if (error) {
    return (
      <Paper sx={{ p: 4, textAlign: 'center' }}>
        <Typography color="error">Failed to load data: {error.message}</Typography>
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
          '& .MuiDataGrid-columnHeaders': {
            background: 'rgba(107,158,122,0.06)',
            borderRadius: 0,
          },
          '& .MuiDataGrid-row:hover': {
            background: 'rgba(107,158,122,0.04)',
          },
          '& .MuiDataGrid-cell': { borderColor: 'rgba(0,0,0,0.05)' },
          '& .MuiDataGrid-columnSeparator': { display: 'none' },
        }}
        {...props}
      />
    </Paper>
  )
}
