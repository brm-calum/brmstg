import React from 'react';
import { useNavigate } from 'react-router-dom';
import { MWarehouseForm } from '../../components/warehouses/MWarehouseForm';
import { useMWarehouses } from '../../hooks/useMWarehouses';
import { useAuth } from '../../contexts/AuthContext';
import { MWarehouseFormData } from '../../lib/types/m-warehouse';
import { useEffect } from 'react';
import { Building2 } from 'lucide-react';

export function MWarehouseCreatePage() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { createMWarehouse, isLoading } = useMWarehouses();

  useEffect(() => {
    if (!user) {
      navigate('/login', { state: { from: '/m-warehouses/create' } });
    }
  }, [user, navigate]);

  if (!user) {
    return null;
  }

  const handleSubmit = async (data: MWarehouseFormData) => {
    try {
      await createMWarehouse(data);
      navigate('/m-warehouses');
    } catch (err) {
      console.error('Failed to create warehouse:', err);
    }
  };

  return (
    <div className="py-6">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="md:flex md:items-center md:justify-between mb-8">
          <div className="min-w-0 flex-1">
            <div className="flex items-center">
              <Building2 className="h-8 w-8 text-green-600 mr-3" />
              <div>
                <h2 className="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:tracking-tight">
                  Add New Warehouse
                </h2>
                <p className="mt-1 text-sm text-gray-500">
                  List your warehouse space and start receiving inquiries
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-lg border-2 border-green-100 p-6 md:p-8">
          <div className="max-w-5xl mx-auto">
            <MWarehouseForm onSubmit={handleSubmit} isLoading={isLoading} />
          </div>
        </div>
      </div>
    </div>
  );
}