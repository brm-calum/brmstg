import React from 'react';
import { Link } from 'react-router-dom';
import { useMWarehouses } from '../hooks/useMWarehouses';
import { Warehouse, Shield, Clock, Search, Building2, Users, MapPin, Ruler } from 'lucide-react';
import { useEffect, useState } from 'react';

export function LandingPage() {
  const { fetchMWarehouses, isLoading } = useMWarehouses();
  const [featuredWarehouses, setFeaturedWarehouses] = useState([]);

  useEffect(() => {
    const loadWarehouses = async () => {
      try {
        const warehouses = await fetchMWarehouses();
        // Filter active warehouses and take the 3 most recent
        const activeWarehouses = warehouses
          .filter(w => w.is_active)
          .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
          .slice(0, 3);
        setFeaturedWarehouses(activeWarehouses);
      } catch (err) {
        console.error('Failed to load warehouses:', err);
      }
    };
    loadWarehouses();
  }, []);

  return (
    <>
      {/* Hero Section */}
      <div className="relative overflow-hidden">
        <div className="absolute inset-0 z-0">
          <img
            src="/images/GYQl88LcLok-unsplash.jpg"
            alt="Warehouse"
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gray-900/70" />
        </div>
        
        <div className="relative z-10 px-4 py-12 sm:py-16 sm:px-6 lg:px-8">
          <div className="mx-auto max-w-7xl">
            <div className="lg:grid lg:grid-cols-12 lg:gap-8">
              <div className="text-center sm:text-center md:mx-auto lg:col-span-6 lg:text-left">
                <h1 className="text-3xl font-bold tracking-tight text-white sm:text-4xl md:text-5xl lg:text-6xl">
                  Find Your Perfect
                  <span className="block text-green-400">Warehouse Space</span>
                </h1>
                <p className="mt-3 text-sm sm:text-base text-gray-300 sm:mt-5 sm:text-lg lg:text-base xl:text-lg">
                  Connect with warehouse owners and find the perfect storage solution for your business.
                  Simple, secure, and efficient.
                </p>
                <div className="mt-6 sm:mt-8 flex flex-col sm:flex-row justify-center gap-4 sm:mx-auto sm:max-w-lg lg:mx-0 lg:justify-start">
                  <div className="w-full sm:w-auto">
                    <Link
                      to="/m-warehouses"
                      className="w-full sm:w-auto flex justify-center items-center rounded-md border border-transparent bg-green-600 px-5 py-3 text-base font-medium text-white shadow-sm hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                    >
                      Browse Warehouses
                    </Link>
                  </div>
                  <div className="w-full sm:w-auto">
                    <Link
                      to="/m-warehouses/create"
                      className="w-full sm:w-auto flex justify-center items-center rounded-md border border-gray-300 bg-white px-5 py-3 text-base font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                    >
                      List Your Space
                    </Link>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Featured Warehouses Section */}
      <div className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center px-4">
            <h2 className="text-3xl font-bold text-gray-900">Featured Warehouses</h2>
            <p className="mt-4 text-lg text-gray-600">
              Discover our selection of premium warehouse spaces
            </p>
          </div>

          <div className="mt-12 grid gap-6 sm:gap-8 sm:grid-cols-2 lg:grid-cols-3">
            {isLoading ? (
              <div className="col-span-3 flex justify-center">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-green-600" />
              </div>
            ) : (
              featuredWarehouses.map((warehouse) => (
                <Link
                  key={warehouse.id}
                  to={`/m-warehouses/${warehouse.id}`}
                  className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow"
                >
                  <div className="aspect-[4/3] relative bg-gray-100">
                    {warehouse.images?.[0]?.url ? (
                      <img
                        src={warehouse.images[0].url}
                        alt={warehouse.name}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex items-center justify-center">
                        <Warehouse className="h-12 w-12 text-gray-300" />
                      </div>
                    )}
                  </div>
                  <div className="p-6">
                    <h3 className="text-lg font-semibold text-gray-900">{warehouse.name}</h3>
                    <div className="mt-2 flex items-center text-sm text-gray-500">
                      <MapPin className="h-4 w-4 mr-1" />
                      {warehouse.city}, {warehouse.country}
                    </div>
                    <div className="mt-2 flex items-center text-sm text-gray-500">
                      <Ruler className="h-4 w-4 mr-1" />
                      {warehouse.spaces.reduce((sum, space) => sum + space.size_m2, 0)} m²
                    </div>
                    <div className="mt-4 text-lg font-medium text-green-600">
                      From €{(Math.min(...warehouse.spaces.map(s => s.price_per_m2_cents)) / 100).toFixed(2)}/m²
                    </div>
                  </div>
                </Link>
              ))
            )}
          </div>

          <div className="mt-12 text-center">
            <div className="px-4">
              <Link
                to="/m-warehouses"
                className="inline-flex items-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
              >
                Browse All Warehouses
              </Link>
            </div>
          </div>
        </div>
      </div>

      {/* Features Section */}
      <div className="py-16 sm:py-24">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <h2 className="text-lg font-semibold text-green-600">Why Choose Us</h2>
            <p className="mt-2 text-2xl sm:text-3xl font-bold leading-8 tracking-tight text-gray-900 sm:text-4xl">
              Everything you need to manage your storage
            </p>
          </div>

          <div className="mt-16">
            <div className="grid grid-cols-1 gap-6 sm:gap-8 sm:grid-cols-2 lg:grid-cols-3">
              {features.map((feature) => (
                <div key={feature.name} className="pt-6">
                  <div className="flow-root rounded-lg bg-gray-50 px-6 pb-8">
                    <div className="-mt-6">
                      <div>
                        <span className="inline-flex items-center justify-center rounded-md bg-green-500 p-3 shadow-lg">
                          <feature.icon className="h-6 w-6 text-white" />
                        </span>
                      </div>
                      <h3 className="mt-8 text-lg font-medium tracking-tight text-gray-900">
                        {feature.name}
                      </h3>
                      <p className="mt-5 text-base text-gray-500">{feature.description}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* CTA Section */}
      <div className="bg-green-700 py-12 sm:py-16">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:flex lg:items-center lg:justify-between lg:px-8">
          <h2 className="text-2xl sm:text-3xl font-bold tracking-tight text-white sm:text-4xl text-center lg:text-left">
            <span className="block">Ready to get started?</span>
            <span className="block text-green-200 mt-1">Join our platform today.</span>
          </h2>
          <div className="mt-8 flex justify-center lg:mt-0 lg:flex-shrink-0">
            <div className="inline-flex rounded-md shadow w-full sm:w-auto">
              <Link
                to="/register"
                className="w-full inline-flex items-center justify-center rounded-md border border-transparent bg-white px-5 py-3 text-base font-medium text-green-600 hover:bg-green-50"
              >
                Get Started
              </Link>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

const features = [
  /*{
    name: 'Secure Platform',
    description: 'Industry-leading security measures to protect your data and transactions.',
    icon: Shield,
  },
  {
    name: 'Real-time Availability',
    description: 'Check space availability and book instantly, 24/7.',
    icon: Clock,
  },*/
  {
    name: 'Smart Search',
    description: 'Find the perfect warehouse space with our advanced search filters.',
    icon: Search,
  },
  /*{
    name: 'Verified Spaces',
    description: 'All warehouse spaces are verified for quality and security.',
    icon: Building2,
  },*/
  {
    name: 'Direct Communication',
    description: 'Connect directly with warehouse owners through our platform.',
    icon: Users,
  },
  {
    name: 'Flexible Options',
    description: 'Choose from a variety of warehouse types and sizes.',
    icon: Warehouse,
  },
];