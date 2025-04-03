import React, { useState, useRef, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { signOut } from '../../lib/auth';
import { useAuth } from '../../contexts/AuthContext';
import { useNotifications } from '../../hooks/useNotifications';
import { useBookingMessages } from '../../hooks/useBookingMessages';
import { LogOut, LogIn, Warehouse, Building2, ChevronDown, FileText, MessageSquare, LayoutDashboard } from 'lucide-react';
import { AdminMenu } from './AdminMenu';
import { UserMenu } from './UserMenu';

export function Navbar({ className = '' }: { className?: string }) {
  const navigate = useNavigate();
  const { user, hasRole } = useAuth();
  const { unreadCount } = useBookingMessages();
  const { unreadCount: adminUnreadCount } = useNotifications();
  const [isWarehouseOpen, setIsWarehouseOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsWarehouseOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSignOut = async () => {
    try {
      await signOut();
      localStorage.removeItem('brm-warehouse-auth');
      window.location.href = '/';
    } catch (error) {
      console.error('Sign out error:', error);
      window.location.href = '/';
    }
  };

  return (
    <nav className={`bg-white shadow-sm ${className}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16">
        <div className="flex items-center justify-between h-full">
          <div className="flex items-center">
            <Link to="/" className="flex items-center">
              <img 
                src="/images/BRM_Main_Logo-1.png"
                alt="BRM Warehouse" 
                className="h-8 sm:h-10 w-auto min-w-[120px] sm:min-w-[140px] object-contain"
              />
            </Link>
          </div>

          <div className="flex items-center space-x-1 sm:space-x-2">
            {user ? (
              <>
                {hasRole('administrator') ? (
                  <AdminMenu />
                <Link
          to="/notifications"
          className="text-gray-600 hover:text-gray-900 px-2.5 py-2 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
        >
          <div className="relative inline-flex items-center">
            <Bell className="h-4 w-4 mr-2" />
            Notifications
            {adminUnreadCount > 0 && (
              <span className="absolute -top-1 -right-1 h-4 w-4 text-xs flex items-center justify-center bg-red-500 text-white rounded-full">
                {adminUnreadCount}
              </span>
            )}
          </div>
        </Link>
                ) : (

                  <Link
                  to="/dashboard"
                  className="flex items-center text-gray-600 hover:text-gray-900 px-2.5 py-2 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
                >
                  <LayoutDashboard className="h-4 w-4 mr-2" />
                  Dashboard
                </Link>
                )}
                <Link
                  to="/messages"
                  className="text-gray-600 hover:text-gray-900 px-2.5 py-2 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
                >
                  <div className="relative inline-flex items-center">
                    <MessageSquare className="h-4 w-4 mr-2" />
                    Messages
                    {unreadCount > 0 && (
                      <span className="absolute -top-1 -right-1 h-4 w-4 text-xs flex items-center justify-center bg-red-500 text-white rounded-full">
                        {unreadCount}
                      </span>
                    )}
                  </div>
                </Link>
                {/* Replaced Warehouses dropdown with a simple link */}
                <Link
                  to="/m-warehouses"
                  className="flex items-center text-gray-600 hover:text-gray-900 px-2.5 py-2 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
                >
                  <Warehouse className="h-4 w-4 mr-2" />
                  Warehouses
                </Link>
                {/* Removed Inquiries and Bookings links */}
                <UserMenu />
                <button
                  onClick={handleSignOut}
                  className="inline-flex items-center px-2.5 py-1.5 text-sm font-medium text-neutral-600 hover:text-neutral-700 rounded-md shadow-sm transition-colors"
                >
                  <LogOut className="h-4 w-4 mr-2" />
                  Sign Out
                </button>
              </>
            ) : (
              <>
                <div className="relative hidden sm:block">
                  <Link
                    to="/m-warehouses"
                    className="inline-flex items-center px-2 py-2 text-sm font-medium text-green-700 hover:text-gray-900 rounded-md shadow-sm transition-colors"
                  >
                    Find Warehouse
                  </Link>
                  <button
                    onClick={() => navigate('/login', { state: { from: '/m-warehouses/create' } })}
                    className="inline-flex items-center px-2 py-2 text-sm font-medium text-green-700 hover:text-gray-900 rounded-md shadow-sm transition-colors"
                  >
                    List Warehouse
                  </button>
                </div>
                {hasRole('administrator') && (
                  <Link
                    to="/notifications"
                    className="text-gray-600 hover:text-gray-900 px-2.5 py-2 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
                  >
                    <div className="relative inline-flex items-center">
                      <Bell className="h-4 w-4 mr-2" />
                      Notifications
                      {adminUnreadCount > 0 && (
                        <span className="absolute -top-1 -right-1 h-4 w-4 text-xs flex items-center justify-center bg-red-500 text-white rounded-full">
                          {adminUnreadCount}
                        </span>
                      )}
                    </div>
                  </Link>
                )}
                <div className="block sm:hidden">
                  <Link
                    to="/m-warehouses"
                    className="inline-flex items-center px-3 py-2 text-sm font-medium text-green-700 hover:text-gray-900 rounded-md shadow-sm transition-colors"
                  >
                    <Warehouse className="h-4 w-4 mr-2" />
                    Warehouses
                  </Link>
                </div>
                <Link
                  to="/contact"
                  className="hidden sm:inline-flex items-center px-2 py-2 text-sm font-medium text-gray-900 hover:text-green-700 rounded-md shadow-sm transition-colors"
                >
                  Contact BRM
                </Link>
                <div className="relative hidden sm:block">
                  <Link
                    to="/login"
                    className="inline-flex items-center px-3 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-md shadow-sm transition-colors"
                  >
                    Sign In
                  </Link>
                </div>
                <div className="block sm:hidden">
                  <Link
                    to="/login"
                    className="text-gray-600 hover:text-gray-900 px-2.5 py-2 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors relative inline-flex items-center"
                  >
                    <LogIn className="h-6 w-6" />
                  </Link>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  );
}
