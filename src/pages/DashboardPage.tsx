import React from 'react';
import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { Building2, MessageSquare, Plus, Warehouse, FileText } from 'lucide-react';
import { useBookingMessages } from '../hooks/useBookingMessages';
import { supabase } from '../lib/supabase';
import { AuthGuard } from '../components/auth/AuthGuard';

export function DashboardPage() {
  const navigate = useNavigate();
  const { user, hasRole } = useAuth();
  const { unreadCount } = useBookingMessages();
  const [stats, setStats] = useState({
    totalInquiries: 0,
    totalBookings: 0,
    activeInquiries: 0,
    submittedInquiries: 0,
    activeBookings: 0,
    totalWarehouses: 0
  });
  const [isLoading, setIsLoading] = useState(true);
  const isWarehouseOwner = hasRole('warehouse_owner');
  const isTrader = hasRole('customer');
  const isAdmin = hasRole('administrator');

  useEffect(() => {
    if (user) {
      loadStats();
      setupSubscriptions();
    }

    return () => {
      // Cleanup subscriptions
      supabase.removeAllChannels();
    };
  }, [user]);

  const setupSubscriptions = () => {
    if (!user) return;

    // Subscribe to inquiries changes
    const inquiriesChannel = supabase
      .channel('inquiries_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'booking_inquiries',
          filter: isAdmin ? undefined : `trader_id=eq.${user.id}`
        },
        () => loadStats()
      )
      .subscribe();

    // Subscribe to bookings changes
    const bookingsChannel = supabase
      .channel('bookings_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'bookings',
          filter: isAdmin 
            ? undefined 
            : isTrader 
              ? `trader_id=eq.${user.id}`
              : `warehouse_owner_id=eq.${user.id}`
        },
        () => loadStats()
      )
      .subscribe();

    // Subscribe to warehouses changes for warehouse owners
    if (isWarehouseOwner || isAdmin) {
      const warehousesChannel = supabase
        .channel('warehouses_changes')
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'm_warehouses',
            filter: isAdmin ? undefined : `owner_id=eq.${user.id}`
          },
          () => loadStats()
        )
        .subscribe();
    }
  };

  const loadStats = async () => {
    if (!user) return;
    
    setIsLoading(true);
    
    try {
      let inquiriesData, bookingsData, warehousesData;

      if (isAdmin) {
        // Admin sees all stats
        const { data: inquiries } = await supabase
          .from('booking_inquiries')
          .select('status');
        inquiriesData = inquiries;

        const { data: bookings } = await supabase
          .from('bookings')
          .select('status');
        bookingsData = bookings;

        const { data: warehouses } = await supabase
          .from('m_warehouses')
          .select('id');
        warehousesData = warehouses;
      } else if (isTrader) {
        // Trader sees their inquiries and bookings
        const { data: inquiries } = await supabase
          .from('booking_inquiries')
          .select('status')
          .eq('trader_id', user.id);
        inquiriesData = inquiries;

        const { data: bookings } = await supabase
          .from('bookings')
          .select('status')
          .eq('trader_id', user.id);
        bookingsData = bookings;
      } else if (isWarehouseOwner) {
        // Warehouse owner sees their warehouses and related bookings
        const { data: warehouses } = await supabase
          .from('m_warehouses')
          .select('id')
          .eq('owner_id', user.id);
        warehousesData = warehouses;

        const { data: bookings } = await supabase
          .from('bookings')
          .select('status')
          .eq('warehouse_owner_id', user.id);
        bookingsData = bookings;
      }

      setStats({
        totalInquiries: inquiriesData?.length || 0,
        totalBookings: bookingsData?.length || 0,
        activeInquiries: inquiriesData?.filter(i => 
          ['submitted', 'under_review', 'offer_pending', 'offer_sent'].includes(i.status)
        ).length || 0,
        submittedInquiries: inquiriesData?.filter(i => i.status === 'submitted').length || 0,
        activeBookings: bookingsData?.filter(b => b.status === 'active').length || 0,
        totalWarehouses: warehousesData?.length || 0
      });
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-green-600" />
      </div>
    );
  }

  if (!user) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-center">
          <p className="text-gray-600">Please sign in to view your dashboard</p>
          <button
            onClick={() => navigate('/login')}
            className="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
          >
            Sign In
          </button>
        </div>
      </div>
    );
  }

  return (
    <AuthGuard>
      <div className="py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center">
            <div className="flex-1">
              <h1 className="text-2xl font-semibold text-gray-900">Welcome Back</h1>
              <p className="mt-2 text-sm text-gray-600">
                {isWarehouseOwner ? 'Manage your warehouse listings and bookings' : 'Track your inquiries and bookings'}
              </p>
            </div>
          </div>
          
          <div className="mt-6 grid gap-6 md:grid-cols-3">
            {/* Warehouse Owner Stats */}
            {isWarehouseOwner && (
              <>
                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <Building2 className="h-8 w-8 text-green-600" />
                    <div className="ml-4">
                      <h2 className="text-lg font-medium text-gray-900">My Warehouses</h2>
                      <p className="text-3xl font-bold text-gray-900">{stats.totalWarehouses}</p>
                    </div>
                  </div>
                  <Link
                    to="/m-warehouses/dashboard"
                    className="mt-4 inline-flex items-center text-sm font-medium text-green-600 hover:text-green-700"
                  >
                    View all warehouses
                    <span className="ml-1">→</span>
                  </Link>
                </div>

                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <MessageSquare className="h-8 w-8 text-blue-600" />
                    <div className="ml-4">
                      <h2 className="text-lg font-medium text-gray-900">My Messages</h2>
                      <div className="flex items-center">
                        <p className="text-3xl font-bold text-gray-900">{unreadCount}</p>
                        <span className="ml-2 text-sm text-gray-500">unread</span>
                      </div>
                    </div>
                  </div>
                  <Link
                    to="/messages"
                    className="mt-4 inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-700"
                  >
                    View messages
                    <span className="ml-1">→</span>
                  </Link>
                </div>
              </>
            )}

            {/* Trader Stats */}
            {isTrader && (
              <>
                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <FileText className="h-8 w-8 text-blue-600" />
                    <div className="ml-4">
                      <h2 className="text-lg font-medium text-gray-900">My Inquiries</h2>
                      <div className="flex items-center">
                        <p className="text-3xl font-bold text-gray-900">{stats.activeInquiries}</p>
                        <span className="ml-2 text-sm text-gray-500">active</span>
                      </div>
                    </div>
                  </div>
                  <Link
                    to="/inquiries"
                    className="mt-4 inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-700"
                  >
                    View all inquiries
                    <span className="ml-1">→</span>
                  </Link>
                </div>

                <div className="bg-white rounded-lg shadow p-6">
                  <div className="flex items-center">
                    <MessageSquare className="h-8 w-8 text-blue-600" />
                    <div className="ml-4">
                      <h2 className="text-lg font-medium text-gray-900">My Messages</h2>
                      <div className="flex items-center">
                        <p className="text-3xl font-bold text-gray-900">{unreadCount}</p>
                        <span className="ml-2 text-sm text-gray-500">unread</span>
                      </div>
                    </div>
                  </div>
                  <Link
                    to="/messages"
                    className="mt-4 inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-700"
                  >
                    View messages
                    <span className="ml-1">→</span>
                  </Link>
                </div>
              </>
            )}

            {/* Common Stats */}
            <div className="bg-white rounded-lg shadow p-6">
              <div className="flex items-center">
                <Building2 className="h-8 w-8 text-blue-600" />
                <div className="ml-4">
                  <h2 className="text-lg font-medium text-gray-900">My Bookings</h2>
                  <div className="flex items-center">
                    <p className="text-3xl font-bold text-gray-900">{stats.activeBookings}</p>
                    <span className="ml-2 text-sm text-gray-500">active</span>
                  </div>
                </div>
              </div>
              <Link
                to="/bookings"
                className="mt-4 inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-700"
              >
                View all bookings
                <span className="ml-1">→</span>
              </Link>
            </div>
          </div>

          {/* Quick Actions */}
          <div className="mt-8">
            <h2 className="text-lg font-medium text-gray-900 mb-4">Quick Actions</h2>
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {/* Warehouse Owner Actions */}
              {isWarehouseOwner && (
                <>
                  <Link
                    to="/m-warehouses/create"
                    className="flex items-center p-4 bg-white shadow rounded-lg hover:shadow-md transition-shadow"
                  >
                    <Plus className="h-6 w-6 text-green-600" />
                    <span className="ml-3 text-gray-900">List New Warehouse</span>
                  </Link>
                  <Link
                    to="/m-warehouses/dashboard"
                    className="flex items-center p-4 bg-white shadow rounded-lg hover:shadow-md transition-shadow"
                  >
                    <Building2 className="h-6 w-6 text-green-600" />
                    <span className="ml-3 text-gray-900">Manage Warehouses</span>
                  </Link>
                </>
              )}

              {/* Trader Actions */}
              {isTrader && (
                <>
                  <Link
                    to="/m-warehouses"
                    className="flex items-center p-4 bg-white shadow rounded-lg hover:shadow-md transition-shadow"
                  >
                    <Warehouse className="h-6 w-6 text-green-600" />
                    <span className="ml-3 text-gray-900">Browse Warehouses</span>
                  </Link>
                  <Link
                    to="/inquiries/new"
                    className="flex items-center p-4 bg-white shadow rounded-lg hover:shadow-md transition-shadow"
                  >
                    <FileText className="h-6 w-6 text-blue-600" />
                    <span className="ml-3 text-gray-900">Create New Inquiry</span>
                  </Link>
                </>
              )}

              {/* Common Actions */}
              <Link
                to="/messages"
                className="flex items-center p-4 bg-white shadow rounded-lg hover:shadow-md transition-shadow"
              >
                <MessageSquare className="h-6 w-6 text-purple-600" />
                <div className="ml-3 flex items-center">
                  <span className="text-gray-900">View Messages</span>
                  {unreadCount > 0 && (
                    <span className="ml-2 px-2 py-1 text-xs font-medium text-white bg-red-500 rounded-full">
                      {unreadCount}
                    </span>
                  )}
                </div>
              </Link>
              <Link
                to="/bookings"
                className="flex items-center p-4 bg-white shadow rounded-lg hover:shadow-md transition-shadow"
              >
                <Building2 className="h-6 w-6 text-purple-600" />
                <div className="ml-3 flex items-center">
                  <span className="text-gray-900">View Bookings</span>
                </div>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}