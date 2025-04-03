-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS process_email_queue CASCADE;
DROP FUNCTION IF EXISTS notify_unread_messages CASCADE;
DROP FUNCTION IF EXISTS schedule_message_notification CASCADE;
DROP FUNCTION IF EXISTS cancel_message_notification CASCADE;

-- Create simplified email queue table
CREATE TABLE IF NOT EXISTS email_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  to_email text NOT NULL,
  to_name text,
  subject text NOT NULL,
  text_content text NOT NULL,
  html_content text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  retry_count integer NOT NULL DEFAULT 0,
  next_retry_at timestamptz,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create function to send email
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

    -- Send email using Mailjet API
    SELECT content INTO v_result
    FROM http((
      'POST',
      v_url,
      ARRAY[
        ('Authorization', 'Basic ' || encode(
          (v_config.api_key || ':' || v_config.api_secret)::bytea,
          'base64'
        ))::http_header,
        ('Content-Type', 'application/json')::http_header
      ],
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

-- Create function to queue message notification
CREATE OR REPLACE FUNCTION queue_message_notification(
  p_message_id uuid,
  p_recipient_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_message booking_messages%ROWTYPE;
  v_sender_name text;
  v_recipient_email text;
  v_config email_config%ROWTYPE;
BEGIN
  -- Get message details
  SELECT * INTO v_message
  FROM booking_messages
  WHERE id = p_message_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Message not found';
  END IF;

  -- Get email configuration
  SELECT * INTO v_config FROM email_config LIMIT 1;

  -- Get sender name
  SELECT 
    COALESCE(first_name || ' ' || last_name, email) INTO v_sender_name
  FROM profiles
  WHERE user_id = v_message.sender_id;

  -- Get recipient email
  SELECT email INTO v_recipient_email
  FROM auth.users
  WHERE id = p_recipient_id;

  -- Queue email
  INSERT INTO email_queue (
    to_email,
    to_name,
    subject,
    text_content,
    html_content
  ) VALUES (
    v_recipient_email,
    v_sender_name,
    'New message from ' || v_sender_name,
    'You have a new message from ' || v_sender_name || E'\n\n' ||
    'Message: ' || v_message.message || E'\n\n' ||
    'Click here to view: ' || v_config.frontend_url || '/messages',
    '<p>You have a new message from <strong>' || v_sender_name || '</strong></p>' ||
    '<p>Message: ' || v_message.message || '</p>' ||
    '<p><a href="' || v_config.frontend_url || '/messages">Click here to view</a></p>'
  );
END;
$$;

-- Create trigger for new messages
CREATE OR REPLACE FUNCTION on_message_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_recipient_id uuid;
BEGIN
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

  -- Queue notification
  PERFORM queue_message_notification(NEW.id, v_recipient_id);
  
  RETURN NEW;
END;
$$;

-- Create trigger for new messages
DROP TRIGGER IF EXISTS message_created_trigger ON booking_messages;
CREATE TRIGGER message_created_trigger
AFTER INSERT ON booking_messages
FOR EACH ROW
EXECUTE FUNCTION on_message_created();

-- Create cron job to process emails
SELECT cron.schedule(
  'process-emails',
  '* * * * *',  -- Every minute
  $$
  SELECT send_email();
  $$
);

-- Enable RLS on email_queue
ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for email_queue
CREATE POLICY "Administrators can view all emails"
ON email_queue
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

CREATE POLICY "System can manage all emails"
ON email_queue
FOR ALL
USING (true)
WITH CHECK (true);

-- Add comments
COMMENT ON FUNCTION send_email IS 'Processes pending emails in the queue and sends them via Mailjet';
COMMENT ON FUNCTION queue_message_notification IS 'Queues an email notification for a message';
COMMENT ON FUNCTION on_message_created IS 'Trigger function to queue notifications for new messages';