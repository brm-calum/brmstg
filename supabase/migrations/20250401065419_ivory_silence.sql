/*
  # Add function to send message to all participants

  1. Changes
    - Add function to send message to all conversation participants
    - Maintain existing send_thread_message function for direct messages
    - Add proper validation and error handling

  2. Security
    - Maintains existing RLS policies
*/

-- Function to send message to all conversation participants
CREATE OR REPLACE FUNCTION send_message_to_all(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_message text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_recipient record;
  v_result text;
  v_success_count int := 0;
  v_error_count int := 0;
  v_errors text := '';
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

  -- Send message to each recipient
  FOR v_recipient IN
    SELECT * FROM get_conversation_recipients(p_inquiry_id, p_booking_id, auth.uid())
  LOOP
    BEGIN
      SELECT send_thread_message(
        p_inquiry_id,
        p_booking_id,
        p_message,
        v_recipient.recipient_id
      ) INTO v_result;

      IF v_result = 'Message sent successfully' THEN
        v_success_count := v_success_count + 1;
      ELSE
        v_error_count := v_error_count + 1;
        v_errors := v_errors || E'\n' || 'Failed to send to ' || v_recipient.recipient_name || ': ' || v_result;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
      v_errors := v_errors || E'\n' || 'Error sending to ' || v_recipient.recipient_name || ': ' || SQLERRM;
    END;
  END LOOP;

  -- Return summary
  IF v_error_count = 0 THEN
    RETURN 'Message sent successfully to ' || v_success_count || ' recipient(s)';
  ELSE
    RETURN 'Message sent to ' || v_success_count || ' recipient(s) with ' || v_error_count || ' error(s):' || v_errors;
  END IF;
END;
$$;

-- Add comments
COMMENT ON FUNCTION send_message_to_all IS 'Sends a message to all participants in a conversation thread';