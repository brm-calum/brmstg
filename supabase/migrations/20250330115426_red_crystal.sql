/*
  # Update save_booking_offer function

  1. Changes
    - Add total_cost_with_fee_cents parameter
    - Update function to save provided fee values
    - Remove fee calculations from function

  2. Security
    - Maintains existing RLS policies
*/

-- Update save_booking_offer function
CREATE OR REPLACE FUNCTION save_booking_offer(
  p_inquiry_id uuid,
  p_total_cost_cents bigint,
  p_platform_fee_percentage numeric,
  p_platform_fee_cents bigint,
  p_total_cost_with_fee_cents bigint,
  p_valid_until timestamptz,
  p_notes text,
  p_spaces jsonb,
  p_services jsonb DEFAULT NULL,
  p_terms jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_offer_id uuid;
BEGIN
  -- Create offer
  INSERT INTO booking_offers (
    inquiry_id,
    total_cost_cents,
    platform_fee_percentage,
    platform_fee_cents,
    total_cost_with_fee_cents,
    valid_until,
    notes,
    status
  ) VALUES (
    p_inquiry_id,
    p_total_cost_cents,
    p_platform_fee_percentage,
    p_platform_fee_cents,
    p_total_cost_with_fee_cents,
    p_valid_until,
    p_notes,
    'draft'
  ) RETURNING id INTO v_offer_id;

  -- Add spaces if provided
  IF p_spaces IS NOT NULL AND jsonb_array_length(p_spaces) > 0 THEN
    INSERT INTO booking_offer_spaces (
      offer_id,
      space_id,
      space_allocated_m2,
      price_per_m2_cents,
      offer_total_cents,
      is_manual_price,
      comments
    )
    SELECT
      v_offer_id,
      (space->>'space_id')::uuid,
      (space->>'space_allocated_m2')::numeric,
      (space->>'price_per_m2_cents')::bigint,
      (space->>'offer_total_cents')::bigint,
      (space->>'is_manual_price')::boolean,
      space->>'comments'
    FROM jsonb_array_elements(p_spaces) space;
  END IF;

  -- Add services if provided
  IF p_services IS NOT NULL AND jsonb_array_length(p_services) > 0 THEN
    INSERT INTO booking_offer_services (
      offer_id,
      service_id,
      pricing_type,
      quantity,
      price_per_hour_cents,
      price_per_unit_cents,
      unit_type,
      fixed_price_cents,
      offer_total_cents,
      comments
    )
    SELECT
      v_offer_id,
      (service->>'service_id')::uuid,
      (service->>'pricing_type')::text,
      (service->>'quantity')::integer,
      (service->>'price_per_hour_cents')::bigint,
      (service->>'price_per_unit_cents')::bigint,
      service->>'unit_type',
      (service->>'fixed_price_cents')::bigint,
      (service->>'offer_total_cents')::bigint,
      service->>'comments'
    FROM jsonb_array_elements(p_services) service;
  END IF;

  -- Add terms if provided
  IF p_terms IS NOT NULL AND jsonb_array_length(p_terms) > 0 THEN
    INSERT INTO booking_offer_terms (
      offer_id,
      term_type,
      description
    )
    SELECT
      v_offer_id,
      term->>'term_type',
      term->>'description'
    FROM jsonb_array_elements(p_terms) term;
  END IF;

  RETURN v_offer_id;
END;
$$;

-- Add comments
COMMENT ON FUNCTION save_booking_offer IS 'Saves a booking offer with provided platform fee values';