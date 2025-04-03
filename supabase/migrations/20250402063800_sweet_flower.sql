/*
  # Fix send_message_to_all function

  1. Changes
    - Update send_message_to_all function to properly handle conversation_id
    - Fix foreign key constraint violation for booking_messages
    - Improve error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS send_message_to_all;

-- Create updated function
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
  v_conversation_id uuid;
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
    'send_message_to_all',
    jsonb_build_object(
      'inquiry_id', p_inquiry_id,
      'booking_id', p_booking_id,
      'sender_id', auth.uid()
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

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
      'message_id', v_message_id,
      'conversation_id', v_conversation_id
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

-- Add comments
COMMENT ON FUNCTION send_message_to_all IS 'Sends a message to all participants in a conversation thread using the conversation system';