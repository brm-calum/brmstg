/*
  # Update message notifications to handle multiple recipients

  1. Changes
    - Add function to get conversation recipients
    - Update on_message_created to send notifications to all recipients except sender
    - Add proper error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Function to get conversation recipients
CREATE OR REPLACE FUNCTION get_conversation_recipients(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_sender_id uuid
)
RETURNS TABLE (
  recipient_id uuid,
  recipient_email text,
  recipient_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- For inquiries
  IF p_inquiry_id IS NOT NULL THEN
    -- Return trader and admin (except sender)
    RETURN QUERY
    SELECT 
      u.id as recipient_id,
      u.email as recipient_email,
      COALESCE(p.first_name || ' ' || p.last_name, u.email) as recipient_name
    FROM booking_inquiries bi
    -- Get trader
    JOIN auth.users u ON u.id = bi.trader_id
    LEFT JOIN profiles p ON p.user_id = u.id
    WHERE bi.id = p_inquiry_id
    AND bi.trader_id != p_sender_id
    UNION
    -- Get admin
    SELECT 
      u.id,
      u.email,
      COALESCE(p.first_name || ' ' || p.last_name, u.email)
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    JOIN auth.users u ON u.id = ur.user_id
    LEFT JOIN profiles p ON p.user_id = u.id
    WHERE r.name = 'administrator'
    AND ur.user_id != p_sender_id
    LIMIT 1;

  -- For bookings
  ELSIF p_booking_id IS NOT NULL THEN
    -- Return trader and warehouse owner (except sender)
    RETURN QUERY
    SELECT 
      u.id as recipient_id,
      u.email as recipient_email,
      COALESCE(p.first_name || ' ' || p.last_name, u.email) as recipient_name
    FROM bookings b
    -- Get both trader and warehouse owner
    LEFT JOIN auth.users u ON u.id IN (b.trader_id, b.warehouse_owner_id)
    LEFT JOIN profiles p ON p.user_id = u.id
    WHERE b.id = p_booking_id
    AND u.id != p_sender_id;
  END IF;
END;
$$;

-- Update on_message_created function
CREATE OR REPLACE FUNCTION on_message_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_config email_config%ROWTYPE;
  v_sender_name text;
  v_context text;
  v_subject text;
  v_inquiry_number text;
  v_booking_number text;
  v_inquiry_info jsonb;
  v_booking_info jsonb;
  v_log_id uuid;
  v_link_path text;
  v_link_text text;
  v_recipient record;
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
      'booking_id', NEW.booking_id,
      'sender_id', NEW.sender_id
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
          'status', status,
          'created_at', created_at
        ) INTO v_inquiry_info
      FROM booking_inquiries
      WHERE id = NEW.inquiry_id;

      v_inquiry_number := '#' || substring(NEW.inquiry_id::text, 1, 8);
      v_link_path := '/inquiries/' || NEW.inquiry_id;
      v_link_text := 'View Inquiry ' || v_inquiry_number;
      
      v_context := CASE
        WHEN v_inquiry_info->>'status' = 'draft' THEN 'New Inquiry'
        ELSE 'Inquiry Update'
      END;
    END IF;

    IF NEW.booking_id IS NOT NULL THEN
      SELECT 
        jsonb_build_object(
          'id', id,
          'trader_id', trader_id,
          'warehouse_owner_id', warehouse_owner_id,
          'status', status,
          'created_at', created_at
        ) INTO v_booking_info
      FROM bookings
      WHERE id = NEW.booking_id;

      v_booking_number := '#' || substring(NEW.booking_id::text, 1, 8);
      v_link_path := '/bookings/' || NEW.booking_id;
      v_link_text := 'View Booking ' || v_booking_number;
      
      v_context := CASE
        WHEN v_booking_info->>'status' = 'active' AND 
             (v_booking_info->>'created_at')::timestamptz > (CURRENT_TIMESTAMP - interval '5 minutes')
        THEN 'New Booking'
        ELSE 'Booking Update'
      END;
    ELSE
      v_context := 'New Message';
      v_link_path := '/messages';
      v_link_text := 'View Messages';
    END IF;

    -- Get sender name
    SELECT 
      COALESCE(first_name || ' ' || last_name, email) INTO v_sender_name
    FROM profiles
    WHERE user_id = NEW.sender_id;

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

    -- Queue email for each recipient
    FOR v_recipient IN
      SELECT * FROM get_conversation_recipients(NEW.inquiry_id, NEW.booking_id, NEW.sender_id)
    LOOP
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
        v_recipient.recipient_email,
        v_recipient.recipient_name,
        v_config.from_email,
        v_config.from_name,
        v_subject,
        v_context || E' from ' || v_sender_name || E'\n\n' ||
        'Message: ' || NEW.message || E'\n\n' ||
        v_link_text || ': ' || v_config.frontend_url || v_link_path,
        '<h2>' || v_context || ' from ' || v_sender_name || '</h2>' ||
        '<p><strong>Message:</strong> ' || NEW.message || '</p>' ||
        '<p><a href="' || v_config.frontend_url || v_link_path || 
        '" style="display: inline-block; padding: 10px 20px; background-color: #059669; color: white; text-decoration: none; border-radius: 6px;">' ||
        v_link_text || '</a></p>',
        CURRENT_TIMESTAMP + interval '15 minutes'
      );
    END LOOP;

    -- Update log with success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'context', v_context,
        'subject', v_subject,
        'link_path', v_link_path,
        'recipients', (
          SELECT json_agg(json_build_object(
            'id', recipient_id,
            'email', recipient_email,
            'name', recipient_name
          ))
          FROM get_conversation_recipients(NEW.inquiry_id, NEW.booking_id, NEW.sender_id)
        )
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS message_created_trigger ON booking_messages;

-- Create trigger for new messages
CREATE TRIGGER message_created_trigger
AFTER INSERT ON booking_messages
FOR EACH ROW
EXECUTE FUNCTION on_message_created();

-- Add comments
COMMENT ON FUNCTION get_conversation_recipients IS 'Gets all recipients for a conversation except the sender';
COMMENT ON FUNCTION on_message_created IS 'Queues email notifications for all conversation recipients except the sender';