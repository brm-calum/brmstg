/*
  # Fix email notifications

  1. Changes
    - Updates email_queue table to include missing columns
    - Fixes on_message_created function to handle missing data
    - Improves error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Add missing columns to email_queue if they don't exist
DO $$ 
BEGIN
  -- Add to_name column
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_queue' AND column_name = 'to_name') 
  THEN
    ALTER TABLE email_queue ADD COLUMN to_name text;
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
END $$;

-- Drop existing function
DROP FUNCTION IF EXISTS on_message_created();

-- Create updated function
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
  v_context text;
  v_subject text;
  v_inquiry_number text;
  v_booking_number text;
  v_inquiry_info jsonb;
  v_booking_info jsonb;
  v_log_id uuid;
BEGIN
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
    'message_notification',
    jsonb_build_object(
      'message_id', NEW.id,
      'inquiry_id', NEW.inquiry_id,
      'booking_id', NEW.booking_id
    ),
    'processing'
  ) RETURNING id INTO v_log_id;

  BEGIN
    -- Get inquiry/booking info
    IF NEW.inquiry_id IS NOT NULL THEN
      SELECT 
        jsonb_build_object(
          'id', id,
          'trader_id', trader_id,
          'status', status
        ) INTO v_inquiry_info
      FROM booking_inquiries
      WHERE id = NEW.inquiry_id;

      v_inquiry_number := '#' || substring(NEW.inquiry_id::text, 1, 8);
    END IF;

    IF NEW.booking_id IS NOT NULL THEN
      SELECT 
        jsonb_build_object(
          'id', id,
          'trader_id', trader_id,
          'warehouse_owner_id', warehouse_owner_id,
          'status', status
        ) INTO v_booking_info
      FROM bookings
      WHERE id = NEW.booking_id;

      v_booking_number := '#' || substring(NEW.booking_id::text, 1, 8);
    END IF;

    -- Get sender name
    SELECT 
      COALESCE(first_name || ' ' || last_name, email) INTO v_sender_name
    FROM profiles
    WHERE user_id = NEW.sender_id;

    -- Determine recipient and context
    IF NEW.inquiry_id IS NOT NULL THEN
      -- For inquiries
      v_recipient_id := CASE 
        WHEN NEW.sender_id = (v_inquiry_info->>'trader_id')::uuid THEN
          -- If sender is trader, recipient is admin
          (SELECT user_id FROM user_roles WHERE role_id = (SELECT id FROM roles WHERE name = 'administrator') LIMIT 1)
        ELSE 
          -- Otherwise recipient is trader
          (v_inquiry_info->>'trader_id')::uuid
      END;

      v_context := CASE
        WHEN v_inquiry_info->>'status' = 'draft' THEN 'New Inquiry'
        ELSE 'Inquiry Update'
      END;
    ELSIF NEW.booking_id IS NOT NULL THEN
      -- For bookings
      v_recipient_id := CASE
        WHEN NEW.sender_id = (v_booking_info->>'trader_id')::uuid THEN
          -- If sender is trader, recipient is warehouse owner
          (v_booking_info->>'warehouse_owner_id')::uuid
        ELSE
          -- Otherwise recipient is trader
          (v_booking_info->>'trader_id')::uuid
      END;

      v_context := CASE
        WHEN v_booking_info->>'status' = 'active' AND 
             (v_booking_info->>'created_at')::timestamptz > (CURRENT_TIMESTAMP - interval '5 minutes')
        THEN 'New Booking'
        ELSE 'Booking Update'
      END;
    ELSE
      v_context := 'New Message';
    END IF;

    -- Get recipient email
    SELECT email INTO v_recipient_email
    FROM auth.users
    WHERE id = v_recipient_id;

    -- Build subject line
    v_subject := CASE
      WHEN v_context = 'New Inquiry' THEN 
        'New Inquiry ' || COALESCE(v_inquiry_number, '') || ' from ' || v_sender_name
      WHEN v_context = 'Inquiry Update' THEN 
        'New Message for Inquiry ' || COALESCE(v_inquiry_number, '') || ' from ' || v_sender_name
      WHEN v_context = 'New Booking' THEN 
        'New Booking ' || COALESCE(v_booking_number, '') || ' from ' || v_sender_name
      WHEN v_context = 'Booking Update' THEN 
        'New Message for Booking ' || COALESCE(v_booking_number, '') || ' from ' || v_sender_name
      ELSE 'New Message from ' || v_sender_name
    END;

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
      v_sender_name,
      v_config.from_email,
      v_config.from_name,
      v_subject,
      v_context || E' from ' || v_sender_name || E'\n\n' ||
      'Message: ' || NEW.message || E'\n\n' ||
      'Click here to view: ' || v_config.frontend_url || 
      CASE 
        WHEN NEW.inquiry_id IS NOT NULL THEN '/inquiries/' || NEW.inquiry_id
        WHEN NEW.booking_id IS NOT NULL THEN '/bookings/' || NEW.booking_id
        ELSE '/messages'
      END,
      '<h2>' || v_context || ' from ' || v_sender_name || '</h2>' ||
      '<p><strong>Message:</strong> ' || NEW.message || '</p>' ||
      '<p><a href="' || v_config.frontend_url || 
      CASE 
        WHEN NEW.inquiry_id IS NOT NULL THEN '/inquiries/' || NEW.inquiry_id
        WHEN NEW.booking_id IS NOT NULL THEN '/bookings/' || NEW.booking_id
        ELSE '/messages'
      END || 
      '">Click here to view</a></p>',
      CURRENT_TIMESTAMP + interval '15 minutes'
    );

    -- Update log with success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'context', v_context,
        'recipient_email', v_recipient_email,
        'subject', v_subject
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

-- Create trigger for new messages
CREATE TRIGGER message_created_trigger
AFTER INSERT ON booking_messages
FOR EACH ROW
EXECUTE FUNCTION on_message_created();

-- Add comments
COMMENT ON FUNCTION on_message_created IS 'Queues email notifications for new messages with appropriate subjects';