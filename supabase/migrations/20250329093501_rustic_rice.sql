/*
  # Update Email System Configuration and Logging

  1. Changes
    - Add frontend_url column to email_config table
    - Create brm_logs table for activity logging
    - Update notify_unread_messages function to use frontend_url from config
    - Add logging for email activities

  2. Security
    - Maintains existing RLS policies
    - Adds RLS policies for logs table
*/

-- Add frontend_url to email_config if it doesn't exist
ALTER TABLE email_config 
ADD COLUMN IF NOT EXISTS frontend_url text NOT NULL DEFAULT 'https://brm24.com';

-- Create activity logs table
CREATE TABLE IF NOT EXISTS brm_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_type text NOT NULL,
  activity_data jsonb NOT NULL,
  status text NOT NULL,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

-- Add index for efficient log querying
CREATE INDEX IF NOT EXISTS idx_brm_logs_activity_type_created
ON brm_logs (activity_type, created_at DESC);

-- Enable RLS on logs table
ALTER TABLE brm_logs ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for logs
CREATE POLICY "Administrators can view all logs"
ON brm_logs
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

CREATE POLICY "System can insert logs"
ON brm_logs
FOR INSERT
WITH CHECK (true);

-- Update notify_unread_messages function
CREATE OR REPLACE FUNCTION notify_unread_messages() 
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_notification message_notifications%ROWTYPE;
  v_message booking_messages%ROWTYPE;
  v_sender_name text;
  v_recipient_email text;
  v_config email_config%ROWTYPE;
  v_log_id uuid;
BEGIN
  -- Get email configuration
  v_config := get_email_config();

  -- Get next notification to process
  SELECT * INTO v_notification
  FROM message_notifications
  WHERE status = 'pending'
  AND scheduled_for <= CURRENT_TIMESTAMP
  ORDER BY scheduled_for ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  -- Exit if no notifications to process
  IF v_notification IS NULL THEN
    RETURN;
  END IF;

  -- Create initial log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'email',
    jsonb_build_object(
      'notification_id', v_notification.id,
      'message_id', v_notification.message_id,
      'recipient_id', v_notification.recipient_id
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  -- Get message details
  SELECT * INTO v_message
  FROM booking_messages
  WHERE id = v_notification.message_id;

  -- Only send if message is still unread
  IF v_message.is_read = false THEN
    BEGIN
      -- Get sender name
      SELECT 
        COALESCE(first_name || ' ' || last_name, email) INTO v_sender_name
      FROM profiles
      WHERE user_id = v_message.sender_id;

      -- Get recipient email
      SELECT email INTO v_recipient_email
      FROM auth.users
      WHERE id = v_notification.recipient_id;

      -- Queue email using process_email_queue
      INSERT INTO email_queue (
        to_email,
        to_name,
        subject,
        text_content,
        html_content,
        from_email,
        from_name,
        provider,
        api_key,
        api_secret
      ) VALUES (
        v_recipient_email,
        v_sender_name,
        'New unread message from ' || v_sender_name,
        'You have an unread message from ' || v_sender_name || E'\n\n' ||
        'Message: ' || v_message.message || E'\n\n' ||
        'Click here to view: ' || v_config.frontend_url || '/messages',
        '<p>You have an unread message from <strong>' || v_sender_name || '</strong></p>' ||
        '<p>Message: ' || v_message.message || '</p>' ||
        '<p><a href="' || v_config.frontend_url || '/messages">Click here to view</a></p>',
        v_config.from_email,
        v_config.from_name,
        v_config.provider,
        v_config.api_key,
        v_config.api_secret
      );

      -- Update log entry with success
      UPDATE brm_logs
      SET 
        status = 'success',
        activity_data = activity_data || jsonb_build_object(
          'email_sent', true,
          'recipient_email', v_recipient_email,
          'sender_name', v_sender_name
        )
      WHERE id = v_log_id;

    EXCEPTION WHEN OTHERS THEN
      -- Update log entry with error
      UPDATE brm_logs
      SET 
        status = 'error',
        error_message = SQLERRM,
        activity_data = activity_data || jsonb_build_object(
          'error_details', SQLERRM
        )
      WHERE id = v_log_id;

      RAISE EXCEPTION 'Failed to send email notification: %', SQLERRM;
    END;
  END IF;

  -- Mark notification as sent
  UPDATE message_notifications
  SET 
    status = 'sent',
    updated_at = CURRENT_TIMESTAMP
  WHERE id = v_notification.id;

  -- Update log entry with completion
  UPDATE brm_logs
  SET 
    activity_data = activity_data || jsonb_build_object(
      'notification_status', 'sent',
      'completed_at', CURRENT_TIMESTAMP
    )
  WHERE id = v_log_id;

EXCEPTION WHEN OTHERS THEN
  -- Update log entry with error if it exists
  IF v_log_id IS NOT NULL THEN
    UPDATE brm_logs
    SET 
      status = 'error',
      error_message = SQLERRM,
      activity_data = activity_data || jsonb_build_object(
        'error_details', SQLERRM
      )
    WHERE id = v_log_id;
  END IF;

  -- Mark notification as cancelled
  IF v_notification.id IS NOT NULL THEN
    UPDATE message_notifications
    SET 
      status = 'cancelled',
      updated_at = CURRENT_TIMESTAMP
    WHERE id = v_notification.id;
  END IF;
  
  RAISE NOTICE 'Failed to process notification: %', SQLERRM;
END;
$$;

-- Add comments
COMMENT ON TABLE brm_logs IS 'System-wide activity logging table';
COMMENT ON COLUMN brm_logs.activity_type IS 'Type of activity (e.g., email, notification)';
COMMENT ON COLUMN brm_logs.activity_data IS 'JSON data specific to the activity';
COMMENT ON COLUMN brm_logs.status IS 'Current status of the activity';
COMMENT ON COLUMN brm_logs.error_message IS 'Error message if activity failed';