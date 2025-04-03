/*
  # Update warehouse foreign key constraints

  1. Changes
    - Add ON UPDATE CASCADE to foreign key constraints
    - Maintain data integrity while allowing updates
    - Fix constraint issues preventing warehouse edits

  2. Security
    - Maintains existing RLS policies
    - Ensures referential integrity
*/

-- Update booking_offer_spaces foreign key constraint
ALTER TABLE booking_offer_spaces
DROP CONSTRAINT IF EXISTS booking_offer_spaces_space_id_fkey,
ADD CONSTRAINT booking_offer_spaces_space_id_fkey
  FOREIGN KEY (space_id)
  REFERENCES m_warehouse_spaces(id)
  ON UPDATE CASCADE;

-- Update booking_inquiry_warehouses foreign key constraint
ALTER TABLE booking_inquiry_warehouses
DROP CONSTRAINT IF EXISTS booking_inquiry_warehouses_warehouse_id_fkey,
ADD CONSTRAINT booking_inquiry_warehouses_warehouse_id_fkey
  FOREIGN KEY (warehouse_id)
  REFERENCES m_warehouses(id)
  ON UPDATE CASCADE;

-- Update m_warehouse_spaces foreign key constraint
ALTER TABLE m_warehouse_spaces
DROP CONSTRAINT IF EXISTS m_warehouse_spaces_warehouse_id_fkey,
ADD CONSTRAINT m_warehouse_spaces_warehouse_id_fkey
  FOREIGN KEY (warehouse_id)
  REFERENCES m_warehouses(id)
  ON UPDATE CASCADE;

-- Update m_warehouse_feature_assignments foreign key constraint
ALTER TABLE m_warehouse_feature_assignments
DROP CONSTRAINT IF EXISTS m_warehouse_feature_assignments_warehouse_id_fkey,
ADD CONSTRAINT m_warehouse_feature_assignments_warehouse_id_fkey
  FOREIGN KEY (warehouse_id)
  REFERENCES m_warehouses(id)
  ON UPDATE CASCADE;

-- Update m_warehouse_service_assignments foreign key constraint
ALTER TABLE m_warehouse_service_assignments
DROP CONSTRAINT IF EXISTS m_warehouse_service_assignments_warehouse_id_fkey,
ADD CONSTRAINT m_warehouse_service_assignments_warehouse_id_fkey
  FOREIGN KEY (warehouse_id)
  REFERENCES m_warehouses(id)
  ON UPDATE CASCADE;

-- Update m_warehouse_images foreign key constraint
ALTER TABLE m_warehouse_images
DROP CONSTRAINT IF EXISTS m_warehouse_images_warehouse_id_fkey,
ADD CONSTRAINT m_warehouse_images_warehouse_id_fkey
  FOREIGN KEY (warehouse_id)
  REFERENCES m_warehouses(id)
  ON UPDATE CASCADE;

-- Add comments
COMMENT ON CONSTRAINT booking_offer_spaces_space_id_fkey ON booking_offer_spaces IS 'Foreign key constraint with cascade update for warehouse spaces';
COMMENT ON CONSTRAINT booking_inquiry_warehouses_warehouse_id_fkey ON booking_inquiry_warehouses IS 'Foreign key constraint with cascade update for warehouses';
COMMENT ON CONSTRAINT m_warehouse_spaces_warehouse_id_fkey ON m_warehouse_spaces IS 'Foreign key constraint with cascade update for warehouse spaces';
COMMENT ON CONSTRAINT m_warehouse_feature_assignments_warehouse_id_fkey ON m_warehouse_feature_assignments IS 'Foreign key constraint with cascade update for warehouse features';
COMMENT ON CONSTRAINT m_warehouse_service_assignments_warehouse_id_fkey ON m_warehouse_service_assignments IS 'Foreign key constraint with cascade update for warehouse services';
COMMENT ON CONSTRAINT m_warehouse_images_warehouse_id_fkey ON m_warehouse_images IS 'Foreign key constraint with cascade update for warehouse images';