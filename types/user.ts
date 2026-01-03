/**
 * User Profile Types
 * 
 * Type definitions for user profiles and related data structures.
 * These types match the database schema and API responses.
 */

/**
 * Public user profile data structure.
 * This matches the columns returned by the `get_all_public_profiles()` database function
 * and the `user_profiles_public` view.
 */
export interface UserProfile {
  user_id: string
  oauth_username: string
  display_name: string | null
  avatar_url: string | null
}

/**
 * Full user profile from the `public.users` table.
 * Includes all columns (some may be private and not exposed to other users).
 */
export interface FullUserProfile extends UserProfile {
  email: string | null
  provider_id: string
  created_at: string
  updated_at: string
}

/**
 * Database response type for the `get_all_public_profiles()` RPC function.
 */
export type PublicProfilesResponse = UserProfile[]

