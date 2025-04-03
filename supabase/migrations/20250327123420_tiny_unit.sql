/*
  # Fix warehouse spaces schema

  1. Changes
    - Adds missing space_type relationship to m_warehouse_spaces
    - Updates space type references to use proper foreign key constraints
    - Adds indexes for better query performance

  2. Security
    - Maintains existing RLS policies
    - Ensures data integrity with proper constraints
*/

-- Add missing relationship to space type
ALTER TABLE m_warehouse_spaces
ADD COLUMN IF NOT EXISTS space_type jsonb GENERATED ALWAYS AS (
  SELECT jsonb_build_object(
    'id', st.id,
    'name', st.name,
    'description', st.description
  )
  FROM m_space_types st
  WHERE st.id = space_type_id
) STORED;

-- Add index for space type lookups
CREATE INDEX IF NOT EXISTS idx_warehouse_spaces_type_lookup 
ON m_warehouse_spaces (space_type_id, warehouse_id);

-- Add index for warehouse lookups
CREATE INDEX IF NOT EXISTS idx_warehouse_spaces_warehouse_lookup
ON m_warehouse_spaces (warehouse_id, space_type_id);

-- Add foreign key constraint if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'm_warehouse_spaces_space_type_id_fkey'
  ) THEN
    ALTER TABLE m_warehouse_spaces
    ADD CONSTRAINT m_warehouse_spaces_space_type_id_fkey
    FOREIGN KEY (space_type_id) 
    REFERENCES m_space_types(id);
  END IF;
END $$;

-- Add unique constraint to prevent duplicate space types per warehouse
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'm_warehouse_spaces_warehouse_id_space_type_id_key'
  ) THEN
    ALTER TABLE m_warehouse_spaces
    ADD CONSTRAINT m_warehouse_spaces_warehouse_id_space_type_id_key
    UNIQUE (warehouse_id, space_type_id);
  END IF;
END $$;

-- Add check constraint for positive values
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.check_constraints 
    WHERE constraint_name = 'm_warehouse_spaces_size_m2_check'
  ) THEN
    ALTER TABLE m_warehouse_spaces
    ADD CONSTRAINT m_warehouse_spaces_size_m2_check
    CHECK (size_m2 > 0);
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.check_constraints 
    WHERE constraint_name = 'm_warehouse_spaces_price_per_m2_cents_check'
  ) THEN
    ALTER TABLE m_warehouse_spaces
    ADD CONSTRAINT m_warehouse_spaces_price_per_m2_cents_check
    CHECK (price_per_m2_cents > 0);
  END IF;
END $$;

-- Add comments
COMMENT ON TABLE m_warehouse_spaces IS 'Stores space information for warehouses';
COMMENT ON COLUMN m_warehouse_spaces.space_type_id IS 'References the space type';
COMMENT ON COLUMN m_warehouse_spaces.space_type IS 'Computed space type information';
COMMENT ON COLUMN m_warehouse_spaces.size_m2 IS 'Size in square meters';
COMMENT ON COLUMN m_warehouse_spaces.price_per_m2_cents IS 'Price per square meter in cents';