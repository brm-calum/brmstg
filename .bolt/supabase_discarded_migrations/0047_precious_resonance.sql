-- Drop existing trigger and function
DROP TRIGGER IF EXISTS handle_new_user_trigger ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- Create improved user registration handler
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  role_ids uuid[];
BEGIN
  -- Get all role IDs except service_provider
  SELECT array_agg(id) INTO role_ids
  FROM roles
  WHERE name != 'service_provider'
  FOR UPDATE;

  -- Create profile
  INSERT INTO profiles (
    user_id,
    first_name,
    last_name
  ) VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'first_name', ''), ''),
    COALESCE(NULLIF(NEW.raw_user_meta_data->>'last_name', ''), '')
  );

  -- Assign all roles except service_provider
  INSERT INTO user_roles (user_id, role_id)
  SELECT NEW.id, unnest(role_ids)
  ON CONFLICT (user_id, role_id) DO NOTHING;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error in handle_new_user: %', SQLERRM;
  RETURN NULL;
END;
$$;

-- Create trigger for new user registration
CREATE TRIGGER handle_new_user_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- Fix existing users to have all roles except service_provider
DO $$
DECLARE
  user_record RECORD;
  role_ids uuid[];
BEGIN
  -- Get all role IDs except service_provider
  SELECT array_agg(id) INTO role_ids
  FROM roles
  WHERE name != 'service_provider';

  -- Process each user
  FOR user_record IN 
    SELECT id FROM auth.users
  LOOP
    -- Assign all roles except service_provider
    INSERT INTO user_roles (user_id, role_id)
    SELECT user_record.id, unnest(role_ids)
    ON CONFLICT (user_id, role_id) DO NOTHING;
  END LOOP;
END;
$$;