import React, { useState, useEffect } from 'react';
import { AuthGuard } from '../../components/auth/AuthGuard';
import { Link } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import { 
  FileText, Users, Building2, Settings, Bell,
  Package, Inbox, CheckCircle, Clock, Loader 
} from 'lucide-react';
import { useNotifications } from '../../hooks/useNotifications';

interface DashboardStats {
  totalInquiries: number;
  totalBookings: number;
  activeInquiries: number;
  submittedInquiries: number;
  activeBookings: number;
}

export function AdminDashboardPage() {
  const [stats, setStats] = useState<DashboardStats>({
    totalInquiries: 0,
    totalBookings: 0,
    activeInquiries: 0,
    submittedInquiries: 0,
    activeBookings: 0
  });
  const [isLoading, setIsLoading] = useState(true);
  const { unreadCount } = useNotifications();

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      // Get inquiry stats
      const { data: inquiryStats, error: inquiryError } = await supabase
        .from('booking_inquiries')
        .select('status', { count: 'exact' });

      if (inquiryError) throw inquiryError;

      // Get booking stats
      const { data: bookingStats, error: bookingError } = await supabase
        .from('bookings')
        .select('status', { count: 'exact' });

      if (bookingError) throw bookingError;

      // Count submitted inquiries
      const submittedCount = inquiryStats?.filter(i => i.status === 'submitted').length || 0;
      const activeInquiryCount = inquiryStats?.filter(i => 
        ['submitted', 'under_review', 'offer_pending', 'offer_sent'].includes(i.status)
      ).length || 0;

      // Count active bookings
      const activeBookingCount = bookingStats?.filter(b => b.status === 'active').length || 0;

      setStats({
        totalInquiries: inquiryStats?.length || 0,
        totalBookings: bookingStats?.length || 0,
        activeInquiries: activeInquiryCount,
        submittedInquiries: submittedCount,
        activeBookings: activeBookingCount
      });
    } catch (err) {
      console.error('Failed to load stats:', err);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader className="h-8 w-8 animate-spin text-green-600" />
      </div>
    );
  }

  return (
    <AuthGuard requiredRoles={['administrator']}>
      <div className="py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-2xl font-semibold text-gray-900">Administrator Dashboard</h1>
          
          {/* Overview Stats */}
          <div className="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
            <div className="bg-white overflow-hidden shadow rounded-lg">
              <div className="p-5">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <FileText className="h-6 w-6 text-gray-400" />
                  </div>
                  <div className="ml-5 w-0 flex-1">
                    <dl>
                      <dt className="text-sm font-medium text-gray-500 truncate">Total Inquiries</dt>
                      <dd className="text-lg font-medium text-gray-900">{stats.totalInquiries}</dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-white overflow-hidden shadow rounded-lg">
              <div className="p-5">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <Package className="h-6 w-6 text-gray-400" />
                  </div>
                  <div className="ml-5 w-0 flex-1">
                    <dl>
                      <dt className="text-sm font-medium text-gray-500 truncate">Total Bookings</dt>
                      <dd className="text-lg font-medium text-gray-900">{stats.totalBookings}</dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Management Sections */}
          <div className="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-2">
            {/* Manage Inquiries */}
            <div className="bg-white shadow rounded-lg p-6">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-medium text-gray-900 flex items-center">
                  <Inbox className="h-5 w-5 text-gray-400 mr-2" />
                  Manage Inquiries
                </h2>
                <Link
                  to="/admin/inquiries"
                  className="text-sm font-medium text-green-600 hover:text-green-500"
                >
                  View all
                </Link>
              </div>
              <div className="mt-4">
                <div className="flex items-baseline">
                  <p className="text-2xl font-semibold text-gray-900">{stats.activeInquiries}</p>
                  <p className="ml-2 text-sm text-gray-500">active inquiries</p>
                </div>
                <div className="mt-4">
                  <div className="flex items-center">
                    <Clock className="h-4 w-4 text-yellow-400 mr-2" />
                    <span className="text-sm text-gray-500">
                      {stats.submittedInquiries} new submissions
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Manage Bookings */}
            <div className="bg-white shadow rounded-lg p-6">
              <div className="flex items-center justify-between">
                <h2 className="text-lg font-medium text-gray-900 flex items-center">
                  <Package className="h-5 w-5 text-gray-400 mr-2" />
                  Manage Bookings
                </h2>
                <Link
                  to="/admin/bookings"
                  className="text-sm font-medium text-green-600 hover:text-green-500"
                >
                  View all
                </Link>
              </div>
              <div className="mt-4">
                <div className="flex items-baseline">
                  <p className="text-2xl font-semibold text-gray-900">{stats.activeBookings}</p>
                  <p className="ml-2 text-sm text-gray-500">active bookings</p>
                </div>
                <div className="mt-4">
                  <div className="flex items-center">
                    <CheckCircle className="h-4 w-4 text-green-400 mr-2" />
                    <span className="text-sm text-gray-500">
                      {stats.activeBookings} currently active
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Quick Actions */}
            <div className="lg:col-span-2">
              <h2 className="text-lg font-medium text-gray-900 mb-4">Quick Actions</h2>
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
                <Link
                  to="/admin/users"
                  className="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400 focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-green-500"
                >
                  <div className="flex-shrink-0">
                    <Users className="h-6 w-6 text-gray-400" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="absolute inset-0" aria-hidden="true" />
                    <p className="text-sm font-medium text-gray-900">Manage Users</p>
                    <p className="text-sm text-gray-500">View and manage user accounts</p>
                  </div>
                </Link>

                <Link
                  to="/m-warehouses/dashboard"
                  className="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400 focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-green-500"
                >
                  <div className="flex-shrink-0">
                    <Building2 className="h-6 w-6 text-gray-400" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="absolute inset-0" aria-hidden="true" />
                    <p className="text-sm font-medium text-gray-900">Manage Warehouses</p>
                    <p className="text-sm text-gray-500">Oversee warehouse listings</p>
                  </div>
                </Link>

                <Link
                  to="/admin/features"
                  className="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400 focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-green-500"
                >
                  <div className="flex-shrink-0">
                    <Settings className="h-6 w-6 text-gray-400" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="absolute inset-0" aria-hidden="true" />
                    <p className="text-sm font-medium text-gray-900">Platform Settings</p>
                    <p className="text-sm text-gray-500">Configure platform features</p>
                  </div>
                </Link>

                <Link
                  to="/notifications"
                  className="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400 focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-green-500"
                >
                  <div className="flex-shrink-0">
                    <Bell className="h-6 w-6 text-gray-400" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="absolute inset-0" aria-hidden="true" />
                    <p className="text-sm font-medium text-gray-900">Notifications</p>
                    <p className="text-sm text-gray-500">View system notifications</p>
                  </div>
                  {unreadCount > 0 && (
                    <span className="absolute -top-2 -right-2 h-6 w-6 text-sm flex items-center justify-center bg-red-500 text-white rounded-full">
                      {unreadCount}
                    </span>
                  )}
                </Link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}