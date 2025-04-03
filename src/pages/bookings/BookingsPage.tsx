import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { AuthGuard } from '../../components/auth/AuthGuard';
import { useBookings } from '../../hooks/useBookings';
import { formatDate } from '../../lib/utils/dates';
import { Building2, Calendar, Euro, Loader, ExternalLink } from 'lucide-react';

export function BookingsPage() {
  const { fetchBookings, isLoading } = useBookings();
  const [bookings, setBookings] = useState([]);

  useEffect(() => {
    loadBookings();
  }, []);

  const loadBookings = async () => {
    try {
      const data = await fetchBookings();
      setBookings(data);
    } catch (err) {
      console.error('Failed to load bookings:', err);
    }
  };

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'active':
        return 'bg-green-100 text-green-800';
      case 'completed':
        return 'bg-blue-100 text-blue-800';
      case 'cancelled':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
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
    <AuthGuard>
      <div className="py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="md:flex md:items-center md:justify-between">
            <div className="min-w-0 flex-1">
              <h2 className="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:tracking-tight">
                My Bookings
              </h2>
              <p className="mt-1 text-sm text-gray-500">
                View and manage your warehouse bookings
              </p>
            </div>
          </div>

          <div className="mt-8">
            {bookings.length === 0 ? (
              <div className="text-center py-12 bg-white rounded-lg shadow">
                <Building2 className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No bookings</h3>
                <p className="mt-1 text-sm text-gray-500">
                  You don't have any active bookings yet.
                </p>
                <div className="mt-6">
                  <Link
                    to="/m-warehouses"
                    className="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
                  >
                    Browse Warehouses
                  </Link>
                </div>
              </div>
            ) : (
              <div className="bg-white shadow overflow-hidden sm:rounded-md">
                <ul role="list" className="divide-y divide-gray-200">
                  {bookings.map((booking) => (
                    <li key={booking.id}>
                      <Link to={`/bookings/${booking.id}`} className="block hover:bg-gray-50">
                        <div className="px-4 py-4 sm:px-6">
                          <div className="flex items-center justify-between">
                            <div className="flex items-center">
                              <Building2 className="h-5 w-5 text-gray-400 mr-2" />
                              <p className="text-sm font-medium text-gray-900 truncate">
                                {booking.warehouse.name}
                              </p>
                            </div>
                            <div className="ml-2 flex-shrink-0">
                              <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${getStatusBadgeClass(booking.status)}`}>
                                {booking.status}
                              </span>
                            </div>
                          </div>
                          <div className="mt-2 sm:flex sm:justify-between">
                            <div className="sm:flex">
                              <div className="flex items-center text-sm text-gray-500">
                                <Calendar className="flex-shrink-0 mr-1.5 h-4 w-4 text-gray-400" />
                                {formatDate(booking.start_date)} - {formatDate(booking.end_date)}
                              </div>
                            </div>
                            <div className="mt-2 flex items-center text-sm text-gray-500 sm:mt-0">
                              <Euro className="flex-shrink-0 mr-1.5 h-4 w-4 text-gray-400" />
                              {(booking.total_cost_cents / 100).toFixed(2)}
                              <ExternalLink className="flex-shrink-0 ml-2 h-4 w-4" />
                            </div>
                          </div>
                        </div>
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}