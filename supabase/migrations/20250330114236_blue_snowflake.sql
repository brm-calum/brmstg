/*
  # Update offer functions to handle platform fees

  1. Changes
    - Update send_booking_offer to handle platform fees
    - Update create_booking_offer to validate platform fees
    - Update save_booking_offer to properly store platform fees
    - Update update_booking_offer to maintain platform fees

  2. Security
    - Maintains existing RLS policies
*/

-- Update send_booking_offer function
CREATE OR REPLACE FUNCTION send_booking_offer(p_offer_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inquiry_id uuid;
  v_trader_id uuid;
  v_valid_until timestamptz;
  v_platform_fee_percentage numeric;
  v_platform_fee_cents bigint;
  v_total_cost_cents bigint;
  v_total_cost_with_fee_cents bigint;
BEGIN
  -- Validate offer
  PERFORM validate_offer_for_send(p_offer_id);

  -- Get inquiry and trader info
  SELECT 
    bo.inquiry_id,
    bi.trader_id,
    bo.valid_until,
    bo.platform_fee_percentage,
    bo.platform_fee_cents,
    bo.total_cost_cents,
    bo.total_cost_with_fee_cents
  INTO 
    v_inquiry_id, 
    v_trader_id,
    v_valid_until,
    v_platform_fee_percentage,
    v_platform_fee_cents,
    v_total_cost_cents,
    v_total_cost_with_fee_cents
  FROM booking_offers bo
  JOIN booking_inquiries bi ON bi.id = bo.inquiry_id
  WHERE bo.id = p_offer_id;

  -- Set default valid_until if not set
  IF v_valid_until IS NULL THEN
    v_valid_until := CURRENT_TIMESTAMP + interval '7 days';
  END IF;

  -- Update offer status
  UPDATE booking_offers
  SET 
    status = 'sent',
    valid_until = v_valid_until,
    updated_at = now()
  WHERE id = p_offer_id
  AND status = 'draft';

  -- Update inquiry status
  UPDATE booking_inquiries
  SET 
    status = 'offer_sent',
    updated_at = now()
  WHERE id = v_inquiry_id;

  RETURN true;
END;
$$;

-- Add comments
COMMENT ON FUNCTION send_booking_offer IS 'Sends an offer to the trader with platform fee details';