/*
  # Add user-specific conversation preferences

  1. New Tables
    - `user_conversation_preferences`
      - `user_id` (uuid, references auth.users)
      - `conversation_id` (uuid, references warehouse_inquiries)
      - `is_favorite` (boolean)
      - `last_read_at` (timestamptz)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `user_conversation_preferences`
    - Add policies for authenticated users to manage their preferences
*/

CREATE TABLE user_conversation_preferences (
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES warehouse_inquiries(id) ON DELETE CASCADE,
  is_favorite boolean DEFAULT false,
  last_read_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, conversation_id)
);

-- Enable RLS
ALTER TABLE user_conversation_preferences ENABLE ROW LEVEL SECURITY;

-- Policies for user_conversation_preferences
CREATE POLICY "Users can manage their own conversation preferences"
  ON user_conversation_preferences
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Function to toggle conversation favorite status
CREATE OR REPLACE FUNCTION toggle_conversation_favorite(p_conversation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_favorite boolean;
BEGIN
  -- Get current favorite status or insert new record
  INSERT INTO user_conversation_preferences (user_id, conversation_id, is_favorite)
  VALUES (auth.uid(), p_conversation_id, true)
  ON CONFLICT (user_id, conversation_id) 
  DO UPDATE SET 
    is_favorite = NOT user_conversation_preferences.is_favorite,
    updated_at = now()
  RETURNING is_favorite INTO v_current_favorite;
  
  RETURN v_current_favorite;
END;
$$;