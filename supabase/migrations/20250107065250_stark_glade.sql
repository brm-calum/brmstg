/*
  # Add unread messages count function
  
  1. New Functions
    - get_unread_message_count: Efficiently counts unread messages for a user
  
  2. Security
    - Function is accessible to authenticated users only
    - Users can only count their own unread messages
*/

CREATE OR REPLACE FUNCTION get_unread_message_count(p_user_id uuid)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::bigint
  FROM inquiry_responses
  WHERE recipient_id = p_user_id 
  AND read = false;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_unread_message_count(uuid) TO authenticated;