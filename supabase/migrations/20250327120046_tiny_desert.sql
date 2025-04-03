-- Drop existing policies first
DROP POLICY IF EXISTS "Public can view active warehouses" ON m_warehouses;
DROP POLICY IF EXISTS "Owners can manage their warehouses" ON m_warehouses;
DROP POLICY IF EXISTS "Administrators can manage all warehouses" ON m_warehouses;

-- Create new policies
-- Everyone can view warehouses
CREATE POLICY "Everyone can view warehouses" ON m_warehouses
FOR SELECT USING (true);

-- Warehouse owners can manage their own warehouses
CREATE POLICY "Owners can manage their warehouses" ON m_warehouses
FOR ALL USING (
  owner_id = auth.uid()
) WITH CHECK (
  owner_id = auth.uid()
);

-- Administrators can manage all warehouses
CREATE POLICY "Administrators can manage all warehouses" ON m_warehouses
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

-- Update space types policies
DROP POLICY IF EXISTS "Enable read access for all users" ON m_space_types;
DROP POLICY IF EXISTS "Administrators can manage space types" ON m_space_types;

-- Everyone can view space types
CREATE POLICY "Everyone can view space types" ON m_space_types
FOR SELECT USING (true);

-- Only admins can manage space types
CREATE POLICY "Administrators can manage space types" ON m_space_types
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

-- Update warehouse features policies
DROP POLICY IF EXISTS "Allow public read access to warehouse features" ON warehouse_features;

-- Everyone can view features
CREATE POLICY "Everyone can view features" ON warehouse_features
FOR SELECT USING (true);

-- Only admins can manage features
CREATE POLICY "Administrators can manage features" ON warehouse_features
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

-- Update warehouse services policies
DROP POLICY IF EXISTS "Allow public read access to warehouse services" ON warehouse_services;

-- Everyone can view services
CREATE POLICY "Everyone can view services" ON warehouse_services
FOR SELECT USING (true);

-- Only admins can manage services
CREATE POLICY "Administrators can manage services" ON warehouse_services
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

-- Enable RLS on all tables
ALTER TABLE m_warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE m_space_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouse_services ENABLE ROW LEVEL SECURITY;