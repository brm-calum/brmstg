import React, { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../../lib/supabase';
import { useBookingMessages } from '../../hooks/useBookingMessages';
import { MessageList } from './MessageList';
import { MessageForm } from './MessageForm';
import { MessageSquare, Loader } from 'lucide-react';

interface MessagingPanelProps {
  inquiryId?: string;
  bookingId?: string;
}

export function MessagingPanel({ inquiryId, bookingId }: MessagingPanelProps) {
  const { getMessages, sendMessage, markAsRead, isLoading } = useBookingMessages();
  const [messages, setMessages] = useState([]);
  const [error, setError] = useState<string | null>(null);
  const [conversationId, setConversationId] = useState<string | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const loadMessages = async () => {
    try {
      // Get conversation ID first
      const { data: conversationId, error: convError } = await supabase
        .rpc('get_conversation_id', {
          p_inquiry_id: inquiryId || null,
          p_booking_id: bookingId || null
        });

      if (convError) {
        console.error('Failed to get conversation:', convError);
        throw convError;
      }

      if (!conversationId) {
        console.warn('No conversation found for inquiry/booking');
        return;
      }

      setConversationId(conversationId);

      const data = await getMessages(
        null,
        null,
        conversationId
      );
      setMessages(data);
    } catch (err) {
      setError('Failed to load messages');
      console.error('Failed to load messages:', err);
    }
  };

  // Scroll to bottom when messages change
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages]);

  useEffect(() => {
    if (inquiryId || bookingId) {
      loadMessages();
      
      // Subscribe to message updates
      const channel = supabase
        .channel(`messages:${conversationId || 'none'}`)
        .on(
          'postgres_changes',
          {
            event: 'INSERT',
            schema: 'public',
            table: 'booking_messages',
            filter: conversationId ? `conversation_id=eq.${conversationId}` : undefined
          },
          () => {
            loadMessages();
          }
        )
        .subscribe();

      // Subscribe to read status updates
      const readStatusChannel = supabase
        .channel(`read_status:${conversationId || 'none'}`)
        .on(
          'postgres_changes',
          {
            event: 'UPDATE',
            schema: 'public',
            table: 'message_read_status'
          },
          () => {
            loadMessages();
          }
        )
        .subscribe();

      return () => {
        channel.unsubscribe();
        readStatusChannel.unsubscribe();
      };
    }
  }, [inquiryId, bookingId, conversationId]);

  const handleSendMessage = async (message: string) => {
    try {
      setError(null);
      // Ensure we pass null for the ID that isn't being used
      await sendMessage(
        inquiryId || null,
        bookingId || null,
        message
      );
      await loadMessages();
    } catch (err) {
      setError('Failed to send message');
      console.error('Failed to send message:', err);
    }
  };

  const handleMessagesRead = async (messageIds: string[]) => {
    try {
      if (!messageIds?.length) return;
      await markAsRead(messageIds);
    } catch (err) {
      console.error('Failed to mark messages as read:', err);
    }
  };

  if (isLoading) {
    return (
      <div className="bg-white shadow rounded-lg p-4 sm:p-6">
        <div className="flex items-center justify-center h-[400px]">
          <Loader className="h-8 w-8 animate-spin text-green-600" />
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white shadow rounded-lg overflow-hidden">
      <div className="px-4 sm:px-6 py-3 sm:py-4 border-b border-gray-200">
        <h2 className="text-lg font-medium text-gray-900">Messages</h2>
      </div>
      <div className="h-[400px] sm:h-[500px] flex flex-col">
        <div className="flex-1 p-4 sm:p-6 overflow-y-auto">
          {error && (
            <div className="mb-4 bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded relative">
              {error}
            </div>
          )}

          <MessageList 
            messages={messages} 
            conversationId={conversationId}
            onRead={handleMessagesRead} 
          />
          <div ref={messagesEndRef} />
        </div>

        <div className="p-4 sm:p-6 border-t border-gray-200">
          <MessageForm onSend={handleSendMessage} disabled={isLoading} />
        </div>
      </div>
    </div>
  );
}