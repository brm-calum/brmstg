/*
  # Fix update_file_label function

  1. Changes
    - Fix column reference from inquirer_id to user_id
    - Add proper error handling
    - Add validation for empty labels
    - Add proper type casting
    - Add transaction handling

  2. Security
    - Function remains security definer
    - Maintains customer-only update restriction
*/

-- Drop existing function
DROP FUNCTION IF EXISTS update_file_label(uuid, text);

-- Create improved function with proper column references
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
  -- Validate input
  IF p_label IS NULL OR trim(p_label) = '' THEN
    RAISE EXCEPTION 'Label cannot be empty';
  END IF;

  -- Get the customer ID (user_id) for this file's inquiry
  SELECT i.user_id INTO v_customer_id
  FROM conversation_files f
  JOIN warehouse_inquiries i ON f.inquiry_id = i.id
  WHERE f.id = p_file_id;

  -- Check if file exists
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'File not found';
  END IF;

  -- Check if user is the customer
  IF v_customer_id != auth.uid() THEN
    RAISE EXCEPTION 'Only the customer can update file labels';
  END IF;

  -- Format the label
  v_formatted_label := format_file_label(p_label);

  -- Start transaction
  BEGIN
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
    DO UPDATE SET 
      usage_count = file_labels.usage_count + 1,
      updated_at = now();

    -- If no rows were affected by the update, raise an error
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Failed to update file label';
    END IF;

  EXCEPTION
    WHEN others THEN
      -- Rollback transaction on any error
      RAISE EXCEPTION 'Failed to update file label: %', SQLERRM;
  END;
END;
$$;