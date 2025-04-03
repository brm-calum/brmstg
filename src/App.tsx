import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './contexts/AuthContext';
import { LoginPage } from './pages/auth/LoginPage';
import { RegisterPage } from './pages/auth/RegisterPage';
import { ResetPasswordPage } from './pages/auth/ResetPasswordPage';
import { AdminDashboardPage } from './pages/admin/DashboardPage';
import { AdminBookingsPage } from './pages/admin/BookingsPage';
import { DashboardPage } from './pages/DashboardPage';
import { UsersPage } from './pages/admin/UsersPage';
import { FeaturesPage } from './pages/admin/FeaturesPage';
import { BookingsPage } from './pages/bookings/BookingsPage';
import { BookingDetailsPage } from './pages/bookings/BookingDetailsPage';
import { MessagesPage } from './pages/MessagesPage';
import { AdminInquiriesPage } from './pages/admin/InquiriesPage';
import { InquiryDetailsPage } from './pages/admin/InquiryDetailsPage';
import { CreateOfferPage } from './pages/admin/CreateOfferPage';
import { EditOfferPage } from './pages/admin/EditOfferPage';
import { DraftOffersPage } from './pages/admin/DraftOffersPage';
import { AboutPage } from './pages/AboutPage';
import { FAQPage } from './pages/FAQPage';
import { ContactPage } from './pages/ContactPage';
import { LandingPage } from './pages/LandingPage';
import { TermsPage } from './pages/TermsPage';
import { PrivacyPage } from './pages/PrivacyPage';
import { WarehousesPage } from './pages/warehouses/WarehousesPage';
import { WarehouseDashboardPage } from './pages/warehouses/WarehouseDashboardPage';
import { WarehouseCreatePage } from './pages/warehouses/WarehouseCreatePage';
import { WarehouseEditPage } from './pages/warehouses/WarehouseEditPage';
import { WarehouseDetailsPage } from './pages/warehouses/WarehouseDetailsPage';
import { MWarehousesPage } from './pages/warehouses/MWarehousesPage';
import { MWarehouseCreatePage } from './pages/warehouses/MWarehouseCreatePage';
import { MWarehouseEditPage } from './pages/warehouses/MWarehouseEditPage';
import { MWarehouseDetailsPage } from './pages/warehouses/MWarehouseDetailsPage';
import { MWarehouseDashboardPage } from './pages/warehouses/MWarehouseDashboardPage';
import { ProfilePage } from './pages/profile/ProfilePage';
import { Layout } from './components/layout/Layout';
import { useLocation } from 'react-router-dom';
import { ErrorBoundary } from './components/ui/ErrorBoundary';
import { InquiriesPage } from './pages/inquiries/InquiriesPage';
import { NewInquiryPage } from './pages/inquiries/NewInquiryPage';
import { InquiryDetailsPage as UserInquiryDetailsPage } from './pages/inquiries/InquiryDetailsPage';
import { OfferViewPage } from './pages/inquiries/OfferViewPage';
import { NotificationsPage } from './pages/NotificationsPage';

function App() {
  const { user } = useAuth();
  const location = useLocation();
  const isLandingPage = location.pathname === '/';

  return (
    <ErrorBoundary>
      <Layout className={isLandingPage ? 'bg-white' : 'bg-gray-50'}>
        <Routes>
          {/* Public Routes */}
          <Route path="/" element={<LandingPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/reset-password" element={<ResetPasswordPage />} />
          <Route path="/about" element={<AboutPage />} />
          <Route path="/faq" element={<FAQPage />} />
          <Route path="/contact" element={<ContactPage />} />
          <Route path="/privacy" element={<PrivacyPage />} />
          <Route path="/terms" element={<TermsPage />} />
          <Route path="/m-warehouses" element={<MWarehousesPage />} />
          <Route path="/m-warehouses/:id" element={<MWarehouseDetailsPage />} />
          
          {/* Protected Routes */}
          {user ? (
            <>
              <Route path="/admin/users" element={<UsersPage />} />
              <Route path="/admin/features" element={<FeaturesPage />} />
              <Route path="/admin/dashboard" element={<AdminDashboardPage />} />
              <Route path="/admin/bookings" element={<AdminBookingsPage />} />
              <Route path="/admin/inquiries" element={<AdminInquiriesPage />} />
              <Route path="/admin/inquiries/:id" element={<InquiryDetailsPage />} />
              <Route path="/admin/inquiries/:inquiryId/offer/new" element={<CreateOfferPage />} />
              <Route path="/admin/inquiries/:inquiryId/offer/:offerId/edit" element={<EditOfferPage />} />
              <Route path="/admin/draft-offers" element={<DraftOffersPage />} />
              <Route path="/messages" element={<MessagesPage />} />
              <Route path="/warehouses/dashboard" element={<WarehouseDashboardPage />} />
              <Route path="/warehouses/create" element={<WarehouseCreatePage />} />
              <Route path="/warehouses/edit/:id" element={<WarehouseEditPage />} />
              <Route path="/warehouses/:id" element={<WarehouseDetailsPage />} />
              <Route path="/m-warehouses/dashboard" element={<MWarehouseDashboardPage />} />
              <Route path="/m-warehouses/create" element={<MWarehouseCreatePage />} />
              <Route path="/m-warehouses/edit/:id" element={<MWarehouseEditPage />} />
              <Route path="/profile" element={<ProfilePage />} />
              <Route path="/dashboard" element={<DashboardPage />} />
              <Route path="/bookings" element={<BookingsPage />} />
              <Route path="/bookings/:id" element={<BookingDetailsPage />} />
              <Route path="/inquiries" element={<InquiriesPage />} />
              <Route path="/inquiries/new" element={<NewInquiryPage />} />
              <Route path="/inquiries/:id" element={<UserInquiryDetailsPage />} />
              <Route path="/inquiries/:inquiryId/offer" element={<OfferViewPage />} />
              <Route path="/notifications" element={<NotificationsPage />} />
            </>
          ) : (
            <Route path="*" element={<Navigate to="/login" replace />} />
          )}
          
          {/* Catch all route */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Layout>
    </ErrorBoundary>
  );
}

export default App;