import React, { useMemo } from 'react';
import { MessageSquare } from 'lucide-react';
import { useAuth } from '../../contexts/AuthContext';
import { Conversation, InquiryPriority } from '../../lib/types/inquiry';
import { ConversationListItem } from './ConversationListItem';
import { LoadingSpinner } from '../ui/LoadingSpinner';
import { EmptyState } from '../ui/EmptyState';

interface ConversationListProps {
  conversations: Conversation[];
  selectedId: string | null;
  isLoading?: boolean;
  onSelect: (id: string) => void;
  onUpdatePriority: (id: string, isPriority: boolean) => void;
}

export function ConversationList({ 
  conversations, 
  selectedId, 
  isLoading, 
  onSelect,
  onUpdatePriority 
}: ConversationListProps) {
  const { user } = useAuth();

  // Sort conversations by priority, unread status, and last activity
  const sortedConversations = useMemo(() => {
    return [...conversations].sort((a, b) => {
      // First sort by priority
      if (a.is_priority !== b.is_priority) {
        return a.is_priority ? -1 : 1;
      }
      
      // Then sort by unread status
      const aUnread = (a.unread_count || 0) > 0;
      const bUnread = (b.unread_count || 0) > 0;
      if (aUnread !== bUnread) {
        return aUnread ? -1 : 1;
      }
      
      // Finally sort by last activity (updated_at)
      return new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime();
    });
  }, [conversations]);

  if (isLoading) {
    return (
      <div className="flex-1 flex items-center justify-center text-gray-500">
        <LoadingSpinner />
      </div>
    );
  }

  if (conversations.length === 0) {
    return (
      <div className="flex-1 flex items-center justify-center text-gray-500">
        <EmptyState />
      </div>
    );
  }

  // Group conversations by priority and read status
  const groupedConversations = useMemo(() => {
    return sortedConversations.reduce((acc, conv) => {
      const key = conv.is_priority ? 'priority' :
                  conv.unread_count ? 'unread' : 'read';
      acc[key] = [...(acc[key] || []), conv];
      return acc;
    }, {} as Record<string, Conversation[]>); 
  }, [sortedConversations]);

  const renderSection = (title: string, items: Conversation[]) => {
    if (!items?.length) return null;

    return (
      <div>
        <h3 className="px-4 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider">
          {title} ({items.length})
        </h3>
        {items.map((conversation) => (
          <ConversationListItem
            key={conversation.inquiry_id}
            conversation={conversation}
            isSelected={selectedId === conversation.inquiry_id}
            onSelect={onSelect}
            onUpdatePriority={onUpdatePriority}
          />
        ))}
      </div>
    );
  };

  return (
    <div className="flex-1 overflow-y-auto bg-white divide-y divide-gray-100">
      {renderSection('Priority', groupedConversations.priority)}
      {renderSection('Unread', groupedConversations.unread)}
      {renderSection('Read', groupedConversations.read)}
    </div>
  );
}