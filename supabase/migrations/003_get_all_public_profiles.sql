-- 003_get_all_public_profiles.sql
-- Purpose: Create a SECURITY DEFINER function to return all public user profiles
-- for authenticated users. This bypasses RLS to allow directory listings while
-- only exposing safe, public columns via the existing user_profiles_public view.
--
-- Security Notes:
-- - Uses SECURITY DEFINER to bypass RLS on the underlying table
-- - Queries the existing user_profiles_public view (defined in 001) for consistency
-- - Only exposes public-safe columns: user_id, oauth_username, display_name, avatar_url
-- - Marked as STABLE since it doesn't modify data and results are consistent within a transaction
-- - Execution granted only to authenticated role
--
-- Rationale:
-- The underlying public.users table has RLS that restricts users to their own row.
-- For directory listings, we need to bypass RLS while maintaining security by:
-- 1. Using the existing view that already limits columns to public-safe data
-- 2. Using SECURITY DEFINER to bypass RLS only for this specific use case
-- 3. Restricting execution to authenticated users only

-- ============================
-- 0) Create function to get all public profiles
-- ============================
CREATE OR REPLACE FUNCTION public.get_all_public_profiles()
RETURNS TABLE (
  user_id uuid,
  oauth_username text,
  display_name text,
  avatar_url text
) 
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  -- Query the existing user_profiles_public view (defined in 001_create_users_rls.sql)
  -- This ensures consistency with the view definition and limits exposure to public columns only
  RETURN QUERY
  SELECT
    v.user_id,
    v.oauth_username,
    v.display_name,
    v.avatar_url
  FROM public.user_profiles_public v
  ORDER BY v.oauth_username ASC;
END;
$$;

-- ============================
-- 1) Grant execute to authenticated users only
-- ============================
GRANT EXECUTE ON FUNCTION public.get_all_public_profiles() TO authenticated;

-- Revoke from public and anon for security
REVOKE EXECUTE ON FUNCTION public.get_all_public_profiles() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.get_all_public_profiles() FROM anon;

-- ============================
-- 2) Add comment documenting the function's purpose and security model
-- ============================
COMMENT ON FUNCTION public.get_all_public_profiles() IS 
'Returns all public user profiles for directory listings. Bypasses RLS on public.users to allow authenticated users to see all profiles, but only exposes public-safe columns via the user_profiles_public view. Execution restricted to authenticated role only.';
