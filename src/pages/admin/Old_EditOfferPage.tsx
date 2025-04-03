import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { AuthGuard } from '../../components/auth/AuthGuard';
import { useInquiries } from '../../hooks/useInquiries';
import { useOffers } from '../../hooks/useOffers';
import { ArrowLeft, AlertCircle, Layers, Calendar, MapPin, Package, Tag, Euro } from 'lucide-react';
import { logDebug } from '../../lib/utils/debug';
import { supabase } from '../../lib/supabase';
import { formatDate } from '../../lib/utils/dates';

export function EditOfferPage() {
  const { inquiryId, offerId } = useParams<{ inquiryId: string; offerId: string }>();
  const navigate = useNavigate();
  const { getInquiry, isLoading: inquiryLoading } = useInquiries();
  const { getDraftOffer, updateOffer, isLoading: offerLoading } = useOffers();
  const [platformFee, setPlatformFee] = useState(20);
  const [inquiry, setInquiry] = useState(null);
  const [spaceAllocations, setSpaceAllocations] = useState({});
  const [serviceAllocations, setServiceAllocations] = useState({});
  const [subTotal, setSubTotal] = useState(0);
  const [offerDetails, setOfferDetails] = useState({
    validUntil: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      .toISOString()
      .split('T')[0],
    notes: ''
  });
  const [platformFeeAmount, setPlatformFeeAmount] = useState(0);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (inquiryId && offerId) {
      loadData();
      loadPlatformFee();
    }
  }, [inquiryId, offerId]);

  const loadPlatformFee = async () => {
    try {
      const { data, error } = await supabase
        .from('platform_config')
        .select('platform_fee_percentage')
        .single();
      
      if (error) throw error;
      if (data) {
        setPlatformFee(data.platform_fee_percentage);
      }
    } catch (err) {
      console.error('Failed to load platform fee:', err);
    }
  };

  const loadData = async () => {
    if (!inquiryId || !offerId) return;

    try {
      // Then get the inquiry
      const inquiryData = await getInquiry(inquiryId);

      // First get the offer details
      const offerData = await getDraftOffer(offerId);
      
      // Calculate duration
      const duration = Math.ceil(
        (new Date(inquiryData.end_date).getTime() - new Date(inquiryData.start_date).getTime()) /
          (1000 * 60 * 60 * 24)
      );

      // Initialize space allocations from offer data
      const initialSpaceAllocations = {};
      inquiryData.space_requests?.forEach(request => {
        const savedSpace = offerData.spaces?.find(s => 
          s.space?.space_type_id === request.space_type_id
        );
        
        if (savedSpace) {
          initialSpaceAllocations[request.id] = {
            allocated: savedSpace.space_allocated_m2,
            listPricePerM2: savedSpace.price_per_m2_cents,
            duration: duration,
            estimatedTotal: savedSpace.offer_total_cents,
            offerTotal: savedSpace.offer_total_cents,
            comments: savedSpace.comments || ''
          };
        }
      });

      // Initialize service allocations from offer data
      const initialServiceAllocations = {};
      inquiryData.services?.forEach(inquiryService => {
        const savedService = offerData.services?.find(s => 
          s.service_id === inquiryService.service_id
        );
        
        if (savedService) {
          initialServiceAllocations[inquiryService.service_id] = {
            pricingType: savedService.pricing_type || 'hourly_rate',
            quantity: savedService.quantity || 1,
            pricePerUnit: savedService.price_per_hour_cents || savedService.price_per_unit_cents || 0,
            estimatedTotal: savedService.offer_total_cents,
            offerTotal: savedService.offer_total_cents,
            unitType: savedService.unit_type || 'hour',
            comments: savedService.comments || ''
          };
        }
      });

      // Set initial offer details
      setOfferDetails({
        validUntil: new Date(offerData.valid_until).toISOString().split('T')[0],
        notes: offerData.notes || ''
      });

      logDebug({
        function_name: 'loadData',
        input_params: {
          inquiryId,
          offerId
        },
        output_data: {
          inquiry: inquiryData,
          offer: offerData
        }
      });

      setInquiry(inquiryData);
      setSpaceAllocations(initialSpaceAllocations);
      setServiceAllocations(initialServiceAllocations);
      
      // Set platform fee and totals
      if (offerData) {
        setPlatformFee(offerData.platform_fee_percentage || platformFee);
        setPlatformFeeAmount(offerData.platform_fee_cents || 0);
        setSubTotal(offerData.total_cost_cents || 0);
      }
    } catch (err) {
      console.error('Failed to load data:', err);
      setError(err instanceof Error ? err : new Error('Failed to load data'));
    }
  };

  // Calculate total price whenever allocations change
  useEffect(() => {
    const spaceTotal = Object.values(spaceAllocations).reduce((sum: number, space: any) => {
      return sum + (space.offerTotal || 0);
    }, 0);

    const serviceTotal = Object.values(serviceAllocations).reduce((sum: number, service: any) => {
      return sum + (service.offerTotal || 0);
    }, 0);

    const newSubTotal = spaceTotal + serviceTotal;
    setSubTotal(newSubTotal);
    
    // Update platform fee amount
    const newPlatformFeeAmount = Math.round(newSubTotal * (platformFee / 100));
    setPlatformFeeAmount(newPlatformFeeAmount);
  }, [spaceAllocations, serviceAllocations, platformFee]);

  const handlePlatformFeeChange = (value: number) => {
    setPlatformFee(value);
    setPlatformFeeAmount(Math.round(subTotal * (value / 100)));
  };

  const handlePlatformFeeAmountChange = (amount: number) => {
    setPlatformFeeAmount(amount);
    setPlatformFee((amount / subTotal) * 100);
  };

  const totalAmount = subTotal + platformFeeAmount;

  const handleSpaceAllocationChange = (requestId: string, field: string, value: number) => {
    setSpaceAllocations(prev => {
      const allocation = prev[requestId];
      if (!allocation) return prev;

      const updated = { ...allocation, [field]: value };

      if (field === 'allocated') {
        // Recalculate estimated and offer totals
        updated.estimatedTotal = value * updated.listPricePerM2 * updated.duration;
        updated.offerTotal = updated.estimatedTotal;
      } else if (field === 'offerTotal') {
        // Direct update of offer total
        updated.offerTotal = value;
      }

      return { ...prev, [requestId]: updated };
    });
  };

  const handleServiceAllocationChange = (serviceId: string, field: string, value: any) => {
    setServiceAllocations(prev => {
      const allocation = prev[serviceId];
      if (!allocation) return prev;

      const updated = { ...allocation, [field]: value };

      if (field === 'quantity' || field === 'pricePerUnit') {
        // Recalculate totals
        updated.estimatedTotal = updated.quantity * updated.pricePerUnit;
        updated.offerTotal = updated.estimatedTotal;
      } else if (field === 'offerTotal') {
        // Direct update of offer total
        updated.offerTotal = value;
      }

      return { ...prev, [serviceId]: updated };
    });
  };

  const handleSubmit = async (sendImmediately = false) => {
    if (!offerId || !inquiryId) return;

    try {
      // Format space allocations data
      const spaceData = Object.entries(spaceAllocations).map(([requestId, allocation]) => {
        const request = inquiry.space_requests.find(r => r.id === requestId);
        const warehouse = inquiry.warehouses?.[0]?.warehouse;
        const space = warehouse?.spaces?.find(s => s.space_type_id === request.space_type_id);
        
        if (!space) {
          throw new Error('No matching space found for allocation');
        }

        return {
          space_id: space.id,
          space_allocated_m2: allocation.allocated,
          price_per_m2_cents: allocation.listPricePerM2,
          offer_total_cents: allocation.offerTotal,
          comments: allocation.comments || ''
        };
      });

      // Format service allocations data
      const serviceData = Object.entries(serviceAllocations).map(([serviceId, allocation]) => {
        return {
          service_id: serviceId,
          pricing_type: allocation.pricingType || 'ask_quote',
          quantity: allocation.quantity,
          price_per_hour_cents: allocation.pricingType === 'hourly_rate' ? Math.round(allocation.pricePerUnit * 100) : null,
          price_per_unit_cents: allocation.pricingType === 'per_unit' ? Math.round(allocation.pricePerUnit * 100) : null,
          fixed_price_cents: allocation.pricingType === 'fixed' ? Math.round(allocation.pricePerUnit * 100) : null,
          unit_type: allocation.unitType,
          offer_total_cents: Math.round(allocation.offerTotal),
          comments: allocation.comments || ''
        };
      });

      // Update offer
      await updateOffer(offerId, {
        platform_fee_percentage: platformFee,
        platform_fee_cents: platformFeeAmount,
        total_cost_cents: subTotal,
        total_cost_with_fee_cents: totalAmount,
        valid_until: new Date(offerDetails.validUntil),
        notes: offerDetails.notes,
        spaces: spaceData,
        services: serviceData
      });

      // Navigate back to inquiry details
      navigate(`/admin/inquiries/${inquiryId}`);
    } catch (err) {
      console.error('Failed to update offer:', err);
      setError(err instanceof Error ? err : new Error('Failed to update offer'));
    }
  };

  const isLoading = inquiryLoading || offerLoading;

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-green-500" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-red-50 border-l-4 border-red-400 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <AlertCircle className="h-5 w-5 text-red-400" />
            </div>
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">
                Error Loading Data
              </h3>
              <div className="mt-2 text-sm text-red-700">
                {error.message}
              </div>
              <div className="mt-4">
                <button
                  type="button"
                  onClick={() => navigate(`/admin/inquiries/${inquiryId}`)}
                  className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  Return to Inquiry
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!inquiry) {
    return (
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="bg-blue-50 border-l-4 border-blue-400 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <AlertCircle className="h-5 w-5 text-blue-400" />
            </div>
            <div className="ml-3">
              <p className="text-sm text-blue-700">
                Inquiry not found. It may have been deleted or you don't have permission to view it.
              </p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <AuthGuard requiredRoles={['administrator']}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex items-center mb-6">
            <button
              onClick={() => navigate(`/admin/inquiries/${inquiryId}`)}
              className="mr-4 text-gray-600 hover:text-gray-900"
            >
              <ArrowLeft className="h-5 w-5" />
            </button>
            <h1 className="text-2xl font-bold text-gray-900">
              Edit Offer
            </h1>
          </div>

          <div className="bg-white shadow rounded-lg p-6 mb-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h2 className="text-lg font-medium mb-4 flex items-center">
                  <Layers className="w-5 h-5 mr-2" />
                  Space Requirements
                </h2>
                {inquiry.space_requests.map(request => (
                  <div key={request.id} className="mb-4">
                    <p className="text-sm text-gray-500">{request.space_type.name}</p>
                    <p className="font-medium">{request.space_required_m2}m²</p>
                  </div>
                ))}
              </div>
              
              <div>
                <h2 className="text-lg font-medium mb-4 flex items-center">
                  <Calendar className="w-5 h-5 mr-2" />
                  Date Range
                </h2>
                <p className="text-sm text-gray-500">From</p>
                <p className="font-medium">{formatDate(inquiry.start_date)}</p>
                <p className="text-sm text-gray-500 mt-2">To</p>
                <p className="font-medium">{formatDate(inquiry.end_date)}</p>
              </div>
            </div>
          </div>

          <div className="bg-white shadow rounded-lg p-6 mb-6">
            <h2 className="text-lg font-medium mb-4 flex items-center">
              <MapPin className="w-5 h-5 mr-2" />
              Selected Warehouse
            </h2>
            {inquiry.warehouses?.[0]?.warehouse && (
              <div>
                <p className="font-medium">{inquiry.warehouses[0].warehouse.name}</p>
                <p className="text-sm text-gray-500">{inquiry.warehouses[0].warehouse.address}</p>
              </div>
            )}
          </div>

          <div className="bg-white shadow rounded-lg p-6 mb-6">
            <h2 className="text-lg font-medium mb-4 flex items-center">
              <Package className="w-5 h-5 mr-2" />
              Space Allocation
            </h2>
            {/* Space allocation table */}
          </div>

          <div className="bg-white shadow rounded-lg p-6 mb-6">
            <h2 className="text-lg font-medium mb-4 flex items-center">
              <Tag className="w-5 h-5 mr-2" />
              Services
            </h2>
            {/* Services table */}
          </div>

          <div className="bg-white shadow rounded-lg p-6 mb-6">
            <h2 className="text-lg font-medium mb-4 flex items-center">
              <Euro className="w-5 h-5 mr-2" />
              Summary
            </h2>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-gray-600">Subtotal</span>
                <span className="font-medium">€{(subTotal / 100).toFixed(2)}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-gray-600">Platform Fee ({platformFee}%)</span>
                <span className="font-medium">€{(platformFeeAmount / 100).toFixed(2)}</span>
              </div>
              <div className="flex justify-between items-center text-lg font-bold">
                <span>Total</span>
                <span>€{(totalAmount / 100).toFixed(2)}</span>
              </div>
            </div>
          </div>

          <div className="flex justify-end space-x-4">
            <button
              onClick={() => navigate(`/admin/inquiries/${inquiryId}`)}
              className="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              onClick={() => handleSubmit(false)}
              className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
            >
              Save Changes
            </button>
          </div>
      </div>
    </AuthGuard>
  );
}