import React, { useEffect } from 'react';
import { Check, X, Clock, Euro, Calendar, Building2, Package, ExternalLink } from 'lucide-react';
import { Link } from 'react-router-dom';
import { formatDate } from '../../lib/utils/dates';
import { useAuth } from '../../contexts/AuthContext';

interface OfferSummaryProps {
  offer: any;
  onAccept?: () => void;
  onReject?: () => void;
  onRequestChanges?: () => void;
  onCreateBooking?: () => void;
  showActions?: boolean;
}

export function OfferSummary({ 
  offer, 
  onAccept, 
  onReject, 
  onRequestChanges, 
  onCreateBooking,
  showActions = true 
}: OfferSummaryProps) {
  const { user, hasRole } = useAuth();
  if (!offer) return null;
  
  const isExpired = new Date(offer.valid_until) < new Date();
  const conditionStatusSent = offer.status === 'offer_sent';
  const conditionStatusAccepted = offer.status === 'accepted';
  const conditionNotExpired = !isExpired;
  const conditionShowActions = showActions;
  const conditionUserMatches = user?.id === offer.inquiry?.trader_id;
  const isAdmin = hasRole('administrator');
  const hasBooking = offer.status === 'accepted' && offer.booking_id;
  const canRespond = conditionStatusSent && conditionNotExpired && conditionShowActions && conditionUserMatches;
  const canCreateBooking = isAdmin && conditionStatusAccepted && conditionShowActions;

  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'draft':
        return 'bg-gray-100 text-gray-800';
      case 'sent':
        return 'bg-yellow-100 text-yellow-800';
      case 'accepted':
        return 'bg-green-100 text-green-800';
      case 'rejected':
        return 'bg-red-100 text-red-800';
      case 'expired':
        return 'bg-orange-100 text-orange-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  {/* // Calculate platform fee
  const platformFeeCents = Math.round(offer.total_cost_cents * (offer.platform_fee_percentage / 100)); */}

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      {/* Header */}
      <div className="mb-6">
        <h3 className="text-xl font-medium text-gray-900">Offer #{offer.id.slice(0, 8)}</h3>
        <div className="mt-2 flex items-center">
          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusBadgeClass(offer.status)}`}>
            {offer.status.charAt(0).toUpperCase() + offer.status.slice(1)}
          </span>
        </div>
        <div className="mt-2 grid grid-cols-2 gap-4">
          <div className="flex items-center text-sm text-gray-600">
            <Building2 className="h-4 w-4 mr-2" />
            {offer.spaces?.[0]?.space?.warehouse?.name || 'Unknown Warehouse'}
          </div>
          <div className="flex items-center text-sm text-gray-600">
            <Calendar className="h-4 w-4 mr-2" />
            {formatDate(offer.inquiry?.start_date)} - {formatDate(offer.inquiry?.end_date)}
          </div>
        </div>
      </div>
      
      {/* Spaces Table */}
      <div className="overflow-hidden border border-gray-200 rounded-lg mb-6">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50 text-xs font-medium text-gray-500 uppercase tracking-wider">
            <tr>
              <th scope="col" className="px-4 py-2 text-left">Space Type</th>
              <th scope="col" className="px-4 py-2 text-right">Allocation</th>
              <th scope="col" className="px-4 py-2 text-right">Price/m²</th>
              <th scope="col" className="px-4 py-2 text-right">Total</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {offer.spaces?.map((space: any) => (
              <tr key={space.id}>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-900">
                  {space.space_type}
                </td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-500 text-right">
                  {space.size_m2} m²
                </td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-500 text-right">
                  €{(space.price_per_m2_cents / 100).toFixed(2)}
                </td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-gray-500 text-right">
                  €{(space.offer_total_cents / 100).toFixed(2)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Services Table */}
      {offer.services?.length > 0 && (
        <div className="overflow-hidden border border-gray-200 rounded-lg mb-6">
          <table className="min-w-full divide-y divide-gray-200 text-sm">
            <thead className="bg-gray-50 text-xs font-medium text-gray-500 uppercase tracking-wider">
              <tr>
                <th scope="col" className="px-4 py-2 text-left">Service</th>
                <th scope="col" className="px-4 py-2 text-right">Quantity</th>
                <th scope="col" className="px-4 py-2 text-right">Rate</th>
                <th scope="col" className="px-4 py-2 text-right">Total</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {offer.services.map((service: any) => (
                <tr key={service.id}>
                  <td className="px-4 py-2 whitespace-nowrap text-gray-900">
                    {service.name}
                  </td>
                  <td className="px-4 py-2 whitespace-nowrap text-gray-500 text-right">
                    {service.quantity || '-'}
                  </td>
                  <td className="px-4 py-2 whitespace-nowrap text-gray-500 text-right">
                    {service.pricing_type === 'hourly_rate' && service.price_per_hour_cents && 
                      `€${(service.price_per_hour_cents / 100).toFixed(2)}/hr`}
                    {service.pricing_type === 'per_unit' && service.price_per_unit_cents && 
                      `€${(service.price_per_unit_cents / 100).toFixed(2)}/${service.unit_type}`}
                    {service.pricing_type === 'fixed' && service.fixed_price_cents && 
                      `€${(service.fixed_price_cents / 100).toFixed(2)}`}
                    {service.pricing_type === 'ask_quote' && 'Quote required'}
                  </td>
                  <td className="px-4 py-2 whitespace-nowrap text-gray-500 text-right">
                    €{(service.offer_total_cents / 100).toFixed(2)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Summary Footer */}
      <div className="mt-8 border-t border-gray-200 pt-6">
        <div className="space-y-4">
          <div className="text-right space-y-3">
              <div>
                <p className="text-sm text-gray-500">Subtotal</p>
                <p className="text-lg font-medium text-gray-900 tabular-nums">€{(offer.total_cost_cents / 100).toFixed(2)}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500">Platform Fee</p>
                <p className="text-lg font-medium text-gray-900 tabular-nums">€{(offer.platform_fee_cents / 100).toFixed(2)}</p>
              </div>
              <div>
                <p className="text-sm text-gray-500">Total</p>
                <p className="text-xl font-bold text-gray-900 tabular-nums">
                  €{(offer.total_cost_with_fee_cents / 100).toFixed(2)}
                </p>
                <p className="text-xs text-gray-500 mt-1">VAT not included</p>
              </div>
              <div className="mt-4 pt-4 border-t border-gray-200">
                <p className="text-sm text-gray-500">Valid until</p>
                <p className="text-base font-medium text-gray-900">{formatDate(offer.valid_until)}</p>
                {isExpired && <p className="text-sm text-red-600">This offer has expired</p>}
              </div>
          </div>

          {canRespond && (
            <div className="mt-6 flex justify-end space-x-4">
              {/*} <button
                onClick={onRequestChanges}
                className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
              >
                Request Changes
              </button> */}
              <button
                onClick={onReject}
                className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-red-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
              >
                <X className="h-4 w-4 mr-2" />
                Reject Offer
              </button>
              <button
                onClick={onAccept}
                className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
              >
                <Check className="h-4 w-4 mr-2" />
                Accept Offer
              </button>
            </div>
          )}
          
          {canCreateBooking && (
            <div className="mt-6 flex justify-end">
              <button
                onClick={onCreateBooking}
                className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
              >
                <Check className="h-4 w-4 mr-2" />
                Create Booking
              </button>
            </div>
          )}
          
          {hasBooking && (
            <div className="mt-6 flex justify-end">
              <Link
                to={`/bookings/${offer.booking_id}`}
                className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700"
              >
                <ExternalLink className="h-4 w-4 mr-2" />
                View Booking
              </Link>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}