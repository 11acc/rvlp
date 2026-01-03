/**
 * User Utility Functions
 * 
 * Helper functions for transforming and filtering user data.
 */

import type { UserProfile, FullUserProfile } from '@/types/user'

/**
 * Transforms a full user profile from the database to a public user profile.
 * Strips private fields and ensures type safety.
 * 
 * @param profile - Full user profile from database
 * @returns Public user profile with only safe fields
 */
export function toPublicProfile(profile: FullUserProfile): UserProfile {
  return {
    user_id: profile.user_id,
    oauth_username: profile.oauth_username,
    display_name: profile.display_name,
    avatar_url: profile.avatar_url,
  }
}

/**
 * Filters out the current user from a list of user profiles.
 * 
 * @param users - Array of user profiles
 * @param currentUserId - ID of the current user to exclude
 * @returns Filtered array without the current user
 */
export function excludeCurrentUser(
  users: UserProfile[],
  currentUserId: string
): UserProfile[] {
  return users.filter((user) => user.user_id !== currentUserId)
}

/**
 * Gets the display name for a user profile.
 * Falls back to oauth_username if display_name is not set.
 * 
 * @param profile - User profile
 * @returns Display name or username
 */
export function getDisplayName(profile: UserProfile): string {
  return profile.display_name || profile.oauth_username
}

/**
 * Gets the avatar fallback initial for a user profile.
 * Uses the first character of display_name or oauth_username.
 * 
 * @param profile - User profile
 * @returns Single character for avatar fallback
 */
export function getAvatarFallback(profile: UserProfile): string {
  const name = getDisplayName(profile)
  return name[0]?.toUpperCase() || '?'
}

