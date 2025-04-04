/*
  # File Label Management System

  1. New Tables
    - `file_labels`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `is_default` (boolean)
      - `usage_count` (integer)
      - `created_at` (timestamp)
      - `created_by` (uuid, references auth.users)

  2. Security
    - Enable RLS on `file_labels`
    - Add policies for reading and managing labels
*/

-- Create file labels table
CREATE TABLE file_labels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  is_default boolean NOT NULL DEFAULT false,
  usage_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE file_labels ENABLE ROW LEVEL SECURITY;

-- Add read policy for all authenticated users
CREATE POLICY "Allow authenticated users to read labels"
  ON file_labels
  FOR SELECT
  TO authenticated
  USING (true);

-- Add insert policy for authenticated users (non-default labels only)
CREATE POLICY "Allow authenticated users to create custom labels"
  ON file_labels
  FOR INSERT
  TO authenticated
  WITH CHECK (
    NOT is_default
    AND created_by = auth.uid()
  );

-- Insert default labels
INSERT INTO file_labels (name, is_default) VALUES
  ('Bill of Lading', true),
  ('Certificate', true),
  ('Contract', true);

-- Function to get label suggestions based on input
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
    l.name,
    l.is_default,
    l.usage_count
  FROM file_labels l
  WHERE 
    l.name ILIKE search_term || '%'
    OR l.name ILIKE '% ' || search_term || '%'
  ORDER BY
    l.is_default DESC,
    l.usage_count DESC,
    l.name ASC
  LIMIT limit_count;
END;
$$;