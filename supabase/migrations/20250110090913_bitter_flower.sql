/*
  # Add updated_at column to file_labels table

  1. Changes
    - Add updated_at column to file_labels table
    - Add trigger to automatically update updated_at
    - Update existing rows with current timestamp

  2. Security
    - No changes to RLS policies
*/

-- Add updated_at column
ALTER TABLE file_labels 
ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();

-- Create function for updating timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger
CREATE TRIGGER update_file_labels_updated_at
  BEFORE UPDATE ON file_labels
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Update existing rows to have current timestamp
UPDATE file_labels SET updated_at = now();