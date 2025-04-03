/*
  # Fix send_conversation_message function

  1. Changes
    - Update get_or_create_conversation function to handle non-existent bookings
    - Add validation to check if booking exists before creating conversation
    - Improve error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_or_create_conversation;

-- Create updated function with booking existence check
CREATE OR REPLACE FUNCTION get_or_create_conversation(
  p_inquiry_id uuid,
  p_booking_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
  v_trader_id uuid;
  v_warehouse_owner_id uuid;
  v_admin_id uuid;
  v_booking_exists boolean;
BEGIN
  -- Validate input
  IF p_inquiry_id IS NULL AND p_booking_id IS NULL THEN
    RAISE EXCEPTION 'Either inquiry_id or booking_id must be provided';
  END IF;

  IF p_inquiry_id IS NOT NULL AND p_booking_id IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot specify both inquiry_id and booking_id';
  END IF;

  -- Check if conversation already exists
  IF p_inquiry_id IS NOT NULL THEN
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE inquiry_id = p_inquiry_id;
  ELSE
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE booking_id = p_booking_id;
  END IF;

  -- If conversation exists, return it
  IF v_conversation_id IS NOT NULL THEN
    RETURN v_conversation_id;
  END IF;

  -- Verify booking exists if booking_id is provided
  IF p_booking_id IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM bookings WHERE id = p_booking_id
    ) INTO v_booking_exists;
    
    IF NOT v_booking_exists THEN
      RAISE EXCEPTION 'Booking with ID % does not exist', p_booking_id;
    END IF;
  END IF;

  -- Get participant IDs
  IF p_inquiry_id IS NOT NULL THEN
    -- Get trader ID
    SELECT trader_id INTO v_trader_id
    FROM booking_inquiries
    WHERE id = p_inquiry_id;
    
    IF v_trader_id IS NULL THEN
      RAISE EXCEPTION 'Inquiry with ID % does not exist', p_inquiry_id;
    END IF;
    
    -- Get admin ID (first administrator found)
    SELECT user_id INTO v_admin_id
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE r.name = 'administrator'
    LIMIT 1;
  ELSE
    -- Get trader and warehouse owner IDs
    SELECT trader_id, warehouse_owner_id INTO v_trader_id, v_warehouse_owner_id
    FROM bookings
    WHERE id = p_booking_id;
    
    IF v_trader_id IS NULL THEN
      RAISE EXCEPTION 'Booking with ID % does not exist or is missing trader information', p_booking_id;
    END IF;
    
    -- Get admin ID (first administrator found)
    SELECT user_id INTO v_admin_id
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE r.name = 'administrator'
    LIMIT 1;
  END IF;

  -- Create new conversation
  INSERT INTO message_conversations (
    inquiry_id,
    booking_id,
    title,
    updated_at
  ) VALUES (
    p_inquiry_id,
    p_booking_id,
    CASE
      WHEN p_inquiry_id IS NOT NULL THEN 'Inquiry #' || substring(p_inquiry_id::text, 1, 8)
      ELSE 'Booking #' || substring(p_booking_id::text, 1, 8)
    END,
    now()
  ) RETURNING id INTO v_conversation_id;

  -- Add participants
  -- Add trader
  INSERT INTO message_participants (
    conversation_id,
    user_id,
    role
  ) VALUES (
    v_conversation_id,
    v_trader_id,
    'trader'
  );

  -- Add warehouse owner if booking
  IF v_warehouse_owner_id IS NOT NULL THEN
    INSERT INTO message_participants (
      conversation_id,
      user_id,
      role
    ) VALUES (
      v_conversation_id,
      v_warehouse_owner_id,
      'warehouse_owner'
    );
  END IF;

  -- Add admin
  IF v_admin_id IS NOT NULL THEN
    INSERT INTO message_participants (
      conversation_id,
      user_id,
      role
    ) VALUES (
      v_conversation_id,
      v_admin_id,
      'administrator'
    );
  END IF;

  RETURN v_conversation_id;
END;
$$;

-- Update send_conversation_message function with better error handling
DROP FUNCTION IF EXISTS send_conversation_message;
CREATE OR REPLACE FUNCTION send_conversation_message(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_message text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
  v_message_id uuid;
  v_participant record;
  v_log_id uuid;
BEGIN
  -- Validate input
  IF p_message IS NULL OR trim(p_message) = '' THEN
    RAISE EXCEPTION 'Message cannot be empty';
  END IF;

  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'send_conversation_message',
    jsonb_build_object(
      'inquiry_id', p_inquiry_id,
      'booking_id', p_booking_id,
      'sender_id', auth.uid()
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  BEGIN
    -- Get or create conversation
    v_conversation_id := get_or_create_conversation(p_inquiry_id, p_booking_id);

    -- Update conversation timestamp
    UPDATE message_conversations
    SET updated_at = now()
    WHERE id = v_conversation_id;

    -- Insert message
    INSERT INTO booking_messages (
      inquiry_id,
      booking_id,
      sender_id,
      message,
      conversation_id
    ) VALUES (
      p_inquiry_id,
      p_booking_id,
      auth.uid(),
      p_message,
      v_conversation_id
    ) RETURNING id INTO v_message_id;

    -- Create read status entries for all participants
    FOR v_participant IN
      SELECT user_id
      FROM message_participants
      WHERE conversation_id = v_conversation_id
    LOOP
      INSERT INTO message_read_status (
        message_id,
        user_id,
        is_read,
        read_at
      ) VALUES (
        v_message_id,
        v_participant.user_id,
        -- Mark as read for sender, unread for others
        v_participant.user_id = auth.uid(),
        CASE WHEN v_participant.user_id = auth.uid() THEN now() ELSE NULL END
      );
    END LOOP;

    -- Update log with success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'message_id', v_message_id,
        'conversation_id', v_conversation_id
      )
    WHERE id = v_log_id;

    RETURN v_message_id;
  EXCEPTION WHEN OTHERS THEN
    -- Update log with error
    UPDATE brm_logs
    SET 
      status = 'error',
      error_message = SQLERRM,
      activity_data = activity_data || jsonb_build_object(
        'error_details', SQLERRM
      )
    WHERE id = v_log_id;

    RAISE;
  END;
END;
$$;

-- Add comments
COMMENT ON FUNCTION get_or_create_conversation IS 'Gets an existing conversation or creates a new one with validation for booking existence';
COMMENT ON FUNCTION send_conversation_message IS 'Sends a message to a conversation with improved error handling';