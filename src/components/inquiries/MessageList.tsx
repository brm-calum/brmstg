import React, { useState, useEffect } from 'react';
import { formatDate } from '../../lib/utils/dates';
import { useAuth } from '../../contexts/AuthContext';
import { supabase } from '../../lib/supabase';

interface Message {
  id: string;
  message: string;
  created_at: string;
  is_read: boolean;
  sender_info?: {
    id?: string;
    first_name: string;
    last_name: string;
    is_admin: boolean;
  };
  is_system_message?: boolean;
}

export interface Message {
  id: string;
  message: string;
  created_at: string;
  is_read: boolean;
  sender_info?: {
    id?: string;
    first_name: string;
    last_name: string;
    is_admin: boolean;
  };
  is_system_message?: boolean;
}

interface MessageListProps {
  messages: Message[];
  conversationId?: string;
  onRead?: (messageIds: string[]) => Promise<void>;
}

export function MessageList({ messages, conversationId, onRead }: MessageListProps) {
  const { user } = useAuth();

  useEffect(() => {
    if (onRead && messages?.length > 0) {
      // Get IDs of unread messages not sent by current user
      const unreadMessageIds = messages
        .filter(m => !m.is_read && m.sender_info?.id !== user?.id)
        .map(m => m.id);
      
      if (unreadMessageIds.length > 0) {
        onRead(unreadMessageIds);
      }
    }
  }, [messages, user?.id]);

  // Mark messages as read when viewed
  useEffect(() => {
    if (conversationId && messages?.length > 0) {
      // Use the on_message_list_viewed function to mark messages as read
      supabase
        .rpc('on_message_list_viewed', {
          p_conversation_id: conversationId
        })
        .then(({ error }) => {
          if (error) {
            console.error('Failed to mark messages as read:', error);
          }
        });
    }
  }, [conversationId, messages?.length]);

  if (!messages?.length) {
    return (
      <div className="text-center py-8 text-gray-500">
        No messages yet
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {messages.map((message) => {
        // Handle system messages and regular messages differently
        const isSystemMessage = message.is_system_message;
        const isOwnMessage = !isSystemMessage && message.sender_info?.id === user?.id;
        
        return (
          <div 
            key={message.id}
            className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`
              max-w-[70%] rounded-lg px-4 py-2 transition-colors
              ${isOwnMessage 
                ? 'bg-green-100 text-green-900' 
                : isSystemMessage
                  ? 'bg-blue-50 text-blue-900'
                  : message.is_read
                    ? 'bg-gray-100 text-gray-900'
                    : 'bg-blue-100 text-blue-900'}
            `}>
              <div className="flex items-center space-x-2 mb-1">
                <span className={`text-sm font-medium ${
                  isSystemMessage
                    ? 'text-blue-700'
                    : message.sender_info?.is_admin
                      ? 'text-green-700'
                      : 'text-gray-700'
                }`}>
                  {isSystemMessage
                    ? 'System'
                    : `${message.sender_info?.first_name || ''} ${message.sender_info?.last_name || ''}`}
                  {message.sender_info?.is_admin && ' (Admin)'}
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
  );
}