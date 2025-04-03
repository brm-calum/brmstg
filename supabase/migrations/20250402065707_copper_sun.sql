/*
  # Update Inquiry, Offer, and Booking Process to Use New Messaging System

  1. Changes
    - Update create_booking_inquiry function to create a conversation and initial message
    - Update submit_booking_inquiry function to send a system message
    - Update send_booking_offer function to send a system message
    - Update respond_to_offer function to send a system message
    - Update create_booking function to send a system message

  2. Security
    - Maintains existing RLS policies
    - Ensures proper message handling for all participants
*/

-- Update create_booking_inquiry function to create a conversation
CREATE OR REPLACE FUNCTION create_booking_inquiry(
  p_warehouse_ids uuid[],
  p_service_ids uuid[],
  p_feature_ids uuid[],
  p_space_requests jsonb,
  p_start_date timestamptz,
  p_end_date timestamptz,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inquiry_id uuid;
  v_conversation_id uuid;
  v_message_id uuid;
BEGIN
  -- Create inquiry
  INSERT INTO booking_inquiries (
    trader_id,
    start_date,
    end_date,
    notes,
    status
  ) VALUES (
    auth.uid(),
    p_start_date,
    p_end_date,
    p_notes,
    'draft'
  ) RETURNING id INTO v_inquiry_id;

  -- Add warehouses
  IF array_length(p_warehouse_ids, 1) > 0 THEN
    INSERT INTO booking_inquiry_warehouses (
      inquiry_id,
      warehouse_id
    )
    SELECT
      v_inquiry_id,
      warehouse_id
    FROM unnest(p_warehouse_ids) AS warehouse_id;
  END IF;

  -- Add services
  IF array_length(p_service_ids, 1) > 0 THEN
    INSERT INTO booking_inquiry_services (
      inquiry_id,
      service_id
    )
    SELECT
      v_inquiry_id,
      service_id
    FROM unnest(p_service_ids) AS service_id;
  END IF;

  -- Add features
  IF array_length(p_feature_ids, 1) > 0 THEN
    INSERT INTO booking_inquiry_features (
      inquiry_id,
      feature_id
    )
    SELECT
      v_inquiry_id,
      feature_id
    FROM unnest(p_feature_ids) AS feature_id;
  END IF;

  -- Add space requests
  IF p_space_requests IS NOT NULL AND jsonb_array_length(p_space_requests) > 0 THEN
    INSERT INTO booking_inquiry_space_requests (
      inquiry_id,
      space_type_id,
      size_m2
    )
    SELECT
      v_inquiry_id,
      (space->>'space_type_id')::uuid,
      (space->>'size_m2')::numeric
    FROM jsonb_array_elements(p_space_requests) space;
  END IF;

  -- Create conversation for the inquiry
  v_conversation_id := get_or_create_conversation(v_inquiry_id, NULL);

  -- Add initial system message
  INSERT INTO booking_messages (
    inquiry_id,
    sender_id,
    message,
    conversation_id,
    is_system_message
  ) VALUES (
    v_inquiry_id,
    auth.uid(),
    'Inquiry created',
    v_conversation_id,
    true
  ) RETURNING id INTO v_message_id;

  -- Create read status entries for all participants
  INSERT INTO message_read_status (
    message_id,
    user_id,
    is_read,
    read_at
  )
  SELECT
    v_message_id,
    mp.user_id,
    true, -- System messages are always read
    now()
  FROM message_participants mp
  WHERE mp.conversation_id = v_conversation_id;

  RETURN v_inquiry_id;
END;
$$;

-- Update submit_booking_inquiry function to send a system message
CREATE OR REPLACE FUNCTION submit_booking_inquiry(p_inquiry_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trader_id uuid;
  v_conversation_id uuid;
  v_message_id uuid;
BEGIN
  -- Get trader ID
  SELECT trader_id INTO v_trader_id
  FROM booking_inquiries
  WHERE id = p_inquiry_id;

  -- Verify ownership
  IF v_trader_id != auth.uid() THEN
    RAISE EXCEPTION 'You do not have permission to submit this inquiry';
  END IF;

  -- Update inquiry status
  UPDATE booking_inquiries
  SET 
    status = 'submitted',
    updated_at = now()
  WHERE id = p_inquiry_id
  AND status = 'draft';

  -- Get conversation ID
  SELECT id INTO v_conversation_id
  FROM message_conversations
  WHERE inquiry_id = p_inquiry_id;

  -- If conversation exists, add system message
  IF v_conversation_id IS NOT NULL THEN
    -- Add system message
    INSERT INTO booking_messages (
      inquiry_id,
      sender_id,
      message,
      conversation_id,
      is_system_message
    ) VALUES (
      p_inquiry_id,
      auth.uid(),
      'Inquiry submitted',
      v_conversation_id,
      true
    ) RETURNING id INTO v_message_id;

    -- Create read status entries for all participants
    INSERT INTO message_read_status (
      message_id,
      user_id,
      is_read,
      read_at
    )
    SELECT
      v_message_id,
      mp.user_id,
      true, -- System messages are always read
      now()
    FROM message_participants mp
    WHERE mp.conversation_id = v_conversation_id;
  END IF;

  RETURN true;
END;
$$;

-- Update send_booking_offer function to send a system message
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
  v_conversation_id uuid;
  v_message_id uuid;
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

  -- Get conversation ID
  SELECT id INTO v_conversation_id
  FROM message_conversations
  WHERE inquiry_id = v_inquiry_id;

  -- If conversation exists, add system message
  IF v_conversation_id IS NOT NULL THEN
    -- Add system message
    INSERT INTO booking_messages (
      inquiry_id,
      sender_id,
      message,
      conversation_id,
      is_system_message
    ) VALUES (
      v_inquiry_id,
      auth.uid(),
      'Offer sent: €' || (v_total_cost_with_fee_cents / 100)::text || ' (valid until ' || 
      to_char(v_valid_until, 'YYYY-MM-DD') || ')',
      v_conversation_id,
      true
    ) RETURNING id INTO v_message_id;

    -- Create read status entries for all participants
    INSERT INTO message_read_status (
      message_id,
      user_id,
      is_read,
      read_at
    )
    SELECT
      v_message_id,
      mp.user_id,
      true, -- System messages are always read
      now()
    FROM message_participants mp
    WHERE mp.conversation_id = v_conversation_id;
  END IF;

  RETURN true;
END;
$$;

-- Update respond_to_offer function to send a system message
CREATE OR REPLACE FUNCTION respond_to_offer(
  p_offer_id uuid,
  p_action text -- 'accept' or 'reject'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inquiry_id uuid;
  v_trader_id uuid;
  v_conversation_id uuid;
  v_message_id uuid;
BEGIN
  -- Validate action
  IF p_action NOT IN ('accept', 'reject') THEN
    RAISE EXCEPTION 'Invalid action: must be "accept" or "reject"';
  END IF;

  -- Get inquiry and trader info
  SELECT 
    bo.inquiry_id,
    bi.trader_id
  INTO 
    v_inquiry_id, 
    v_trader_id
  FROM booking_offers bo
  JOIN booking_inquiries bi ON bi.id = bo.inquiry_id
  WHERE bo.id = p_offer_id;

  -- Verify ownership
  IF v_trader_id != auth.uid() THEN
    RAISE EXCEPTION 'You do not have permission to respond to this offer';
  END IF;

  -- Update offer status
  UPDATE booking_offers
  SET 
    status = CASE WHEN p_action = 'accept' THEN 'accepted' ELSE 'rejected' END,
    updated_at = now()
  WHERE id = p_offer_id
  AND status = 'sent';

  -- Update inquiry status
  UPDATE booking_inquiries
  SET 
    status = CASE WHEN p_action = 'accept' THEN 'accepted' ELSE 'rejected' END,
    updated_at = now()
  WHERE id = v_inquiry_id;

  -- Get conversation ID
  SELECT id INTO v_conversation_id
  FROM message_conversations
  WHERE inquiry_id = v_inquiry_id;

  -- If conversation exists, add system message
  IF v_conversation_id IS NOT NULL THEN
    -- Add system message
    INSERT INTO booking_messages (
      inquiry_id,
      sender_id,
      message,
      conversation_id,
      is_system_message
    ) VALUES (
      v_inquiry_id,
      auth.uid(),
      CASE WHEN p_action = 'accept' THEN 'Offer accepted' ELSE 'Offer rejected' END,
      v_conversation_id,
      true
    ) RETURNING id INTO v_message_id;

    -- Create read status entries for all participants
    INSERT INTO message_read_status (
      message_id,
      user_id,
      is_read,
      read_at
    )
    SELECT
      v_message_id,
      mp.user_id,
      true, -- System messages are always read
      now()
    FROM message_participants mp
    WHERE mp.conversation_id = v_conversation_id;
  END IF;

  RETURN true;
END;
$$;

-- Update create_booking function to send a system message
CREATE OR REPLACE FUNCTION create_booking(p_offer_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id uuid;
  v_offer booking_offers%ROWTYPE;
  v_inquiry_id uuid;
  v_inquiry_conversation_id uuid;
  v_booking_conversation_id uuid;
  v_message_id uuid;
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

  v_inquiry_id := v_offer.inquiry_id;

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
    platform_fee_cents,
    total_cost_with_fee_cents,
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
    o.platform_fee_cents,
    o.total_cost_with_fee_cents,
    'active'
  FROM booking_offers o
  JOIN booking_inquiries i ON i.id = o.inquiry_id
  JOIN booking_inquiry_warehouses iw ON iw.inquiry_id = i.id
  JOIN m_warehouses w ON w.id = iw.warehouse_id
  WHERE o.id = p_offer_id
  RETURNING id INTO v_booking_id;

  -- Update offer status
  UPDATE booking_offers
  SET status = 'booked'
  WHERE id = p_offer_id;

  -- Update inquiry status
  UPDATE booking_inquiries
  SET status = 'booked'
  WHERE id = v_inquiry_id;

  -- Get inquiry conversation ID
  SELECT id INTO v_inquiry_conversation_id
  FROM message_conversations
  WHERE inquiry_id = v_inquiry_id;

  -- Create booking conversation
  v_booking_conversation_id := get_or_create_conversation(NULL, v_booking_id);

  -- Add system message to inquiry conversation
  IF v_inquiry_conversation_id IS NOT NULL THEN
    -- Add system message
    INSERT INTO booking_messages (
      inquiry_id,
      sender_id,
      message,
      conversation_id,
      is_system_message
    ) VALUES (
      v_inquiry_id,
      auth.uid(),
      'Booking created: #' || substring(v_booking_id::text, 1, 8),
      v_inquiry_conversation_id,
      true
    ) RETURNING id INTO v_message_id;

    -- Create read status entries for all participants
    INSERT INTO message_read_status (
      message_id,
      user_id,
      is_read,
      read_at
    )
    SELECT
      v_message_id,
      mp.user_id,
      true, -- System messages are always read
      now()
    FROM message_participants mp
    WHERE mp.conversation_id = v_inquiry_conversation_id;
  END IF;

  -- Add welcome message to booking conversation
  INSERT INTO booking_messages (
    booking_id,
    sender_id,
    message,
    conversation_id,
    is_system_message
  ) VALUES (
    v_booking_id,
    auth.uid(),
    'Booking created. You can use this conversation to communicate about the booking.',
    v_booking_conversation_id,
    true
  ) RETURNING id INTO v_message_id;

  -- Create read status entries for all participants
  INSERT INTO message_read_status (
    message_id,
    user_id,
    is_read,
    read_at
  )
  SELECT
    v_message_id,
    mp.user_id,
    true, -- System messages are always read
    now()
  FROM message_participants mp
  WHERE mp.conversation_id = v_booking_conversation_id;

  RETURN v_booking_id;
END;
$$;

-- Add comments
COMMENT ON FUNCTION create_booking_inquiry IS 'Creates a booking inquiry with initial conversation and system message';
COMMENT ON FUNCTION submit_booking_inquiry IS 'Submits a booking inquiry and adds a system message';
COMMENT ON FUNCTION send_booking_offer IS 'Sends a booking offer and adds a system message';
COMMENT ON FUNCTION respond_to_offer IS 'Responds to an offer and adds a system message';
COMMENT ON FUNCTION create_booking IS 'Creates a booking, adds system messages, and creates a booking conversation';