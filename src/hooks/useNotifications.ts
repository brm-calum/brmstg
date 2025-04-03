import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

export function useNotifications() {
  const { user } = useAuth();
  const [unreadCount, setUnreadCount] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (user) {
      loadUnreadCount();
      subscribeToNotifications();
    }
  }, [user]);

  const loadUnreadCount = async () => {
    try {
      const { data: notifications, error } = await supabase
        .from('notifications')
        .select('id', { count: 'exact' })
        .eq('user_id', user?.id)
        .eq('is_read', false);

      if (error) throw error;
      setUnreadCount(notifications?.length || 0);
    } catch (err) {
      console.error('Failed to load notifications:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const subscribeToNotifications = () => {
    const channel = supabase
      .channel('notifications')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${user?.id}`
        },
        () => {
          loadUnreadCount();
        }
      )
      .subscribe();

    return () => {
      channel.unsubscribe();
    };
  };

  return {
    unreadCount,
    isLoading,
    refresh: loadUnreadCount
  };
}