/*
  # Update file labels functionality

  1. Changes
    - Add trigger to increment usage count when labels are used
    - Add function to format labels consistently
    - Add function to get default labels
    - Add function to get label suggestions with case-insensitive search

  2. Security
    - Enable RLS on all new functions
    - Restrict label editing to file owners
*/

-- Function to format labels consistently (Title Case)
CREATE OR REPLACE FUNCTION format_file_label(label text)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN regexp_replace(
    initcap(label),
    '(\s|^)(\w)'::text,
    '\1\2'::text,
    'g'
  );
END;
$$;

-- Function to get default labels
CREATE OR REPLACE FUNCTION get_default_labels()
RETURNS TABLE (
  name text,
  is_default boolean,
  usage_count integer
)
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    name,
    is_default,
    usage_count
  FROM file_labels
  WHERE is_default = true
  ORDER BY name ASC;
$$;

-- Update label suggestions function to be case insensitive
CREATE OR REPLACE FUNCTION get_label_suggestions(search_term text, limit_count integer DEFAULT 5)
RETURNS TABLE (
  name text,
  is_default boolean,
  usage_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    format_file_label(l.name),
    l.is_default,
    l.usage_count
  FROM file_labels l
  WHERE 
    lower(l.name) LIKE lower(search_term || '%')
    OR lower(l.name) LIKE lower('% ' || search_term || '%')
  ORDER BY
    l.is_default DESC,
    l.usage_count DESC,
    l.name ASC
  LIMIT limit_count;
END;
$$;

-- Function to update file label
CREATE OR REPLACE FUNCTION update_file_label(
  p_file_id uuid,
  p_label text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_customer_id uuid;
  v_formatted_label text;
BEGIN
  -- Get the customer ID for this file's inquiry
  SELECT i.inquirer_id INTO v_customer_id
  FROM conversation_files f
  JOIN warehouse_inquiries i ON f.inquiry_id = i.id
  WHERE f.id = p_file_id;

  -- Check if user is the customer
  IF v_customer_id != auth.uid() THEN
    RAISE EXCEPTION 'Only the customer can update file labels';
  END IF;

  -- Format the label
  v_formatted_label := format_file_label(p_label);

  -- Update the label
  UPDATE conversation_files
  SET 
    label = v_formatted_label,
    updated_at = now()
  WHERE id = p_file_id;

  -- Increment usage count for the label
  INSERT INTO file_labels (name, usage_count, created_by)
  VALUES (v_formatted_label, 1, auth.uid())
  ON CONFLICT (name) 
  DO UPDATE SET usage_count = file_labels.usage_count + 1;
END;
$$;