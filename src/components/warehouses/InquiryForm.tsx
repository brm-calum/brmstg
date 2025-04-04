import React, { useState } from 'react';
import { useBookings } from '../../hooks/useBookings';
import { Calendar, Ruler, MessageSquare } from 'lucide-react';
import { ErrorMessage } from '../ui/ErrorMessage';

interface InquiryFormData {
  warehouseId: string;
  startDate: Date;
  endDate: Date;
  spaceNeeded: number;
  message: string;
}

interface InquiryFormProps {
  warehouseId: string;
  warehouseSize: number;
  onSuccess: () => void;
  onCancel: () => void;
}

export function InquiryForm({ warehouseId, warehouseSize, onSuccess, onCancel }: InquiryFormProps) {
  const { createInquiry, isLoading } = useBookings();
  const [error, setError] = useState<Error | null>(null);
  const [formData, setFormData] = useState<InquiryFormData>({
    warehouseId,
    startDate: new Date(),
    endDate: new Date(),
    spaceNeeded: 0,
    message: '',
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    try {
      if (formData.spaceNeeded > warehouseSize) {
        setError(new Error(`Space needed cannot exceed warehouse size (${warehouseSize}m²)`));
        return;
      }

      await createInquiry({
        warehouseId,
        ...formData,
      });
      onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to submit inquiry'));
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {error && (
        <ErrorMessage 
          error={error}
          onDismiss={() => setError(null)}
        />
      )}

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">
            Rental Period
          </label>
          <div className="mt-1 grid grid-cols-2 gap-4">
            <div>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Calendar className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type="date"
                  required
                  value={formData.startDate.toISOString().split('T')[0]}
                  onChange={(e) => setFormData(prev => ({
                    ...prev,
                    startDate: new Date(e.target.value)
                  }))}
                  className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
                />
              </div>
              <p className="mt-1 text-sm text-gray-500">Start Date</p>
            </div>
            <div>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Calendar className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  type="date"
                  required
                  value={formData.endDate.toISOString().split('T')[0]}
                  onChange={(e) => setFormData(prev => ({
                    ...prev,
                    endDate: new Date(e.target.value)
                  }))}
                  className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
                />
              </div>
              <p className="mt-1 text-sm text-gray-500">End Date</p>
            </div>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">
            Space Needed (m²)
          </label>
          <div className="mt-1 relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <Ruler className="h-5 w-5 text-gray-400" />
            </div>
            <input
              type="number"
              required
              min="1"
              max={warehouseSize.toString()}
              value={formData.spaceNeeded || ''}
              onChange={(e) => setFormData(prev => ({
                ...prev,
                spaceNeeded: e.target.value ? parseFloat(e.target.value) : 0
              }))}
              className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
            />
          </div>
          <p className="mt-1 text-sm text-gray-500">
            Maximum available: {warehouseSize}m²
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700">
            Message
          </label>
          <div className="mt-1 relative">
            <div className="absolute top-3 left-3">
              <MessageSquare className="h-5 w-5 text-gray-400" />
            </div>
            <div className="relative">
              <textarea
                required
                value={formData.message}
                onChange={(e) => setFormData(prev => ({
                  ...prev,
                  message: e.target.value
                }))}
                rows={4}
                className="block w-full pl-10 border-gray-300 rounded-md focus:ring-green-500 focus:border-green-500"
                placeholder="Describe your storage needs..."
                disabled={isLoading}
              />
            </div>
          </div>
        </div>
      </div>

      <div className="flex justify-end space-x-3">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={isLoading}
          className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 disabled:opacity-50"
        >
          {isLoading ? 'Sending...' : 'Send Inquiry'}
        </button>
      </div>
    </form>
  );
}