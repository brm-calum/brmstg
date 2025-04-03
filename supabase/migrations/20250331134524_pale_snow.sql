/*
  # Fix email queue status constraint

  1. Changes
    - Updates email_queue status check constraint to include 'cancelled'
    - Maintains existing functionality and security

  2. Security
    - Maintains existing RLS policies
*/

-- Drop existing status check constraint
ALTER TABLE email_queue
DROP CONSTRAINT IF EXISTS email_queue_status_check;

-- Add updated status check constraint
ALTER TABLE email_queue
ADD CONSTRAINT email_queue_status_check
CHECK (status IN ('pending', 'sent', 'failed', 'cancelled'));

-- Add comments
COMMENT ON CONSTRAINT email_queue_status_check ON email_queue IS 'Validates email queue status values';