/*
  # Update RLS policies for warehouse management

  1. Changes
    - Adds RLS policies for warehouse feature assignments
    - Adds RLS policies for warehouse service assignments
    - Adds RLS policies for warehouse spaces
    - Adds RLS policies for warehouse images

  2. Security
    - Everyone can view all warehouse-related data
    - Warehouse owners can manage their own warehouse data
    - Administrators can manage all warehouse data
*/
-- Feature assignments policies
DROP POLICY IF EXISTS "Administrators can manage space types" ON m_space_types;
DROP POLICY IF EXISTS "Allow public read access to space types" ON m_space_types;
DROP POLICY IF EXISTS "Everyone can view space types" ON m_space_types;

CREATE POLICY "Everyone can view space types" ON m_space_types
FOR SELECT USING (true);

CREATE POLICY "Administrators can manage all space types" ON m_space_types
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

------------------------------------------------------------
-- Feature assignments policies
DROP POLICY IF EXISTS "Everyone can view warehouse features" ON m_warehouse_feature_assignments;
DROP POLICY IF EXISTS "Owners can manage their warehouse features" ON m_warehouse_feature_assignments;
DROP POLICY IF EXISTS "Administrators can manage all warehouse features" ON m_warehouse_feature_assignments;

CREATE POLICY "Everyone can view warehouse features" ON m_warehouse_feature_assignments
FOR SELECT USING (true);

CREATE POLICY "Owners can manage their warehouse features" ON m_warehouse_feature_assignments
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
);

CREATE POLICY "Administrators can manage all warehouse features" ON m_warehouse_feature_assignments
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

-- Service assignments policies
DROP POLICY IF EXISTS "Everyone can view warehouse services" ON m_warehouse_service_assignments;
DROP POLICY IF EXISTS "Owners can manage their warehouse services" ON m_warehouse_service_assignments;
DROP POLICY IF EXISTS "Administrators can manage all warehouse services" ON m_warehouse_service_assignments;

CREATE POLICY "Everyone can view warehouse services" ON m_warehouse_service_assignments
FOR SELECT USING (true);

CREATE POLICY "Owners can manage their warehouse services" ON m_warehouse_service_assignments
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
);

CREATE POLICY "Administrators can manage all warehouse services" ON m_warehouse_service_assignments
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

-- Warehouse spaces policies
DROP POLICY IF EXISTS "Everyone can view warehouse spaces" ON m_warehouse_spaces;
DROP POLICY IF EXISTS "Owners can manage their warehouse spaces" ON m_warehouse_spaces;
DROP POLICY IF EXISTS "Administrators can manage all warehouse spaces" ON m_warehouse_spaces;

CREATE POLICY "Everyone can view warehouse spaces" ON m_warehouse_spaces
FOR SELECT USING (true);

CREATE POLICY "Owners can manage their warehouse spaces" ON m_warehouse_spaces
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
);

CREATE POLICY "Administrators can manage all warehouse spaces" ON m_warehouse_spaces
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

-- Warehouse images policies
DROP POLICY IF EXISTS "Everyone can view warehouse images" ON m_warehouse_images;
DROP POLICY IF EXISTS "Owners can manage their warehouse images" ON m_warehouse_images;
DROP POLICY IF EXISTS "Administrators can manage all warehouse images" ON m_warehouse_images;

CREATE POLICY "Everyone can view warehouse images" ON m_warehouse_images
FOR SELECT USING (true);

CREATE POLICY "Owners can manage their warehouse images" ON m_warehouse_images
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
);

CREATE POLICY "Administrators can manage all warehouse images" ON m_warehouse_images
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
ALTER TABLE m_warehouse_feature_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE m_warehouse_service_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE m_warehouse_spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE m_warehouse_images ENABLE ROW LEVEL SECURITY;