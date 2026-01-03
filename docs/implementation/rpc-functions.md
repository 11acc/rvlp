# RPC Functions: Implementation Guide

## Quick Reference

```typescript
// Server Component
const supabase = await createClient()
const { data, error } = await supabase.rpc('function_name')
```

## What We're Doing

Calling PostgreSQL functions via Supabase's RPC interface. This is the standard method for executing database functions that need to bypass RLS or perform complex operations.

## Current Implementation

**Location**: `app/dashboard/layout.tsx`

```typescript
const { data: allUsers, error: usersError } = await supabase.rpc('get_all_public_profiles')
```

Calls the function defined in `003_get_all_public_profiles.sql`, which:
- Uses `SECURITY DEFINER` to bypass RLS
- Queries `user_profiles_public` view (not table directly)
- Returns only public-safe columns

## Why RPC

**Problem**: RLS on `public.users` restricts queries to current user's row only. Directory listings need all users.

**Solution**: `SECURITY DEFINER` function bypasses RLS while maintaining security by:
1. Querying a view that exposes only safe columns
2. Restricting execution to authenticated users
3. Using `STABLE` and `SET search_path` for safety

**Alternative considered**: Direct view query fails because views inherit RLS from underlying tables.

## Security Model

RPC calls execute with the authenticated user's session context:
- Client uses `@supabase/ssr` with cookie-based auth
- Function receives authenticated user context
- `SECURITY DEFINER` bypasses RLS but function still respects grants

**Key point**: We use the anon key with authenticated session, not the service role key.

## Best Practices

### Server Components Only

RPC calls belong in Server Components:

```typescript
// ✅ Correct
export default async function Layout() {
  const supabase = await createClient()
  const { data } = await supabase.rpc('function_name')
}

// ❌ Wrong - don't call RPC in Client Components
'use client'
export function Component() {
  const supabase = createClient()
  const { data } = await supabase.rpc('function_name') // Avoid
}
```

**Rationale**: Server-side execution provides data on initial render, better performance, and secure session handling.

### Error Handling

Always handle errors:

```typescript
const { data, error } = await supabase.rpc('function_name')

if (error) {
  console.error('RPC error:', error)
  return [] // Graceful fallback
}

return data || []
```

### Type Safety

Match TypeScript interfaces to function return types:

```typescript
// types/user.ts
export interface UserProfile {
  user_id: string
  oauth_username: string
  display_name: string | null
  avatar_url: string | null
}

// Usage
const { data } = await supabase.rpc<UserProfile[]>('get_all_public_profiles')
```

## Function Design Checklist

When creating a new RPC function:

- [ ] Uses `SECURITY DEFINER` only when RLS bypass needed
- [ ] Queries views, not tables directly
- [ ] Marked `STABLE` if read-only
- [ ] `SET search_path = public` to prevent injection
- [ ] `GRANT EXECUTE` to `authenticated` only
- [ ] `REVOKE EXECUTE` from `PUBLIC` and `anon`
- [ ] Documented with security rationale

## When to Use RPC

**Use RPC for**:
- Directory listings (bypass RLS)
- Complex aggregations
- Custom return structures
- Operations requiring SECURITY DEFINER

**Don't use RPC for**:
- Simple table queries (use `.from().select()`)
- Single-row lookups (use `.eq().single()`)
- Operations that work with standard RLS

## Common Patterns

### Directory Listing
```typescript
const { data: profiles } = await supabase.rpc('get_all_public_profiles')
```

### With Parameters
```typescript
const { data } = await supabase.rpc('function_name', {
  param1: value1,
  param2: value2
})
```

## Troubleshooting

**Function not found** (`PGRST116`):
- Verify function exists in `public` schema
- Check migration was applied

**Permission denied**:
- Verify `GRANT EXECUTE` in migration
- Check function grants to `authenticated` role

**Empty results despite SECURITY DEFINER**:
- Verify function uses `SECURITY DEFINER`
- Check function queries correct view/table

## References

- Function definition: `supabase/migrations/003_get_all_public_profiles.sql`
- Implementation: `app/dashboard/layout.tsx`
- [Supabase RPC Docs](https://supabase.com/docs/guides/database/functions)
