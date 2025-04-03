/*
  # Update Email Notifications for Read Messages

  1. Changes
    - Add function to cancel pending email notifications when a message is marked as read
    - Update on_message_read_status_updated trigger to handle email cancellation
    - Add logging for email cancellation events

  2. Security
    - Maintains existing RLS policies
*/

-- Function to cancel pending email notifications for a message
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
  ) RETURNING id INTO v_log_id;

  -- Get message content (first 50 characters for matching)
  SELECT substring(message from 1 for 50) INTO v_message
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
    RETURNING id
  )
  SELECT COUNT(*) INTO v_cancelled_count FROM cancelled;

  -- Update log with results
  UPDATE brm_logs
  SET 
    status = 'success',
    activity_data = activity_data || jsonb_build_object(
      'cancelled_count', v_cancelled_count,
      'user_email', v_user_email,
      'message_preview', v_message
    )
  WHERE id = v_log_id;

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
  WHERE id = v_log_id;

  RETURN 0;
END;
$$;

-- Update on_message_read_status_updated function
CREATE OR REPLACE FUNCTION on_message_read_status_updated()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Cancel pending email notifications when a message is marked as read
  IF NEW.is_read = true AND OLD.is_read = false THEN
    PERFORM cancel_message_email_notifications(NEW.message_id, NEW.user_id);
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

-- Add comments
COMMENT ON FUNCTION cancel_message_email_notifications IS 'Cancels pending email notifications for a message when it is marked as read';
COMMENT ON FUNCTION on_message_read_status_updated IS 'Trigger function to cancel email notifications when a message is marked as read';