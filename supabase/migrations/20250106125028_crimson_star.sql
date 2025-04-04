/*
  # Add profile fields table

  1. New Tables
    - `profile_fields`: Configurable profile fields
      - `id` (uuid, primary key)
      - `name` (text): Field name/key
      - `label` (text): Display label
      - `type` (text): Input type (text, email, select, etc)
      - `required` (boolean): Whether field is required
      - `options` (text[]): Options for select fields
      - `display_order` (integer): Order to display fields
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS
    - Add policy for authenticated users to read fields
*/

CREATE TABLE profile_fields (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  label text NOT NULL,
  type text NOT NULL,
  required boolean NOT NULL DEFAULT false,
  options text[] DEFAULT NULL,
  display_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE profile_fields ENABLE ROW LEVEL SECURITY;

-- Add read policy for authenticated users
CREATE POLICY "Allow authenticated users to read profile fields"
  ON profile_fields
  FOR SELECT
  TO authenticated
  USING (true);

-- Insert default fields
INSERT INTO profile_fields (name, label, type, required, display_order) VALUES
  ('first_name', 'First Name', 'text', true, 1),
  ('last_name', 'Last Name', 'text', true, 2),
  ('phone', 'Phone Number', 'tel', false, 3),
  ('company_name', 'Company Name', 'text', false, 4),
  ('job_title', 'Job Title', 'text', false, 5),
  ('industry', 'Industry', 'select', false, 6),
  ('company_size', 'Company Size', 'select', false, 7);

-- Update select field options
UPDATE profile_fields 
SET options = ARRAY[
  'Manufacturing',
  'Retail',
  'Logistics',
  'E-commerce',
  'Other'
]
WHERE name = 'industry';

UPDATE profile_fields
SET options = ARRAY[
  '1-10 employees',
  '11-50 employees',
  '51-200 employees',
  '201-1000 employees',
  '1000+ employees'
]
WHERE name = 'company_size';