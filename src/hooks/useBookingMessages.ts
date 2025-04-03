import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { handleError } from '../lib/utils/errors';
import { useEffect } from 'react';
import { logDebug } from '../lib/utils/debug';

export function useBookingMessages() {
  const { user } = useAuth();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);
  const [unreadCount, setUnreadCount] = useState(0);
  const [threads, setThreads] = useState([]);

  useEffect(() => {
    if (user) {
      refresh();
      loadThreads();
      
      // Subscribe to new messages
      const channel = supabase
        .channel('messages')
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'booking_messages'
          },
          () => {
            refresh();
            loadThreads();
          }
        )
        .subscribe();

      // Subscribe to read status changes
      const readStatusChannel = supabase
        .channel('read_status')
        .on(
          'postgres_changes',
          {
            event: 'UPDATE',
            schema: 'public',
            table: 'message_read_status',
            filter: `user_id=eq.${user.id}`
          },
          () => {
            refresh();
            loadThreads();
          }
        )
        .subscribe();

      return () => {
        channel.unsubscribe();
        readStatusChannel.unsubscribe();
      };
    }
  }, [user]);

  const loadThreads = async () => {
    try {
      const { data: threads, error: threadsError } = await supabase
        .rpc('get_user_threads');

      if (threadsError) throw threadsError;
      setThreads(threads || []);
    } catch (err) {
      console.error('Failed to load threads:', err);
    }
  };

  const refresh = async () => {
    try {
      logDebug({
        function_name: 'refresh',
        input_params: { user_id: user?.id }
      });

      if (!user) {
        logDebug({
          function_name: 'refresh',
          error_message: 'No user found'
        });
        return;
      }

      // Load unread count
      const { data: count, error: countError } = await supabase
        .rpc('get_unread_message_count', { p_user_id: user.id });

      if (countError) throw countError;
      setUnreadCount(count || 0);

      // Load threads
      await loadThreads();

      logDebug({
        function_name: 'refresh',
        output_data: { unread_count: count }
      });
    } catch (err) {
      console.error('Failed to load unread count:', err);
      logDebug({
        function_name: 'refresh',
        error_message: err instanceof Error ? err.message : 'Unknown error'
      });
    }
  };

  const getMessages = async (inquiryId?: string | null, bookingId?: string | null, conversationId?: string | null) => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      // Log parameters for debugging
      logDebug({
        function_name: 'getMessages',
        input_params: { 
          inquiryId, 
          bookingId, 
          conversationId 
        }
      });

      let messagesData;
      
      if (conversationId) {
        // If conversation ID is provided, use it directly
        const { data, error } = await supabase
          .rpc('get_thread_messages', {
            p_conversation_id: conversationId
          });
        
        if (error) {
          logDebug({
            function_name: 'getMessages',
            error_message: error.message,
            input_params: { conversationId }
          });
          throw error;
        }
        
        messagesData = data;
      } else if (inquiryId || bookingId) {
        // Get conversation ID first
        const { data: conversation, error: convError } = await supabase
          .rpc('get_conversation_id', {
            p_inquiry_id: inquiryId,
            p_booking_id: bookingId
          });

        if (convError) {
          logDebug({
            function_name: 'getMessages',
            error_message: convError.message,
            input_params: { inquiryId, bookingId }
          });
          throw convError;
        }

        // Use the conversation ID to get messages
        const { data, error } = await supabase
          .rpc('get_thread_messages', { 
            p_conversation_id: conversation
          });
        
        if (error) {
          logDebug({
            function_name: 'getMessages',
            error_message: error.message,
            input_params: { conversation }
          });
          throw error;
        }
        
        messagesData = data;
      }

      // Log success
      logDebug({
        function_name: 'getMessages',
        output_data: { 
          messageCount: messagesData?.length || 0 
        }
      });

      return messagesData || [];
    } catch (err) {
      const appError = handleError(err, 'getMessages');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const sendMessage = async (inquiryId: string | null, bookingId: string | null, message: string): Promise<void> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      // Send message to all recipients
      const { error: sendError } = await supabase
        .rpc('send_conversation_message', {
          p_inquiry_id: inquiryId,
          p_booking_id: bookingId,
          p_message: message
        });

      if (sendError) throw sendError;
    } catch (err) {
      const appError = handleError(err, 'sendMessage');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const markAsRead = async (messageIds: string[]) => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      const { error: markError } = await supabase
        .rpc('mark_messages_read', { p_message_ids: messageIds });

      if (markError) throw markError;
      await refresh();
    } catch (err) {
      const appError = handleError(err, 'markAsRead');
      setError(appError);
      throw appError;
    }
  };

  return {
    getMessages,
    sendMessage,
    markAsRead,
    unreadCount,
    threads,
    isLoading,
    error,
    refresh
  };
}