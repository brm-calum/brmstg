import React, { useState, useRef, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { formatRelativeTime } from '../../lib/utils/dates';
import { Files, MessageSquare } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { UserAvatar } from './UserAvatar';
import { MessageBubble } from './MessageBubble';
import { FilesSummary } from './FilesSummary';
import { InquiryResponse, FileInfo } from './InquiryResponse';
import { DebugError } from '../ui/DebugError';
import { uploadFile } from '../../lib/utils/files';

interface InquiryThreadProps {
  inquiry: any;
  onRespond: (message: string) => Promise<void>;
}

export function InquiryThread({ inquiry, onRespond }: InquiryThreadProps) {
  const { user } = useAuth();
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [error, setError] = useState<{ error: Error; debugInfo?: any } | null>(null);
  const [activeTab, setActiveTab] = useState<'messages' | 'files'>('messages'); 
  const [isMarkingRead, setIsMarkingRead] = useState(false);
  const customerId = inquiry.inquirer_id;

  // Mark messages as read when they become visible
  useEffect(() => {
    let timeoutId: number;

    const markMessagesRead = async () => {
      if (!inquiry.responses || isMarkingRead) return;
      
      const unreadMessages = inquiry.responses
        .filter(response => !response.read && response.recipient_id === user?.id)
        .map(response => response.id);
      
      if (unreadMessages.length === 0) return;

      try {
        setIsMarkingRead(true);
        await supabase.rpc('mark_messages_read', {
          p_response_ids: unreadMessages
        });
      } catch (err) {
        console.error('Failed to mark messages as read:', err);
      } finally {
        setIsMarkingRead(false);
      }
    };

    // Delay marking messages as read to ensure they're actually visible
    timeoutId = window.setTimeout(markMessagesRead, 1000);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [inquiry.responses, user?.id]);

  // Scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [inquiry.responses]);

  const handleSubmit = async (message: string) => {
    if (!user) return;
    try {
      await onRespond(message);
    } catch (err: any) {
      setError({
        error: err,
        debugInfo: {
          inquiryId: inquiry.inquiry_id,
          messageLength: message.length,
          userId: user.id
        }
      });
    }
  };
  const renderMessage = (message: any, isInitial = false) => {
    const isOwn = message.user_id === user?.id;
    const showReadStatus = !isOwn && message.recipient_id === user?.id;

    return (
      <div
        className={`flex ${isOwn ? 'justify-end' : 'justify-start'} mb-4`}
        key={message.id}
      >
        <div className={`flex ${isOwn ? 'flex-row-reverse' : 'flex-row'} items-end max-w-[80%]`}>
          <UserAvatar
            firstName={message.user_name.split(' ')[0]}
            lastName={message.user_name.split(' ')[1]}
            className={isOwn ? 'ml-3' : 'mr-3'}
          />
          <MessageBubble
            message={message}
            isOwn={isOwn}
            inquiry={inquiry}
            customerId={customerId}
          />
        </div>
      </div>
    );
  };

  return (
    <div className="flex-1 flex flex-col bg-gray-50 mt-16 h-[calc(100vh-4rem)]">
      {error && (
        <DebugError 
          error={error.error}
          debugInfo={error.debugInfo}
        />
      )}
      <div className="bg-white border-b border-gray-200 shadow-sm sticky top-16 z-10">
        <nav className="max-w-screen-xl mx-auto px-6 flex space-x-8">
          <button
            type="button"
            onClick={() => setActiveTab('messages')} 
            className={`py-5 px-3 border-b-2 font-medium text-sm transition-colors ${
              activeTab === 'messages'
                ? 'border-green-500 text-green-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            <MessageSquare className="h-5 w-5 inline-block mr-2" />
            Messages
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('files')}
            className={`py-5 px-3 border-b-2 font-medium text-sm transition-colors ${
              activeTab === 'files'
                ? 'border-green-500 text-green-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
            }`}
          >
            <Files className="h-5 w-5 inline-block mr-2" />
            Files
          </button>
        </nav>
      </div>

      {/* Content */}
      {activeTab === 'messages' ? (
        <div className="flex-1 overflow-y-auto p-4 md:p-6 mb-auto">
          <div className="max-w-screen-xl mx-auto">
          {/* Initial Message */}
          {renderMessage({
            id: inquiry.inquiry_id,
            message: inquiry.initial_message,
            user_id: inquiry.inquirer_id,
            user_name: `${inquiry.inquirer_first_name} ${inquiry.inquirer_last_name}`,
            created_at: inquiry.created_at,
            files: inquiry.files || []
          }, true)}

          {/* Responses */}
          {inquiry.responses?.map((response: any) => renderMessage(response))}
          <div ref={messagesEndRef} />
          </div>
        </div>
      ) : (
        <div className="flex-1 overflow-y-auto p-4 md:p-6 mb-auto">
          <div className="max-w-screen-xl mx-auto">
          <FilesSummary inquiry={inquiry} customerId={customerId} />
          </div>
        </div>
      )}
      
      {/* Response Form */}
      {inquiry.thread_status === 'open' && (
        <div className="mt-auto">
          <InquiryResponse
            inquiryId={inquiry.inquiry_id}
            onSubmit={handleSubmit} 
          />
        </div>
      )}
    </div>
  );
}