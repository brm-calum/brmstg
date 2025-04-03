/*
  # Fix warehouse space references

  1. Changes
    - Remove cascade updates from booking_offer_spaces
    - Add space history reference to booking_offer_spaces
    - Update functions to use space history

  2. Security
    - Maintains existing RLS policies
*/

-- Remove cascade update from booking_offer_spaces
ALTER TABLE booking_offer_spaces
DROP CONSTRAINT IF EXISTS booking_offer_spaces_space_id_fkey;

-- Add space history reference
ALTER TABLE booking_offer_spaces
ADD COLUMN space_history_id uuid REFERENCES m_warehouse_space_history(id);

-- Function to get space history for an offer
CREATE OR REPLACE FUNCTION get_offer_space_history(p_offer_id uuid)
RETURNS TABLE (
  space_id uuid,
  space_history_id uuid,
  space_type_id uuid,
  size_m2 numeric,
  price_per_m2_cents bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT 
    bos.space_id,
    bos.space_history_id,
    wsh.space_type_id,
    wsh.size_m2,
    wsh.price_per_m2_cents
  FROM booking_offer_spaces bos
  LEFT JOIN m_warehouse_space_history wsh ON wsh.id = bos.space_history_id
  WHERE bos.offer_id = p_offer_id;
$$;

-- Function to create space history for an offer
CREATE OR REPLACE FUNCTION create_offer_space_history(p_offer_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_space_record RECORD;
  v_history_id uuid;
BEGIN
  -- For each space in the offer
  FOR v_space_record IN
    SELECT 
      bos.id as offer_space_id,
      ws.*
    FROM booking_offer_spaces bos
    JOIN m_warehouse_spaces ws ON ws.id = bos.space_id
    WHERE bos.offer_id = p_offer_id
    AND bos.space_history_id IS NULL
  LOOP
    -- Create space history record
    INSERT INTO m_warehouse_space_history (
      warehouse_history_id,
      space_type_id,
      size_m2,
      price_per_m2_cents
    ) VALUES (
      (SELECT warehouse_history_id FROM booking_offers WHERE id = p_offer_id),
      v_space_record.space_type_id,
      v_space_record.size_m2,
      v_space_record.price_per_m2_cents
    ) RETURNING id INTO v_history_id;

    -- Update offer space with history reference
    UPDATE booking_offer_spaces
    SET space_history_id = v_history_id
    WHERE id = v_space_record.offer_space_id;
  END LOOP;
END;
$$;

-- Trigger function to create space history when offer is created
CREATE OR REPLACE FUNCTION on_offer_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Create space history records
  PERFORM create_offer_space_history(NEW.id);
  RETURN NEW;
END;
$$;

-- Create trigger for new offers
CREATE TRIGGER offer_created_trigger
AFTER INSERT ON booking_offers
FOR EACH ROW
EXECUTE FUNCTION on_offer_created();

-- Add comments
COMMENT ON COLUMN booking_offer_spaces.space_history_id IS 'Reference to historical space state';
COMMENT ON FUNCTION get_offer_space_history IS 'Gets historical space data for an offer';
COMMENT ON FUNCTION create_offer_space_history IS 'Creates historical space records for an offer';
COMMENT ON FUNCTION on_offer_created IS 'Creates space history records when an offer is created';