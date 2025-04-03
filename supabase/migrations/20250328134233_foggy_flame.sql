/*
  # Email Notifications for Unread Messages

  1. New Tables
    - message_notifications: Tracks scheduled notifications for unread messages
      - id (uuid, primary key)
      - message_id (uuid, references booking_messages)
      - recipient_id (uuid, references auth.users)
      - scheduled_for (timestamptz)
      - status (text: pending, sent, cancelled)
      - created_at (timestamptz)
      - updated_at (timestamptz)

  2. Functions
    - notify_unread_messages(): Processes pending notifications and sends emails
    - schedule_message_notification(): Trigger function to schedule notifications
    - cancel_message_notification(): Trigger function to cancel notifications

  3. Security
    - RLS enabled on message_notifications table
    - Functions run with SECURITY DEFINER
*/

-- Create message notifications table
CREATE TABLE IF NOT EXISTS message_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL REFERENCES booking_messages(id) ON DELETE CASCADE,
  recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  scheduled_for timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add index for efficient notification processing
CREATE INDEX IF NOT EXISTS idx_message_notifications_status_scheduled
ON message_notifications (status, scheduled_for)
WHERE status = 'pending';

-- Function to process and send notifications
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
BEGIN
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
      'Click here to view: ' || current_setting('app.frontend_url') || '/messages',
      '<p>You have an unread message from <strong>' || v_sender_name || '</strong></p>' ||
      '<p>Message: ' || v_message.message || '</p>' ||
      '<p><a href="' || current_setting('app.frontend_url') || '/messages">Click here to view</a></p>'
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

-- Function to schedule notification for new message
CREATE OR REPLACE FUNCTION schedule_message_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Schedule notification for 15 minutes from now
  INSERT INTO message_notifications (
    message_id,
    recipient_id,
    scheduled_for
  ) VALUES (
    NEW.id,
    CASE 
      WHEN NEW.inquiry_id IS NOT NULL THEN
        -- For inquiry messages, notify the other party
        (SELECT CASE 
          WHEN NEW.sender_id = inquiry.trader_id THEN 
            (SELECT user_id FROM user_roles WHERE role_id = (SELECT id FROM roles WHERE name = 'administrator') LIMIT 1)
          ELSE inquiry.trader_id
        END
        FROM booking_inquiries inquiry
        WHERE inquiry.id = NEW.inquiry_id)
      ELSE
        -- For booking messages, notify the other party
        (SELECT CASE 
          WHEN NEW.sender_id = booking.trader_id THEN booking.warehouse_owner_id
          ELSE booking.trader_id
        END
        FROM bookings booking
        WHERE booking.id = NEW.booking_id)
    END,
    CURRENT_TIMESTAMP + interval '15 minutes'
  );
  
  RETURN NEW;
END;
$$;

-- Function to cancel notification when message is read
CREATE OR REPLACE FUNCTION cancel_message_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Cancel pending notification
  UPDATE message_notifications
  SET 
    status = 'cancelled',
    updated_at = CURRENT_TIMESTAMP
  WHERE message_id = NEW.id
  AND status = 'pending';
  
  RETURN NEW;
END;
$$;

-- Trigger for new messages
DROP TRIGGER IF EXISTS message_notification_trigger ON booking_messages;
CREATE TRIGGER message_notification_trigger
AFTER INSERT ON booking_messages
FOR EACH ROW
EXECUTE FUNCTION schedule_message_notification();

-- Trigger for read messages
DROP TRIGGER IF EXISTS message_read_trigger ON booking_messages;
CREATE TRIGGER message_read_trigger
AFTER UPDATE OF is_read ON booking_messages
FOR EACH ROW
WHEN (OLD.is_read = false AND NEW.is_read = true)
EXECUTE FUNCTION cancel_message_notification();

-- Create cron job to process notifications
SELECT cron.schedule(
  'process-message-notifications',
  '* * * * *', -- Run every minute
  $$
  SELECT notify_unread_messages();
  $$
);

-- Enable RLS on message_notifications table
ALTER TABLE message_notifications ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for message_notifications
CREATE POLICY "Users can view their own notifications"
ON message_notifications
FOR SELECT
USING (recipient_id = auth.uid());

CREATE POLICY "System can manage all notifications"
ON message_notifications
FOR ALL
USING (true)
WITH CHECK (true);

-- Add comments
COMMENT ON TABLE message_notifications IS 'Tracks scheduled notifications for unread messages';
COMMENT ON FUNCTION notify_unread_messages IS 'Processes pending notifications and sends emails using process_email_queue';
COMMENT ON FUNCTION schedule_message_notification IS 'Schedules a notification for a new message';
COMMENT ON FUNCTION cancel_message_notification IS 'Cancels pending notification when message is read';