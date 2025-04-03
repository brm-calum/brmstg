/*
  # Fix send_message_to_all function return type

  1. Changes
    - Update send_message_to_all function to return void instead of text
    - Update send_thread_message function to return void
    - Improve error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS send_message_to_all;
DROP FUNCTION IF EXISTS send_thread_message;

-- Create updated send_thread_message function
CREATE OR REPLACE FUNCTION send_thread_message(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_message text,
  p_recipient_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_message_id uuid;
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
    'send_message',
    jsonb_build_object(
      'inquiry_id', p_inquiry_id,
      'booking_id', p_booking_id,
      'recipient_id', p_recipient_id
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  -- Insert message
  INSERT INTO booking_messages (
    inquiry_id,
    booking_id,
    sender_id,
    recipient_id,
    message,
    is_read
  ) VALUES (
    p_inquiry_id,
    p_booking_id,
    auth.uid(),
    p_recipient_id,
    p_message,
    false
  ) RETURNING id INTO v_message_id;

  -- Update log with success
  UPDATE brm_logs
  SET 
    status = 'success',
    activity_data = activity_data || jsonb_build_object(
      'message_id', v_message_id
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
$$;

-- Create updated send_message_to_all function
CREATE OR REPLACE FUNCTION send_message_to_all(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_message text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient record;
  v_log_id uuid;
  v_success_count int := 0;
  v_error_count int := 0;
  v_errors text := '';
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
    'send_message_to_all',
    jsonb_build_object(
      'inquiry_id', p_inquiry_id,
      'booking_id', p_booking_id,
      'sender_id', auth.uid()
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  -- Send message to each recipient
  FOR v_recipient IN
    SELECT * FROM get_conversation_recipients(p_inquiry_id, p_booking_id, auth.uid())
  LOOP
    BEGIN
      PERFORM send_thread_message(
        p_inquiry_id,
        p_booking_id,
        p_message,
        v_recipient.recipient_id
      );
      v_success_count := v_success_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
      v_errors := v_errors || E'\n' || 'Error sending to ' || v_recipient.recipient_name || ': ' || SQLERRM;
    END;
  END LOOP;

  -- Update log with results
  UPDATE brm_logs
  SET 
    status = CASE 
      WHEN v_error_count = 0 THEN 'success'
      WHEN v_success_count = 0 THEN 'error'
      ELSE 'partial_success'
    END,
    activity_data = activity_data || jsonb_build_object(
      'success_count', v_success_count,
      'error_count', v_error_count,
      'errors', v_errors
    )
  WHERE id = v_log_id;

  -- Raise exception if no messages were sent
  IF v_success_count = 0 THEN
    RAISE EXCEPTION 'Failed to send message to any recipients: %', v_errors;
  END IF;
END;
$$;

-- Add comments
COMMENT ON FUNCTION send_thread_message IS 'Sends a message in a conversation thread with proper validation and error handling';
COMMENT ON FUNCTION send_message_to_all IS 'Sends a message to all participants in a conversation thread';