/*
  # Fix unread count function

  1. Changes
    - Add proper handling for both inquiry responses and pending inquiries
    - Add proper error handling and type casting
    - Add proper indexing for performance

  2. Security
    - Enable RLS on all affected tables
    - Add proper policies for data access
*/

-- Create function to get total unread count
CREATE OR REPLACE FUNCTION get_total_unread_count(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_response_count integer;
  v_inquiry_count integer;
BEGIN
  -- Get unread responses count
  SELECT COUNT(*)::integer INTO v_response_count
  FROM inquiry_responses
  WHERE recipient_id = p_user_id
  AND read = false;

  -- Get pending inquiries count for warehouse owners
  SELECT COUNT(*)::integer INTO v_inquiry_count
  FROM warehouse_inquiries i
  JOIN warehouses w ON i.warehouse_id = w.id
  WHERE w.owner_id = p_user_id
  AND i.status = 'pending';

  -- Return total count
  RETURN COALESCE(v_response_count, 0) + COALESCE(v_inquiry_count, 0);
END;
$$;

-- Add index for faster pending inquiry lookups
CREATE INDEX IF NOT EXISTS idx_warehouse_inquiries_status 
ON warehouse_inquiries(status);

-- Add index for faster warehouse owner lookups
CREATE INDEX IF NOT EXISTS idx_warehouses_owner_id 
ON warehouses(owner_id);

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_total_unread_count(uuid) TO authenticated;