import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { useMWarehouses } from '../../hooks/useMWarehouses';
import { MWarehouseList } from '../../components/warehouses/MWarehouseList';
import { WarehouseMap } from '../../components/warehouses/WarehouseMap';
import { Plus, List, Map as MapIcon, Filter, X, Search } from 'lucide-react';
import { MWarehouse } from '../../lib/types/m-warehouse';
import { supabase } from '../../lib/supabase';


export function MWarehousesPage() {
  const { user, hasRole } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { fetchMWarehouses, isLoading } = useMWarehouses();
  const [viewMode, setViewMode] = useState<'list' | 'map'>('list');
  const [selectedWarehouseId, setSelectedWarehouseId] = useState<string | null>(null);
  const [warehouses, setWarehouses] = useState<MWarehouse[]>([]);
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState({
    search: '',
    spaceTypes: [] as string[],
    features: [] as string[],
    services: [] as string[]
  });
  const [spaceTypes, setSpaceTypes] = useState([]);
  const [features, setFeatures] = useState([]);
  const [services, setServices] = useState([]);
  const [filteredWarehouses, setFilteredWarehouses] = useState<MWarehouse[]>([]);

  useEffect(() => {
    const state = location.state;
    if (state?.viewMode === 'map') {
      setViewMode('map');
      if (state.selectedId) {
        setSelectedWarehouseId(state.selectedId);
      }
    }
  }, [location]);

  useEffect(() => {
    const loadData = async () => {
      try {
        const warehousesData = await fetchMWarehouses();
        setWarehouses(warehousesData);
        setFilteredWarehouses(warehousesData);

        const { data: spaceTypesData } = await supabase
          .from('m_space_types')
          .select('id, name')
          .order('name');
        if (spaceTypesData) setSpaceTypes(spaceTypesData);

        const { data: featuresData } = await supabase
          .from('warehouse_features')
          .select('id, name')
          .order('name');
        if (featuresData) setFeatures(featuresData);

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

  // Filter warehouses when filters change
  useEffect(() => {
    const filtered = warehouses.filter(warehouse => {
      const matchesSearch = !filters.search || 
        [
          warehouse.name,
          warehouse.description,
          warehouse.city,
          warehouse.country,
          warehouse.address
        ].some(field => 
          field?.toLowerCase().includes(filters.search.toLowerCase())
        );

      const matchesSpaceTypes = filters.spaceTypes.length === 0 || 
        filters.spaceTypes.every(typeId =>
          warehouse.spaces.some(space => space.space_type_id === typeId)
        );

      const matchesFeatures = filters.features.length === 0 || 
        filters.features.every(featureId =>
          warehouse.features.some(feature => feature.id === featureId)
        );

      const matchesServices = filters.services.length === 0 || 
        filters.services.every(serviceId =>
          warehouse.services.some(service => service.id === serviceId)
        );

      return matchesSearch && matchesSpaceTypes && matchesFeatures && matchesServices;
    });

    setFilteredWarehouses(filtered);
  }, [warehouses, filters]);

  const clearFilters = () => {
    setFilters({
      search: '',
      spaceTypes: [],
      features: [],
      services: []
    });
  };

  const hasActiveFilters = () => {
    return (
      filters.search ||
      filters.spaceTypes.length > 0 ||
      filters.features.length > 0 ||
      filters.services.length > 0
    );
  };

  const handleWarehouseClick = (id: string) => {
    navigate(`/m-warehouses/${id}`);
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Mobile Filter Drawer */}
      {showFilters && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="fixed inset-0 bg-black bg-opacity-25" onClick={() => setShowFilters(false)} />
          <div className="fixed inset-y-0 right-0 w-full max-w-xs bg-white shadow-xl">
            <div className="h-full flex flex-col">
              <div className="px-4 py-3 border-b border-gray-200 flex items-center justify-between">
                <h2 className="text-lg font-medium text-gray-900">Filters</h2>
                <button onClick={() => setShowFilters(false)} className="text-gray-400 hover:text-gray-500">
                  <X className="h-6 w-6" />
                </button>
              </div>
              <div className="flex-1 px-4 py-4 overflow-y-auto">
                <div className="space-y-6">
                  {/* Mobile Space Types */}
                  <div>
                    <h3 className="text-sm font-medium text-gray-900 mb-2">Space Types</h3>
                    <div className="flex flex-wrap gap-2">
                      {spaceTypes.map((type: any) => (
                        <button
                          key={type.id}
                          onClick={() => {
                            const newSpaceTypes = filters.spaceTypes.includes(type.id)
                              ? filters.spaceTypes.filter(id => id !== type.id)
                              : [...filters.spaceTypes, type.id];
                            setFilters({ ...filters, spaceTypes: newSpaceTypes });
                          }}
                          className={`px-3 py-1.5 rounded-full text-sm ${
                            filters.spaceTypes.includes(type.id)
                              ? 'bg-green-100 text-green-800 border-green-200'
                              : 'bg-gray-100 text-gray-700 border-gray-200'
                          } border`}
                        >
                          {type.name}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Mobile Features */}
                  <div>
                    <h3 className="text-sm font-medium text-gray-900 mb-2">Features</h3>
                    <div className="flex flex-wrap gap-2">
                      {features.map((feature: any) => (
                        <button
                          key={feature.id}
                          onClick={() => {
                            const newFeatures = filters.features.includes(feature.id)
                              ? filters.features.filter(id => id !== feature.id)
                              : [...filters.features, feature.id];
                            setFilters({ ...filters, features: newFeatures });
                          }}
                          className={`px-3 py-1.5 rounded-full text-sm ${
                            filters.features.includes(feature.id)
                              ? 'bg-green-100 text-green-800 border-green-200'
                              : 'bg-gray-100 text-gray-700 border-gray-200'
                          } border`}
                        >
                          {feature.name}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Mobile Services */}
                  <div>
                    <h3 className="text-sm font-medium text-gray-900 mb-2">Services</h3>
                    <div className="flex flex-wrap gap-2">
                      {services.map((service: any) => (
                        <button
                          key={service.id}
                          onClick={() => {
                            const newServices = filters.services.includes(service.id)
                              ? filters.services.filter(id => id !== service.id)
                              : [...filters.services, service.id];
                            setFilters({ ...filters, services: newServices });
                          }}
                          className={`px-3 py-1.5 rounded-full text-sm ${
                            filters.services.includes(service.id)
                              ? 'bg-green-100 text-green-800 border-green-200'
                              : 'bg-gray-100 text-gray-700 border-gray-200'
                          } border`}
                        >
                          {service.name}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="pt-20 pb-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col items-center space-y-3 sm:space-y-4">
            <div className="text-center">
              <h1 className="text-xl sm:text-2xl font-semibold text-gray-900">Warehouses</h1>
              <p className="mt-1 sm:mt-2 text-sm text-gray-600">
                Browse available warehouse spaces
              </p>
            </div>
            <div className="flex rounded-md shadow-sm w-full sm:w-auto justify-center">
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
          </div>

          {/* Search Bar */}
          <div className="mb-4 sm:mb-6">
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                <Search className="h-6 w-6 text-green-600" />
              </div>
              <input
                type="text"
                value={filters.search}
                onChange={(e) => setFilters({ ...filters, search: e.target.value })}
                placeholder="Search warehouses by location..."
                className="block w-full pl-12 pr-4 py-4 bg-white border-2 border-green-100 rounded-xl shadow-lg focus:ring-2 focus:ring-green-500 focus:border-green-300 text-lg transition-shadow duration-200 hover:shadow-xl"
              />
            </div>
          </div>

          {/* Actions Bar */}
          <div className="flex flex-wrap items-center justify-between gap-3 mb-4 sm:mb-6">
            <div className="flex items-center gap-2">
              <button
                onClick={() => setShowFilters(true)}
                className="lg:hidden inline-flex items-center px-2 sm:px-3 py-1.5 sm:py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
              >
                <Filter className="h-4 w-4 mr-1.5" />
                Filters
                {hasActiveFilters() && (
                  <span className="ml-1.5 px-1.5 py-0.5 text-xs bg-green-100 text-green-800 rounded-full">
                    Active
                  </span>
                )}
              </button>
            </div>
            {user && (hasRole('warehouse_owner') || hasRole('administrator')) && (
              <Link
                to="/m-warehouses/create"
                className="inline-flex items-center px-2 sm:px-3 py-1.5 sm:py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700"
              >
                <Plus className="h-4 w-4 mr-1.5" />
                <span className="hidden sm:inline">Add Warehouse</span>
                <span className="sm:hidden">Add</span>
              </Link>
            )}
          </div>

          <div className="flex gap-6">
            {/* Desktop Filters Sidebar */}
            <div className="hidden lg:block w-64 flex-shrink-0">
              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sticky top-20">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-sm font-medium text-gray-900">Filters</h3>
                  {hasActiveFilters() && (
                    <button
                      onClick={clearFilters}
                      className="text-sm text-gray-500 hover:text-gray-700"
                    >
                      Clear all
                    </button>
                  )}
                </div>

                <div className="space-y-4">
                  {/* Space Types */}
                  <div>
                    <label className="block text-xs font-medium text-gray-700 mb-2">Space Types</label>
                    <div className="flex flex-wrap gap-2">
                      {spaceTypes.map((type: any) => (
                        <button
                          key={type.id}
                          onClick={() => {
                            const newSpaceTypes = filters.spaceTypes.includes(type.id)
                              ? filters.spaceTypes.filter(id => id !== type.id)
                              : [...filters.spaceTypes, type.id];
                            setFilters({ ...filters, spaceTypes: newSpaceTypes });
                          }}
                          className={`px-2 py-1 rounded-full text-xs ${
                            filters.spaceTypes.includes(type.id)
                              ? 'bg-green-100 text-green-800 border-green-200'
                              : 'bg-gray-100 text-gray-700 border-gray-200'
                          } border`}
                        >
                          {type.name}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Features */}
                  <div>
                    <label className="block text-xs font-medium text-gray-700 mb-2">Features</label>
                    <div className="flex flex-wrap gap-2">
                      {features.map((feature: any) => (
                        <button
                          key={feature.id}
                          onClick={() => {
                            const newFeatures = filters.features.includes(feature.id)
                              ? filters.features.filter(id => id !== feature.id)
                              : [...filters.features, feature.id];
                            setFilters({ ...filters, features: newFeatures });
                          }}
                          className={`px-2 py-1 rounded-full text-xs ${
                            filters.features.includes(feature.id)
                              ? 'bg-green-100 text-green-800 border-green-200'
                              : 'bg-gray-100 text-gray-700 border-gray-200'
                          } border`}
                        >
                          {feature.name}
                        </button>
                      ))}
                    </div>
                  </div>

                  {/* Services */}
                  <div>
                    <label className="block text-xs font-medium text-gray-700 mb-2">Services</label>
                    <div className="flex flex-wrap gap-2">
                      {services.map((service: any) => (
                        <button
                          key={service.id}
                          onClick={() => {
                            const newServices = filters.services.includes(service.id)
                              ? filters.services.filter(id => id !== service.id)
                              : [...filters.services, service.id];
                            setFilters({ ...filters, services: newServices });
                          }}
                          className={`px-2 py-1 rounded-full text-xs ${
                            filters.services.includes(service.id)
                              ? 'bg-green-100 text-green-800 border-green-200'
                              : 'bg-gray-100 text-gray-700 border-gray-200'
                          } border`}
                        >
                          {service.name}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Main Content */}
            <div className={`flex-1 ${viewMode === 'map' ? 'h-[calc(100vh-14rem)]' : ''}`}>
              {viewMode === 'list' ? (
                <MWarehouseList 
                  filters={filters}
                  onWarehousesLoaded={(loaded) => {
                    setWarehouses(loaded);
                  }}
                />
              ) : (
                <div className="h-full rounded-lg overflow-hidden border border-gray-200 mt-2">
                  <WarehouseMap
                    warehouses={filteredWarehouses}
                    onWarehouseClick={handleWarehouseClick}
                    selectedWarehouseId={selectedWarehouseId}
                  />
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}