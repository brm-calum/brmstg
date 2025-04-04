-- Fetch warehouses with their types, images, features, and services
SELECT 
  w.*,
  wt.name as type_name,
  json_agg(DISTINCT jsonb_build_object(
    'id', wi.id,
    'url', wi.url,
    'order', wi.order
  )) FILTER (WHERE wi.id IS NOT NULL) as images,
  json_agg(DISTINCT jsonb_build_object(
    'id', wf.id,
    'name', wf.name,
    'type', wf.type,
    'icon', wf.icon,
    'custom_value', wfa.custom_value
  )) FILTER (WHERE wf.id IS NOT NULL) as features,
  json_agg(DISTINCT jsonb_build_object(
    'id', ws.id,
    'name', ws.name,
    'description', ws.description,
    'icon', ws.icon,
    'pricing_type', wsa.pricing_type,
    'hourly_rate_cents', wsa.price_per_hour_cents,
    'unit_rate_cents', wsa.price_per_unit_cents,
    'unit_type', wsa.unit_type,
    'notes', wsa.notes
  )) FILTER (WHERE ws.id IS NOT NULL) as services
FROM warehouses w
LEFT JOIN warehouse_types wt ON w.type_id = wt.id
LEFT JOIN warehouse_images wi ON w.id = wi.warehouse_id
LEFT JOIN warehouse_feature_assignments wfa ON w.id = wfa.warehouse_id
LEFT JOIN warehouse_features wf ON wfa.feature_id = wf.id
LEFT JOIN warehouse_service_assignments wsa ON w.id = wsa.warehouse_id
LEFT JOIN warehouse_services ws ON wsa.service_id = ws.id
WHERE w.is_active = true
  OR w.owner_id = auth.uid()  -- Include user's own inactive warehouses when authenticated
GROUP BY w.id, wt.id
ORDER BY w.created_at DESC;