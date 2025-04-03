/*
  # Fix warehouse filtering function

  1. Changes
    - Updates filter_warehouses_by_requirements to handle empty space requests
    - Improves validation and error handling
    - Adds proper type casting for parameters

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS filter_warehouses_by_requirements;

-- Create updated function
CREATE OR REPLACE FUNCTION filter_warehouses_by_requirements(
  p_city text DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_space_requests text DEFAULT NULL,
  p_feature_ids uuid[] DEFAULT NULL,
  p_service_ids uuid[] DEFAULT NULL
) RETURNS SETOF m_warehouses
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_space_requests jsonb;
BEGIN
  -- Convert space_requests to jsonb and validate
  IF p_space_requests IS NOT NULL THEN
    BEGIN
      v_space_requests := p_space_requests::jsonb;
      IF NOT jsonb_typeof(v_space_requests) = 'array' THEN
        RAISE EXCEPTION 'space_requests must be a JSON array';
      END IF;
    EXCEPTION WHEN others THEN
      RAISE EXCEPTION 'Invalid space_requests format: %', SQLERRM;
    END;
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
      v_space_requests IS NULL 
      OR jsonb_array_length(v_space_requests) = 0
      OR EXISTS (
        SELECT 1
        FROM jsonb_array_elements(v_space_requests) AS sr
        JOIN m_warehouse_spaces s ON s.warehouse_id = w.id
        WHERE 
          s.space_type_id = (sr->>'space_type_id')::uuid
          AND s.size_m2 >= (sr->>'size_m2')::numeric
      )
    )
    -- Check features if provided
    AND (
      p_feature_ids IS NULL 
      OR array_length(p_feature_ids, 1) IS NULL
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
      OR array_length(p_service_ids, 1) IS NULL
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