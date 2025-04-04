-- Drop views first
DROP VIEW IF EXISTS warehouse_inquiries_view;

-- Drop functions
DROP FUNCTION IF EXISTS get_warehouse_inquiries(uuid);
DROP FUNCTION IF EXISTS get_user_inquiries(uuid);
DROP FUNCTION IF EXISTS create_warehouse_inquiry(uuid, date, date, numeric, text);
DROP FUNCTION IF EXISTS respond_to_inquiry(uuid, text);
DROP FUNCTION IF EXISTS notify_warehouse_owner_of_inquiry();

-- Drop triggers
DROP TRIGGER IF EXISTS notify_warehouse_owner_trigger ON warehouse_inquiries;

-- Drop tables
DROP TABLE IF EXISTS warehouse_bookings;
DROP TABLE IF EXISTS warehouse_inquiries;
DROP TABLE IF EXISTS warehouse_notifications;

-- Drop types
DROP TYPE IF EXISTS booking_status;
DROP TYPE IF EXISTS inquiry_status;