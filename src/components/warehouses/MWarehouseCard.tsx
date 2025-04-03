import React from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { MWarehouse } from '../../lib/types/m-warehouse';
import { Warehouse, MapPin, Ruler, Euro, Tag, Package, MessageSquare } from 'lucide-react';

interface MWarehouseCardProps {
  warehouse: MWarehouse;
}

export function MWarehouseCard({ warehouse }: MWarehouseCardProps) {
  const navigate = useNavigate();

  const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const target = e.target as HTMLElement;
    if (target.closest('.inquiry-button')) {
      e.stopPropagation();
      return;
    }
    navigate(`/m-warehouses/${warehouse.id}`);
  };

  // Calculate total space and average price
  const totalSpace = warehouse.spaces.reduce((sum, space) => sum + space.size_m2, 0);
  const avgPrice = warehouse.spaces.reduce((sum, space) => sum + space.price_per_m2_cents, 0) / warehouse.spaces.length;

  return (
    <div
      onClick={handleClick}
      className="bg-white rounded-lg shadow overflow-hidden hover:shadow-lg transition-all duration-200 cursor-pointer flex flex-col h-full"
    >
      {/* Image Section - Fixed Height */}
      <div className="aspect-[4/3] relative bg-gray-100 overflow-hidden">
        {warehouse.images?.[0]?.url ? (
          <img
            src={warehouse.images[0].url}
            alt={warehouse.name}
            className="w-full h-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center bg-gray-50">
            <Warehouse className="h-12 w-12 text-gray-300" />
          </div>
        )}
      </div>

      {/* Content Section - Flexible Height */}
      <div className="p-4 sm:p-6 flex-1 flex flex-col">
        {/* Header */}
        <div className="mb-4">
          <h3 className="text-lg font-medium text-gray-900">
            {warehouse.name}
          </h3>
          <div className="mt-2 flex flex-wrap gap-1">
            {warehouse.spaces.map(space => (
              <span
                key={space.id}
                className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mb-1"
              >
                {space.space_type?.name}
              </span>
            ))}
          </div>
        </div>
        
        {/* Description */}
        <p className="text-sm text-gray-500 line-clamp-2 mb-3 sm:mb-4">
          {warehouse.description}
        </p>

        {/* Info Grid */}
        <div className="space-y-2 sm:space-y-2.5 mb-4 sm:mb-6">
          <div className="flex items-center text-sm text-gray-500">
            <MapPin className="h-4 w-4 mr-2" />
            {warehouse.city}, {warehouse.country}
          </div>
          <div className="flex items-center text-sm text-gray-500">
            <Ruler className="h-4 w-4 mr-2" />
            {totalSpace} m² total
          </div>
          <div className="flex items-center text-sm text-gray-500">
            <Euro className="h-4 w-4 mr-2" />
            From {(Math.min(...warehouse.spaces.map(s => s.price_per_m2_cents)) / 100).toFixed(2)} €/m²
          </div>
        </div>

        {/* Features & Services */}
        {(warehouse.features?.length > 0 || warehouse.services?.length > 0) && (
          <div className="space-y-2 mb-4 sm:mb-6">
            {warehouse.features?.length > 0 && (
              <div className="flex flex-wrap gap-1 sm:gap-2">
                {warehouse.features.slice(0, 3).map((feature) => (
                  <span
                    key={feature.id}
                    className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
                  >
                    <Tag className="h-3 w-3 mr-1" />
                    {feature.name}
                  </span>
                ))}
                {warehouse.features.length > 3 && (
                  <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                    +{warehouse.features.length - 3} more
                  </span>
                )}
              </div>
            )}

            {warehouse.services?.length > 0 && (
              <div className="flex flex-wrap gap-1 sm:gap-2">
                {warehouse.services.slice(0, 2).map((service) => (
                  <span
                    key={service.id}
                    className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
                  >
                    <Package className="h-3 w-3 mr-1" />
                    {service.name}
                  </span>
                ))}
                {warehouse.services.length > 2 && (
                  <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    +{warehouse.services.length - 2} more
                  </span>
                )}
              </div>
            )}
          </div>
        )}

        {/* Spaces Grid */}
        <div className="grid grid-cols-2 gap-2 mb-4 sm:mb-6">
          {warehouse.spaces.map(space => (
            <div key={space.id} className="bg-gray-50 p-1.5 sm:p-2 rounded-md">
              <div className="font-medium text-xs sm:text-sm">{space.space_type?.name}</div>
              <div className="text-xs sm:text-sm text-gray-500">{space.size_m2} m²</div>
              <div className="text-xs sm:text-sm text-gray-500">
                {(space.price_per_m2_cents / 100).toFixed(2)} €/m²
              </div>
            </div>
          ))}
        </div>

        {/* Action Buttons - Fixed at Bottom */}
        <div className="mt-auto flex flex-col sm:flex-row gap-2 sm:justify-between sm:items-center">
          <button
            onClick={(e) => {
              e.stopPropagation();
              navigate('/inquiries/new', { state: { warehouseId: warehouse.id } });
            }}
            className="inquiry-button w-full sm:w-auto inline-flex justify-center items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
          >
            <MessageSquare className="h-4 w-4 mr-1" />
            Send Inquiry
          </button>
          <Link
            to="/m-warehouses"
            state={{ viewMode: 'map', selectedId: warehouse.id }}
            onClick={(e) => {
              e.stopPropagation();
              e.preventDefault();
              navigate('/m-warehouses', { 
                state: { viewMode: 'map', selectedId: warehouse.id },
                replace: true 
              });
            }}
            className="w-full sm:w-auto inline-flex justify-center items-center px-3 py-1.5 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            <MapPin className="h-4 w-4 mr-1" />
            Show on Map
          </Link>
        </div>
      </div>
    </div>
  );
}