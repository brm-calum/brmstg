import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { AuthGuard } from '../../components/auth/AuthGuard';
import { useBookings } from '../../hooks/useBookings';
import { BookingDetails } from '../../components/bookings/BookingDetails';
import { MessagingPanel } from '../../components/inquiries/MessagingPanel';
import { ArrowLeft, Loader } from 'lucide-react';

export function BookingDetailsPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { getBooking, isLoading } = useBookings();
  const [booking, setBooking] = useState(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (id) {
      loadBooking(id);
    }
  }, [id]);

  const loadBooking = async (bookingId: string) => {
    try {
      const data = await getBooking(bookingId);
      setBooking(data);
    } catch (err) {
      console.error('Failed to load booking:', err);
      setError(err instanceof Error ? err.message : 'Failed to load booking');
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader className="h-8 w-8 animate-spin text-green-600" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-red-50 border-l-4 border-red-400 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <ArrowLeft className="h-5 w-5 text-red-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-red-700">{error}</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!booking) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <ArrowLeft className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Booking not found. It may have been deleted or you don't have permission to view it.
              </p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <AuthGuard>
      <div className="py-6 px-2 sm:px-0">
        <div className="max-w-7xl mx-auto px-2 sm:px-6 lg:px-8">
          <div className="flex items-center mb-6">
            <button
              onClick={() => navigate(-1)}
              className="mr-4 text-gray-600 hover:text-gray-900"
            >
              <ArrowLeft className="h-5 w-5" />
            </button>
            <h1 className="text-2xl font-bold text-gray-900">
              Booking Details
            </h1>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
            {/* Booking Details */}
            <div>
              <BookingDetails booking={booking} />
            </div>

            {/* Messages */}
            <div>
              <MessagingPanel bookingId={id} />
            </div>
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}