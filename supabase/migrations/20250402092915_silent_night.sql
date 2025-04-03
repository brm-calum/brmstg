/*
  # Add Message Read Status Logic

  1. Changes
    - Add function to mark messages as read
    - Add trigger to automatically mark messages as read when viewed
    - Add function to get unread messages for a conversation
    - Update message_read_status table with indexes for better performance

  2. Security
    - Maintain existing RLS policies
    - Ensure users can only mark their own messages as read
*/

-- Create index for faster read status lookups
CREATE INDEX IF NOT EXISTS idx_message_read_status_message_user
ON message_read_status (message_id, user_id);

-- Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_read(
  p_message_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
  v_updated_count integer;
BEGIN
  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status,
    created_by
  ) VALUES (
    'mark_messages_read',
    jsonb_build_object(
      'message_ids', p_message_ids,
      'user_id', auth.uid()
    ),
    'processing',
    auth.uid()
  ) RETURNING id INTO v_log_id;

  -- Update read status for current user
  WITH updated AS (
    UPDATE message_read_status
    SET 
      is_read = true,
      read_at = now()
    WHERE message_id = ANY(p_message_ids)
    AND user_id = auth.uid()
    AND is_read = false
    RETURNING message_id
  )
  SELECT COUNT(*) INTO v_updated_count FROM updated;

  -- Update log with success
  UPDATE brm_logs
  SET 
    status = 'success',
    activity_data = activity_data || jsonb_build_object(
      'updated_count', v_updated_count
    )
  WHERE id = v_log_id;
END;
$$;

-- Function to mark all messages in a conversation as read
CREATE OR REPLACE FUNCTION mark_conversation_read(
  p_conversation_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
  v_updated_count integer;
  v_message_ids uuid[];
BEGIN
  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status,
    created_by
  ) VALUES (
    'mark_conversation_read',
    jsonb_build_object(
      'conversation_id', p_conversation_id,
      'user_id', auth.uid()
    ),
    'processing',
    auth.uid()
  ) RETURNING id INTO v_log_id;

  -- Verify user has access to this conversation
  IF NOT EXISTS (
    SELECT 1 FROM message_participants
    WHERE conversation_id = p_conversation_id
    AND user_id = auth.uid()
  ) THEN
    -- Update log with error
    UPDATE brm_logs
    SET 
      status = 'error',
      error_message = 'Access denied',
      activity_data = activity_data || jsonb_build_object(
        'error_details', 'User does not have access to this conversation'
      )
    WHERE id = v_log_id;
    
    RAISE EXCEPTION 'Access denied: You are not a participant in this conversation';
  END IF;

  -- Get all unread message IDs for this user in this conversation
  SELECT array_agg(bm.id) INTO v_message_ids
  FROM booking_messages bm
  LEFT JOIN message_read_status mrs ON mrs.message_id = bm.id AND mrs.user_id = auth.uid()
  WHERE bm.conversation_id = p_conversation_id
  AND (mrs.is_read IS NULL OR mrs.is_read = false);

  -- If there are no unread messages, exit
  IF v_message_ids IS NULL OR array_length(v_message_ids, 1) IS NULL THEN
    -- Update log with info
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'updated_count', 0,
        'info', 'No unread messages found'
      )
    WHERE id = v_log_id;
    
    RETURN;
  END IF;

  -- Update read status for all unread messages
  WITH updated AS (
    UPDATE message_read_status
    SET 
      is_read = true,
      read_at = now()
    WHERE message_id = ANY(v_message_ids)
    AND user_id = auth.uid()
    AND is_read = false
    RETURNING message_id
  )
  SELECT COUNT(*) INTO v_updated_count FROM updated;

  -- Insert read status for messages that don't have an entry yet
  WITH missing_messages AS (
    SELECT bm.id
    FROM booking_messages bm
    LEFT JOIN message_read_status mrs ON mrs.message_id = bm.id AND mrs.user_id = auth.uid()
    WHERE bm.conversation_id = p_conversation_id
    AND mrs.message_id IS NULL
  ),
  inserted AS (
    INSERT INTO message_read_status (
      message_id,
      user_id,
      is_read,
      read_at
    )
    SELECT 
      id,
      auth.uid(),
      true,
      now()
    FROM missing_messages
    RETURNING message_id
  )
  SELECT v_updated_count + COUNT(*) INTO v_updated_count FROM inserted;

  -- Update log with success
  UPDATE brm_logs
  SET 
    status = 'success',
    activity_data = activity_data || jsonb_build_object(
      'updated_count', v_updated_count,
      'message_ids', v_message_ids
    )
  WHERE id = v_log_id;
END;
$$;

-- Function to get unread messages for a conversation
CREATE OR REPLACE FUNCTION get_unread_messages(
  p_conversation_id uuid
)
RETURNS TABLE (
  message_id uuid,
  created_at timestamptz,
  sender_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify user has access to this conversation
  IF NOT EXISTS (
    SELECT 1 FROM message_participants
    WHERE conversation_id = p_conversation_id
    AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Access denied: You are not a participant in this conversation';
  END IF;

  -- Return unread messages
  RETURN QUERY
  SELECT
    bm.id as message_id,
    bm.created_at,
    bm.sender_id
  FROM booking_messages bm
  LEFT JOIN message_read_status mrs ON mrs.message_id = bm.id AND mrs.user_id = auth.uid()
  WHERE bm.conversation_id = p_conversation_id
  AND (mrs.is_read IS NULL OR mrs.is_read = false)
  AND bm.sender_id != auth.uid() -- Don't include messages sent by current user
  ORDER BY bm.created_at ASC;
END;
$$;

-- Update MessageList component to mark messages as read when viewed
CREATE OR REPLACE FUNCTION on_message_list_viewed(
  p_conversation_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_message_ids uuid[];
BEGIN
  -- Get all unread message IDs for this user in this conversation
  SELECT array_agg(bm.id) INTO v_message_ids
  FROM booking_messages bm
  LEFT JOIN message_read_status mrs ON mrs.message_id = bm.id AND mrs.user_id = auth.uid()
  WHERE bm.conversation_id = p_conversation_id
  AND (mrs.is_read IS NULL OR mrs.is_read = false)
  AND bm.sender_id != auth.uid(); -- Don't include messages sent by current user

  -- If there are no unread messages, exit
  IF v_message_ids IS NULL OR array_length(v_message_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  -- Mark messages as read
  PERFORM mark_messages_read(v_message_ids);
END;
$$;

-- Update get_thread_messages to mark messages as read when viewed
CREATE OR REPLACE FUNCTION get_thread_messages(
  p_conversation_id uuid,
  p_mark_as_read boolean DEFAULT true
)
RETURNS TABLE (
  id uuid,
  message text,
  created_at timestamptz,
  is_read boolean,
  sender_info jsonb,
  is_system_message boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status,
    created_by
  ) VALUES (
    'get_thread_messages',
    jsonb_build_object(
      'conversation_id', p_conversation_id,
      'mark_as_read', p_mark_as_read
    ),
    'processing',
    auth.uid()
  ) RETURNING id INTO v_log_id;

  -- Verify user has access to this conversation
  IF NOT EXISTS (
    SELECT 1 FROM message_participants
    WHERE conversation_id = p_conversation_id
    AND user_id = auth.uid()
  ) THEN
    -- Update log with error
    UPDATE brm_logs
    SET 
      status = 'error',
      error_message = 'Access denied',
      activity_data = activity_data || jsonb_build_object(
        'error_details', 'User does not have access to this conversation'
      )
    WHERE id = v_log_id;
    
    RAISE EXCEPTION 'Access denied: You are not a participant in this conversation';
  END IF;

  -- Mark messages as read if requested
  IF p_mark_as_read THEN
    PERFORM mark_conversation_read(p_conversation_id);
  END IF;

  -- Return messages with read status for current user
  RETURN QUERY
  SELECT
    bm.id,
    bm.message,
    bm.created_at,
    COALESCE(mrs.is_read, false) as is_read,
    jsonb_build_object(
      'id', bm.sender_id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'is_admin', EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = bm.sender_id
        AND r.name = 'administrator'
      )
    ) as sender_info,
    bm.is_system_message
  FROM booking_messages bm
  LEFT JOIN message_read_status mrs ON mrs.message_id = bm.id AND mrs.user_id = auth.uid()
  LEFT JOIN profiles p ON p.user_id = bm.sender_id
  WHERE bm.conversation_id = p_conversation_id
  ORDER BY bm.created_at ASC;

  -- Update log with success
  UPDATE brm_logs
  SET 
    status = 'success',
    activity_data = activity_data || jsonb_build_object(
      'message_count', (SELECT COUNT(*) FROM booking_messages WHERE conversation_id = p_conversation_id)
    )
  WHERE id = v_log_id;
END;
$$;

-- Update get_thread_messages for inquiry/booking to use the new function
CREATE OR REPLACE FUNCTION get_thread_messages(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_mark_as_read boolean DEFAULT true
)
RETURNS TABLE (
  id uuid,
  message text,
  created_at timestamptz,
  is_read boolean,
  sender_info jsonb,
  is_system_message boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
  v_log_id uuid;
BEGIN
  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status,
    created_by
  ) VALUES (
    'get_thread_messages',
    jsonb_build_object(
      'inquiry_id', p_inquiry_id,
      'booking_id', p_booking_id,
      'mark_as_read', p_mark_as_read
    ),
    'processing',
    auth.uid()
  ) RETURNING id INTO v_log_id;

  -- Get conversation ID
  v_conversation_id := get_conversation_id(p_inquiry_id, p_booking_id);

  -- Update log with conversation ID
  UPDATE brm_logs
  SET activity_data = activity_data || jsonb_build_object(
    'conversation_id', v_conversation_id
  )
  WHERE id = v_log_id;

  -- Return messages using the conversation ID function
  RETURN QUERY
  SELECT * FROM get_thread_messages(v_conversation_id, p_mark_as_read);

  -- Update log with success
  UPDATE brm_logs
  SET 
    status = 'success'
  WHERE id = v_log_id;
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
$$;

-- Add comments
COMMENT ON FUNCTION mark_messages_read IS 'Marks specific messages as read for the current user';
COMMENT ON FUNCTION mark_conversation_read IS 'Marks all messages in a conversation as read for the current user';
COMMENT ON FUNCTION get_unread_messages IS 'Gets all unread messages in a conversation for the current user';
COMMENT ON FUNCTION on_message_list_viewed IS 'Marks messages as read when the message list is viewed';
COMMENT ON FUNCTION get_thread_messages(uuid, boolean) IS 'Gets all messages in a thread by conversation_id with option to mark as read';
COMMENT ON FUNCTION get_thread_messages(uuid, uuid, boolean) IS 'Gets all messages in a thread by inquiry_id or booking_id with option to mark as read';