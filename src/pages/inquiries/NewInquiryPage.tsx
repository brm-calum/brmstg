import React from 'react';
import { AuthGuard } from '../../components/auth/AuthGuard';
import { InquiryForm } from '../../components/inquiries/InquiryForm';
import { ArrowLeft, AlertCircle, Building2 } from 'lucide-react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useInquiries } from '../../hooks/useInquiries';
import { InquiryFormData } from '../../lib/types/inquiry';
import { useEffect } from 'react';
import { useState } from 'react';
import { useMWarehouses } from '../../hooks/useMWarehouses';

export function NewInquiryPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { createInquiry, submitInquiry } = useInquiries();
  const { fetchMWarehouses } = useMWarehouses();
  const { warehouseId } = location.state || {};
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [selectedWarehouses, setSelectedWarehouses] = useState<any[]>([]);
  const [warehouses, setWarehouses] = useState<any[]>([]);

  useEffect(() => {
    // Scroll to top when component mounts
    window.scrollTo(0, 0);
    loadWarehouses();
  }, []);

  const loadWarehouses = async () => {
    try {
      const data = await fetchMWarehouses();
      setWarehouses(data);
      if (warehouseId) {
        const selected = data.find(w => w.id === warehouseId);
        if (selected) {
          setSelectedWarehouses([selected]);
        }
      }
    } catch (err) {
      console.error('Failed to load warehouses:', err);
    }
  };

  const handleWarehouseChange = (ids: string[]) => {
    const selected = warehouses.filter(w => ids.includes(w.id));
    setSelectedWarehouses(selected);
  };

  const handleSubmit = async (formData: InquiryFormData) => {
    try {
      setError(null);
      setIsSubmitting(true);

      // Create separate inquiries for each warehouse
      const inquiryPromises = formData.warehouse_ids.map(async (warehouseId) => {
        const singleWarehouseData = {
          ...formData,
          warehouse_ids: [warehouseId]
        };

        try {
          // Create and submit inquiry
          const inquiryId = await createInquiry(singleWarehouseData);
          await submitInquiry(inquiryId);
          return inquiryId;
        } catch (err) {
          throw new Error(`Failed to create inquiry for warehouse ${warehouseId}: ${err instanceof Error ? err.message : 'Unknown error'}`);
        }
      });

      const results = await Promise.allSettled(inquiryPromises);
      const failures = results.filter(r => r.status === 'rejected');
      
      if (failures.length > 0) {
        throw new Error(`Failed to create ${failures.length} inquiries`);
      }
      
      // Navigate to inquiries page
      navigate('/inquiries');
    } catch (err) {
      console.error('Failed to create inquiry:', err);
      setError(err instanceof Error ? err.message : 'Failed to create inquiry');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AuthGuard requiredRoles={['customer']}>
      <div className="py-6">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center mb-6">
            <button
              onClick={() => navigate('/inquiries')}
              className="mr-4 text-gray-600 hover:text-gray-900"
            >
              <ArrowLeft className="h-5 w-5" />
            </button>
            <h1 className="text-2xl font-bold leading-7 text-gray-900">
              New Booking Inquiry
            </h1>
            {selectedWarehouses.length > 0 && (
              <div className="mt-4 bg-gray-50 rounded-lg p-4">
                <h2 className="text-sm font-medium text-gray-700 flex items-center mb-3">
                  <Building2 className="h-4 w-4 mr-2 text-gray-400" />
                  Selected Warehouses ({selectedWarehouses.length})
                </h2>
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  {selectedWarehouses.map(warehouse => (
                    <div key={warehouse.id} className="bg-white p-3 rounded-lg shadow-sm">
                      <div className="font-medium text-gray-900">{warehouse.name}</div>
                      <div className="text-sm text-gray-500">{warehouse.city}, {warehouse.country}</div>
                      <div className="mt-1 text-xs text-gray-400">
                        {warehouse.spaces.reduce((total: number, space: any) => total + space.size_m2, 0)} m² total
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
          
          {error && (
            <div className="mt-4 bg-red-50 border-l-4 border-red-400 p-4">
              <div className="flex">
                <div className="flex-shrink-0">
                  <AlertCircle className="h-5 w-5 text-red-400" />
                </div>
                <div className="ml-3">
                  <p className="text-sm text-red-700">{error}</p>
                </div>
              </div>
            </div>
          )}

          <div className="mt-4">
            <InquiryForm 
              onSubmit={handleSubmit}
              initialData={warehouseId ? { warehouse_ids: [warehouseId] } : undefined}
              isSubmitting={isSubmitting}
              onWarehouseChange={handleWarehouseChange}
            />
          </div>
        </div>
      </div>
    </AuthGuard>
  );
}