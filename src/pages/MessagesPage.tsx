import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Link } from 'react-router-dom';
import { AuthGuard } from '../components/auth/AuthGuard';
import { useBookingMessages } from '../hooks/useBookingMessages';
import { MessageList, Message } from '../components/inquiries/MessageList';
import { MessageForm } from '../components/inquiries/MessageForm';
import { MessageSquare, Building2, Calendar } from 'lucide-react';
import { formatDate } from '../lib/utils/dates';

interface Thread {
  thread_id: string;
  thread_type: 'inquiry' | 'booking';
  thread_info: {
    warehouses?: { name: string }[];
    warehouse?: { name: string };
    status: string;
  };
  last_message_at: string;
  unread_count: number;
}

export function MessagesPage() {
  const navigate = useNavigate();
  const { getMessages, sendMessage, threads, isLoading } = useBookingMessages();
  const [selectedThread, setSelectedThread] = useState<Thread | null>(null);
  const [messages, setMessages] = useState<any[]>([]);

  // Log raw conversation threads when they change
  useEffect(() => {
    console.log("Raw conversation threads:", threads);
  }, [threads]);

  useEffect(() => {
    if (selectedThread) {
      loadMessages();
    }
  }, [selectedThread?.thread_id]);

  const loadMessages = async () => {
    try {
      const data = await getMessages(
        null,
        null,
        selectedThread?.thread_id
      );
      setMessages(data);
    } catch (err) {
      console.error('Failed to load messages:', err);
    }
  };

  const handleSendMessage = async (message: string) => {
    if (!selectedThread) return;
    
    const inquiryId = selectedThread.thread_type === 'inquiry' ? selectedThread.thread_info.id : null;
    const bookingId = selectedThread.thread_type === 'booking' ? selectedThread.thread_info.id : null;
    
    try {
      await sendMessage(
        inquiryId,
        bookingId,
        message
      );
      await loadMessages();
    } catch (err) {
      console.error('Failed to send message:', err);
    }
  };

  return (
    <AuthGuard>
      <div className="py-6">
        <div className="max-w-7xl mx-auto px-2 sm:px-6 lg:px-8">
          <div className="flex items-center mb-6">
            <MessageSquare className="h-6 w-6 text-gray-400 mr-2" />
            <h1 className="text-2xl font-bold text-gray-900">
              Messages
            </h1>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-12 gap-4 md:gap-6">
            {/* Conversations List */}
            <div className="md:col-span-4 bg-white rounded-lg shadow overflow-hidden">
              <div className="px-3 sm:px-4 py-3 border-b border-gray-200">
                <h2 className="text-lg font-medium text-gray-900">Conversations</h2>
              </div>
              <div className="divide-y divide-gray-200 max-h-[calc(100vh-12rem)] md:max-h-[calc(100vh-16rem)] overflow-y-auto">
                {threads.map((thread) => (
                  <button
                    key={thread.thread_id}
                    onClick={() => setSelectedThread(thread)}
                    className={`w-full px-4 py-3 text-left hover:bg-gray-50 focus:outline-none transition-all ${
                      selectedThread?.thread_id === thread.thread_id ? 'bg-green-50' : 
                      thread.unread_count > 0 ? 'bg-blue-50 font-medium' : ''
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <div className={`text-sm ${thread.unread_count > 0 ? 'font-bold text-blue-900' : 'text-gray-900'}`}>
                          {thread.thread_type === 'inquiry' ? 'Inquiry' : 'Booking'} #{thread.thread_info.id.slice(0, 8)}
                        </div>
                        <div className={`mt-1 text-xs ${thread.unread_count > 0 ? 'text-blue-600 font-medium' : 'text-gray-500'} flex items-center truncate max-w-[150px]`}>
                          <Building2 className="h-3 w-3 mr-1" />
                          {thread.thread_info.warehouses?.[0]?.name || thread.thread_info.warehouse?.name || 'No warehouse'}
                        </div>
                        <div className={`mt-1 text-xs ${thread.unread_count > 0 ? 'text-blue-600 font-medium' : 'text-gray-500'} flex items-center`}>
                          <Calendar className="h-3 w-3 mr-1" />
                          {formatDate(thread.last_message_at)}
                        </div>
                      </div>
                      <div className="flex flex-col items-end space-y-2">
                        <div className={`px-2 py-1 text-xs font-medium rounded-full ${
                        thread.thread_info.status === 'accepted' ? 'bg-green-100 text-green-800' :
                        thread.thread_info.status === 'rejected' ? 'bg-red-100 text-red-800' :
                        'bg-gray-100 text-gray-800'
                        }`}>
                          {thread.thread_info.status.replace('_', ' ')}
                        </div>
                        {thread.unread_count > 0 && (
                          <span className="px-2 py-1 text-xs font-bold bg-red-500 text-white rounded-full shadow-sm">
                            {thread.unread_count}
                          </span>
                        )}
                      </div>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* Messages */}
            <div className="md:col-span-8 bg-white rounded-lg shadow">
              {selectedThread ? (
                <div className="h-full flex flex-col">
                  <div className="px-4 sm:px-6 py-3 sm:py-4 border-b border-gray-200">
                    <div className="text-lg font-medium text-gray-900">
                      {selectedThread.thread_type === 'inquiry' ? 'Inquiry' : 'Booking'} #{selectedThread.thread_info.id.slice(0, 8)}
                    </div>
                    <div className="mt-1 text-sm text-gray-500 truncate">
                      {selectedThread.thread_info.warehouses?.[0]?.name || selectedThread.thread_info.warehouse?.name}
                    </div>
                  </div>
                  
                  <div className="flex-1 p-4 sm:p-6 overflow-y-auto">
                    <MessageList 
                      messages={messages} 
                      conversationId={selectedThread?.thread_id}
                      onRead={async (messageIds) => {
                        try {
                          await markAsRead(messageIds);
                        } catch (err) {
                          console.error('Failed to mark messages as read:', err);
                        }
                      }}
                    />
                  </div>
                  
                  <div className="px-4 sm:px-6 py-3 sm:py-4 border-t border-gray-200">
                    <MessageForm onSend={handleSendMessage} disabled={isLoading} />
                  </div>
                </div>
              ) : (
                <div className="h-[300px] md:h-full flex items-center justify-center text-gray-500 p-4 text-center">
                  Select an inquiry to view messages
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}