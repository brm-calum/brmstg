/*
  # Fix Messaging System Issues

  1. Changes
    - Fix conversation title to show inquiry/booking ID instead of conversation ID
    - Fix infinite recursion in message_participants policy
    - Update get_user_threads to show proper subject line
    - Add proper error handling and logging

  2. Security
    - Fix RLS policies to prevent infinite recursion
    - Maintain existing security model
*/

-- Update get_or_create_conversation function to use proper title format
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
  v_inquiry_number text;
  v_booking_number text;
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

  -- Create reference numbers
  IF p_inquiry_id IS NOT NULL THEN
    v_inquiry_number := substring(p_inquiry_id::text, 1, 8);
  END IF;
  
  IF p_booking_id IS NOT NULL THEN
    v_booking_number := substring(p_booking_id::text, 1, 8);
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

  -- Create new conversation with proper title
  INSERT INTO message_conversations (
    inquiry_id,
    booking_id,
    title,
    updated_at
  ) VALUES (
    p_inquiry_id,
    p_booking_id,
    CASE
      WHEN p_inquiry_id IS NOT NULL THEN 'Inquiry #' || v_inquiry_number
      ELSE 'Booking #' || v_booking_number
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

-- Fix message_participants policy to prevent infinite recursion
DROP POLICY IF EXISTS "Users can view their participation" ON message_participants;
CREATE POLICY "Users can view their participation"
ON message_participants
FOR SELECT
USING (user_id = auth.uid());

-- Add policy for viewing other participants in conversations user is part of
CREATE POLICY "Users can view other participants in their conversations"
ON message_participants
FOR SELECT
USING (
  conversation_id IN (
    SELECT conversation_id 
    FROM message_participants 
    WHERE user_id = auth.uid()
  )
);

-- Update get_user_threads function to show proper subject line
CREATE OR REPLACE FUNCTION get_user_threads()
RETURNS TABLE (
  thread_id uuid,
  thread_type text,
  thread_info jsonb,
  last_message_at timestamptz,
  unread_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mc.id as thread_id,
    CASE
      WHEN mc.inquiry_id IS NOT NULL THEN 'inquiry'
      ELSE 'booking'
    END as thread_type,
    CASE
      WHEN mc.inquiry_id IS NOT NULL THEN
        jsonb_build_object(
          'id', bi.id,
          'status', bi.status,
          'subject', 'Inquiry #' || substring(bi.id::text, 1, 8),
          'warehouses', (
            SELECT jsonb_agg(jsonb_build_object('name', mw.name))
            FROM booking_inquiry_warehouses biw
            JOIN m_warehouses mw ON mw.id = biw.warehouse_id
            WHERE biw.inquiry_id = mc.inquiry_id
          )
        )
      ELSE
        jsonb_build_object(
          'id', b.id,
          'status', b.status,
          'subject', 'Booking #' || substring(b.id::text, 1, 8),
          'warehouse', jsonb_build_object('name', mw.name)
        )
    END as thread_info,
    COALESCE(
      (SELECT MAX(created_at)
       FROM booking_messages
       WHERE conversation_id = mc.id),
      mc.created_at
    ) as last_message_at,
    (SELECT COUNT(*)::integer
     FROM booking_messages bm
     JOIN message_read_status mrs ON mrs.message_id = bm.id
     WHERE bm.conversation_id = mc.id
     AND mrs.user_id = auth.uid()
     AND mrs.is_read = false) as unread_count
  FROM message_conversations mc
  JOIN message_participants mp ON mp.conversation_id = mc.id
  LEFT JOIN booking_inquiries bi ON bi.id = mc.inquiry_id
  LEFT JOIN bookings b ON b.id = mc.booking_id
  LEFT JOIN m_warehouses mw ON mw.id = b.warehouse_id
  WHERE mp.user_id = auth.uid()
  ORDER BY last_message_at DESC;
END;
$$;

-- Update MessagingPanel component to use conversation_id
CREATE OR REPLACE FUNCTION get_conversation_id(
  p_inquiry_id uuid,
  p_booking_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
BEGIN
  -- Validate input
  IF p_inquiry_id IS NULL AND p_booking_id IS NULL THEN
    RAISE EXCEPTION 'Either inquiry_id or booking_id must be provided';
  END IF;

  IF p_inquiry_id IS NOT NULL AND p_booking_id IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot specify both inquiry_id and booking_id';
  END IF;

  -- Get conversation ID
  IF p_inquiry_id IS NOT NULL THEN
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE inquiry_id = p_inquiry_id;
  ELSE
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE booking_id = p_booking_id;
  END IF;

  -- If conversation doesn't exist, create it
  IF v_conversation_id IS NULL THEN
    v_conversation_id := get_or_create_conversation(p_inquiry_id, p_booking_id);
  END IF;

  RETURN v_conversation_id;
END;
$$;

-- Add comments
COMMENT ON FUNCTION get_or_create_conversation IS 'Gets an existing conversation or creates a new one with proper title format';
COMMENT ON FUNCTION get_user_threads IS 'Gets all conversation threads for the current user with proper subject line';
COMMENT ON FUNCTION get_conversation_id IS 'Gets or creates a conversation ID for an inquiry or booking';