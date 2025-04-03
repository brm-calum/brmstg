/*
  # Fix warehouse filter function

  1. Changes
    - Updates filter_warehouses_by_requirements to properly handle space requests
    - Adds validation for JSON array input
    - Improves error handling for malformed input

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS filter_warehouses_by_requirements;

-- Create updated function
CREATE OR REPLACE FUNCTION filter_warehouses_by_requirements(
  p_city text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_space_requests jsonb DEFAULT NULL,
  p_feature_ids uuid[] DEFAULT NULL,
  p_service_ids uuid[] DEFAULT NULL
) RETURNS SETOF m_warehouses
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Validate space_requests format if provided
  IF p_space_requests IS NOT NULL THEN
    IF NOT jsonb_typeof(p_space_requests) = 'array' THEN
      RAISE EXCEPTION 'space_requests must be a JSON array';
    END IF;
  END IF;

  RETURN QUERY
  SELECT DISTINCT w.*
  FROM m_warehouses w
  WHERE 
    -- Filter by location if provided
    (p_city IS NULL OR w.city ILIKE '%' || p_city || '%')
    AND (p_country IS NULL OR w.country ILIKE '%' || p_country || '%')
    -- Check space requirements if provided
    AND (
      p_space_requests IS NULL 
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_space_requests) AS sr
        JOIN m_warehouse_spaces s ON s.warehouse_id = w.id
        WHERE 
          s.space_type_id = (sr->>'space_type_id')::uuid
          AND s.size_m2 >= (sr->>'size_m2')::numeric
      )
    )
    -- Check features if provided
    AND (
      p_feature_ids IS NULL 
      OR p_feature_ids = '{}'::uuid[]
      OR EXISTS (
        SELECT 1
        FROM m_warehouse_feature_assignments f
        WHERE f.warehouse_id = w.id
        AND f.feature_id = ANY(p_feature_ids)
      )
    )
    -- Check services if provided
    AND (
      p_service_ids IS NULL 
      OR p_service_ids = '{}'::uuid[]
      OR EXISTS (
        SELECT 1
        FROM m_warehouse_service_assignments s
        WHERE s.warehouse_id = w.id
        AND s.service_id = ANY(p_service_ids)
      )
    )
    -- Only active warehouses
    AND w.is_active = true;
END;
$$;

-- Add comments
COMMENT ON FUNCTION filter_warehouses_by_requirements IS 'Filters warehouses based on location, space requirements, features, and services';