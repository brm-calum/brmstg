/*
  # Fix get_thread_messages Function

  1. Changes
    - Update get_thread_messages to accept conversation_id parameter
    - Add overloaded function that accepts inquiry_id or booking_id
    - Maintain backward compatibility with existing code
    - Improve error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Add is_system_message column to booking_messages if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'booking_messages' AND column_name = 'is_system_message') 
  THEN
    ALTER TABLE booking_messages ADD COLUMN is_system_message boolean NOT NULL DEFAULT false;
  END IF;
END $$;

-- Create function to get messages by conversation_id
CREATE OR REPLACE FUNCTION get_thread_messages_by_conversation(
  p_conversation_id uuid
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
BEGIN
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
END;
$$;

-- Update get_thread_messages function to use conversation_id
DROP FUNCTION IF EXISTS get_thread_messages(uuid, uuid);
CREATE OR REPLACE FUNCTION get_thread_messages(
  p_inquiry_id uuid,
  p_booking_id uuid
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
      'booking_id', p_booking_id
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  BEGIN
    -- Get conversation ID
    IF p_inquiry_id IS NOT NULL THEN
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
      'conversation_id', v_conversation_id
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

    -- Return messages using the conversation ID function
    RETURN QUERY
    SELECT * FROM get_thread_messages_by_conversation(v_conversation_id);

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

-- Add direct conversation_id function for efficiency
CREATE OR REPLACE FUNCTION get_thread_messages(
  p_conversation_id uuid
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
BEGIN
  -- Return messages using the conversation ID function
  RETURN QUERY
  SELECT * FROM get_thread_messages_by_conversation(p_conversation_id);
END;
$$;

-- Add comments
COMMENT ON FUNCTION get_thread_messages_by_conversation IS 'Gets all messages in a thread by conversation ID with read status for the current user';
COMMENT ON FUNCTION get_thread_messages(uuid, uuid) IS 'Gets all messages in a thread by inquiry_id or booking_id with read status for the current user';
COMMENT ON FUNCTION get_thread_messages(uuid) IS 'Gets all messages in a thread by conversation_id with read status for the current user';