/*
  # Add notification email functions

  1. Changes
    - Add on_notification_created function for email notifications
    - Add on_notification_read function to cancel pending emails
    - Add triggers for notification events
    - Add proper error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Function to handle new notifications
CREATE OR REPLACE FUNCTION on_notification_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_config email_config%ROWTYPE;
  v_recipient_email text;
  v_log_id uuid;
BEGIN
  -- Only queue emails for administrator notifications
  IF NOT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = NEW.user_id 
    AND r.name = 'administrator'
  ) THEN
    RETURN NEW;
  END IF;

  -- Get email configuration
  SELECT * INTO v_config FROM email_config LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email configuration not found';
  END IF;

  -- Create initial log entry
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'notification_email',
    jsonb_build_object(
      'notification_id', NEW.id,
      'user_id', NEW.user_id
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  BEGIN
    -- Get recipient email
    SELECT email INTO v_recipient_email
    FROM auth.users
    WHERE id = NEW.user_id;

    -- Queue email
    INSERT INTO email_queue (
      to_email,
      to_name,
      from_email,
      from_name,
      subject,
      text_content,
      html_content,
      next_retry_at
    ) VALUES (
      v_recipient_email,
      'Administrator',
      v_config.from_email,
      v_config.from_name,
      NEW.title,
      NEW.message || E'\n\n' ||
      'Click here to view: ' || v_config.frontend_url || '/notifications',
      '<h2>' || NEW.title || '</h2>' ||
      '<p>' || NEW.message || '</p>' ||
      '<p><a href="' || v_config.frontend_url || '/notifications' || 
      '" style="display: inline-block; padding: 10px 20px; background-color: #059669; color: white; text-decoration: none; border-radius: 6px;">' ||
      'View Notification</a></p>',
      CURRENT_TIMESTAMP + interval '15 minutes'
    );

    -- Update log with success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'recipient_email', v_recipient_email,
        'subject', NEW.title
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
  
  RETURN NEW;
END;
$$;

-- Function to handle read notifications
CREATE OR REPLACE FUNCTION on_notification_read()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Cancel pending email notifications
  UPDATE email_queue
  SET 
    status = 'cancelled',
    updated_at = CURRENT_TIMESTAMP
  WHERE to_email = (
    SELECT email 
    FROM auth.users 
    WHERE id = NEW.user_id
  )
  AND status = 'pending'
  AND next_retry_at > CURRENT_TIMESTAMP;

  -- Log cancellation
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'notification_email',
    jsonb_build_object(
      'notification_id', NEW.id,
      'cancelled_at', CURRENT_TIMESTAMP,
      'reason', 'Notification read'
    ),
    'cancelled'
  );
  
  RETURN NEW;
END;
$$;

-- Create trigger for new notifications
CREATE TRIGGER notification_created_trigger
AFTER INSERT ON notifications
FOR EACH ROW
EXECUTE FUNCTION on_notification_created();

-- Create trigger for read notifications
CREATE TRIGGER notification_read_trigger
AFTER UPDATE OF is_read ON notifications
FOR EACH ROW
WHEN (OLD.is_read = false AND NEW.is_read = true)
EXECUTE FUNCTION on_notification_read();

-- Add comments
COMMENT ON FUNCTION on_notification_created IS 'Queues email notifications for new administrator notifications';
COMMENT ON FUNCTION on_notification_read IS 'Cancels pending email notifications when a notification is read';