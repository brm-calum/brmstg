/*
  # Update warehouse status permissions

  1. Changes
    - Allow administrators to toggle warehouse status
    - Maintain owner's ability to toggle their own warehouses
    - Add validation for status changes

  2. Security
    - Maintains existing RLS policies
    - Adds proper permission checks
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS toggle_m_warehouse_status;

-- Create updated function
CREATE OR REPLACE FUNCTION toggle_m_warehouse_status(
  p_warehouse_id uuid,
  p_is_active boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_warehouse m_warehouses%ROWTYPE;
BEGIN
  -- Get warehouse
  SELECT * INTO v_warehouse
  FROM m_warehouses
  WHERE id = p_warehouse_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Warehouse not found';
  END IF;

  -- Check permissions
  IF NOT (
    -- Allow if user is warehouse owner
    v_warehouse.owner_id = auth.uid()
    OR
    -- Or if user is administrator
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid() 
      AND r.name = 'administrator'
    )
  ) THEN
    RAISE EXCEPTION 'Not authorized to toggle warehouse status';
  END IF;

  -- Update warehouse status
  UPDATE m_warehouses
  SET 
    is_active = p_is_active,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_warehouse_id;

  -- Log status change
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status,
    created_by
  ) VALUES (
    'warehouse_status_change',
    jsonb_build_object(
      'warehouse_id', p_warehouse_id,
      'old_status', v_warehouse.is_active,
      'new_status', p_is_active
    ),
    'success',
    auth.uid()
  );

  RETURN true;
END;
$$;

-- Add comments
COMMENT ON FUNCTION toggle_m_warehouse_status IS 'Toggles warehouse active status, allowing both owners and administrators';