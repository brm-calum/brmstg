import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { handleError } from '../lib/utils/errors';
import { useAuth } from '../contexts/AuthContext';
import { logDebug } from '../lib/utils/debug';

export interface OfferSpace {
  space_id: string; // This is the key field that must match m_warehouse_spaces.id
  space_allocated_m2: number;
  price_per_m2_cents: number;
  offer_total_cents: number;
  is_manual_price?: boolean;
  comments?: string;
}

export interface OfferService {
  service_id: string;
  pricing_type: 'hourly_rate' | 'per_unit' | 'fixed' | 'ask_quote';
  quantity?: number;
  price_per_hour_cents?: number;
  price_per_unit_cents?: number;
  unit_type?: string;
  fixed_price_cents?: number;
  offer_total_cents: number;
  comments?: string;
}

export interface OfferTerm {
  term_type: string;
  description: string;
}

export interface OfferFormData {
  inquiry_id: string;
  total_cost_cents: number;
  platform_fee_percentage: number;
  platform_fee_cents: number;
  total_cost_with_fee_cents: number;
  valid_until: Date;
  notes?: string;
  spaces: OfferSpace[];
  services?: OfferService[];
  terms?: OfferTerm[];
}

export function useOffers() {
  const { user } = useAuth();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const createBooking = async (offerId: string): Promise<string> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: bookingId, error: createError } = await supabase
        .rpc('create_booking', {
          p_offer_id: offerId
        });

      if (createError) throw createError;
      
      // Send private message to trader with booking link
      const { error: messageError } = await supabase
        .rpc('send_private_message', {
          p_recipient_id: offer.inquiry.trader.id,
          p_message: `Your booking has been created! You can view it here: /bookings/${bookingId}`,
          p_booking_id: bookingId
        });

      if (messageError) {
        console.error('Failed to send booking message:', messageError);
      }

      return bookingId;
    } catch (err) {
      const appError = handleError(err, 'createBooking');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const createOffer = async (data: OfferFormData): Promise<string> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: offerId, error: createError } = await supabase
        .rpc('create_booking_offer', {
          p_inquiry_id: data.inquiry_id,
          p_total_cost_cents: data.total_cost_cents,
          p_valid_until: data.valid_until.toISOString(),
          p_notes: data.notes,
          p_spaces: data.spaces,
          p_services: data.services
        });

      if (createError) throw createError;
      return offerId;
    } catch (err) {
      const appError = handleError(err, 'createOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const getTraderOffer = async (inquiryId: string) => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: offer, error: offerError } = await supabase
        .rpc('get_trader_offer', {
          p_inquiry_id: inquiryId
        });

      if (offerError) throw offerError;
      return offer;
    } catch (err) {
      const appError = handleError(err, 'getTraderOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const sendOffer = async (offerId: string): Promise<boolean> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: success, error: sendError } = await supabase
        .rpc('send_booking_offer', {
          p_offer_id: offerId
        });

      if (sendError) throw sendError;
      return success;
    } catch (err) {
      const appError = handleError(err, 'sendOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const getDraftOffer = async (offerId: string) => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: offer, error: offerError } = await supabase
        .from('booking_offers')
        .select(`
          *,
          inquiry:inquiry_id(
            id,
            start_date,
            end_date
          ),
          spaces:booking_offer_spaces(
            id,
            space_id,
            space_allocated_m2,
            price_per_m2_cents,
            offer_total_cents,
            is_manual_price,
            comments,
            space:m_warehouse_spaces(
              id,
              warehouse_id,
              space_type_id,
              size_m2,
              price_per_m2_cents,
              space_type:m_space_types(*)
            )
          ),
          services:booking_offer_services(
            id,
            service_id,
            pricing_type,
            quantity,
            price_per_hour_cents,
            price_per_unit_cents,
            unit_type,
            fixed_price_cents,
            offer_total_cents,
            comments,
            service:warehouse_services(
              id,
              name,
              description
            )
          ),
          terms:booking_offer_terms(
            id,
            term_type,
            description
          )
        `)
        .eq('id', offerId)
        .eq('status', 'draft')
        .single();

      if (offerError) throw offerError;

      // Transform the data to match the expected format
      const transformedOffer = {
        inquiry_id: offer.inquiry_id,
        total_cost_cents: offer.total_cost_cents,
        valid_until: offer.valid_until,
        notes: offer.notes,
        spaces: offer.spaces?.map((space: any) => ({
          space_id: space.space_id,
          space_allocated_m2: space.space_allocated_m2,
          price_per_m2_cents: space.price_per_m2_cents,
          offer_total_cents: space.offer_total_cents,
          is_manual_price: space.is_manual_price,
          comments: space.comments,
          space: space.space
        })) || [],
        services: offer.services?.map((service: any) => ({
          service_id: service.service_id,
          pricing_type: service.pricing_type,
          quantity: service.quantity,
          price_per_hour_cents: service.price_per_hour_cents,
          price_per_unit_cents: service.price_per_unit_cents,
          unit_type: service.unit_type,
          fixed_price_cents: service.fixed_price_cents,
          offer_total_cents: service.offer_total_cents,
          comments: service.comments,
          service: service.service
        })) || [],
        terms: offer.terms?.map((term: any) => ({
          term_type: term.term_type,
          description: term.description
        })) || []
      };

      return transformedOffer;
    } catch (err) {
      const appError = handleError(err, 'getDraftOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const saveDraftOffer = async (data: OfferFormData): Promise<string> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      // Log input data for debugging
      logDebug({
        function_name: 'saveDraftOffer',
        input_params: {
          inquiry_id: data.inquiry_id,
          platform_fee_percentage: data.platform_fee_percentage,
          platform_fee_cents: data.platform_fee_cents,
          total_cost_with_fee_cents: data.total_cost_with_fee_cents,
          spaces: data.spaces,
          services: data.services,
          terms: data.terms
        }
      });

      // Call RPC function to save offer
      const { data: offerId, error: saveError } = await supabase
        .rpc('save_booking_offer', {
          p_inquiry_id: data.inquiry_id,
          p_total_cost_cents: data.total_cost_cents,
          p_platform_fee_percentage: data.platform_fee_percentage,
          p_platform_fee_cents: data.platform_fee_cents,
          p_total_cost_with_fee_cents: data.total_cost_with_fee_cents,
          p_valid_until: data.valid_until.toISOString(),
          p_notes: data.notes,
          p_spaces: data.spaces,
          p_services: data.services || null,
          p_terms: data.terms || null
        });

      if (saveError) throw saveError;
      return offerId;
    } catch (err) {
      const appError = handleError(err, 'saveDraftOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const updateOffer = async (id: string, data: Omit<OfferFormData, 'inquiry_id'>): Promise<boolean> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      // Log input data for debugging
      logDebug({
        function_name: 'updateOffer',
        input_params: {
          offer_id: id,
          platform_fee_percentage: data.platform_fee_percentage,
          platform_fee_cents: data.platform_fee_cents,
          total_cost_with_fee_cents: data.total_cost_with_fee_cents,
          spaces: data.spaces,
          services: data.services,
          terms: data.terms
        }
      });

      // Call RPC function to update offer
      const { data: success, error: updateError } = await supabase
        .rpc('update_booking_offer', {
          p_offer_id: id,
          p_total_cost_cents: data.total_cost_cents,
          p_platform_fee_percentage: data.platform_fee_percentage,
          p_platform_fee_cents: data.platform_fee_cents,
          p_total_cost_with_fee_cents: data.total_cost_with_fee_cents,
          p_valid_until: data.valid_until.toISOString(),
          p_notes: data.notes,
          p_spaces: data.spaces,
          p_services: data.services || null,
          p_terms: data.terms || null
        });

      if (updateError) throw updateError;
      return success;
    } catch (err) {
      const appError = handleError(err, 'updateOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  
  const acceptOffer = async (offerId: string): Promise<boolean> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      // Accept offer using the RPC function
      const { data: success, error: acceptError } = await supabase
        .rpc('respond_to_offer', {
          p_offer_id: offerId,
          p_action: 'accept'
        });

      if (acceptError) throw acceptError;
      return success;
    } catch (err) {
      const appError = handleError(err, 'acceptOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const rejectOffer = async (offerId: string): Promise<boolean> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      // Reject offer using the RPC function
      const { data: success, error: rejectError } = await supabase
        .rpc('respond_to_offer', {
          p_offer_id: offerId,
          p_action: 'reject'
        });

      if (rejectError) throw rejectError;
      return success;
    } catch (err) {
      const appError = handleError(err, 'rejectOffer');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const getOffersForInquiry = async (inquiryId: string) => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      // Get all offers for an inquiry using the RPC function
      const { data: offers, error: offersError } = await supabase
        .rpc('get_booking_offers', {
          p_inquiry_id: inquiryId
        });

      if (offersError) throw offersError;
      return offers;
    } catch (err) {
      const appError = handleError(err, 'getOffersForInquiry');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  const requestChanges = async (offerId: string, message: string): Promise<boolean> => {
    if (!user) throw new Error('User not authenticated');
    
    try {
      setIsLoading(true);
      setError(null);

      const { data: success, error: requestError } = await supabase
        .rpc('request_offer_changes', {
          p_offer_id: offerId,
          p_message: message
        });

      if (requestError) throw requestError;
      return success;
    } catch (err) {
      const appError = handleError(err, 'requestChanges');
      setError(appError);
      throw appError;
    } finally {
      setIsLoading(false);
    }
  };

  return {
    saveDraftOffer,
    getDraftOffer,
    createOffer,
    getTraderOffer,
    updateOffer,
    sendOffer,
    acceptOffer,
    rejectOffer,
    requestChanges,
    getOffersForInquiry,
    createBooking,
    isLoading,
    error
  };
}
