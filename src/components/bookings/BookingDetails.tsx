import React from 'react';
import { Building2, Calendar, Euro, MapPin, Package, Tag } from 'lucide-react';
import { Booking } from '../../lib/types/booking';
import { formatDate } from '../../lib/utils/dates';

interface BookingDetailsProps {
  booking: Booking;
}

export function BookingDetails({ booking }: BookingDetailsProps) {
  return (
    <div className="bg-white shadow rounded-lg">
      <div className="px-6 py-4 border-b border-gray-200">
        <h2 className="text-lg font-medium text-gray-900">Booking Details</h2>
      </div>
      <div className="p-6 space-y-6">
        {/* Status */}
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-gray-500">Status</span>
          <span className={`px-2 py-1 text-sm font-medium rounded-full ${
            booking.status === 'active' ? 'bg-green-100 text-green-800' :
            booking.status === 'completed' ? 'bg-blue-100 text-blue-800' :
            'bg-red-100 text-red-800'
          }`}>
            {booking.status.charAt(0).toUpperCase() + booking.status.slice(1)}
          </span>
        </div>

        {/* Warehouse Info */}
        <div className="flex items-start">
          <Building2 className="h-5 w-5 text-gray-400 mt-1 mr-3" />
          <div>
            <div className="font-medium text-gray-900">{booking.warehouse.name}</div>
            <div className="text-sm text-gray-500">
              {booking.warehouse.address}<br />
              {booking.warehouse.city}, {booking.warehouse.country}
            </div>
          </div>
        </div>

        {/* Date Range */}
        <div className="flex items-center">
          <Calendar className="h-5 w-5 text-gray-400 mr-3" />
          <div>
            <div className="font-medium text-gray-900">Booking Period</div>
            <div className="text-sm text-gray-500">
              {formatDate(booking.start_date)} to {formatDate(booking.end_date)}
            </div>
          </div>
        </div>

        {/* Spaces */}
        <div>
          <h3 className="text-sm font-medium text-gray-900 mb-3">Booked Spaces</h3>
          <div className="space-y-3">
            {booking.spaces.map((space, index) => (
              <div key={index} className="bg-gray-50 p-3 rounded-lg">
                <div className="flex justify-between items-center">
                  <span className="text-sm font-medium text-gray-900">{space.space_type}</span>
                  <span className="text-sm text-gray-500">{space.size_m2} m²</span>
                </div>
                <div className="text-sm text-gray-500 mt-1">
                  €{(space.price_per_m2_cents / 100).toFixed(2)}/m²
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Services */}
        {booking.services && booking.services.length > 0 && (
          <div>
            <h3 className="text-sm font-medium text-gray-900 mb-3">Booked Services</h3>
            <div className="space-y-3">
              {booking.services.map((service, index) => (
                <div key={index} className="bg-gray-50 p-3 rounded-lg">
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium text-gray-900">{service.name}</span>
                    <span className="text-sm text-gray-500">
                      {service.quantity} {service.unit_type || 'units'}
                    </span>
                  </div>
                  <div className="text-sm text-gray-500 mt-1">
                    {service.pricing_type === 'hourly_rate' && service.price_per_hour_cents && (
                      <>€{(service.price_per_hour_cents / 100).toFixed(2)}/hour</>
                    )}
                    {service.pricing_type === 'per_unit' && service.price_per_unit_cents && (
                      <>€{(service.price_per_unit_cents / 100).toFixed(2)}/{service.unit_type}</>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Total Cost */}
        <div className="border-t border-gray-200 pt-4">
          <div className="flex justify-between items-center">
            <span className="text-base font-medium text-gray-900">Total Cost</span>
            <span className="text-lg font-bold text-gray-900">
              €{(booking.total_cost_cents / 100).toFixed(2)}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}