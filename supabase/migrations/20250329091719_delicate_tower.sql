/*
  # Update Email Configuration System

  1. Changes
    - Updates notify_unread_messages function to use email_config table
    - Adds validation for email configuration
    - Improves error handling for missing configuration
*/

-- Function to get email configuration with validation
CREATE OR REPLACE FUNCTION get_email_config()
RETURNS email_config
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_config email_config%ROWTYPE;
BEGIN
  -- Get email configuration
  SELECT * INTO v_config FROM email_config LIMIT 1;
  
  -- Validate configuration exists
  IF v_config IS NULL THEN
    RAISE EXCEPTION 'Email configuration not found';
  END IF;
  
  -- Validate required fields
  IF v_config.api_key IS NULL OR v_config.api_secret IS NULL THEN
    RAISE EXCEPTION 'Invalid email configuration: missing API credentials';
  END IF;
  
  IF v_config.from_email IS NULL OR v_config.from_name IS NULL THEN
    RAISE EXCEPTION 'Invalid email configuration: missing sender details';
  END IF;
  
  RETURN v_config;
END;
$$;

-- Update notify_unread_messages to use email configuration
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
  v_frontend_url text;
  v_config email_config%ROWTYPE;
BEGIN
  -- Get email configuration
  v_config := get_email_config();

  -- Get frontend URL with fallback
  BEGIN
    v_frontend_url := current_setting('app.frontend_url');
  EXCEPTION WHEN OTHERS THEN
    v_frontend_url := 'https://brm24.com';
  END;

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

  -- Get message details
  SELECT * INTO v_message
  FROM booking_messages
  WHERE id = v_notification.message_id;

  -- Only send if message is still unread
  IF v_message.is_read = false THEN
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
      'Click here to view: ' || v_frontend_url || '/messages',
      '<p>You have an unread message from <strong>' || v_sender_name || '</strong></p>' ||
      '<p>Message: ' || v_message.message || '</p>' ||
      '<p><a href="' || v_frontend_url || '/messages">Click here to view</a></p>',
      v_config.from_email,
      v_config.from_name,
      v_config.provider,
      v_config.api_key,
      v_config.api_secret
    );
  END IF;

  -- Mark notification as sent
  UPDATE message_notifications
  SET 
    status = 'sent',
    updated_at = CURRENT_TIMESTAMP
  WHERE id = v_notification.id;

EXCEPTION WHEN OTHERS THEN
  -- Log error and mark notification as failed
  UPDATE message_notifications
  SET 
    status = 'cancelled',
    updated_at = CURRENT_TIMESTAMP
  WHERE id = v_notification.id;
  
  RAISE NOTICE 'Failed to process notification: %', SQLERRM;
END;
$$;

-- Add columns to email_queue table if they don't exist
DO $$ 
BEGIN
  -- Add provider column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_queue' AND column_name = 'provider') 
  THEN
    ALTER TABLE email_queue ADD COLUMN provider text;
  END IF;

  -- Add from_email column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_queue' AND column_name = 'from_email') 
  THEN
    ALTER TABLE email_queue ADD COLUMN from_email text;
  END IF;

  -- Add from_name column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_queue' AND column_name = 'from_name') 
  THEN
    ALTER TABLE email_queue ADD COLUMN from_name text;
  END IF;

  -- Add api_key column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_queue' AND column_name = 'api_key') 
  THEN
    ALTER TABLE email_queue ADD COLUMN api_key text;
  END IF;

  -- Add api_secret column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_queue' AND column_name = 'api_secret') 
  THEN
    ALTER TABLE email_queue ADD COLUMN api_secret text;
  END IF;
END $$;