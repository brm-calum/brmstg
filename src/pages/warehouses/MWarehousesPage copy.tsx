import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { useMWarehouses } from '../../hooks/useMWarehouses';
import { MWarehouseList } from '../../components/warehouses/MWarehouseList';
import { MWarehouseFilters } from '../../components/warehouses/MWarehouseFilters';
import { Plus, List, Map as MapIcon, Filter, X } from 'lucide-react';
import { MWarehouse } from '../../lib/types/m-warehouse';
import { supabase } from '../../lib/supabase';

export function MWarehousesPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { user } = useAuth();
  const { fetchMWarehouses, isLoading } = useMWarehouses();
  const [viewMode, setViewMode] = useState<'list' | 'map'>('list');
  const [selectedWarehouseId, setSelectedWarehouseId] = useState<string | null>(null);
  const [warehouses, setWarehouses] = useState<MWarehouse[]>([]);
  const [showFilters, setShowFilters] = useState(true);
  const [filters, setFilters] = useState({
    search: '',
    minSize: '',
    maxSize: '',
    minPrice: '',
    maxPrice: '',
    city: '',
    country: '',
    spaceTypes: [] as string[],
    features: [] as string[],
    services: [] as string[]
  });
  const [spaceTypes, setSpaceTypes] = useState([]);
  const [features, setFeatures] = useState([]);
  const [services, setServices] = useState([]);

  // Handle location state from navigation
  useEffect(() => {
    const state = location.state;
    if (state?.viewMode === 'map') {
      setViewMode('map');
      if (state.selectedId) {
        setSelectedWarehouseId(state.selectedId);
      }
    }
  }, [location]);

  // Load warehouses and filter options
  useEffect(() => {
    const loadData = async () => {
      try {
        // Load warehouses
        const warehousesData = await fetchMWarehouses();
        setWarehouses(warehousesData);

        // Load space types
        const { data: spaceTypesData } = await supabase
          .from('m_space_types')
          .select('id, name')
          .order('name');
        if (spaceTypesData) setSpaceTypes(spaceTypesData);

        // Load features
        const { data: featuresData } = await supabase
          .from('warehouse_features')
          .select('id, name')
          .order('name');
        if (featuresData) setFeatures(featuresData);

        // Load services
        const { data: servicesData } = await supabase
          .from('warehouse_services')
          .select('id, name')
          .order('name');
        if (servicesData) setServices(servicesData);
      } catch (err) {
        console.error('Failed to load data:', err);
      }
    };
    loadData();
  }, []);

  const handleFilterChange = (newFilters: typeof filters) => {
    setFilters(newFilters);
  };

  const clearFilters = () => {
    setFilters({
      search: '',
      minSize: '',
      maxSize: '',
      minPrice: '',
      maxPrice: '',
      city: '',
      country: '',
      spaceTypes: [],
      features: [],
      services: []
    });
  };

  const hasActiveFilters = () => {
    return (
      filters.search ||
      filters.minSize ||
      filters.maxSize ||
      filters.minPrice ||
      filters.maxPrice ||
      filters.city ||
      filters.country ||
      filters.spaceTypes.length > 0 ||
      filters.features.length > 0 ||
      filters.services.length > 0
    );
  };

  return (
    <div className="pt-20 pb-6">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center">
          <div className="flex-1">
            <h1 className="text-2xl font-semibold text-gray-900">Warehouses</h1>
            <p className="mt-2 text-sm text-gray-600">
              Browse warehouses with multiple space types
            </p>
          </div>
          <div className="flex items-center space-x-4">
            <button
              onClick={() => setShowFilters(!showFilters)}
              className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
            >
              <Filter className="h-4 w-4 mr-2" />
              {showFilters ? 'Hide Filters' : 'Show Filters'}
            </button>
            <div className="flex rounded-md shadow-sm">
              <button
                onClick={() => setViewMode('list')}
                className={`px-4 py-2 text-sm font-medium rounded-l-md border ${
                  viewMode === 'list'
                    ? 'bg-green-600 text-white border-green-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
                }`}
              >
                <List className="h-4 w-4" />
              </button>
              <button
                onClick={() => setViewMode('map')}
                className={`px-4 py-2 text-sm font-medium rounded-r-md border-t border-r border-b -ml-px ${
                  viewMode === 'map'
                    ? 'bg-green-600 text-white border-green-600'
                    : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'
                }`}
              >
                <MapIcon className="h-4 w-4" />
              </button>
            </div>
            {user && (
              <Link
                to="/m-warehouses/create"
                className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700"
              >
                <Plus className="h-4 w-4 mr-2" />
                Add Warehouse
              </Link>
            )}
          </div>
        </div>

        <div className="mt-8 flex gap-6">
          {/* Filters Sidebar */}
          <div className={`w-64 flex-shrink-0 transition-all duration-300 ${showFilters ? 'block' : 'hidden'}`}>
            <div className="bg-white rounded-lg shadow p-6 sticky top-24">
              <div className="flex justify-between items-center mb-4">

                {hasActiveFilters() && (
                  <button
                    onClick={clearFilters}
                    className="text-sm text-gray-500 hover:text-gray-700 flex items-center"
                  >
                    <X className="h-4 w-4 mr-1" />
                    Clear
                  </button>
                )}
              </div>

              <div className="space-y-6">
                {/* Search */}
                <div>
                  <label className="block text-sm font-medium text-gray-700">Search by Location</label>
                  <input
                    type="text"
                    value={filters.search}
                    onChange={(e) => setFilters({ ...filters, search: e.target.value })}
                    placeholder="Search warehouses by location"
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm"
                  />
                </div>

                {/* Space Types */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Space Types</label>
                  <div className="space-y-2 max-h-40 overflow-y-auto">
                    {spaceTypes.map((type: any) => (
                      <label key={type.id} className="flex items-center">
                        <input
                          type="checkbox"
                          checked={filters.spaceTypes.includes(type.id)}
                          onChange={(e) => {
                            const newSpaceTypes = e.target.checked
                              ? [...filters.spaceTypes, type.id]
                              : filters.spaceTypes.filter(id => id !== type.id);
                            setFilters({ ...filters, spaceTypes: newSpaceTypes });
                          }}
                          className="rounded border-gray-300 text-green-600 focus:ring-green-500"
                        />
                        <span className="ml-2 text-sm text-gray-600">{type.name}</span>
                      </label>
                    ))}
                  </div>
                </div>

                {/* Features */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Features</label>
                  <div className="space-y-2 max-h-40 overflow-y-auto">
                    {features.map((feature: any) => (
                      <label key={feature.id} className="flex items-center">
                        <input
                          type="checkbox"
                          checked={filters.features.includes(feature.id)}
                          onChange={(e) => {
                            const newFeatures = e.target.checked
                              ? [...filters.features, feature.id]
                              : filters.features.filter(id => id !== feature.id);
                            setFilters({ ...filters, features: newFeatures });
                          }}
                          className="rounded border-gray-300 text-green-600 focus:ring-green-500"
                        />
                        <span className="ml-2 text-sm text-gray-600">{feature.name}</span>
                      </label>
                    ))}
                  </div>
                </div>

                {/* Services */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Services</label>
                  <div className="space-y-2 max-h-40 overflow-y-auto">
                    {services.map((service: any) => (
                      <label key={service.id} className="flex items-center">
                        <input
                          type="checkbox"
                          checked={filters.services.includes(service.id)}
                          onChange={(e) => {
                            const newServices = e.target.checked
                              ? [...filters.services, service.id]
                              : filters.services.filter(id => id !== service.id);
                            setFilters({ ...filters, services: newServices });
                          }}
                          className="rounded border-gray-300 text-green-600 focus:ring-green-500"
                        />
                        <span className="ml-2 text-sm text-gray-600">{service.name}</span>
                      </label>
                    ))}
                  </div>
                </div>

                {/* Size Range */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Size (m²)</label>
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      type="number"
                      placeholder="Min"
                      value={filters.minSize}
                      onChange={(e) => setFilters({ ...filters, minSize: e.target.value })}
                      className="block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm"
                    />
                    <input
                      type="number"
                      placeholder="Max"
                      value={filters.maxSize}
                      onChange={(e) => setFilters({ ...filters, maxSize: e.target.value })}
                      className="block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm"
                    />
                  </div>
                </div>

                {/* Price Range */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Price (€/m²)</label>
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      type="number"
                      placeholder="Min"
                      value={filters.minPrice}
                      onChange={(e) => setFilters({ ...filters, minPrice: e.target.value })}
                      className="block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm"
                    />
                    <input
                      type="number"
                      placeholder="Max"
                      value={filters.maxPrice}
                      onChange={(e) => setFilters({ ...filters, maxPrice: e.target.value })}
                      className="block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm"
                    />
                  </div>
                </div>

                {/* Location */}
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">Location</label>
                  <input
                    type="text"
                    placeholder="City"
                    value={filters.city}
                    onChange={(e) => setFilters({ ...filters, city: e.target.value })}
                    className="block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm mb-2"
                  />
                  <input
                    type="text"
                    placeholder="Country"
                    value={filters.country}
                    onChange={(e) => setFilters({ ...filters, country: e.target.value })}
                    className="block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Main Content */}
          <div className={`flex-1 ${viewMode === 'map' ? 'h-[calc(100vh-16rem)]' : ''}`}>
            <div className="overflow-y-auto">
              <MWarehouseList 
                filters={filters}
                onWarehousesLoaded={(loaded) => {
                  setWarehouses(loaded);
                }}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}