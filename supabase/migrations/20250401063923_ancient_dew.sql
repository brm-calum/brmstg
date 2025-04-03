/*
  # Update message notifications for all participants

  1. Changes
    - Update get_conversation_recipients to handle all three participant types
    - Add administrator to booking conversation recipients
    - Improve recipient selection logic
    - Maintain existing functionality for inquiries

  2. Security
    - Maintains existing RLS policies
*/

-- Update get_conversation_recipients function
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
DECLARE
  v_admin_id uuid;
BEGIN
  -- Get admin ID (first administrator found)
  SELECT user_id INTO v_admin_id
  FROM user_roles ur
  JOIN roles r ON r.id = ur.role_id
  WHERE r.name = 'administrator'
  LIMIT 1;

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
    FROM auth.users u
    LEFT JOIN profiles p ON p.user_id = u.id
    WHERE u.id = v_admin_id
    AND v_admin_id != p_sender_id;

  -- For bookings
  ELSIF p_booking_id IS NOT NULL THEN
    -- Return all participants except sender
    RETURN QUERY
    -- Get trader
    SELECT 
      u.id as recipient_id,
      u.email as recipient_email,
      COALESCE(p.first_name || ' ' || p.last_name, u.email) as recipient_name
    FROM bookings b
    JOIN auth.users u ON u.id = b.trader_id
    LEFT JOIN profiles p ON p.user_id = u.id
    WHERE b.id = p_booking_id
    AND b.trader_id != p_sender_id
    UNION
    -- Get warehouse owner
    SELECT 
      u.id,
      u.email,
      COALESCE(p.first_name || ' ' || p.last_name, u.email)
    FROM bookings b
    JOIN auth.users u ON u.id = b.warehouse_owner_id
    LEFT JOIN profiles p ON p.user_id = u.id
    WHERE b.id = p_booking_id
    AND b.warehouse_owner_id != p_sender_id
    UNION
    -- Get admin
    SELECT 
      u.id,
      u.email,
      COALESCE(p.first_name || ' ' || p.last_name, u.email)
    FROM auth.users u
    LEFT JOIN profiles p ON p.user_id = u.id
    WHERE u.id = v_admin_id
    AND v_admin_id != p_sender_id;
  END IF;
END;
$$;

-- Add comments
COMMENT ON FUNCTION get_conversation_recipients IS 'Gets all conversation recipients (trader, warehouse owner, admin) except the sender';