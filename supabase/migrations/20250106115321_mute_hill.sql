/*
  # Add public access policies for features and services

  1. Changes
    - Add public read access to warehouse_features table
    - Add public read access to warehouse_services table

  2. Security
    - Enable RLS on both tables
    - Add policies for public read access
    - Maintain existing policies for authenticated users
*/

-- Enable RLS on warehouse_features
ALTER TABLE warehouse_features ENABLE ROW LEVEL SECURITY;

-- Add public read policy for warehouse_features
CREATE POLICY "Allow public read access to warehouse features"
  ON warehouse_features
  FOR SELECT
  TO public
  USING (true);

-- Enable RLS on warehouse_services
ALTER TABLE warehouse_services ENABLE ROW LEVEL SECURITY;

-- Add public read policy for warehouse_services
CREATE POLICY "Allow public read access to warehouse services"
  ON warehouse_services
  FOR SELECT
  TO public
  USING (true);