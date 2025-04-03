import React, { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { BookingMessage } from '../../lib/types/booking';
import { formatDate } from '../../lib/utils/dates';
import { Send } from 'lucide-react';

interface BookingMessagesProps {
  messages: BookingMessage[];
  onSendMessage: (message: string) => Promise<void>;
}

export function BookingMessages({ messages, onSendMessage }: BookingMessagesProps) {
  const { user } = useAuth();
  const [newMessage, setNewMessage] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newMessage.trim() || isSubmitting) return;

    try {
      setIsSubmitting(true);
      await onSendMessage(newMessage);
      setNewMessage('');
    } catch (err) {
      console.error('Failed to send message:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="bg-white shadow rounded-lg flex flex-col h-full">
      <div className="px-6 py-4 border-b border-gray-200">
        <h2 className="text-lg font-medium text-gray-900">Messages</h2>
      </div>

      {/* Message List */}
      <div className="flex-1 p-6 overflow-y-auto">
        <div className="space-y-4">
          {messages.map((message) => {
            const isOwnMessage = message.sender_id === user?.id;
            
            return (
              <div 
                key={message.id}
                className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'}`}
              >
                <div className={`
                  max-w-[70%] rounded-lg px-4 py-2
                  ${isOwnMessage 
                    ? 'bg-green-100 text-green-900' 
                    : 'bg-gray-100 text-gray-900'}
                `}>
                  <div className="flex items-center space-x-2 mb-1">
                    <span className={`text-sm font-medium ${
                      message.sender_info.is_admin ? 'text-green-700' : 'text-gray-700'
                    }`}>
                      {message.sender_info.first_name} {message.sender_info.last_name}
                      {message.sender_info.is_admin && ' (Admin)'}
                    </span>
                    <span className="text-xs text-gray-500">
                      {formatDate(message.created_at)}
                    </span>
                  </div>
                  <p className="text-sm whitespace-pre-wrap">{message.message}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Message Input */}
      <div className="px-6 py-4 border-t border-gray-200">
        <form onSubmit={handleSubmit} className="flex space-x-4">
          <textarea
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Type your message..."
            className="flex-1 min-h-[80px] rounded-lg border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500"
            disabled={isSubmitting}
          />
          <button
            type="submit"
            disabled={isSubmitting || !newMessage.trim()}
            className="self-end inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50"
          >
            <Send className="h-4 w-4 mr-2" />
            Send
          </button>
        </form>
      </div>
    </div>
  );
}