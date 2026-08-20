import React from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext.jsx'
import AppShell from '../components/layout/AppShell.jsx'

// Pages
import Login from '../pages/Login.jsx'
import NotFound from '../pages/NotFound.jsx'

// Admin
import AdminDashboard from '../pages/admin/Dashboard.jsx'
import AdminUsers from '../pages/admin/Users.jsx'
import AdminGroundOwners from '../pages/admin/GroundOwners.jsx'
import AdminGrounds from '../pages/admin/Grounds.jsx'
import AdminGroundDetail from '../pages/admin/GroundDetail.jsx'
import AdminSports from '../pages/admin/Sports.jsx'
import AdminAmenities from '../pages/admin/Amenities.jsx'
import AdminAppVersions from '../pages/admin/AppVersions.jsx'
import AdminBookings from '../pages/admin/Bookings.jsx'
import AdminPayments from '../pages/admin/Payments.jsx'
import AdminGames from '../pages/admin/Games.jsx'
import AdminCoaches from '../pages/admin/Coaches.jsx'
import AdminReviews from '../pages/admin/Reviews.jsx'
import AdminProfile from '../pages/admin/Profile.jsx'
import AdminSettlements from '../pages/admin/Settlements.jsx'

// Owner
import OwnerDashboard from '../pages/owner/Dashboard.jsx'
import OwnerGrounds from '../pages/owner/Grounds.jsx'
import OwnerGroundDetail from '../pages/owner/GroundDetail.jsx'
import OwnerBookings from '../pages/owner/Bookings.jsx'
import OwnerGames from '../pages/owner/Games.jsx'
import OwnerBankDetails from '../pages/owner/BankDetails.jsx'
import OwnerProfile from '../pages/owner/Profile.jsx'

function ProtectedRoute({ children, requiredRole }) {
  const { isAuthenticated, isAdmin, isOwner } = useAuth()

  if (!isAuthenticated) return <Navigate to="/login" replace />

  if (requiredRole === 'admin' && !isAdmin)
    return <Navigate to={isOwner ? '/owner/dashboard' : '/login'} replace />

  if (requiredRole === 'ground_owner' && !isOwner)
    return <Navigate to={isAdmin ? '/admin/dashboard' : '/login'} replace />

  return children
}

function RootRedirect() {
  const { isAuthenticated, isAdmin, isOwner } = useAuth()
  if (!isAuthenticated) return <Navigate to="/login" replace />
  if (isAdmin) return <Navigate to="/admin/dashboard" replace />
  if (isOwner) return <Navigate to="/owner/dashboard" replace />
  return <Navigate to="/login" replace />
}

export default function AppRouter() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<RootRedirect />} />

        {/* Admin Routes */}
        <Route
          path="/admin"
          element={
            <ProtectedRoute requiredRole="admin">
              <AppShell />
            </ProtectedRoute>
          }
        >
          <Route index element={<Navigate to="/admin/dashboard" replace />} />
          <Route path="dashboard" element={<AdminDashboard />} />
          <Route path="users" element={<AdminUsers />} />
          <Route path="ground-owners" element={<AdminGroundOwners />} />
          <Route path="grounds" element={<AdminGrounds />} />
          <Route path="grounds/:id" element={<AdminGroundDetail />} />
          <Route path="sports" element={<AdminSports />} />
          <Route path="amenities" element={<AdminAmenities />} />
          <Route path="app-versions" element={<AdminAppVersions />} />
          <Route path="bookings" element={<AdminBookings />} />
          <Route path="payments" element={<AdminPayments />} />
          <Route path="settlements" element={<AdminSettlements />} />
          <Route path="games" element={<AdminGames />} />
          <Route path="coaches" element={<AdminCoaches />} />
          <Route path="reviews" element={<AdminReviews />} />
          <Route path="profile" element={<AdminProfile />} />
        </Route>

        {/* Owner Routes */}
        <Route
          path="/owner"
          element={
            <ProtectedRoute requiredRole="ground_owner">
              <AppShell />
            </ProtectedRoute>
          }
        >
          <Route index element={<Navigate to="/owner/dashboard" replace />} />
          <Route path="dashboard" element={<OwnerDashboard />} />
          <Route path="grounds" element={<OwnerGrounds />} />
          <Route path="grounds/:id" element={<OwnerGroundDetail />} />
          <Route path="bookings" element={<OwnerBookings />} />
          <Route path="games" element={<OwnerGames />} />
          <Route path="bank-details" element={<OwnerBankDetails />} />
          <Route path="profile" element={<OwnerProfile />} />
        </Route>

        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  )
}
