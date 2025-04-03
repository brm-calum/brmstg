import React from 'react';
import { Navbar } from './Navbar';
import { Footer } from './Footer';

interface LayoutProps {
  children: React.ReactNode;
  className?: string;
}

export function Layout({ children, className = 'bg-gray-50' }: LayoutProps) {
  return (
    <div className={`min-h-screen ${className}`}>
      <Navbar className="sticky top-0 z-50" />
      <main className="min-h-[calc(100vh-4rem)]">{children}</main>
      <Footer />
    </div>
  );
}