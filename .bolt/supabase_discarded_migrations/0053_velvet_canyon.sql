/*
  # Add Warehouse Inquiry Notifications

  1. New Tables
    - `notifications` table for storing user notifications
    - `email_templates` table for storing email templates

  2. Changes
    - Add notification triggers for inquiries
    - Add email template for inquiry notifications

  3. Security
    - Enable RLS on new tables
    - Add policies for notification access
*/

-- Create notifications table
CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  read boolean DEFAULT false,
  data jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create email templates table
CREATE TABLE email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;

-- Create indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(read);
CREATE INDEX idx_notifications_type ON notifications(type);

-- Create RLS policies
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

-- Create function to create notification
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_message text,
  p_data jsonb DEFAULT '{}'
)
RETURNS void AS $$
BEGIN
  INSERT INTO notifications (
    user_id,
    type,
    title,
    message,
    data
  ) VALUES (
    p_user_id,
    p_type,
    p_title,
    p_message,
    p_data
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to handle inquiry notifications
CREATE OR REPLACE FUNCTION handle_inquiry_notification()
RETURNS TRIGGER AS $$
DECLARE
  warehouse_record RECORD;
  owner_id uuid;
  warehouse_name text;
BEGIN
  -- Get warehouse details
  SELECT id, owner_id, name INTO warehouse_record
  FROM warehouses
  WHERE id = NEW.warehouse_id;

  -- Create notification for warehouse owner
  PERFORM create_notification(
    warehouse_record.owner_id,
    'inquiry',
    'New Warehouse Inquiry',
    format('You have received a new inquiry for %s', warehouse_record.name),
    jsonb_build_object(
      'inquiry_id', NEW.id,
      'warehouse_id', NEW.warehouse_id,
      'warehouse_name', warehouse_record.name
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for inquiry notifications
CREATE TRIGGER inquiry_notification_trigger
  AFTER INSERT ON warehouse_inquiries
  FOR EACH ROW
  EXECUTE FUNCTION handle_inquiry_notification();

-- Insert default email templates
INSERT INTO email_templates (name, subject, body) VALUES
('inquiry_notification', 
 'New Inquiry for {warehouse_name}',
 'You have received a new inquiry for your warehouse {warehouse_name}.\n\n' ||
 'Details:\n' ||
 'Start Date: {start_date}\n' ||
 'End Date: {end_date}\n' ||
 'Space Needed: {space_needed}m²\n\n' ||
 'Message from inquirer:\n{message}\n\n' ||
 'You can respond to this inquiry through your warehouse dashboard.'
)
ON CONFLICT (name) DO UPDATE
SET 
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  updated_at = CURRENT_TIMESTAMP;