# Troubleshooting

Common issues and solutions.

## Authentication Issues

### "Invalid Refresh Token: Refresh Token Not Found"

**Error:**
```
AuthApiError: Invalid Refresh Token: Refresh Token Not Found
```

**Cause:** Expected when:
- Server restarts with stale browser cookies
- Session expired
- Cookies manually cleared

**Solution:** This is normal behavior. User is redirected to login. No fix needed.

**To suppress in dev** (optional), in `proxy.ts`:
```typescript
const { error } = await supabase.auth.getUser()
if (error && process.env.NODE_ENV === 'development') {
  const expected = ['refresh_token_not_found', 'session_not_found']
  if (!expected.includes(error.code || '')) {
    console.error('Unexpected auth error:', error)
  }
}
```

### OAuth Redirect Mismatch

**Error:**
```
redirect_uri_mismatch
```

**Solution:**

1. **Discord Developer Portal:**
   - OAuth2 → Redirects
   - Add: `https://your-project.supabase.co/auth/v1/callback`

2. **Supabase Dashboard:**
   - Authentication → URL Configuration → Redirect URLs
   - Add: `http://localhost:3000/**` (dev)
   - Add: `https://yourdomain.com/**` (prod)

3. URLs must match **exactly** (trailing slashes matter).

### Stuck on Root After Login

**Symptom:** OAuth succeeds but redirects to `/` instead of `/dashboard`.

**Solution:** Check `app/auth/oauth/route.ts`:
```typescript
let next = searchParams.get('next') ?? '/dashboard'  // Default should be /dashboard
```

### Session Not Persisting

**Symptom:** User randomly logged out on page refresh.

**Checks:**

1. **proxy.ts exists and named correctly?**
   ```bash
   ls proxy.ts  # Should exist in root
   ```

2. **Matcher running?**
   - Add temporary log to proxy.ts
   - Should see log on every request

3. **Cookies blocked?**
   - Browser DevTools → Application → Cookies
   - Look for `sb-*` cookies

## Database Issues

### RLS Blocking Queries

**Symptom:** Query returns empty array or permission denied.

**Debug:**

1. Check if RLS is enabled:
   ```sql
   SELECT tablename, rowsecurity FROM pg_tables
   WHERE schemaname = 'public';
   ```

2. Verify policy exists:
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'users';
   ```

3. Test with service role (bypasses RLS):
   ```typescript
   const supabase = createClient(url, serviceRoleKey)
   const { data } = await supabase.from('users').select('*')
   ```

### Migration Conflicts

**Error:**
```
migration "xxx" has already been applied
```

**Solution (Local only):**
```bash
npx supabase db reset
```

**For production:**
- Create a new migration to fix the issue
- Never edit applied migrations

### Profile Not Created on Signup

**Symptom:** User can login but `public.users` row is missing.

**Check trigger:**
```sql
SELECT * FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';
```

**Check function:**
```sql
SELECT prosrc FROM pg_proc WHERE proname = 'handle_new_user';
```

**Verify OAuth metadata:**
```sql
SELECT id, raw_user_meta_data FROM auth.users ORDER BY created_at DESC LIMIT 1;
```

Must contain `provider_id` and `name`.

## Development Issues

### proxy.ts Not Running

**Symptoms:**
- No `[PROXY]` logs in console
- Cookies not refreshing

**Checks:**

1. File named `proxy.ts` (not `middleware.ts`)
2. Export is `export async function proxy()`
3. Restart dev server after changes

### Environment Variables Not Loading

**Checks:**

1. File is `.env.local` (not `.env`)
2. Restart dev server after changes
3. Client-side vars need `NEXT_PUBLIC_` prefix

**Test:**
```typescript
console.log(process.env.NEXT_PUBLIC_SUPABASE_URL)
```

### TypeScript Errors After Migration

**Error:**
```
Type 'null' is not assignable to type 'User'
```

**Solution:** Add null check before using:
```typescript
const { data: { user } } = await supabase.auth.getUser()
if (!user) redirect('/auth/login')
// TypeScript now knows user is not null
```

## Log Locations

### Server Logs

- Terminal running `npm run dev`
- Look for `[PROXY]` and Next.js errors

### Browser Logs

- DevTools → Console
- Network tab for failed requests

### Supabase Logs

- Dashboard → Logs
- Or: `npx supabase logs` (local)

## Quick Fixes

| Issue | Quick Fix |
|-------|-----------|
| Auth not working | Clear cookies, restart server |
| RLS errors | Check `auth.uid()` matches `user_id` |
| Migration failed | `npx supabase db reset` (local) |
| Cookies not setting | Verify `proxy.ts` exists |
| OAuth fails | Check redirect URLs in both dashboards |
| Profile missing | Check signup trigger in SQL |

## Getting Help

1. Check browser console for errors
2. Check terminal for server errors
3. Review Supabase Dashboard → Logs
4. Verify environment variables are set
5. Compare against patterns in [AUTHENTICATION.md](./AUTHENTICATION.md)
