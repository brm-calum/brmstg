/*
  # Update get_booking_offers function

  1. Changes
    - Adds warehouse name to spaces
    - Adds offer_total_cents to spaces
    - Adds pricing_type and rate details to services
    - Adds offer_total_cents to services
    - Adds platform fee and total cost details

  2. Security
    - Maintains existing RLS policies
*/

-- Update get_booking_offers function
CREATE OR REPLACE FUNCTION get_booking_offers(p_inquiry_id uuid)
RETURNS json[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN ARRAY(
    SELECT json_build_object(
      'id', bo.id,
      'status', bo.status,
      'total_cost_cents', bo.total_cost_cents,
      'platform_fee_percentage', bo.platform_fee_percentage,
      'platform_fee_cents', bo.platform_fee_cents,
      'total_cost_with_fee_cents', bo.total_cost_with_fee_cents,
      'valid_until', bo.valid_until,
      'notes', bo.notes,
      'created_at', bo.created_at,
      'booking_id', b.id,
      'spaces', (
        SELECT json_agg(json_build_object(
          'id', bos.id,
          'space_type', mst.name,
          'size_m2', bos.space_allocated_m2,
          'price_per_m2_cents', bos.price_per_m2_cents,
          'offer_total_cents', bos.offer_total_cents,
          'space', json_build_object(
            'warehouse', json_build_object(
              'id', mw.id,
              'name', mw.name
            )
          )
        ))
        FROM booking_offer_spaces bos
        JOIN m_warehouse_spaces mws ON mws.id = bos.space_id
        JOIN m_space_types mst ON mst.id = mws.space_type_id
        JOIN m_warehouses mw ON mw.id = mws.warehouse_id
        WHERE bos.offer_id = bo.id
      ),
      'services', (
        SELECT json_agg(json_build_object(
          'id', bos.id,
          'name', ws.name,
          'quantity', bos.quantity,
          'pricing_type', bos.pricing_type,
          'price_per_hour_cents', bos.price_per_hour_cents,
          'price_per_unit_cents', bos.price_per_unit_cents,
          'unit_type', bos.unit_type,
          'fixed_price_cents', bos.fixed_price_cents,
          'offer_total_cents', bos.offer_total_cents
        ))
        FROM booking_offer_services bos
        JOIN warehouse_services ws ON ws.id = bos.service_id
        WHERE bos.offer_id = bo.id
      )
    )
    FROM booking_offers bo
    LEFT JOIN bookings b ON b.offer_id = bo.id
    WHERE bo.inquiry_id = p_inquiry_id
    ORDER BY bo.created_at DESC
  );
END;
$$;

-- Add comments
COMMENT ON FUNCTION get_booking_offers IS 'Gets all offers for an inquiry with complete space, service and fee details';