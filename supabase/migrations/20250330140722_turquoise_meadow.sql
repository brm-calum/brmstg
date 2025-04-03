/*
  # Update booking offer function with platform fee handling

  1. Changes
    - Updates update_booking_offer function to include platform fee fields
    - Adds validation for platform fee values
    - Maintains existing functionality

  2. Security
    - Maintains existing RLS policies
*/

-- Update update_booking_offer function
CREATE OR REPLACE FUNCTION update_booking_offer(
  p_offer_id uuid,
  p_total_cost_cents bigint,
  p_platform_fee_percentage numeric,
  p_platform_fee_cents bigint,
  p_total_cost_with_fee_cents bigint,
  p_valid_until timestamptz,
  p_notes text,
  p_spaces jsonb,
  p_services jsonb DEFAULT NULL,
  p_terms jsonb DEFAULT NULL
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_calculated_platform_fee_cents bigint;
  v_calculated_total_with_fee_cents bigint;
BEGIN
  -- Validate costs
  IF p_total_cost_cents <= 0 THEN
    RAISE EXCEPTION 'Total cost must be greater than 0';
  END IF;

  IF p_platform_fee_percentage < 0 OR p_platform_fee_percentage > 100 THEN
    RAISE EXCEPTION 'Platform fee percentage must be between 0 and 100';
  END IF;

  -- Calculate expected values
  v_calculated_platform_fee_cents := ROUND(p_total_cost_cents * (p_platform_fee_percentage / 100));
  v_calculated_total_with_fee_cents := p_total_cost_cents + v_calculated_platform_fee_cents;

  -- Validate provided values match calculated values
  IF v_calculated_platform_fee_cents != p_platform_fee_cents THEN
    RAISE EXCEPTION 'Platform fee cents does not match calculated value';
  END IF;

  IF v_calculated_total_with_fee_cents != p_total_cost_with_fee_cents THEN
    RAISE EXCEPTION 'Total cost with fee does not match calculated value';
  END IF;

  -- Update offer
  UPDATE booking_offers SET
    total_cost_cents = p_total_cost_cents,
    platform_fee_percentage = p_platform_fee_percentage,
    platform_fee_cents = p_platform_fee_cents,
    total_cost_with_fee_cents = p_total_cost_with_fee_cents,
    valid_until = p_valid_until,
    notes = p_notes,
    updated_at = now()
  WHERE id = p_offer_id;

  -- Delete existing allocations
  DELETE FROM booking_offer_spaces WHERE offer_id = p_offer_id;
  DELETE FROM booking_offer_services WHERE offer_id = p_offer_id;
  DELETE FROM booking_offer_terms WHERE offer_id = p_offer_id;

  -- Insert space allocations
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
      p_offer_id,
      (space->>'space_id')::uuid,
      (space->>'space_allocated_m2')::numeric,
      (space->>'price_per_m2_cents')::bigint,
      (space->>'offer_total_cents')::bigint,
      (space->>'is_manual_price')::boolean,
      space->>'comments'
    FROM jsonb_array_elements(p_spaces) space;
  END IF;

  -- Insert service allocations
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
      p_offer_id,
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

  -- Insert terms
  IF p_terms IS NOT NULL AND jsonb_array_length(p_terms) > 0 THEN
    INSERT INTO booking_offer_terms (
      offer_id,
      term_type,
      description
    )
    SELECT
      p_offer_id,
      term->>'term_type',
      term->>'description'
    FROM jsonb_array_elements(p_terms) term;
  END IF;

  RETURN true;
END;
$$;

-- Add comments
COMMENT ON FUNCTION update_booking_offer IS 'Updates a booking offer with platform fee handling and validation';