/*
  # Update get_trader_offer function

  1. Changes
    - Update get_trader_offer to return platform fee values
    - Ensure platform fee and total with fee are included in response
    - Maintain existing functionality and security

  2. Security
    - Maintains existing RLS policies
*/

-- Update get_trader_offer function
CREATE OR REPLACE FUNCTION get_trader_offer(p_inquiry_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_offer json;
BEGIN
  -- Get offer with trader info and booking_id
  SELECT 
    json_build_object(
      'id', bo.id,
      'inquiry_id', bo.inquiry_id,
      'status', bo.status,
      'total_cost_cents', bo.total_cost_cents,
      'platform_fee_percentage', bo.platform_fee_percentage,
      'platform_fee_cents', bo.platform_fee_cents,
      'total_cost_with_fee_cents', bo.total_cost_with_fee_cents,
      'valid_until', bo.valid_until,
      'notes', bo.notes,
      'created_at', bo.created_at,
      'updated_at', bo.updated_at,
      'booking_id', b.id, -- Add booking_id
      'inquiry', json_build_object(
        'id', bi.id,
        'trader_id', bi.trader_id,
        'start_date', bi.start_date,
        'end_date', bi.end_date,
        'trader', json_build_object(
          'id', p.user_id,
          'first_name', p.first_name,
          'last_name', p.last_name,
          'email', p.contact_email
        )
      ),
      'spaces', (
        SELECT json_agg(
          json_build_object(
            'id', bos.id,
            'space_id', bos.space_id,
            'space_allocated_m2', bos.space_allocated_m2,
            'price_per_m2_cents', bos.price_per_m2_cents,
            'offer_total_cents', bos.offer_total_cents,
            'comments', bos.comments,
            'space', json_build_object(
              'id', ms.id,
              'warehouse_id', ms.warehouse_id,
              'space_type', mst,
              'warehouse', json_build_object(
                'id', mw.id,
                'name', mw.name
              )
            )
          )
        )
        FROM booking_offer_spaces bos
        JOIN m_warehouse_spaces ms ON ms.id = bos.space_id
        JOIN m_space_types mst ON mst.id = ms.space_type_id
        JOIN m_warehouses mw ON mw.id = ms.warehouse_id
        WHERE bos.offer_id = bo.id
      ),
      'services', (
        SELECT json_agg(
          json_build_object(
            'id', bose.id,
            'service_id', bose.service_id,
            'pricing_type', bose.pricing_type,
            'quantity', bose.quantity,
            'price_per_hour_cents', bose.price_per_hour_cents,
            'price_per_unit_cents', bose.price_per_unit_cents,
            'unit_type', bose.unit_type,
            'fixed_price_cents', bose.fixed_price_cents,
            'offer_total_cents', bose.offer_total_cents,
            'comments', bose.comments,
            'service', json_build_object(
              'id', ws.id,
              'name', ws.name,
              'description', ws.description
            )
          )
        )
        FROM booking_offer_services bose
        JOIN warehouse_services ws ON ws.id = bose.service_id
        WHERE bose.offer_id = bo.id
      )
    ) INTO v_offer
  FROM booking_offers bo
  JOIN booking_inquiries bi ON bi.id = bo.inquiry_id
  JOIN profiles p ON p.user_id = bi.trader_id
  LEFT JOIN bookings b ON b.offer_id = bo.id -- Add join to bookings
  WHERE bi.id = p_inquiry_id
  AND (
    -- Allow access if user is the trader
    bi.trader_id = auth.uid()
    OR
    -- Or if user is an administrator
    EXISTS (
      SELECT 1 FROM user_roles ur
      JOIN roles r ON r.id = ur.role_id
      WHERE ur.user_id = auth.uid() 
      AND r.name = 'administrator'
    )
  )
  AND bo.status != 'draft'
  ORDER BY bo.created_at DESC
  LIMIT 1;

  RETURN v_offer;
END;
$$;

-- Add comments
COMMENT ON FUNCTION get_trader_offer IS 'Gets the latest non-draft offer for an inquiry with trader information and platform fee details';