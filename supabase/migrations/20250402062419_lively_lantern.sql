/*
  # Fix get_user_threads function return type

  1. Changes
    - Update get_user_threads function to properly cast unread_count to integer
    - Fix the structure of query to match function result type
    - Maintain existing functionality

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_user_threads();

-- Create updated function with proper type casting
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
    (SELECT COUNT(*)::integer  -- Explicitly cast to integer
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

-- Add comments
COMMENT ON FUNCTION get_user_threads IS 'Gets all conversation threads for the current user with proper integer type for unread_count';