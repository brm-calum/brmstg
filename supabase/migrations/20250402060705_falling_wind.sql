/*
  # Redesign Message System for Conversations

  1. New Tables
    - `message_conversations`: Stores conversation metadata
    - `message_participants`: Tracks participants in each conversation
    - `message_read_status`: Tracks read status per user per message

  2. Changes
    - Modify booking_messages to use conversation-based model
    - Update message sending and reading functions
    - Fix email notification system
    - Correct unread count calculation

  3. Security
    - Add RLS policies for new tables
    - Maintain existing security for messages
*/

-- Create conversation table
CREATE TABLE message_conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  inquiry_id uuid REFERENCES booking_inquiries(id) ON DELETE CASCADE,
  booking_id uuid REFERENCES bookings(id) ON DELETE CASCADE,
  title text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conversation_reference CHECK (
    (inquiry_id IS NOT NULL AND booking_id IS NULL) OR
    (inquiry_id IS NULL AND booking_id IS NOT NULL)
  )
);

-- Create participants table
CREATE TABLE message_participants (
  conversation_id uuid NOT NULL REFERENCES message_conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('trader', 'warehouse_owner', 'administrator')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

-- Create read status table
CREATE TABLE message_read_status (
  message_id uuid NOT NULL REFERENCES booking_messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamptz,
  PRIMARY KEY (message_id, user_id)
);

-- Add conversation_id to booking_messages
ALTER TABLE booking_messages
ADD COLUMN conversation_id uuid REFERENCES message_conversations(id) ON DELETE CASCADE;

-- Create index for faster lookups
CREATE INDEX idx_booking_messages_conversation
ON booking_messages (conversation_id, created_at);

CREATE INDEX idx_message_read_status_user
ON message_read_status (user_id, is_read);

-- Enable RLS on new tables
ALTER TABLE message_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_read_status ENABLE ROW LEVEL SECURITY;

-- Add RLS policies
CREATE POLICY "Users can view conversations they participate in"
ON message_conversations
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM message_participants
    WHERE conversation_id = id
    AND user_id = auth.uid()
  )
);

CREATE POLICY "Users can view their participation"
ON message_participants
FOR SELECT
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM message_participants mp
    WHERE mp.conversation_id = conversation_id
    AND mp.user_id = auth.uid()
  )
);

CREATE POLICY "Users can view their read status"
ON message_read_status
FOR SELECT
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM booking_messages bm
    JOIN message_conversations mc ON mc.id = bm.conversation_id
    JOIN message_participants mp ON mp.conversation_id = mc.id
    WHERE bm.id = message_id
    AND mp.user_id = auth.uid()
  )
);

CREATE POLICY "Users can update their own read status"
ON message_read_status
FOR UPDATE
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Function to get or create a conversation
CREATE OR REPLACE FUNCTION get_or_create_conversation(
  p_inquiry_id uuid,
  p_booking_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
  v_trader_id uuid;
  v_warehouse_owner_id uuid;
  v_admin_id uuid;
BEGIN
  -- Validate input
  IF p_inquiry_id IS NULL AND p_booking_id IS NULL THEN
    RAISE EXCEPTION 'Either inquiry_id or booking_id must be provided';
  END IF;

  IF p_inquiry_id IS NOT NULL AND p_booking_id IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot specify both inquiry_id and booking_id';
  END IF;

  -- Check if conversation already exists
  IF p_inquiry_id IS NOT NULL THEN
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE inquiry_id = p_inquiry_id;
  ELSE
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE booking_id = p_booking_id;
  END IF;

  -- If conversation exists, return it
  IF v_conversation_id IS NOT NULL THEN
    RETURN v_conversation_id;
  END IF;

  -- Get participant IDs
  IF p_inquiry_id IS NOT NULL THEN
    -- Get trader ID
    SELECT trader_id INTO v_trader_id
    FROM booking_inquiries
    WHERE id = p_inquiry_id;
    
    -- Get admin ID (first administrator found)
    SELECT user_id INTO v_admin_id
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE r.name = 'administrator'
    LIMIT 1;
  ELSE
    -- Get trader and warehouse owner IDs
    SELECT trader_id, warehouse_owner_id INTO v_trader_id, v_warehouse_owner_id
    FROM bookings
    WHERE id = p_booking_id;
    
    -- Get admin ID (first administrator found)
    SELECT user_id INTO v_admin_id
    FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE r.name = 'administrator'
    LIMIT 1;
  END IF;

  -- Create new conversation
  INSERT INTO message_conversations (
    inquiry_id,
    booking_id,
    title,
    updated_at
  ) VALUES (
    p_inquiry_id,
    p_booking_id,
    CASE
      WHEN p_inquiry_id IS NOT NULL THEN 'Inquiry #' || substring(p_inquiry_id::text, 1, 8)
      ELSE 'Booking #' || substring(p_booking_id::text, 1, 8)
    END,
    now()
  ) RETURNING id INTO v_conversation_id;

  -- Add participants
  -- Add trader
  INSERT INTO message_participants (
    conversation_id,
    user_id,
    role
  ) VALUES (
    v_conversation_id,
    v_trader_id,
    'trader'
  );

  -- Add warehouse owner if booking
  IF v_warehouse_owner_id IS NOT NULL THEN
    INSERT INTO message_participants (
      conversation_id,
      user_id,
      role
    ) VALUES (
      v_conversation_id,
      v_warehouse_owner_id,
      'warehouse_owner'
    );
  END IF;

  -- Add admin
  IF v_admin_id IS NOT NULL THEN
    INSERT INTO message_participants (
      conversation_id,
      user_id,
      role
    ) VALUES (
      v_conversation_id,
      v_admin_id,
      'administrator'
    );
  END IF;

  RETURN v_conversation_id;
END;
$$;

-- Function to send a message to a conversation
CREATE OR REPLACE FUNCTION send_conversation_message(
  p_inquiry_id uuid,
  p_booking_id uuid,
  p_message text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
  v_message_id uuid;
  v_participant record;
BEGIN
  -- Validate input
  IF p_message IS NULL OR trim(p_message) = '' THEN
    RAISE EXCEPTION 'Message cannot be empty';
  END IF;

  -- Get or create conversation
  v_conversation_id := get_or_create_conversation(p_inquiry_id, p_booking_id);

  -- Update conversation timestamp
  UPDATE message_conversations
  SET updated_at = now()
  WHERE id = v_conversation_id;

  -- Insert message
  INSERT INTO booking_messages (
    inquiry_id,
    booking_id,
    sender_id,
    message,
    conversation_id
  ) VALUES (
    p_inquiry_id,
    p_booking_id,
    auth.uid(),
    p_message,
    v_conversation_id
  ) RETURNING id INTO v_message_id;

  -- Create read status entries for all participants
  FOR v_participant IN
    SELECT user_id
    FROM message_participants
    WHERE conversation_id = v_conversation_id
  LOOP
    INSERT INTO message_read_status (
      message_id,
      user_id,
      is_read,
      read_at
    ) VALUES (
      v_message_id,
      v_participant.user_id,
      -- Mark as read for sender, unread for others
      v_participant.user_id = auth.uid(),
      CASE WHEN v_participant.user_id = auth.uid() THEN now() ELSE NULL END
    );
  END LOOP;

  RETURN v_message_id;
END;
$$;

-- Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_read(
  p_message_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update read status for current user
  UPDATE message_read_status
  SET 
    is_read = true,
    read_at = now()
  WHERE message_id = ANY(p_message_ids)
  AND user_id = auth.uid()
  AND is_read = false;
END;
$$;

-- Function to get unread message count
CREATE OR REPLACE FUNCTION get_unread_message_count(
  p_user_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*)::integer INTO v_count
  FROM message_read_status mrs
  WHERE mrs.user_id = p_user_id
  AND mrs.is_read = false;
  
  RETURN v_count;
END;
$$;

-- Function to get user threads
DROP FUNCTION get_user_threads();
CREATE OR REPLACE FUNCTION get_user_threads()
RETURNS TABLE (
  thread_id uuid,
  thread_type text,
  thread_info jsonb,
  last_message_at timestamptz,
  unread_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    mc.id as thread_id,
    CASE
      WHEN mc.inquiry_id IS NOT NULL THEN 'inquiry'
      ELSE 'booking'
    END as thread_type,
    CASE
      WHEN mc.inquiry_id IS NOT NULL THEN
        jsonb_build_object(
          'id', mc.inquiry_id,
          'status', bi.status,
          'warehouses', (
            SELECT jsonb_agg(jsonb_build_object('name', mw.name))
            FROM booking_inquiry_warehouses biw
            JOIN m_warehouses mw ON mw.id = biw.warehouse_id
            WHERE biw.inquiry_id = mc.inquiry_id
          )
        )
      ELSE
        jsonb_build_object(
          'id', mc.booking_id,
          'status', b.status,
          'warehouse', jsonb_build_object('name', mw.name)
        )
    END as thread_info,
    COALESCE(
      (SELECT MAX(created_at)
       FROM booking_messages
       WHERE conversation_id = mc.id),
      mc.created_at
    ) as last_message_at,
    (SELECT COUNT(*)
     FROM booking_messages bm
     JOIN message_read_status mrs ON mrs.message_id = bm.id
     WHERE bm.conversation_id = mc.id
     AND mrs.user_id = auth.uid()
     AND mrs.is_read = false) as unread_count
  FROM message_conversations mc
  JOIN message_participants mp ON mp.conversation_id = mc.id
  LEFT JOIN booking_inquiries bi ON bi.id = mc.inquiry_id
  LEFT JOIN bookings b ON b.id = mc.booking_id
  LEFT JOIN m_warehouses mw ON mw.id = b.warehouse_id
  WHERE mp.user_id = auth.uid()
  ORDER BY last_message_at DESC;
END;
$$;

-- Function to get thread messages
DROP FUNCTION get_thread_messages(uuid,uuid);
CREATE OR REPLACE FUNCTION get_thread_messages(
  p_inquiry_id uuid,
  p_booking_id uuid
)
RETURNS TABLE (
  id uuid,
  message text,
  created_at timestamptz,
  is_read boolean,
  sender_info jsonb,
  is_system_message boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conversation_id uuid;
BEGIN
  -- Get conversation ID
  IF p_inquiry_id IS NOT NULL THEN
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE inquiry_id = p_inquiry_id;
  ELSIF p_booking_id IS NOT NULL THEN
    SELECT id INTO v_conversation_id
    FROM message_conversations
    WHERE booking_id = p_booking_id;
  END IF;

  -- If conversation doesn't exist, return empty result
  IF v_conversation_id IS NULL THEN
    RETURN;
  END IF;

  -- Return messages with read status for current user
  RETURN QUERY
  SELECT
    bm.id,
    bm.message,
    bm.created_at,
    COALESCE(mrs.is_read, false) as is_read,
    jsonb_build_object(
      'id', bm.sender_id,
      'first_name', p.first_name,
      'last_name', p.last_name,
      'is_admin', EXISTS (
        SELECT 1 FROM user_roles ur
        JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = bm.sender_id
        AND r.name = 'administrator'
      )
    ) as sender_info,
    bm.is_system_message
  FROM booking_messages bm
  LEFT JOIN message_read_status mrs ON mrs.message_id = bm.id AND mrs.user_id = auth.uid()
  LEFT JOIN profiles p ON p.user_id = bm.sender_id
  WHERE bm.conversation_id = v_conversation_id
  ORDER BY bm.created_at ASC;
END;
$$;

-- Function to migrate existing messages to the new system
CREATE OR REPLACE FUNCTION migrate_existing_messages()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_message record;
  v_conversation_id uuid;
  v_participants uuid[];
  v_participant uuid;
BEGIN
  -- Process each message
  FOR v_message IN
    SELECT *
    FROM booking_messages
    WHERE conversation_id IS NULL
  LOOP
    -- Get or create conversation
    v_conversation_id := get_or_create_conversation(v_message.inquiry_id, v_message.booking_id);
    
    -- Update message with conversation ID
    UPDATE booking_messages
    SET conversation_id = v_conversation_id
    WHERE id = v_message.id;
    
    -- Get participants
    SELECT array_agg(user_id) INTO v_participants
    FROM message_participants
    WHERE conversation_id = v_conversation_id;
    
    -- Create read status entries
    FOREACH v_participant IN ARRAY v_participants
    LOOP
      INSERT INTO message_read_status (
        message_id,
        user_id,
        is_read,
        read_at
      ) VALUES (
        v_message.id,
        v_participant,
        -- Mark as read for sender or if original message was marked read
        v_participant = v_message.sender_id OR v_message.is_read,
        NULL
        /*CASE 
          WHEN v_participant = v_message.sender_id OR v_message.is_read 
          THEN v_message.updated_at 
          ELSE NULL 
        END*/
      );
    END LOOP;
  END LOOP;
END;
$$;

-- Migrate existing messages
SELECT migrate_existing_messages();

-- Update on_message_created function for email notifications
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
      'sender_id', NEW.sender_id,
      'conversation_id', NEW.conversation_id
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

    -- Queue email for each recipient (except sender)
    FOR v_recipient IN
      SELECT 
        u.id as recipient_id,
        u.email as recipient_email,
        COALESCE(p.first_name || ' ' || p.last_name, u.email) as recipient_name
      FROM message_participants mp
      JOIN auth.users u ON u.id = mp.user_id
      LEFT JOIN profiles p ON p.user_id = u.id
      WHERE mp.conversation_id = NEW.conversation_id
      AND mp.user_id != NEW.sender_id
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
        'link_path', v_link_path
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
DROP TRIGGER message_created_trigger ON booking_messages;
CREATE TRIGGER message_created_trigger
AFTER INSERT ON booking_messages
FOR EACH ROW
EXECUTE FUNCTION on_message_created();

-- Function to handle read status updates
CREATE OR REPLACE FUNCTION on_message_read_status_updated()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Cancel pending email notifications when a message is read
  IF NEW.is_read = true AND OLD.is_read = false THEN
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
    AND next_retry_at > CURRENT_TIMESTAMP
    AND subject LIKE '%' || (
      SELECT substring(message from 1 for 30)
      FROM booking_messages
      WHERE id = NEW.message_id
    ) || '%';

    -- Log cancellation
    INSERT INTO brm_logs (
      activity_type,
      activity_data,
      status
    ) VALUES (
      'email',
      jsonb_build_object(
        'message_id', NEW.message_id,
        'user_id', NEW.user_id,
        'cancelled_at', CURRENT_TIMESTAMP,
        'reason', 'Message read'
      ),
      'cancelled'
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for read status updates
CREATE TRIGGER message_read_status_updated_trigger
AFTER UPDATE ON message_read_status
FOR EACH ROW
EXECUTE FUNCTION on_message_read_status_updated();

-- Add comments
COMMENT ON TABLE message_conversations IS 'Stores conversation metadata for messages';
COMMENT ON TABLE message_participants IS 'Tracks participants in each conversation';
COMMENT ON TABLE message_read_status IS 'Tracks read status per user per message';
COMMENT ON FUNCTION get_or_create_conversation IS 'Gets an existing conversation or creates a new one';
COMMENT ON FUNCTION send_conversation_message IS 'Sends a message to a conversation';
COMMENT ON FUNCTION mark_messages_read IS 'Marks messages as read for the current user';
COMMENT ON FUNCTION get_unread_message_count IS 'Gets the count of unread messages for a user';
COMMENT ON FUNCTION get_user_threads IS 'Gets all conversation threads for the current user';
COMMENT ON FUNCTION get_thread_messages IS 'Gets all messages in a thread with read status for the current user';
COMMENT ON FUNCTION migrate_existing_messages IS 'Migrates existing messages to the new conversation system';
COMMENT ON FUNCTION on_message_created IS 'Sends email notifications for new messages';
COMMENT ON FUNCTION on_message_read_status_updated IS 'Cancels email notifications when a message is read';