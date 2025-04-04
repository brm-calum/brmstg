import React, { useCallback } from 'react';
import { Calendar, Star } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { Conversation } from '../../lib/types/inquiry';
import { formatRelativeTime } from '../../lib/utils/dates';
import { UserAvatar } from './UserAvatar';
import { ConversationStatus } from './ConversationStatus';

interface ConversationListItemProps {
  conversation: Conversation;
  isSelected: boolean;
  onSelect: (id: string) => void;
  onUpdatePriority: (id: string, isPriority: boolean) => void;
}

export function ConversationListItem({
  conversation,
  isSelected,
  onSelect,
  onUpdatePriority
}: ConversationListItemProps) {
  const hasUnread = conversation.unread_count > 0;
  const { user } = useAuth();
  const isRecipient = conversation.responses?.some(r => r.recipient_id === user?.id);

  const handlePriorityToggle = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    onUpdatePriority(conversation.inquiry_id, !conversation.is_priority);
  }, [conversation.inquiry_id, conversation.is_priority, onUpdatePriority]);

  return (
    <button
      onClick={() => onSelect(conversation.inquiry_id)}
      className={`w-full text-left px-4 py-3 hover:bg-gray-100 focus:outline-none transition-colors ${
        isSelected ? 'bg-gray-100' : ''
      }`}
    >
      <div className="flex items-start space-x-3">
        <UserAvatar 
          firstName={conversation.inquirer_first_name}
          lastName={conversation.inquirer_last_name}
          isOnline={conversation.status === 'pending'}
        />
        <div className="flex-1 min-w-0">
          <div className="flex justify-between items-start">
            <h3 className="text-sm font-medium text-gray-900 truncate">
              {conversation.warehouse_name} - {conversation.inquiry_code}
            </h3>
            <div className="flex items-center space-x-1 text-xs text-gray-500">
              <span>{formatRelativeTime(conversation.updated_at)}</span>
              {conversation.is_priority !== undefined && (
                <div
                  role="button"
                  tabIndex={0}
                  onClick={handlePriorityToggle}
                  className={`p-1 rounded-full hover:bg-gray-200 focus:outline-none ${
                    conversation.is_priority ? 'text-amber-500' : 'text-gray-400'
                  }`}
                >
                  <Star className="h-4 w-4" />
                </div>
              )}
            </div>
          </div>
          <div className="mt-0.5 flex items-center justify-between">
            <p className="text-sm text-gray-600 truncate">
              {conversation.responses?.[conversation.responses.length - 1]?.message || conversation.message}
            </p>
            {isRecipient && hasUnread && (
              <span className="flex items-center justify-center h-5 w-5 rounded-full text-xs font-medium text-white bg-green-500">
                {conversation.unread_count}
              </span>
            )}
          </div>
        </div>
      </div>
    </button>
  );
}