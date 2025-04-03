import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { handleError } from '../lib/utils/errors';
import { Booking, BookingMessage } from '../lib/types/booking';

export function useBookings() {
  const { user } = useAuth();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetchBookings = async (): Promise<Booking[]> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: bookings, error: bookingsError } = await supabase
        .rpc('get_user_bookings');

      if (bookingsError) throw bookingsError;
      return bookings || [];
    } catch (err) {
      const appError = handleError(err, 'fetchBookings');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const getBooking = async (id: string): Promise<Booking> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: booking, error: bookingError } = await supabase
        .rpc('get_booking_details', {
          p_booking_id: id
        });

      if (bookingError) throw bookingError;
      return booking;
    } catch (err) {
      const appError = handleError(err, 'getBooking');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const getBookingMessages = async (bookingId: string): Promise<BookingMessage[]> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: messages, error: messagesError } = await supabase
        .from('booking_messages')
        .select(`
          *,
          sender_info:sender_id(
            first_name,
            last_name,
            is_admin:user_roles(
              roles:role_id(name)
            )
          )
        `)
        .eq('booking_id', bookingId)
        .order('created_at', { ascending: true });

      if (messagesError) throw messagesError;

      // Transform the data to match the expected format
      return messages.map(message => ({
        ...message,
        sender_info: {
          ...message.sender_info,
          is_admin: message.sender_info.is_admin.some(role => role.roles.name === 'administrator')
        }
      }));
    } catch (err) {
      const appError = handleError(err, 'getBookingMessages');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const sendBookingMessage = async (bookingId: string, message: string): Promise<void> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { error: messageError } = await supabase
        .rpc('send_booking_message', {
          p_booking_id: bookingId,
          p_message: message
        });

      if (messageError) throw messageError;
    } catch (err) {
      const appError = handleError(err, 'sendBookingMessage');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  return {
    fetchBookings,
    getBooking,
    getBookingMessages,
    sendBookingMessage,
    isLoading,
    error
  };
}