/*
  # Update message notifications with proper subjects

  1. Changes
    - Updates on_message_created to set proper email subjects
    - Adds helper function to determine message context
    - Improves email content formatting

  2. Security
    - Maintains existing RLS policies
*/

-- Function to determine message context
CREATE OR REPLACE FUNCTION get_message_context(
  p_inquiry_id uuid,
  p_booking_id uuid
)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    CASE
      WHEN p_inquiry_id IS NOT NULL THEN
        CASE
          WHEN EXISTS (
            SELECT 1 FROM booking_inquiries 
            WHERE id = p_inquiry_id 
            AND status = 'draft'
          ) THEN 'New Inquiry'
          ELSE 'Inquiry Update'
        END
      WHEN p_booking_id IS NOT NULL THEN
        CASE
          WHEN EXISTS (
            SELECT 1 FROM bookings 
            WHERE id = p_booking_id 
            AND created_at > (CURRENT_TIMESTAMP - interval '5 minutes')
          ) THEN 'New Booking'
          ELSE 'Booking Update'
        END
      ELSE 'New Message'
    END;
$$;

-- Update on_message_created function
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
BEGIN
  -- Get email configuration
  SELECT * INTO v_config FROM email_config LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email configuration not found';
  END IF;

  -- Get message context
  v_context := get_message_context(NEW.inquiry_id, NEW.booking_id);

  -- Get reference numbers if available
  IF NEW.inquiry_id IS NOT NULL THEN
    SELECT '#' || substring(id::text, 1, 8) INTO v_inquiry_number
    FROM booking_inquiries
    WHERE id = NEW.inquiry_id;
  END IF;

  IF NEW.booking_id IS NOT NULL THEN
    SELECT '#' || substring(id::text, 1, 8) INTO v_booking_number
    FROM bookings
    WHERE id = NEW.booking_id;
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
    subject,
    text_content,
    html_content,
    next_retry_at
  ) VALUES (
    v_recipient_email,
    v_sender_name,
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
  
  RETURN NEW;
END;
$$;

-- Drop old trigger if it exists
DROP TRIGGER IF EXISTS message_created_trigger ON booking_messages;

-- Create new trigger for messages
CREATE TRIGGER message_created_trigger
AFTER INSERT ON booking_messages
FOR EACH ROW
EXECUTE FUNCTION on_message_created();

-- Add comments
COMMENT ON FUNCTION get_message_context IS 'Determines the context of a message based on inquiry/booking status';
COMMENT ON FUNCTION on_message_created IS 'Queues email notifications for new messages with appropriate subjects';