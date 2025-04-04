/*
  # Add user-specific conversation priorities

  1. New Tables
    - `user_conversation_priorities` - Stores user-specific priority settings for conversations
      - `user_id` (uuid, references auth.users)
      - `conversation_id` (uuid, references warehouse_inquiries)
      - `is_priority` (boolean)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for user access
*/

-- Create table for user-specific conversation priorities
CREATE TABLE user_conversation_priorities (
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  conversation_id uuid REFERENCES warehouse_inquiries(id) ON DELETE CASCADE,
  is_priority boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, conversation_id)
);

-- Enable RLS
ALTER TABLE user_conversation_priorities ENABLE ROW LEVEL SECURITY;

-- Add policy for users to manage their own priorities
CREATE POLICY "Users can manage their own conversation priorities"
  ON user_conversation_priorities
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Function to toggle conversation priority for a specific user
CREATE OR REPLACE FUNCTION toggle_user_conversation_priority(p_conversation_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_priority boolean;
BEGIN
  -- Get current priority status or insert new record
  INSERT INTO user_conversation_priorities (user_id, conversation_id, is_priority)
  VALUES (auth.uid(), p_conversation_id, true)
  ON CONFLICT (user_id, conversation_id) 
  DO UPDATE SET 
    is_priority = NOT user_conversation_priorities.is_priority,
    updated_at = now()
  RETURNING is_priority INTO v_current_priority;
  
  RETURN v_current_priority;
END;
$$;