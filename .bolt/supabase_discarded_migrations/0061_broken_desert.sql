-- Drop existing trigger first
DROP TRIGGER IF EXISTS notify_warehouse_owner_trigger ON warehouse_inquiries;

-- Now we can safely drop the function
DROP FUNCTION IF EXISTS notify_warehouse_owner_of_inquiry();

-- Create improved notification function
CREATE OR REPLACE FUNCTION notify_warehouse_owner_of_inquiry()
RETURNS TRIGGER AS $$
DECLARE
  warehouse_owner_email text;
BEGIN
  -- Get warehouse owner's contact email with explicit table references
  SELECT owner_profile.contact_email INTO warehouse_owner_email
  FROM warehouses w
  JOIN profiles owner_profile ON owner_profile.user_id = w.owner_id
  WHERE w.id = NEW.warehouse_id;

  -- Insert notification (you would implement actual email sending here)
  RAISE NOTICE 'New inquiry notification would be sent to %', warehouse_owner_email;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
CREATE TRIGGER notify_warehouse_owner_trigger
  AFTER INSERT ON warehouse_inquiries
  FOR EACH ROW
  EXECUTE FUNCTION notify_warehouse_owner_of_inquiry();