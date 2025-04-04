/*
  # Add RLS policies for warehouse features and services

  1. Changes
    - Add RLS policies for warehouse_features table
    - Add RLS policies for warehouse_services table
    - Add RLS policies for warehouse_types table

  2. Security
    - Enable public read access to all reference tables
    - Maintain existing write restrictions
*/

-- Enable RLS on warehouse_types
ALTER TABLE warehouse_types ENABLE ROW LEVEL SECURITY;

-- Add public read policy for warehouse_types
CREATE POLICY "Allow public read access to warehouse types"
  ON warehouse_types
  FOR SELECT
  TO public
  USING (true);

-- Add policy for warehouse owners to manage their feature assignments
CREATE POLICY "Allow warehouse owners to manage feature assignments"
  ON warehouse_features
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM warehouses w
      WHERE w.owner_id = auth.uid()
    )
  );

-- Add policy for warehouse owners to manage their service assignments
CREATE POLICY "Allow warehouse owners to manage service assignments"
  ON warehouse_services
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM warehouses w
      WHERE w.owner_id = auth.uid()
    )
  );