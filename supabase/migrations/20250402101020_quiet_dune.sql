/*
  # Update Email Notifications for Read Messages

  1. Changes
    - Improve cancel_message_email_notifications function to better match emails to messages
    - Update on_message_read_status_updated trigger to handle email cancellation more effectively
    - Add detailed logging for email cancellation events

  2. Security
    - Maintains existing RLS policies
*/


-- Update function to cancel pending email notifications for a message
CREATE OR REPLACE FUNCTION cancel_message_email_notifications(
  p_message_id uuid,
  p_user_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_message text;
  v_user_email text;
  v_cancelled_count integer;
  v_log_id uuid;
  v_conversation_id uuid;
BEGIN
  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status,
    created_by
  ) VALUES (
    'cancel_email_notifications',
    jsonb_build_object(
      'message_id', p_message_id,
      'user_id', p_user_id
    ),
    'processing',
    p_user_id
  ) RETURNING brm_logs.id INTO v_log_id;

  -- Get message content and conversation ID
  SELECT message, conversation_id INTO v_message, v_conversation_id
  FROM booking_messages
  WHERE id = p_message_id;

  -- Get user email
  SELECT email INTO v_user_email
  FROM auth.users
  WHERE id = p_user_id;

  -- Cancel pending email notifications
  WITH cancelled AS (
    UPDATE email_queue
    SET 
      status = 'cancelled',
      updated_at = CURRENT_TIMESTAMP
    WHERE to_email = v_user_email
    AND status = 'pending'
    AND next_retry_at > CURRENT_TIMESTAMP
    AND (
      -- Match by message content (first 30 chars)
      text_content LIKE '%' || substring(v_message from 1 for 30) || '%'
      OR
      html_content LIKE '%' || substring(v_message from 1 for 30) || '%'
    )
    RETURNING id
  )
  SELECT COUNT(*) INTO v_cancelled_count FROM cancelled;

  -- If no emails were cancelled by content matching, try to cancel by conversation
  IF v_cancelled_count = 0 AND v_conversation_id IS NOT NULL THEN
    -- Get conversation details
    DECLARE
      v_inquiry_id uuid;
      v_booking_id uuid;
      v_link_path text;
    BEGIN
      SELECT inquiry_id, booking_id INTO v_inquiry_id, v_booking_id
      FROM message_conversations
      WHERE id = v_conversation_id;
      
      -- Determine link path
      IF v_inquiry_id IS NOT NULL THEN
        v_link_path := '/inquiries/' || v_inquiry_id;
      ELSIF v_booking_id IS NOT NULL THEN
        v_link_path := '/bookings/' || v_booking_id;
      ELSE
        v_link_path := '/messages';
      END IF;
      
      -- Cancel emails with matching link path
      WITH cancelled AS (
        UPDATE email_queue
        SET 
          status = 'cancelled',
          updated_at = CURRENT_TIMESTAMP
        WHERE to_email = v_user_email
        AND status = 'pending'
        AND next_retry_at > CURRENT_TIMESTAMP
        AND (
          -- Match by link path
          text_content LIKE '%' || v_link_path || '%'
          OR
          html_content LIKE '%' || v_link_path || '%'
        )
        RETURNING id
      )
      SELECT COUNT(*) INTO v_cancelled_count FROM cancelled;
    END;
  END IF;

  -- Update log with results
  UPDATE brm_logs
  SET 
    status = 'success',
    activity_data = activity_data || jsonb_build_object(
      'cancelled_count', v_cancelled_count,
      'user_email', v_user_email,
      'message_preview', substring(v_message from 1 for 50),
      'conversation_id', v_conversation_id
    )
  WHERE brm_logs.id = v_log_id;

  RETURN v_cancelled_count;
EXCEPTION WHEN OTHERS THEN
  -- Update log with error
  UPDATE brm_logs
  SET 
    status = 'error',
    error_message = SQLERRM,
    activity_data = activity_data || jsonb_build_object(
      'error_details', SQLERRM
    )
  WHERE brm_logs.id = v_log_id;

  RETURN 0;
END;
$$;


-- Update on_message_read_status_updated function
CREATE OR REPLACE FUNCTION on_message_read_status_updated()
RETURNS trigger
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
    'message_read_status_updated',
    jsonb_build_object(
      'message_id', NEW.message_id,
      'user_id', NEW.user_id,
      'is_read', NEW.is_read,
      'read_at', NEW.read_at
    ),
    'processing',
    NEW.user_id
  ) RETURNING brm_logs.id INTO v_log_id;

  -- Cancel pending email notifications when a message is marked as read
  IF NEW.is_read = true AND OLD.is_read = false THEN
    DECLARE
      v_cancelled_count integer;
    BEGIN
      SELECT cancel_message_email_notifications(NEW.message_id, NEW.user_id) INTO v_cancelled_count;
      
      -- Update log with results
      UPDATE brm_logs
      SET 
        status = 'success',
        activity_data = activity_data || jsonb_build_object(
          'cancelled_count', v_cancelled_count
        )
      WHERE brm_logs.id = v_log_id;
    EXCEPTION WHEN OTHERS THEN
      -- Update log with error
      UPDATE brm_logs
      SET 
        status = 'error',
        error_message = SQLERRM,
        activity_data = activity_data || jsonb_build_object(
          'error_details', SQLERRM
        )
      WHERE brm_logs.id = v_log_id;
    END;
  ELSE
    -- Update log with no action needed
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'info', 'No action needed - message was already read'
      )
    WHERE brm_logs.id = v_log_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS message_read_status_updated_trigger ON message_read_status;

-- Create trigger for read status updates
CREATE TRIGGER message_read_status_updated_trigger
AFTER UPDATE ON message_read_status
FOR EACH ROW
WHEN (NEW.is_read = true AND OLD.is_read = false)
EXECUTE FUNCTION on_message_read_status_updated();

-- Add function to mark all messages in a conversation as read
CREATE OR REPLACE FUNCTION mark_all_conversation_messages_read(
  p_conversation_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
  v_updated_count integer := 0;
  v_message_ids uuid[];
BEGIN
  -- Create log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status,
    created_by
  ) VALUES (
    'mark_all_conversation_messages_read',
    jsonb_build_object(
      'conversation_id', p_conversation_id,
      'user_id', auth.uid()
    ),
    'processing',
    auth.uid()
  ) RETURNING brm_logs.id INTO v_log_id;

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
    WHERE brm_logs.id = v_log_id;
    
    RAISE EXCEPTION 'Access denied: You are not a participant in this conversation';
  END IF;

  -- Get all unread message IDs for this user in this conversation
  SELECT array_agg(bm.id) INTO v_message_ids
  FROM booking_messages bm
  LEFT JOIN message_read_status mrs ON mrs.message_id = bm.id AND mrs.user_id = auth.uid()
  WHERE bm.conversation_id = p_conversation_id
  AND (mrs.is_read IS NULL OR mrs.is_read = false)
  AND bm.sender_id != auth.uid(); -- Don't include messages sent by current user

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
    WHERE brm_logs.id = v_log_id;
    
    RETURN 0;
  END IF;

  -- Update existing read status entries
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
    AND bm.id = ANY(v_message_ids)
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
  WHERE brm_logs.id = v_log_id;

  RETURN v_updated_count;
END;
$$;

-- Add comments
COMMENT ON FUNCTION cancel_message_email_notifications IS 'Cancels pending email notifications for a message when it is marked as read';
COMMENT ON FUNCTION on_message_read_status_updated IS 'Trigger function to cancel email notifications when a message is marked as read';
COMMENT ON FUNCTION mark_all_conversation_messages_read IS 'Marks all messages in a conversation as read for the current user';