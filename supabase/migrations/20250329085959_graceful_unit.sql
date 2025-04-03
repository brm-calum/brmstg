/*
  # Add Frontend URL Configuration

  1. Changes
    - Adds app.frontend_url configuration parameter
    - Updates notify_unread_messages function to use environment variable
*/

-- Set the frontend URL configuration
ALTER DATABASE postgres SET app.frontend_url = 'https://brm24.com';

-- Update the notify_unread_messages function to handle missing frontend URL
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
BEGIN
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
      html_content
    ) VALUES (
      v_recipient_email,
      v_sender_name,
      'New unread message from ' || v_sender_name,
      'You have an unread message from ' || v_sender_name || E'\n\n' ||
      'Message: ' || v_message.message || E'\n\n' ||
      'Click here to view: ' || v_frontend_url || '/messages',
      '<p>You have an unread message from <strong>' || v_sender_name || '</strong></p>' ||
      '<p>Message: ' || v_message.message || '</p>' ||
      '<p><a href="' || v_frontend_url || '/messages">Click here to view</a></p>'
    );
  END IF;

  -- Mark notification as sent
  UPDATE message_notifications
  SET 
    status = 'sent',
    updated_at = CURRENT_TIMESTAMP
  WHERE id = v_notification.id;
END;
$$;