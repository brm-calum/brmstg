/*
  # Fix get_user_inquiries function

  1. Changes
    - Fix column references in the query
    - Add proper joins for inquirer information
    - Include file metadata in the response
    - Add proper type casting for JSON aggregation
    - Fix file associations with responses

  2. Security
    - Function is security definer to ensure proper RLS
    - Only returns inquiries where user is either inquirer or recipient
*/

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_inquiries();

-- Create improved function with proper column references and joins
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
      ) as files
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
      ) as files
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
      ) as responses
    FROM inquiry_responses r
    LEFT JOIN profiles p ON r.user_id = p.user_id
    LEFT JOIN response_files rf ON r.id = rf.response_id
    GROUP BY r.inquiry_id
  )
  SELECT 
    json_build_object(
      'inquiry_id', i.id,
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
      'unread_count', (
        SELECT COUNT(*)
        FROM inquiry_responses ir
        WHERE ir.inquiry_id = i.id
        AND ir.recipient_id = auth.uid()
        AND ir.read = false
      )
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