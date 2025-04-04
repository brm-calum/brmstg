/*
  # Warehouse Inquiry Notification System
  
  1. Notification Function
    - Improved error handling
    - Optimized queries
    - Better logging
  
  2. Changes
    - Drop existing trigger and function
    - Create new optimized function
    - Create new trigger
*/

-- Drop existing objects
DROP TRIGGER IF EXISTS notify_warehouse_owner_trigger ON warehouse_inquiries;
DROP FUNCTION IF EXISTS notify_warehouse_owner_of_inquiry();

-- Create notification function with optimized queries
CREATE OR REPLACE FUNCTION notify_warehouse_owner_of_inquiry()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  owner_info record;
BEGIN
  -- Single optimized query to get all required information
  SELECT 
    p.contact_email as owner_email,
    w.name as warehouse_name,
    CONCAT(ip.first_name, ' ', ip.last_name) as inquirer_name
  INTO owner_info
  FROM warehouses w
  JOIN profiles p ON p.user_id = w.owner_id
  JOIN profiles ip ON ip.user_id = NEW.user_id
  WHERE w.id = NEW.warehouse_id;

  -- Basic validation
  IF owner_info IS NULL THEN
    RAISE WARNING 'Could not find owner information for warehouse %', NEW.warehouse_id;
    RETURN NEW;
  END IF;

  -- Log notification details
  RAISE NOTICE 'Inquiry notification: Warehouse=%, From=%, To=%',
    owner_info.warehouse_name,
    owner_info.inquirer_name,
    owner_info.owner_email;

  RETURN NEW;
EXCEPTION 
  WHEN OTHERS THEN
    RAISE WARNING 'Notification error: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Create notification trigger
CREATE TRIGGER notify_warehouse_owner_trigger
AFTER INSERT ON warehouse_inquiries
FOR EACH ROW
EXECUTE FUNCTION notify_warehouse_owner_of_inquiry();