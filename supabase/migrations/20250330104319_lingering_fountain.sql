/*
  # Add total cost with fee column

  1. Changes
    - Add total_cost_with_fee_cents column to booking_offers and bookings
    - Update functions to handle total cost with fee
    - Add validation for total cost calculations

  2. Security
    - Maintains existing RLS policies
*/

-- Add total cost with fee column to booking_offers
ALTER TABLE booking_offers
ADD COLUMN IF NOT EXISTS total_cost_with_fee_cents bigint GENERATED ALWAYS AS (
  total_cost_cents + platform_fee_cents
) STORED;

-- Add total cost with fee column to bookings
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS total_cost_with_fee_cents bigint GENERATED ALWAYS AS (
  total_cost_cents + platform_fee_cents
) STORED;

-- Update create_booking_offer function to validate costs
CREATE OR REPLACE FUNCTION create_booking_offer(
  p_inquiry_id uuid,
  p_total_cost_cents bigint,
  p_platform_fee_percentage numeric,
  p_valid_until timestamptz,
  p_notes text DEFAULT NULL,
  p_spaces jsonb DEFAULT NULL,
  p_services jsonb DEFAULT NULL,
  p_terms jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_offer_id uuid;
  v_platform_fee_cents bigint;
BEGIN
  -- Validate costs
  IF p_total_cost_cents <= 0 THEN
    RAISE EXCEPTION 'Total cost must be greater than 0';
  END IF;

  IF p_platform_fee_percentage < 0 OR p_platform_fee_percentage > 100 THEN
    RAISE EXCEPTION 'Platform fee percentage must be between 0 and 100';
  END IF;

  -- Calculate platform fee
  v_platform_fee_cents := ROUND(p_total_cost_cents * (p_platform_fee_percentage / 100));

  -- Create offer
  INSERT INTO booking_offers (
    inquiry_id,
    total_cost_cents,
    platform_fee_percentage,
    valid_until,
    notes,
    status
  ) VALUES (
    p_inquiry_id,
    p_total_cost_cents,
    p_platform_fee_percentage,
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

-- Update create_booking function to handle total cost with fee
CREATE OR REPLACE FUNCTION create_booking(p_offer_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id uuid;
  v_offer booking_offers%ROWTYPE;
BEGIN
  -- Get offer details
  SELECT * INTO v_offer
  FROM booking_offers
  WHERE id = p_offer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Offer not found';
  END IF;

  IF v_offer.status != 'accepted' THEN
    RAISE EXCEPTION 'Cannot create booking: offer is not accepted';
  END IF;

  -- Create booking
  INSERT INTO bookings (
    inquiry_id,
    offer_id,
    trader_id,
    warehouse_owner_id,
    warehouse_id,
    start_date,
    end_date,
    total_cost_cents,
    platform_fee_percentage,
    status
  )
  SELECT
    o.inquiry_id,
    o.id,
    i.trader_id,
    w.owner_id,
    w.id,
    i.start_date,
    i.end_date,
    o.total_cost_cents,
    o.platform_fee_percentage,
    'active'
  FROM booking_offers o
  JOIN booking_inquiries i ON i.id = o.inquiry_id
  JOIN booking_inquiry_warehouses iw ON iw.inquiry_id = i.id
  JOIN warehouses w ON w.id = iw.warehouse_id
  WHERE o.id = p_offer_id
  RETURNING id INTO v_booking_id;

  -- Update offer status
  UPDATE booking_offers
  SET status = 'booked'
  WHERE id = p_offer_id;

  -- Update inquiry status
  UPDATE booking_inquiries
  SET status = 'booked'
  WHERE id = v_offer.inquiry_id;

  RETURN v_booking_id;
END;
$$;

-- Add comments
COMMENT ON COLUMN booking_offers.total_cost_with_fee_cents IS 'Total cost including platform fee';
COMMENT ON COLUMN bookings.total_cost_with_fee_cents IS 'Total cost including platform fee';
COMMENT ON FUNCTION create_booking_offer IS 'Creates a new booking offer with platform fee calculation';
COMMENT ON FUNCTION create_booking IS 'Creates a booking from an accepted offer, including platform fee';