/*
  # Fix Email Notification System

  1. Changes
    - Creates http_header composite type
    - Updates send_email function to use proper HTTP headers
    - Ensures notifications are only sent after 15 minutes
    - Adds proper error handling and logging

  2. Security
    - Maintains existing RLS policies
    - Ensures secure handling of API credentials
*/

-- Create http_header type if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'http_header') THEN
    CREATE TYPE http_header AS (
      field_name text,
      field_value text
    );
  END IF;
END $$;

-- Update send_email function to use proper HTTP headers
CREATE OR REPLACE FUNCTION send_email()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email email_queue%ROWTYPE;
  v_config email_config%ROWTYPE;
  v_url text := 'https://api.mailjet.com/v3.1/send';
  v_payload json;
  v_result json;
  v_max_retries constant integer := 3;
  v_headers http_header[];
BEGIN
  -- Get email configuration
  SELECT * INTO v_config FROM email_config LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email configuration not found';
  END IF;

  -- Get next email to process
  SELECT * INTO v_email
  FROM email_queue
  WHERE status = 'pending'
  AND (next_retry_at IS NULL OR next_retry_at <= CURRENT_TIMESTAMP)
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  -- Exit if no emails to process
  IF v_email IS NULL THEN
    RETURN;
  END IF;

  -- Log attempt
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'email',
    jsonb_build_object(
      'email_id', v_email.id,
      'to_email', v_email.to_email,
      'subject', v_email.subject
    ),
    'processing'
  );

  BEGIN
    -- Prepare email payload
    v_payload := json_build_object(
      'Messages', json_build_array(
        json_build_object(
          'From', json_build_object(
            'Email', v_config.from_email,
            'Name', v_config.from_name
          ),
          'To', json_build_array(
            json_build_object(
              'Email', v_email.to_email,
              'Name', v_email.to_name
            )
          ),
          'Subject', v_email.subject,
          'TextPart', v_email.text_content,
          'HTMLPart', COALESCE(v_email.html_content, v_email.text_content)
        )
      )
    );

    -- Prepare headers
    v_headers := ARRAY[
      ROW('Authorization', 'Basic ' || encode((v_config.api_key || ':' || v_config.api_secret)::bytea, 'base64'))::http_header,
      ROW('Content-Type', 'application/json')::http_header
    ];

    -- Send email using Mailjet API
    SELECT content INTO v_result
    FROM http((
      'POST',
      v_url,
      v_headers,
      'application/json',
      v_payload::text
    ));

    -- Mark email as sent
    UPDATE email_queue
    SET 
      status = 'sent',
      updated_at = CURRENT_TIMESTAMP
    WHERE id = v_email.id;

    -- Log success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'sent_at', CURRENT_TIMESTAMP
      )
    WHERE activity_type = 'email' 
    AND (activity_data->>'email_id')::uuid = v_email.id;

  EXCEPTION WHEN OTHERS THEN
    -- Handle error
    IF v_email.retry_count >= v_max_retries THEN
      -- Mark as failed after max retries
      UPDATE email_queue
      SET
        status = 'failed',
        error_message = SQLERRM,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = v_email.id;

      -- Log failure
      UPDATE brm_logs
      SET 
        status = 'error',
        error_message = SQLERRM,
        activity_data = activity_data || jsonb_build_object(
          'failed_at', CURRENT_TIMESTAMP,
          'retry_count', v_email.retry_count
        )
      WHERE activity_type = 'email' 
      AND (activity_data->>'email_id')::uuid = v_email.id;
    ELSE
      -- Schedule retry with exponential backoff
      UPDATE email_queue
      SET
        retry_count = retry_count + 1,
        next_retry_at = CURRENT_TIMESTAMP + (power(2, retry_count) * interval '1 minute'),
        error_message = SQLERRM,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = v_email.id;

      -- Log retry
      UPDATE brm_logs
      SET 
        status = 'retrying',
        error_message = SQLERRM,
        activity_data = activity_data || jsonb_build_object(
          'retry_count', v_email.retry_count + 1,
          'next_retry', CURRENT_TIMESTAMP + (power(2, v_email.retry_count) * interval '1 minute')
        )
      WHERE activity_type = 'email' 
      AND (activity_data->>'email_id')::uuid = v_email.id;
    END IF;
  END;
END;
$$;

-- Update message notification trigger to only queue after 15 minutes
CREATE OR REPLACE FUNCTION on_message_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recipient_id uuid;
  v_config email_config%ROWTYPE;
  v_sender_name text;
  v_recipient_email text;
BEGIN
  -- Get email configuration
  SELECT * INTO v_config FROM email_config LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email configuration not found';
  END IF;

  -- Determine recipient
  SELECT
    CASE 
      WHEN NEW.inquiry_id IS NOT NULL THEN
        CASE 
          WHEN NEW.sender_id = inquiry.trader_id THEN 
            (SELECT user_id FROM user_roles WHERE role_id = (SELECT id FROM roles WHERE name = 'administrator') LIMIT 1)
          ELSE inquiry.trader_id
        END
      ELSE
        CASE 
          WHEN NEW.sender_id = booking.trader_id THEN booking.warehouse_owner_id
          ELSE booking.trader_id
        END
    END INTO v_recipient_id
  FROM booking_inquiries inquiry
  LEFT JOIN bookings booking ON booking.id = NEW.booking_id
  WHERE inquiry.id = NEW.inquiry_id
  OR booking.id = NEW.booking_id;

  -- Get sender name
  SELECT 
    COALESCE(first_name || ' ' || last_name, email) INTO v_sender_name
  FROM profiles
  WHERE user_id = NEW.sender_id;

  -- Get recipient email
  SELECT email INTO v_recipient_email
  FROM auth.users
  WHERE id = v_recipient_id;

  -- Schedule email for 15 minutes later
  INSERT INTO email_queue (
    to_email,
    to_name,
    subject,
    text_content,
    html_content,
    next_retry_at -- Use this for scheduling
  ) VALUES (
    v_recipient_email,
    v_sender_name,
    'Unread message from ' || v_sender_name,
    'You have an unread message from ' || v_sender_name || E'\n\n' ||
    'Message: ' || NEW.message || E'\n\n' ||
    'Click here to view: ' || v_config.frontend_url || '/messages',
    '<p>You have an unread message from <strong>' || v_sender_name || '</strong></p>' ||
    '<p>Message: ' || NEW.message || '</p>' ||
    '<p><a href="' || v_config.frontend_url || '/messages">Click here to view</a></p>',
    CURRENT_TIMESTAMP + interval '15 minutes'
  );
  
  RETURN NEW;
END;
$$;

-- Update trigger to cancel email if message is read
CREATE OR REPLACE FUNCTION on_message_read()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Cancel pending email notifications for this message
  UPDATE email_queue
  SET 
    status = 'cancelled',
    updated_at = CURRENT_TIMESTAMP
  WHERE to_email = (
    SELECT email 
    FROM auth.users 
    WHERE id = NEW.sender_id
  )
  AND status = 'pending'
  AND next_retry_at > CURRENT_TIMESTAMP;

  -- Log cancellation
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'email',
    jsonb_build_object(
      'message_id', NEW.id,
      'cancelled_at', CURRENT_TIMESTAMP,
      'reason', 'Message read'
    ),
    'cancelled'
  );
  
  RETURN NEW;
END;
$$;

-- Drop old trigger if it exists
DROP TRIGGER IF EXISTS message_read_trigger ON booking_messages;

-- Create new trigger for read messages
CREATE TRIGGER message_read_trigger
AFTER UPDATE OF is_read ON booking_messages
FOR EACH ROW
WHEN (OLD.is_read = false AND NEW.is_read = true)
EXECUTE FUNCTION on_message_read();

-- Add comments
COMMENT ON FUNCTION send_email IS 'Processes pending emails in the queue and sends them via Mailjet';
COMMENT ON FUNCTION on_message_created IS 'Schedules email notification for unread messages after 15 minutes';
COMMENT ON FUNCTION on_message_read IS 'Cancels pending email notifications when a message is read';