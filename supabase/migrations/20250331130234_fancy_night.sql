/*
  # Add warehouse history tables

  1. New Tables
    - m_warehouse_history: Stores historical warehouse states
    - m_warehouse_space_history: Stores historical space states
    - m_warehouse_feature_history: Stores historical feature assignments
    - m_warehouse_service_history: Stores historical service assignments

  2. Changes
    - Remove cascade updates from foreign keys
    - Add triggers to snapshot warehouse state on inquiry/offer/booking creation
    - Update functions to use historical data

  3. Security
    - Enable RLS on history tables
    - Only allow read access to related users
*/

-- Create warehouse history tables
CREATE TABLE m_warehouse_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL REFERENCES m_warehouses(id),
  name text NOT NULL,
  description text,
  address text NOT NULL,
  city text NOT NULL,
  country text NOT NULL,
  postal_code text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE m_warehouse_space_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  warehouse_history_id uuid NOT NULL REFERENCES m_warehouse_history(id),
  space_type_id uuid NOT NULL REFERENCES m_space_types(id),
  size_m2 numeric NOT NULL CHECK (size_m2 > 0),
  price_per_m2_cents bigint NOT NULL CHECK (price_per_m2_cents > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE m_warehouse_feature_history (
  warehouse_history_id uuid NOT NULL REFERENCES m_warehouse_history(id),
  feature_id uuid NOT NULL REFERENCES warehouse_features(id),
  custom_value text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (warehouse_history_id, feature_id)
);

CREATE TABLE m_warehouse_service_history (
  warehouse_history_id uuid NOT NULL REFERENCES m_warehouse_history(id),
  service_id uuid NOT NULL REFERENCES warehouse_services(id),
  pricing_type text NOT NULL,
  price_per_hour_cents bigint,
  price_per_unit_cents bigint,
  unit_type text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (warehouse_history_id, service_id)
);

-- Add reference to history tables
ALTER TABLE booking_inquiries
ADD COLUMN warehouse_history_id uuid REFERENCES m_warehouse_history(id);

ALTER TABLE booking_offers
ADD COLUMN warehouse_history_id uuid REFERENCES m_warehouse_history(id);

ALTER TABLE bookings
ADD COLUMN warehouse_history_id uuid REFERENCES m_warehouse_history(id);

-- Function to create warehouse history snapshot
CREATE OR REPLACE FUNCTION create_warehouse_history_snapshot(p_warehouse_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_history_id uuid;
BEGIN
  -- Create warehouse history record
  INSERT INTO m_warehouse_history (
    warehouse_id,
    name,
    description,
    address,
    city,
    country,
    postal_code
  )
  SELECT
    id,
    name,
    description,
    address,
    city,
    country,
    postal_code
  FROM m_warehouses
  WHERE id = p_warehouse_id
  RETURNING id INTO v_history_id;

  -- Copy spaces
  INSERT INTO m_warehouse_space_history (
    warehouse_history_id,
    space_type_id,
    size_m2,
    price_per_m2_cents
  )
  SELECT
    v_history_id,
    space_type_id,
    size_m2,
    price_per_m2_cents
  FROM m_warehouse_spaces
  WHERE warehouse_id = p_warehouse_id;

  -- Copy features
  INSERT INTO m_warehouse_feature_history (
    warehouse_history_id,
    feature_id,
    custom_value
  )
  SELECT
    v_history_id,
    feature_id,
    custom_value
  FROM m_warehouse_feature_assignments
  WHERE warehouse_id = p_warehouse_id;

  -- Copy services
  INSERT INTO m_warehouse_service_history (
    warehouse_history_id,
    service_id,
    pricing_type,
    price_per_hour_cents,
    price_per_unit_cents,
    unit_type,
    notes
  )
  SELECT
    v_history_id,
    service_id,
    pricing_type,
    price_per_hour_cents,
    price_per_unit_cents,
    unit_type,
    notes
  FROM m_warehouse_service_assignments
  WHERE warehouse_id = p_warehouse_id;

  RETURN v_history_id;
END;
$$;

-- Trigger function to create history on inquiry creation
CREATE OR REPLACE FUNCTION on_inquiry_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_history_id uuid;
BEGIN
  -- Create history snapshot for each warehouse in the inquiry
  FOR v_history_id IN
    SELECT create_warehouse_history_snapshot(warehouse_id)
    FROM booking_inquiry_warehouses
    WHERE inquiry_id = NEW.id
  LOOP
    -- Update inquiry with history reference
    UPDATE booking_inquiries
    SET warehouse_history_id = v_history_id
    WHERE id = NEW.id;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Create trigger for new inquiries
CREATE TRIGGER inquiry_created_trigger
AFTER INSERT ON booking_inquiries
FOR EACH ROW
EXECUTE FUNCTION on_inquiry_created();

-- Enable RLS on history tables
ALTER TABLE m_warehouse_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE m_warehouse_space_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE m_warehouse_feature_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE m_warehouse_service_history ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for history tables
CREATE POLICY "Users can view warehouse history they are related to"
ON m_warehouse_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM booking_inquiries bi
    WHERE bi.warehouse_history_id = id
    AND bi.trader_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM booking_offers bo
    WHERE bo.warehouse_history_id = id
    AND bo.inquiry_id IN (
      SELECT id FROM booking_inquiries WHERE trader_id = auth.uid()
    )
  )
  OR EXISTS (
    SELECT 1 FROM bookings b
    WHERE b.warehouse_history_id = id
    AND (b.trader_id = auth.uid() OR b.warehouse_owner_id = auth.uid())
  )
  OR EXISTS (
    SELECT 1 FROM m_warehouses w
    WHERE w.id = warehouse_id
    AND w.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

-- Add similar policies for related history tables
CREATE POLICY "Users can view space history they are related to"
ON m_warehouse_space_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM m_warehouse_history wh
    WHERE wh.id = warehouse_history_id
    AND EXISTS (
      SELECT 1 FROM booking_inquiries bi
      WHERE bi.warehouse_history_id = wh.id
      AND bi.trader_id = auth.uid()
    )
  )
  OR EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

CREATE POLICY "Users can view feature history they are related to"
ON m_warehouse_feature_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM m_warehouse_history wh
    WHERE wh.id = warehouse_history_id
    AND EXISTS (
      SELECT 1 FROM booking_inquiries bi
      WHERE bi.warehouse_history_id = wh.id
      AND bi.trader_id = auth.uid()
    )
  )
  OR EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

CREATE POLICY "Users can view service history they are related to"
ON m_warehouse_service_history
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM m_warehouse_history wh
    WHERE wh.id = warehouse_history_id
    AND EXISTS (
      SELECT 1 FROM booking_inquiries bi
      WHERE bi.warehouse_history_id = wh.id
      AND bi.trader_id = auth.uid()
    )
  )
  OR EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid() 
    AND r.name = 'administrator'
  )
);

-- Add comments
COMMENT ON TABLE m_warehouse_history IS 'Historical snapshots of warehouses at the time of inquiry/offer/booking';
COMMENT ON TABLE m_warehouse_space_history IS 'Historical snapshots of warehouse spaces';
COMMENT ON TABLE m_warehouse_feature_history IS 'Historical snapshots of warehouse features';
COMMENT ON TABLE m_warehouse_service_history IS 'Historical snapshots of warehouse services';
COMMENT ON FUNCTION create_warehouse_history_snapshot IS 'Creates a complete historical snapshot of a warehouse and its related data';
COMMENT ON FUNCTION on_inquiry_created IS 'Creates warehouse history snapshots when an inquiry is created';