/*
  # Fix send_thread_message function

  1. Changes
    - Update send_thread_message function to properly handle return type
    - Add proper validation for message parameters
    - Improve error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS send_thread_message;

-- Create updated function
CREATE OR REPLACE FUNCTION send_thread_message(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_message text,
  p_recipient_id uuid
)
RETURNS text
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
    RETURN 'Message cannot be empty';
  END IF;

  IF p_inquiry_id IS NULL AND p_booking_id IS NULL THEN
    RETURN 'Either inquiry_id or booking_id must be provided';
  END IF;

  IF p_inquiry_id IS NOT NULL AND p_booking_id IS NOT NULL THEN
    RETURN 'Cannot specify both inquiry_id and booking_id';
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

  RETURN 'Message sent successfully';

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

  RETURN 'Failed to send message: ' || SQLERRM;
END;
$$;

-- Add comments
COMMENT ON FUNCTION send_thread_message IS 'Sends a message in a conversation thread with proper validation and error handling';