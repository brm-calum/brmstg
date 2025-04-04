-- Drop existing trigger and function
DROP TRIGGER IF EXISTS notify_warehouse_owner_trigger ON warehouse_inquiries;
DROP FUNCTION IF EXISTS notify_warehouse_owner_of_inquiry();

-- Create improved notification function with better error handling and logging
CREATE OR REPLACE FUNCTION notify_warehouse_owner_of_inquiry()
RETURNS TRIGGER AS $$
DECLARE
  owner_data RECORD;
  inquirer_data RECORD;
BEGIN
  -- Get warehouse owner and inquirer details in a single query
  WITH owner_info AS (
    SELECT 
      w.owner_id,
      w.name AS warehouse_name,
      p.contact_email AS owner_email,
      p.first_name AS owner_first_name,
      p.last_name AS owner_last_name
    FROM warehouses w
    JOIN profiles p ON p.user_id = w.owner_id
    WHERE w.id = NEW.warehouse_id
  ),
  inquirer_info AS (
    SELECT 
      p.contact_email AS inquirer_email,
      p.first_name AS inquirer_first_name,
      p.last_name AS inquirer_last_name
    FROM profiles p
    WHERE p.user_id = NEW.user_id
  )
  SELECT 
    o.*,
    i.inquirer_email,
    i.inquirer_first_name,
    i.inquirer_last_name
  INTO owner_data
  FROM owner_info o
  CROSS JOIN inquirer_info i;

  -- Validate required data
  IF owner_data.owner_email IS NULL THEN
    RAISE WARNING 'Owner email not found for warehouse %. Notification not sent.', NEW.warehouse_id;
    RETURN NEW;
  END IF;

  -- Log notification details
  INSERT INTO warehouse_notifications (
    warehouse_id,
    owner_id,
    inquirer_id,
    notification_type,
    recipient_email,
    notification_data,
    status
  ) VALUES (
    NEW.warehouse_id,
    owner_data.owner_id,
    NEW.user_id,
    'inquiry',
    owner_data.owner_email,
    jsonb_build_object(
      'warehouse_name', owner_data.warehouse_name,
      'inquirer_name', concat(owner_data.inquirer_first_name, ' ', owner_data.inquirer_last_name),
      'inquiry_id', NEW.id,
      'space_needed', NEW.space_needed,
      'start_date', NEW.start_date,
      'end_date', NEW.end_date,
      'message', NEW.message
    ),
    'pending'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't prevent inquiry creation
  RAISE WARNING 'Failed to create notification: %', SQLERRM;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS warehouse_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id uuid REFERENCES warehouses NOT NULL,
  owner_id uuid REFERENCES auth.users NOT NULL,
  inquirer_id uuid REFERENCES auth.users NOT NULL,
  notification_type text NOT NULL,
  recipient_email text NOT NULL,
  notification_data jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at timestamptz
);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_notifications_warehouse ON warehouse_notifications(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_notifications_owner ON warehouse_notifications(owner_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON warehouse_notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON warehouse_notifications(notification_type);

-- Enable RLS
ALTER TABLE warehouse_notifications ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own notifications"
  ON warehouse_notifications FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid() OR inquirer_id = auth.uid());

-- Create trigger for inquiry notifications
CREATE TRIGGER notify_warehouse_owner_trigger
  AFTER INSERT ON warehouse_inquiries
  FOR EACH ROW
  EXECUTE FUNCTION notify_warehouse_owner_of_inquiry();