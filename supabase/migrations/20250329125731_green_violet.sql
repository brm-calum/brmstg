/*
  # Fix send_email function HTTP request structure

  1. Changes
    - Updates send_email function to match working example
    - Fixes HTTP request structure and header formatting
    - Simplifies payload handling

  2. Security
    - Maintains existing security measures
    - No changes to RLS policies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS send_email();

-- Create updated send_email function
CREATE OR REPLACE FUNCTION send_email()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email email_queue%ROWTYPE;
  v_config email_config%ROWTYPE;
  retval json;
BEGIN
  -- Get email configuration
  SELECT * INTO v_config FROM email_config LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email configuration not found';
  END IF;

  -- Get next email to process
  SELECT * INTO v_email
  FROM email_queue
  WHERE status = 'pending'
  AND (next_retry_at IS NULL OR next_retry_at <= CURRENT_TIMESTAMP)
  ORDER BY created_at ASC
  LIMIT 1
  FOR UPDATE SKIP LOCKED;

  -- Exit if no emails to process
  IF v_email IS NULL THEN
    RETURN;
  END IF;

  -- Log attempt
  INSERT INTO brm_logs (
    activity_type,
    activity_data,
    status
  ) VALUES (
    'email',
    jsonb_build_object(
      'email_id', v_email.id,
      'to_email', v_email.to_email,
      'subject', v_email.subject
    ),
    'processing'
  );

  BEGIN
    -- Send request using the working example structure
    SELECT * INTO retval
    FROM http((
      'POST',
      'https://api.mailjet.com/v3.1/send',
      ARRAY[http_header(
        'Authorization',
        'Basic ' || regexp_replace(
          encode(
            (v_config.api_key || ':' || v_config.api_secret)::bytea, 
            'base64'
          )::text, 
          '\s', 
          '', 
          'g'
        )
      )],
      'application/json',
      json_build_object(
        'Messages', json_build_array(
          json_build_object(
            'From', json_build_object(
              'Email', v_config.from_email,
              'Name', v_config.from_name
            ),
            'To', json_build_array(
              json_build_object(
                'Email', v_email.to_email,
                'Name', v_email.to_name
              )
            ),
            'Subject', v_email.subject,
            'TextPart', v_email.text_content,
            'HTMLPart', COALESCE(v_email.html_content, v_email.text_content)
          )
        )
      )::text
    ));

    -- Mark email as sent
    UPDATE email_queue
    SET 
      status = 'sent',
      updated_at = CURRENT_TIMESTAMP
    WHERE id = v_email.id;

    -- Log success
    UPDATE brm_logs
    SET 
      status = 'success',
      activity_data = activity_data || jsonb_build_object(
        'sent_at', CURRENT_TIMESTAMP,
        'response', retval
      )
    WHERE activity_type = 'email' 
    AND (activity_data->>'email_id')::uuid = v_email.id;

  EXCEPTION WHEN OTHERS THEN
    -- Handle error
    IF v_email.retry_count >= 3 THEN
      -- Mark as failed after max retries
      UPDATE email_queue
      SET
        status = 'failed',
        error_message = SQLERRM,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = v_email.id;

      -- Log failure
      UPDATE brm_logs
      SET 
        status = 'error',
        error_message = SQLERRM,
        activity_data = activity_data || jsonb_build_object(
          'failed_at', CURRENT_TIMESTAMP,
          'retry_count', v_email.retry_count
        )
      WHERE activity_type = 'email' 
      AND (activity_data->>'email_id')::uuid = v_email.id;
    ELSE
      -- Schedule retry with exponential backoff
      UPDATE email_queue
      SET
        retry_count = retry_count + 1,
        next_retry_at = CURRENT_TIMESTAMP + (power(2, retry_count) * interval '1 minute'),
        error_message = SQLERRM,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = v_email.id;

      -- Log retry
      UPDATE brm_logs
      SET 
        status = 'retrying',
        error_message = SQLERRM,
        activity_data = activity_data || jsonb_build_object(
          'retry_count', v_email.retry_count + 1,
          'next_retry', CURRENT_TIMESTAMP + (power(2, v_email.retry_count) * interval '1 minute')
        )
      WHERE activity_type = 'email' 
      AND (activity_data->>'email_id')::uuid = v_email.id;
    END IF;
  END;
END;
$$;

-- Add comments
COMMENT ON FUNCTION send_email IS 'Processes pending emails in the queue and sends them via Mailjet API';