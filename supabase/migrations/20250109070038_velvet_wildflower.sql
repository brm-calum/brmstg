/*
  # Make warehouse features and services publicly readable

  1. Changes
    - Add public read access to warehouse features and services
    - Add public read access to feature and service assignments
    - Keep write access restricted to authenticated users

  2. Security
    - Enables public read access while maintaining secure write restrictions
    - Ensures warehouse owners can still manage their features and services
*/

-- Enable RLS on warehouse_feature_assignments
ALTER TABLE warehouse_feature_assignments ENABLE ROW LEVEL SECURITY;

-- Add public read policy for warehouse_feature_assignments
CREATE POLICY "Allow public read access to warehouse feature assignments"
  ON warehouse_feature_assignments
  FOR SELECT
  TO public
  USING (true);

-- Add policy for warehouse owners to manage their feature assignments
CREATE POLICY "Allow warehouse owners to manage feature assignments"
  ON warehouse_feature_assignments
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM warehouses w
      WHERE w.id = warehouse_id
      AND w.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM warehouses w
      WHERE w.id = warehouse_id
      AND w.owner_id = auth.uid()
    )
  );

-- Enable RLS on warehouse_service_assignments
ALTER TABLE warehouse_service_assignments ENABLE ROW LEVEL SECURITY;

-- Add public read policy for warehouse_service_assignments
CREATE POLICY "Allow public read access to warehouse service assignments"
  ON warehouse_service_assignments
  FOR SELECT
  TO public
  USING (true);

-- Add policy for warehouse owners to manage their service assignments
CREATE POLICY "Allow warehouse owners to manage service assignments"
  ON warehouse_service_assignments
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM warehouses w
      WHERE w.id = warehouse_id
      AND w.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM warehouses w
      WHERE w.id = warehouse_id
      AND w.owner_id = auth.uid()
    )
  );