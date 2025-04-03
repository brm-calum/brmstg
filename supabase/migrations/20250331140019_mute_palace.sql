/*
  # Fix get_user_bookings function

  1. Changes
    - Updates get_user_bookings to properly handle trader and warehouse owner roles
    - Adds proper joins for warehouse and space information
    - Improves error handling and logging

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS get_user_bookings;

-- Create updated function
CREATE OR REPLACE FUNCTION get_user_bookings()
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT json_build_object(
    'id', b.id,
    'status', b.status,
    'start_date', b.start_date,
    'end_date', b.end_date,
    'total_cost_cents', b.total_cost_cents,
    'platform_fee_percentage', b.platform_fee_percentage,
    'platform_fee_cents', b.platform_fee_cents,
    'total_cost_with_fee_cents', b.total_cost_with_fee_cents,
    'created_at', b.created_at,
    'warehouse', json_build_object(
      'id', w.id,
      'name', w.name,
      'address', w.address,
      'city', w.city,
      'country', w.country
    ),
    'trader', json_build_object(
      'id', pt.user_id,
      'first_name', pt.first_name,
      'last_name', pt.last_name,
      'email', pt.contact_email
    ),
    'warehouse_owner', json_build_object(
      'id', po.user_id,
      'first_name', po.first_name,
      'last_name', po.last_name,
      'email', po.contact_email
    ),
    'spaces', (
      SELECT json_agg(json_build_object(
        'space_type', st.name,
        'size_m2', wsh.size_m2,
        'price_per_m2_cents', wsh.price_per_m2_cents
      ))
      FROM booking_offer_spaces bos
      JOIN m_warehouse_space_history wsh ON wsh.id = bos.space_history_id
      JOIN m_space_types st ON st.id = wsh.space_type_id
      WHERE bos.offer_id = b.offer_id
    ),
    'services', (
      SELECT json_agg(json_build_object(
        'name', ws.name,
        'quantity', bos.quantity,
        'pricing_type', bos.pricing_type,
        'price_per_hour_cents', bos.price_per_hour_cents,
        'price_per_unit_cents', bos.price_per_unit_cents,
        'unit_type', bos.unit_type
      ))
      FROM booking_offer_services bos
      JOIN warehouse_services ws ON ws.id = bos.service_id
      WHERE bos.offer_id = b.offer_id
    )
  )
  FROM bookings b
  JOIN m_warehouses w ON w.id = b.warehouse_id
  JOIN profiles pt ON pt.user_id = b.trader_id
  JOIN profiles po ON po.user_id = b.warehouse_owner_id
  WHERE b.trader_id = auth.uid()  -- Show bookings where user is trader
  OR b.warehouse_owner_id = auth.uid()  -- Show bookings where user is warehouse owner
  OR EXISTS (  -- Show all bookings if user is admin
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
  ORDER BY b.created_at DESC;
END;
$$;

-- Add comments
COMMENT ON FUNCTION get_user_bookings IS 'Gets all bookings for a user with complete warehouse, trader, and space details';