/*
  # Fix send_email function to use existing http_request type

  1. Changes
    - Updates send_email function to use existing http_request type structure
    - Properly formats headers using http_header type
    - Maintains all existing functionality and error handling

  2. Security
    - Maintains existing security measures
    - No changes to RLS policies
*/

-- Update send_email function to use existing http_request type
CREATE OR REPLACE FUNCTION send_email()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email email_queue%ROWTYPE;
  v_config email_config%ROWTYPE;
  v_url text := 'https://api.mailjet.com/v3.1/send';
  v_payload json;
  v_response json;
  v_max_retries constant integer := 3;
  v_auth text;
  v_headers extensions.http_header[];
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
    -- Prepare email payload
    v_payload := json_build_object(
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
    );

    -- Prepare auth header
    v_auth := encode((v_config.api_key || ':' || v_config.api_secret)::bytea, 'base64');
    
    -- Prepare headers
    v_headers := ARRAY[
      ROW('Authorization'::text, 'Basic ' || v_auth::text)::extensions.http_header,
      ROW('Content-Type'::text, 'application/json'::text)::extensions.http_header
    ];

    -- Send email using Mailjet API
    SELECT content::json INTO v_response
    FROM extensions.http((
      'POST',                                    -- method
      v_url,                                    -- uri
      v_headers,                                -- headers
      'application/json',                       -- content_type
      v_payload::text                           -- content
    )::http_request);

    -- Check response
    IF v_response IS NULL OR v_response->>'Messages' IS NULL THEN
      RAISE EXCEPTION 'Invalid response from Mailjet API';
    END IF;

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
        'response', v_response
      )
    WHERE activity_type = 'email' 
    AND (activity_data->>'email_id')::uuid = v_email.id;

  EXCEPTION WHEN OTHERS THEN
    -- Handle error
    IF v_email.retry_count >= v_max_retries THEN
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