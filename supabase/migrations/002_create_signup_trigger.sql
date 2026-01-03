-- 002_create_signup_trigger.sql
-- Purpose: Create a trigger and SECURITY DEFINER function that inserts a row
-- into public.users when a new auth.users row is created (OAuth signup).
-- This file is idempotent where possible.

-- Assumptions:
-- - public.users table exists (created by 001_create_users_rls.sql).
-- - auth.users is the Supabase Auth users table.
-- - raw_user_meta_data is JSON containing provider info from OAuth (Discord).
-- - We trust auth system to provide correct new.id (uuid).

-- ============================
-- 0) Create/replace function to handle new users
-- ============================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  v_provider_id text;
  v_oauth_username text;
  v_full_name text;
  v_avatar_url text;
BEGIN
  -- Extract safely using ->> operator (returns null if key missing)
  v_provider_id := NEW.raw_user_meta_data ->> 'provider_id';
  v_oauth_username := NEW.raw_user_meta_data ->> 'name';
  v_full_name := NEW.raw_user_meta_data ->> 'full_name';
  v_avatar_url := NEW.raw_user_meta_data ->> 'avatar_url';

  -- Basic validation: provider id and username required in this use case.
  IF v_provider_id IS NULL OR v_oauth_username IS NULL THEN
    RAISE EXCEPTION 'handle_new_user: missing provider_id or name for auth.user % - skipping profile insert', NEW.id;
    RETURN NEW;
  END IF;

  -- Insert only if a corresponding row doesn't already exist (idempotency)
  BEGIN
    INSERT INTO public.users (
      user_id,
      provider_id,
      oauth_username,
      email,
      display_name,
      avatar_url,
      created_at,
      updated_at
    )
    VALUES (
      NEW.id,
      v_provider_id,
      v_oauth_username,
      NEW.email,
      COALESCE(v_full_name, NEW.email, v_oauth_username),
      v_avatar_url,
      NOW(),
      NOW()
    )
    ON CONFLICT (user_id) DO NOTHING; -- safe if row already exists
  EXCEPTION WHEN unique_violation THEN
    -- If unique constraints on provider_id or oauth_username conflict, skip insert and log.
    RAISE NOTICE 'handle_new_user: unique constraint conflict while inserting profile for auth.user % - skipping', NEW.id;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Restrict who can execute the function. Revoke public execute.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;

-- ============================
-- 1) Create trigger on auth.users AFTER INSERT
-- ============================
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();