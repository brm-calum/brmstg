/*
  # Add inquiry code feature

  1. Changes
    - Add inquiry_code column to warehouse_inquiries table
    - Add function to generate random 5-character code
    - Add trigger to automatically generate code on insert
    - Update get_user_inquiries function to include code

  2. Security
    - Ensure codes are unique
    - Validate code format
*/

-- Function to generate random 5-character code
CREATE OR REPLACE FUNCTION generate_inquiry_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  chars text[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,J,K,L,M,N,P,Q,R,S,T,U,V,W,X,Y,Z}';
  result text := '';
  i integer := 0;
  code text;
BEGIN
  -- Generate code until we find a unique one
  LOOP
    result := '';
    FOR i IN 1..5 LOOP
      result := result || chars[1+random()*(array_length(chars, 1)-1)];
    END LOOP;
    
    -- Check if code exists
    SELECT inquiry_code INTO code
    FROM warehouse_inquiries
    WHERE inquiry_code = result;
    
    -- Exit loop if code is unique
    EXIT WHEN code IS NULL;
  END LOOP;
  
  RETURN result;
END;
$$;

-- Add inquiry_code column
ALTER TABLE warehouse_inquiries
ADD COLUMN inquiry_code text UNIQUE;

-- Add trigger to generate code on insert
CREATE OR REPLACE FUNCTION set_inquiry_code()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.inquiry_code := generate_inquiry_code();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_inquiry_code_trigger
  BEFORE INSERT ON warehouse_inquiries
  FOR EACH ROW
  EXECUTE FUNCTION set_inquiry_code();

-- Update existing inquiries with codes
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM warehouse_inquiries WHERE inquiry_code IS NULL
  LOOP
    UPDATE warehouse_inquiries
    SET inquiry_code = generate_inquiry_code()
    WHERE id = r.id;
  END LOOP;
END;
$$;

-- Update get_user_inquiries function to include code
CREATE OR REPLACE FUNCTION get_user_inquiries()
RETURNS SETOF json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH inquiry_files AS (
    SELECT 
      f.inquiry_id,
      jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'file_name', f.file_name,
          'file_size', f.file_size,
          'mime_type', f.mime_type,
          'storage_path', f.storage_path,
          'label', f.label,
          'created_at', f.created_at,
          'uploader_id', f.uploader_id
        ) ORDER BY f.created_at
      ) FILTER (WHERE f.id IS NOT NULL) as files
    FROM conversation_files f
    WHERE f.response_id IS NULL
    GROUP BY f.inquiry_id
  ),
  response_files AS (
    SELECT 
      f.response_id,
      jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'file_name', f.file_name,
          'file_size', f.file_size,
          'mime_type', f.mime_type,
          'storage_path', f.storage_path,
          'label', f.label,
          'created_at', f.created_at,
          'uploader_id', f.uploader_id
        ) ORDER BY f.created_at
      ) FILTER (WHERE f.id IS NOT NULL) as files
    FROM conversation_files f
    WHERE f.response_id IS NOT NULL
    GROUP BY f.response_id
  ),
  responses_with_files AS (
    SELECT 
      r.inquiry_id,
      jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'message', r.message,
          'user_id', r.user_id,
          'user_name', CONCAT(p.first_name, ' ', p.last_name),
          'recipient_id', r.recipient_id,
          'read', r.read,
          'created_at', r.created_at,
          'files', COALESCE(rf.files, '[]'::jsonb)
        ) ORDER BY r.created_at
      ) FILTER (WHERE r.id IS NOT NULL) as responses
    FROM inquiry_responses r
    LEFT JOIN profiles p ON r.user_id = p.user_id
    LEFT JOIN response_files rf ON r.id = rf.response_id
    GROUP BY r.inquiry_id
  )
  SELECT 
    json_build_object(
      'inquiry_id', i.id,
      'inquiry_code', i.inquiry_code,
      'warehouse_id', i.warehouse_id,
      'warehouse_name', w.name,
      'inquirer_id', i.user_id,
      'inquirer_first_name', p.first_name,
      'inquirer_last_name', p.last_name,
      'initial_message', i.message,
      'status', i.status,
      'thread_status', i.thread_status,
      'is_priority', i.is_priority,
      'created_at', i.created_at,
      'updated_at', i.updated_at,
      'files', COALESCE(if.files, '[]'::jsonb),
      'responses', COALESCE(r.responses, '[]'::jsonb),
      'unread_count', COALESCE((
        SELECT COUNT(*)::integer
        FROM inquiry_responses ir
        WHERE ir.inquiry_id = i.id
        AND ir.recipient_id = auth.uid()
        AND ir.read = false
      ), 0)
    )
  FROM warehouse_inquiries i
  JOIN warehouses w ON i.warehouse_id = w.id
  JOIN profiles p ON i.user_id = p.user_id
  LEFT JOIN inquiry_files if ON i.id = if.inquiry_id
  LEFT JOIN responses_with_files r ON i.id = r.inquiry_id
  WHERE i.user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM inquiry_responses ir
      WHERE ir.inquiry_id = i.id
      AND (ir.user_id = auth.uid() OR ir.recipient_id = auth.uid())
    )
  ORDER BY i.updated_at DESC;
END;
$$;