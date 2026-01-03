-- 001_create_users_rls.sql
-- Purpose: Create public.users table, RLS policies, view, triggers, and helper functions.

-- ============================
-- 0) Create table if it doesn't exist
-- ============================
CREATE TABLE IF NOT EXISTS public.users (
  user_id uuid NOT NULL,
  provider_id text NOT NULL,
  oauth_username text NOT NULL,
  email character varying NULL,
  display_name text NULL,
  avatar_url text NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (user_id),
  CONSTRAINT users_oauth_username_key UNIQUE (oauth_username),
  CONSTRAINT users_provider_id_key UNIQUE (provider_id),
  CONSTRAINT users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON UPDATE CASCADE ON DELETE CASCADE
) TABLESPACE pg_default;

-- ============================
-- 1) Ensure updated_at is set on UPDATE
-- ============================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS users_set_updated_at ON public.users;
CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================
-- 2) Enable Row Level Security
-- ============================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- ============================
-- 3) Index for policy performance
-- ============================
CREATE INDEX IF NOT EXISTS idx_users_user_id ON public.users(user_id);

-- ============================
-- 4) RLS Policies
-- ============================

-- 4a) Allow authenticated users to SELECT only their own row
CREATE POLICY users_select_own_profile
  ON public.users
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- 4b) Allow authenticated users to INSERT only rows that match auth.uid()
CREATE POLICY users_self_insert
  ON public.users
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 4c) Allow authenticated users to UPDATE only their own row, and prevent changing user_id
CREATE POLICY users_update_own_profile
  ON public.users
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Note: No DELETE policy — authenticated users cannot delete their row.

-- ============================
-- 5) Public view for directory/listing (safe columns)
-- ============================
CREATE OR REPLACE VIEW public.user_profiles_public AS
SELECT
  user_id,
  oauth_username,
  display_name,
  avatar_url
FROM public.users;

GRANT SELECT ON public.user_profiles_public TO authenticated;

-- ============================
-- 6) Immutable fields protection
-- ============================
CREATE OR REPLACE FUNCTION public.prevent_system_field_updates()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    RAISE EXCEPTION 'user_id cannot be changed';
  END IF;

  IF OLD.provider_id IS DISTINCT FROM NEW.provider_id THEN
    RAISE EXCEPTION 'provider_id cannot be changed';
  END IF;

  IF OLD.oauth_username IS DISTINCT FROM NEW.oauth_username THEN
    RAISE EXCEPTION 'oauth_username cannot be changed';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS ensure_immutable_fields ON public.users;
CREATE TRIGGER ensure_immutable_fields
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.prevent_system_field_updates();

-- ============================
-- 7) Restrict execute on helper functions
-- ============================
REVOKE EXECUTE ON FUNCTION public.set_updated_at() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.prevent_system_field_updates() FROM PUBLIC;

-- ============================
-- 8) Final notes
-- ============================
-- Service_role bypasses RLS automatically; no extra SQL needed.
-- If you later want to force reads through the view only, you can REVOKE SELECT on public.users from authenticated,
-- but that would prevent clients from reading private columns of their own profile. We keep base table SELECT for authenticated so users can read full data for their own row.