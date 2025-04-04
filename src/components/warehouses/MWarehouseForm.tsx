import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { MWarehouseFormData, MSpaceType } from '../../lib/types/m-warehouse';
import { supabase } from '../../lib/supabase';
import { Loader, ImageIcon, Plus, Minus, Clock, Tag, Package } from 'lucide-react';
import { ImageUpload } from './ImageUpload';
import { FeatureSelector } from './FeatureSelector';
import { ServiceSelector } from './ServiceSelector';

interface MWarehouseFormProps {
  onSubmit: (data: MWarehouseFormData) => Promise<void>;
  initialData?: Partial<MWarehouseFormData>;
  isLoading?: boolean;
}

export function MWarehouseForm({ onSubmit, initialData, isLoading }: MWarehouseFormProps) {
  const navigate = useNavigate();
  const [spaceTypes, setSpaceTypes] = useState<MSpaceType[]>([]);
  const [formData, setFormData] = useState<MWarehouseFormData>({
    name: initialData?.name || '',
    description: initialData?.description || '',
    address: initialData?.address || '',
    city: initialData?.city || '',
    country: initialData?.country || '',
    postal_code: initialData?.postal_code || '',
    spaces: initialData?.spaces?.length ? initialData.spaces : [{
      space_type_id: '',
      size_m2: 0,
      price_per_m2_cents: 0
    }],
    features: initialData?.features?.map(f => ({
      id: f.id,
      custom_value: f.custom_value
    })) || [],
    services: initialData?.services?.map(s => ({
      id: s.service?.id,           // Extract the id from the nested service object
      service: s.service,          // Include the nested service object too
      pricing_type: s.pricing_type || 'ask_quote',
      price_per_hour_cents: s.price_per_hour_cents,
      price_per_unit_cents: s.price_per_unit_cents,
      unit_type: s.unit_type,
      notes: s.notes
    })) || [],
    images: initialData?.images || [],
  });

  useEffect(() => {
    loadSpaceTypes();
  }, []);

  const loadSpaceTypes = async () => {
    try {
      const { data } = await supabase
        .from('m_space_types')
        .select('*')
        .order('name');
      if (data) setSpaceTypes(data);
    } catch (err) {
      console.error('Failed to load space types:', err);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
  };

  const handleChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>
  ) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSpaceChange = (index: number, field: string, value: string | number) => {
    setFormData(prev => ({
      ...prev,
      spaces: prev.spaces.map((space, i) => 
        i === index ? { ...space, [field]: value } : space
      ),
    }));
  };

  const addSpace = () => {
    setFormData(prev => ({
      ...prev,
      spaces: [...prev.spaces, {
        space_type_id: spaceTypes[0]?.id || '',
        size_m2: 0,
        price_per_m2_cents: 0
      }],
    }));
  };

  const removeSpace = (index: number) => {
    setFormData(prev => ({
      ...prev,
      spaces: prev.spaces.filter((_, i) => i !== index),
    }));
  };

  const handleImagesChange = (newImages: { url: string; order: number }[]) => {
    setFormData(prev => ({
      ...prev,
      images: newImages,
    }));
  };

  const inputClasses = "block w-full pl-4 pr-4 py-3 bg-white border-2 border-green-100 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:border-green-300 text-base transition-shadow duration-200 hover:shadow-md";
  const labelClasses = "block text-sm font-medium text-gray-700 mb-2";
  const sectionClasses = "bg-white rounded-xl shadow-lg border-2 border-green-100 p-6 mb-6 transition-all duration-200 hover:shadow-xl";

  return (
    <form onSubmit={handleSubmit} className="space-y-8">
      {/* Basic Information */}
      <div className={sectionClasses}>
        <h3 className="text-lg font-medium text-gray-900 mb-6">Basic Information</h3>
        <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
          <div>
            <label htmlFor="name" className={labelClasses}>
              Warehouse Name *
            </label>
            <input
              type="text"
              id="name"
              name="name"
              required
              value={formData.name}
              onChange={handleChange}
              className={inputClasses}
              placeholder="Enter warehouse name"
            />
          </div>

          <div className="md:col-span-2">
            <label htmlFor="description" className={labelClasses}>
              Description
            </label>
            <textarea
              id="description"
              name="description"
              rows={3}
              value={formData.description}
              onChange={handleChange}
              className={inputClasses}
              placeholder="Describe your warehouse space"
            />
          </div>

          <div className="md:col-span-2">
            <label htmlFor="address" className={labelClasses}>
              Address *
            </label>
            <input
              type="text"
              id="address"
              name="address"
              required
              value={formData.address}
              onChange={handleChange}
              className={inputClasses}
              placeholder="Enter full street address"
            />
          </div>

          <div>
            <label htmlFor="city" className={labelClasses}>
              City *
            </label>
            <input
              type="text"
              id="city"
              name="city"
              required
              value={formData.city}
              onChange={handleChange}
              className={inputClasses}
              placeholder="Enter city"
            />
          </div>

          <div>
            <label htmlFor="postal_code" className={labelClasses}>
              Postal Code *
            </label>
            <input
              type="text"
              id="postal_code"
              name="postal_code"
              required
              value={formData.postal_code}
              onChange={handleChange}
              className={inputClasses}
              placeholder="Enter postal code"
            />
          </div>

          <div>
            <label htmlFor="country" className={labelClasses}>
              Country *
            </label>
            <input
              type="text"
              id="country"
              name="country"
              required
              value={formData.country}
              onChange={handleChange}
              className={inputClasses}
              placeholder="Enter country"
            />
          </div>
        </div>
      </div>

      {/* Storage Spaces */}
      <div className={sectionClasses}>
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-lg font-medium text-gray-900">Warehouse Spaces</h3>
        </div>

        <div className="space-y-6">
          {formData.spaces.map((space, index) => (
            <div key={index} className="bg-gray-50 rounded-xl p-6 border-2 border-gray-100">
              <div className="flex justify-between items-start mb-4">
                <h4 className="text-sm font-medium text-gray-900">Space {index + 1}</h4>
                <button
                  type="button"
                  onClick={() => removeSpace(index)}
                  className="text-gray-400 hover:text-red-500"
                >
                  <Minus className="h-4 w-4" />
                </button>
              </div>

              <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
                <div>
                  <label className={labelClasses}>
                    Space Type *
                  </label>
                  <select
                    value={space.space_type_id}
                    onChange={(e) => handleSpaceChange(index, 'space_type_id', e.target.value)}
                    className={inputClasses}
                    required
                  >
                    <option value="">Select a type</option>
                    {spaceTypes.map(type => (
                      <option key={type.id} value={type.id}>
                        {type.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className={labelClasses}>
                    Size (m²) *
                  </label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={space.size_m2 || ''}
                    onChange={(e) => handleSpaceChange(index, 'size_m2', parseFloat(e.target.value))}
                    className={inputClasses}
                    required
                    placeholder="Enter space size"
                  />
                </div>

                <div>
                  <label className={labelClasses}>
                    Price per m² (€) *
                  </label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={space.price_per_m2_cents ? space.price_per_m2_cents / 100 : ''}
                    onChange={(e) => handleSpaceChange(
                      index,
                      'price_per_m2_cents',
                      Math.round(parseFloat(e.target.value) * 100)
                    )}
                    className={inputClasses}
                    required
                    placeholder="Enter price per m²"
                  />
                </div>
              </div>
            </div>
          ))}
            <button
            type="button"
            onClick={addSpace}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-xl shadow-sm text-white bg-green-600 hover:bg-green-700"
          >
            <Plus className="h-4 w-4 mr-2" />
            Add Space
          </button>
        </div>
      </div>

      {/* Features */}
      <div className={sectionClasses}>
        <div className="mb-6">
          <h3 className="text-lg font-medium text-gray-900 flex items-center">
            <Tag className="h-5 w-5 mr-2 text-gray-400" />
            Warehouse Features
          </h3>
          <p className="mt-1 text-sm text-gray-500">
            Select the features available at your warehouse
          </p>
        </div>
        <FeatureSelector
          selectedFeatures={formData.features}
          onChange={(features) => setFormData(prev => ({ ...prev, features }))}
        />
      </div>

      {/* Services */}
      <div className={sectionClasses}>
        <div className="mb-6">
          <h3 className="text-lg font-medium text-gray-900 flex items-center">
            <Package className="h-5 w-5 mr-2 text-gray-400" />
            Available Services
          </h3>
          <p className="mt-1 text-sm text-gray-500">
            Select and configure available services
          </p>
        </div>
        <ServiceSelector
          selectedServices={formData.services}
          onChange={(services) => setFormData(prev => ({ ...prev, services }))}
        />
      </div>

      {/* Images */}
      <div className={sectionClasses}>
        <div className="mb-6">
          <h3 className="text-lg font-medium text-gray-900 flex items-center">
            <ImageIcon className="h-5 w-5 mr-2 text-gray-400" />
            Warehouse Images
          </h3>
          <p className="mt-1 text-sm text-gray-500">
            Add photos of your warehouse space to attract potential customers
          </p>
        </div>
        <ImageUpload
          images={formData.images}
          onChange={handleImagesChange}
          maxImages={5}
        />
      </div>

      {/* Action Buttons */}
      <div className="flex justify-end space-x-4">
        <button
          type="button"
          onClick={() => navigate(-1)}
          className="px-6 py-3 text-sm font-medium text-gray-700 bg-white border-2 border-gray-300 rounded-xl shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={async () => {
            try {
              await onSubmit(formData);
            } catch (err) {
              console.error('Failed to save warehouse:', err);
            }
          }}
          disabled={isLoading}
          className="inline-flex justify-center px-6 py-3 text-sm font-medium text-white bg-green-600 border border-transparent rounded-xl shadow-sm hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 disabled:opacity-50"
        >
          {isLoading ? (
            <>
              <Loader className="w-4 h-4 mr-2 animate-spin" />
              Saving...
            </>
          ) : (
            'Save Warehouse'
          )}
        </button>
      </div>
    </form>
  );
}