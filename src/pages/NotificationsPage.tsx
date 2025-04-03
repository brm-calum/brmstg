import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { AuthGuard } from '../components/auth/AuthGuard';
import { useNotifications } from '../hooks/useNotifications';
import { formatDate } from '../lib/utils/dates';
import { 
  Bell, FileText, Package, MessageSquare, 
  Building2, CheckCircle, Loader, Check 
} from 'lucide-react';
import { supabase } from '../lib/supabase';

interface Notification {
  id: string;
  type: string;
  title: string;
  message: string;
  created_at: string;
  is_read: boolean;
  inquiry_id?: string;
  booking_id?: string;
  thread_info?: any;
}

export function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const { refresh } = useNotifications();

  useEffect(() => {
    loadNotifications();
  }, []);

  const loadNotifications = async () => {
    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setNotifications(data || []);
    } catch (err) {
      console.error('Failed to load notifications:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const markAsRead = async (notificationId: string) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_read: true })
        .eq('id', notificationId);

      if (error) throw error;

      // Update local state
      setNotifications(prev =>
        prev.map(n =>
          n.id === notificationId ? { ...n, is_read: true } : n
        )
      );

      // Refresh notification count
      refresh();
    } catch (err) {
      console.error('Failed to mark notification as read:', err);
    }
  };

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'inquiry_message':
      case 'booking_message':
        return <MessageSquare className="h-5 w-5 text-blue-500" />;
      case 'inquiry_submitted':
        return <FileText className="h-5 w-5 text-green-500" />;
      case 'booking_created':
        return <Package className="h-5 w-5 text-purple-500" />;
      case 'booking_confirmed':
        return <CheckCircle className="h-5 w-5 text-green-500" />;
      default:
        return <Bell className="h-5 w-5 text-gray-400" />;
    }
  };

  const getNotificationLink = (notification: Notification) => {
    if (notification.inquiry_id) {
      return `/inquiries/${notification.inquiry_id}`;
    }
    if (notification.booking_id) {
      return `/bookings/${notification.booking_id}`;
    }
    return '#';
  };

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader className="h-8 w-8 animate-spin text-green-600" />
      </div>
    );
  }

  return (
    <AuthGuard requiredRoles={['administrator']}>
      <div className="py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-semibold text-gray-900">Notifications</h1>
            {notifications.some(n => !n.is_read) && (
              <button
                onClick={async () => {
                  const unreadIds = notifications
                    .filter(n => !n.is_read)
                    .map(n => n.id);
                  
                  for (const id of unreadIds) {
                    await markAsRead(id);
                  }
                }}
                className="inline-flex items-center px-3 py-1.5 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                <Check className="h-4 w-4 mr-2" />
                Mark all as read
              </button>
            )}
          </div>

          <div className="mt-6">
            {notifications.length === 0 ? (
              <div className="text-center py-12">
                <Bell className="mx-auto h-12 w-12 text-gray-400" />
                <h3 className="mt-2 text-sm font-medium text-gray-900">No notifications</h3>
                <p className="mt-1 text-sm text-gray-500">
                  You don't have any notifications at the moment.
                </p>
              </div>
            ) : (
              <div className="bg-white shadow overflow-hidden sm:rounded-md">
                <ul role="list" className="divide-y divide-gray-200">
                  {notifications.map((notification) => {
                    const link = getNotificationLink(notification);
                    const NotificationWrapper = link === '#' ? 'div' : Link;

                    return (
                      <li key={notification.id}>
                        <NotificationWrapper
                          to={link}
                          className={`block hover:bg-gray-50 ${
                            !notification.is_read ? 'bg-blue-50' : ''
                          }`}
                        >
                          <div className="px-4 py-4 sm:px-6">
                            <div className="flex items-center justify-between">
                              <div className="flex items-center">
                                {getNotificationIcon(notification.type)}
                                <div className="ml-4">
                                  <p className={`text-sm font-medium ${
                                    notification.is_read ? 'text-gray-900' : 'text-blue-900'
                                  }`}>
                                    {notification.title}
                                  </p>
                                  <p className={`mt-1 text-sm ${
                                    notification.is_read ? 'text-gray-500' : 'text-blue-600'
                                  }`}>
                                    {notification.message}
                                  </p>
                                </div>
                              </div>
                              <div className="ml-6 flex items-center space-x-4">
                                <div className="flex flex-col items-end">
                                  <p className="text-sm text-gray-500">
                                    {formatDate(notification.created_at)}
                                  </p>
                                  {!notification.is_read && (
                                    <button
                                      onClick={(e) => {
                                        e.preventDefault();
                                        e.stopPropagation();
                                        markAsRead(notification.id);
                                      }}
                                      className="mt-1 text-xs text-blue-600 hover:text-blue-800"
                                    >
                                      Mark as read
                                    </button>
                                  )}
                                </div>
                              </div>
                            </div>
                          </div>
                        </NotificationWrapper>
                      </li>
                    );
                  })}
                </ul>
              </div>
            )}
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}