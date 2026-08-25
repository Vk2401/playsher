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
import AdminDatabaseSchema from '../pages/admin/DatabaseSchema.jsx'
import AdminAdmins from '../pages/admin/Admins.jsx'
import AdminBookings from '../pages/admin/Bookings.jsx'
import AdminPayments from '../pages/admin/Payments.jsx'
import AdminGames from '../pages/admin/Games.jsx'
import AdminCoaches from '../pages/admin/Coaches.jsx'
import AdminReviews from '../pages/admin/Reviews.jsx'
import AdminProfile from '../pages/admin/Profile.jsx'
import AdminSettlements from '../pages/admin/Settlements.jsx'
import AdminCoachSessions from '../pages/admin/CoachSessions.jsx'

// Owner
import OwnerDashboard from '../pages/owner/Dashboard.jsx'
import OwnerGrounds from '../pages/owner/Grounds.jsx'
import OwnerGroundDetail from '../pages/owner/GroundDetail.jsx'
import OwnerBookings from '../pages/owner/Bookings.jsx'
import OwnerGames from '../pages/owner/Games.jsx'
import OwnerBankDetails from '../pages/owner/BankDetails.jsx'
import OwnerProfile from '../pages/owner/Profile.jsx'
import OwnerCoachRequests from '../pages/owner/CoachRequests.jsx'
import OwnerCoachSessions from '../pages/owner/CoachSessions.jsx'

// Coach
import CoachDashboard from '../pages/coach/Dashboard.jsx'
import CoachProfile from '../pages/coach/Profile.jsx'
import CoachAvailability from '../pages/coach/Availability.jsx'
import CoachGrounds from '../pages/coach/Grounds.jsx'
import CoachBookings from '../pages/coach/Bookings.jsx'
import CoachNotifications from '../pages/coach/Notifications.jsx'

function ProtectedRoute({ children, requiredRole }) {
  const { isAuthenticated, user, homePath } = useAuth()

  if (!isAuthenticated) return <Navigate to="/login" replace />

  // Wrong panel for this role: send them to their own rather than to /login,
  // which would read as "your session expired" to someone who is signed in.
  if (requiredRole && user?.role !== requiredRole) {
    return <Navigate to={homePath} replace />
  }

  return children
}

function RootRedirect() {
  const { isAuthenticated, homePath } = useAuth()
  if (!isAuthenticated) return <Navigate to="/login" replace />
  return <Navigate to={homePath} replace />
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
          <Route path="database-schema" element={<AdminDatabaseSchema />} />
          <Route path="admins" element={<AdminAdmins />} />
          <Route path="bookings" element={<AdminBookings />} />
          <Route path="payments" element={<AdminPayments />} />
          <Route path="settlements" element={<AdminSettlements />} />
          <Route path="games" element={<AdminGames />} />
          <Route path="coaches" element={<AdminCoaches />} />
          <Route path="coach-sessions" element={<AdminCoachSessions />} />
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
          <Route path="coach-requests" element={<OwnerCoachRequests />} />
          <Route path="coach-sessions" element={<OwnerCoachSessions />} />
          <Route path="bank-details" element={<OwnerBankDetails />} />
          <Route path="profile" element={<OwnerProfile />} />
        </Route>

        {/* Coach Routes */}
        <Route
          path="/coach"
          element={
            <ProtectedRoute requiredRole="coach">
              <AppShell />
            </ProtectedRoute>
          }
        >
          <Route index element={<Navigate to="/coach/dashboard" replace />} />
          <Route path="dashboard" element={<CoachDashboard />} />
          <Route path="bookings" element={<CoachBookings />} />
          <Route path="availability" element={<CoachAvailability />} />
          <Route path="grounds" element={<CoachGrounds />} />
          <Route path="notifications" element={<CoachNotifications />} />
          <Route path="profile" element={<CoachProfile />} />
        </Route>

        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  )
}
