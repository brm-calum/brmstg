import React, { useState, useEffect } from 'react';
import { Plus, Minus } from 'lucide-react';
import { SpaceRequest } from '../../lib/types/inquiry';

interface SpaceRequestFormProps {
  spaceRequests: SpaceRequest[];
  spaceTypes: Array<{ id: string; name: string }>;
  warehouses: any[];
  selectedWarehouseIds: string[];
  onChange: (requests: SpaceRequest[]) => void;
}

export function SpaceRequestForm({ spaceRequests, spaceTypes, warehouses, selectedWarehouseIds, onChange }: SpaceRequestFormProps) {
  const [availableSpaceTypes, setAvailableSpaceTypes] = useState<Array<{ id: string; name: string }>>(spaceTypes);

  // Update available space types when selected warehouses change
  useEffect(() => {
    if (selectedWarehouseIds.length === 0) {
      setAvailableSpaceTypes(spaceTypes);
      return;
    }

    // Get selected warehouses
    const selectedWarehouses = warehouses.filter(w => selectedWarehouseIds.includes(w.id));
    
    // Find space types available in all selected warehouses
    const commonSpaceTypes = spaceTypes.filter(spaceType => {
      return selectedWarehouses.every(warehouse => 
        warehouse.spaces.some(space => space.space_type_id === spaceType.id)
      );
    });

    setAvailableSpaceTypes(commonSpaceTypes);

    // Remove any space requests for types that are no longer available
    const validRequests = spaceRequests.filter(request =>
      commonSpaceTypes.some(type => type.id === request.space_type_id)
    );

    if (validRequests.length !== spaceRequests.length) {
      onChange(validRequests);
    }
  }, [selectedWarehouseIds, warehouses, spaceTypes]);

  // Add first space type if no requests exist
  React.useEffect(() => {
    if (availableSpaceTypes.length > 0 && spaceRequests.length === 0) {
      // Find the 'outdoors' space type
      const outdoorsType = availableSpaceTypes.find(type => type.name.toLowerCase() === 'outdoors');
      const defaultTypeId = outdoorsType?.id || availableSpaceTypes[0].id;
      
      onChange([
        { space_type_id: defaultTypeId, size_m2: 0 }
      ]);
    }
  }, [availableSpaceTypes, spaceRequests.length]);

  const addSpaceRequest = () => {
    onChange([
      ...spaceRequests,
      { space_type_id: availableSpaceTypes[0]?.id || '', size_m2: 0 }
    ]);
  };

  const removeSpaceRequest = (index: number) => {
    onChange(spaceRequests.filter((_, i) => i !== index));
  };

  const updateSpaceRequest = (index: number, field: keyof SpaceRequest, value: any) => {
    onChange(
      spaceRequests.map((request, i) =>
        i === index ? { ...request, [field]: value } : request
      )
    );
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <label className="block text-sm font-medium text-gray-700">
          Space Requirements
        </label>
      </div>

      {spaceRequests.length === 0 ? (
        <p className="text-sm text-gray-500">
          Click "Add Space" to specify your space requirements
        </p>
      ) : (
        <div className="space-y-4">
          {spaceRequests.map((request, index) => (
            <div key={index} className="flex items-start space-x-4 bg-gray-50 p-4 rounded-lg">
              <div className="flex-1 grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Space Type
                  </label>
                  <select
                    value={request.space_type_id}
                    onChange={(e) => updateSpaceRequest(index, 'space_type_id', e.target.value)}
                    className={`mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm ${
                      availableSpaceTypes.length === 0 ? 'bg-gray-100' : ''
                    }`}
                    disabled={availableSpaceTypes.length === 0}
                  >
                    {availableSpaceTypes.length === 0 ? (
                      <option value="">No space types available</option>
                    ) : availableSpaceTypes.map((type) => (
                      <option key={type.id} value={type.id}>
                        {type.name}
                      </option>
                    ))}
                  </select>
                  {availableSpaceTypes.length === 0 && (
                    <p className="mt-1 text-xs text-gray-500">
                      Select warehouses to see available space types
                    </p>
                  )}
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Size (m²)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={request.size_m2}
                    onChange={(e) => updateSpaceRequest(index, 'size_m2', parseFloat(e.target.value))}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-green-500 focus:ring-green-500 sm:text-sm"
                  />
                </div>
              </div>

              <button
                type="button"
                onClick={() => removeSpaceRequest(index)}
                className="mt-6 text-gray-400 hover:text-red-500"
              >
                <Minus className="h-5 w-5" />
              </button>
            </div>
          ))}
        </div>
      )}
              <button
          type="button"
          onClick={addSpaceRequest}
          className="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700"
        >
          <Plus className="h-4 w-4 mr-2" />
          Add Space Type
        </button>
    </div>
  );
}