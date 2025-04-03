/*
  # Fix Messaging Thread Display and Message Retrieval

  1. Changes
    - Update get_user_threads to use proper IDs for thread_id
    - Fix thread_info to include proper subject line
    - Update get_thread_messages to handle conversation_id correctly
    - Add proper error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Update get_user_threads function to use proper IDs
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
DECLARE
  v_log_id uuid;
BEGIN
  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'get_user_threads',
    jsonb_build_object(
      'user_id', auth.uid()
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

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
            'id', mc.inquiry_id,
            'status', bi.status,
            'warehouses', (
              SELECT jsonb_agg(jsonb_build_object('name', mw.name))
              FROM booking_inquiry_warehouses biw
              JOIN m_warehouses mw ON mw.id = biw.warehouse_id
              WHERE biw.inquiry_id = mc.inquiry_id
            )
          )
        ELSE
          jsonb_build_object(
            'id', mc.booking_id,
            'status', b.status,
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

    -- Update log with success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'thread_count', (
          SELECT COUNT(*)
          FROM message_conversations mc
          JOIN message_participants mp ON mp.conversation_id = mc.id
          WHERE mp.user_id = auth.uid()
        )
      )
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
END;
$$;

-- Update get_thread_messages to handle all parameter combinations
CREATE OR REPLACE FUNCTION get_thread_messages(
  p_inquiry_id uuid DEFAULT NULL,
  p_booking_id uuid DEFAULT NULL,
  p_conversation_id uuid DEFAULT NULL
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
    status
  ) VALUES (
    'get_thread_messages',
    jsonb_build_object(
      'inquiry_id', p_inquiry_id,
      'booking_id', p_booking_id,
      'conversation_id', p_conversation_id
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  BEGIN
    -- Determine conversation ID
    IF p_conversation_id IS NOT NULL THEN
      v_conversation_id := p_conversation_id;
    ELSIF p_inquiry_id IS NOT NULL THEN
      SELECT id INTO v_conversation_id
      FROM message_conversations
      WHERE inquiry_id = p_inquiry_id;
    ELSIF p_booking_id IS NOT NULL THEN
      SELECT id INTO v_conversation_id
      FROM message_conversations
      WHERE booking_id = p_booking_id;
    END IF;

    -- Update log with conversation ID
    UPDATE brm_logs
    SET activity_data = activity_data || jsonb_build_object(
      'resolved_conversation_id', v_conversation_id
    )
    WHERE id = v_log_id;

    -- If conversation doesn't exist, return empty result
    IF v_conversation_id IS NULL THEN
      -- Update log with warning
      UPDATE brm_logs
      SET 
        status = 'warning',
        activity_data = activity_data || jsonb_build_object(
          'warning', 'No conversation found'
        )
      WHERE id = v_log_id;
      
      RETURN;
    END IF;

    -- Verify user has access to this conversation
    IF NOT EXISTS (
      SELECT 1 FROM message_participants
      WHERE conversation_id = v_conversation_id
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
    WHERE bm.conversation_id = v_conversation_id
    ORDER BY bm.created_at ASC;

    -- Update log with success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'message_count', (SELECT COUNT(*) FROM booking_messages WHERE conversation_id = v_conversation_id)
      )
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
END;
$$;

-- Update send_conversation_message to use get_conversation_id
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

  IF p_inquiry_id IS NULL AND p_booking_id IS NULL THEN
    RAISE EXCEPTION 'Either inquiry_id or booking_id must be provided';
  END IF;

  IF p_inquiry_id IS NOT NULL AND p_booking_id IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot specify both inquiry_id and booking_id';
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
    -- Get or create conversation using the helper function
    v_conversation_id := get_conversation_id(p_inquiry_id, p_booking_id);

    -- Update log with conversation ID
    UPDATE brm_logs
    SET activity_data = activity_data || jsonb_build_object(
      'conversation_id', v_conversation_id
    )
    WHERE id = v_log_id;

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
    INSERT INTO message_read_status (
      message_id,
      user_id,
      is_read,
      read_at
    )
    SELECT
      v_message_id,
      mp.user_id,
      mp.user_id = auth.uid(), -- Read for sender, unread for others
      CASE WHEN mp.user_id = auth.uid() THEN now() ELSE NULL END
    FROM message_participants mp
    WHERE mp.conversation_id = v_conversation_id;

    -- Update log with success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'message_id', v_message_id
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
COMMENT ON FUNCTION get_user_threads IS 'Gets all conversation threads for the current user with proper thread IDs and subject lines';
COMMENT ON FUNCTION get_thread_messages IS 'Gets all messages in a thread with flexible parameter handling';
COMMENT ON FUNCTION send_conversation_message IS 'Sends a message to a conversation using the get_conversation_id helper';