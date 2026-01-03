# Authentication

Implementation details for OAuth, session management, and protected routes.

## OAuth Flow (Discord)

### 1. Initiate OAuth

**File:** `components/login-form.tsx`

```typescript
'use client'

const supabase = createClient()

await supabase.auth.signInWithOAuth({
  provider: 'discord',
  options: {
    redirectTo: `${process.env.NEXT_PUBLIC_SITE_URL}/auth/oauth`,
  },
})
```

This redirects the browser to Discord → Supabase → back to `/auth/oauth`.

### 2. Handle Callback

**File:** `app/auth/oauth/route.ts`

```typescript
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  let next = searchParams.get('next') ?? '/dashboard'

  // Security: only allow relative redirects
  if (!next.startsWith('/')) {
    next = '/dashboard'
  }

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)

    if (!error) {
      return NextResponse.redirect(`${origin}${next}`)
    }
  }

  return NextResponse.redirect(`${origin}/auth/error`)
}
```

### 3. Session Stored

Supabase sets httpOnly cookies containing:
- Access token (short-lived)
- Refresh token (long-lived)

## Token Refresh (proxy.ts)

**File:** `proxy.ts`

Runs on every request to keep tokens fresh:

```typescript
export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_OR_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  // This call refreshes tokens if needed
  await supabase.auth.getUser()

  return supabaseResponse
}
```

**Why this works:**
- `getUser()` validates the access token with Supabase Auth
- If expired, Supabase automatically uses refresh token to get new access token
- New tokens are set via `setAll()` callback
- Response includes updated cookies

**Matcher config:**
```typescript
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
}
```

## Supabase Client Creation

### Server Component Client

**File:** `lib/supabase/server.ts`

```typescript
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_OR_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // Ignored in Server Components
          }
        },
      },
    }
  )
}
```

**Usage:**
```typescript
const supabase = await createClient()
```

### Browser Client

**File:** `lib/supabase/client.ts`

```typescript
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_OR_ANON_KEY!
  )
}
```

**Usage:**
```typescript
const supabase = createClient()
```

## Protected Route Pattern

### Layout + Page Auth Checks

**Critical:** Both layout AND page must check auth because they execute in parallel.

**Layout** (`app/dashboard/layout.tsx`):
```typescript
export default async function DashboardLayout({ children }) {
  const supabase = await createClient()
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error || !user) {
    redirect('/auth/login')
  }

  return (
    <div>
      <nav><LogoutButton /></nav>
      {children}
    </div>
  )
}
```

**Page** (`app/dashboard/page.tsx`):
```typescript
export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  // Page must check auth before accessing user data
  if (!user) {
    redirect('/auth/login')
  }

  // Now safe to use user.id
  const { data: profile } = await supabase
    .from('users')
    .select('*')
    .eq('user_id', user.id)
    .single()

  return <div>{profile.display_name}</div>
}
```

### Why Both Checks?

Next.js Server Components execute in parallel ([docs](https://nextjs.org/docs/app/building-your-application/rendering/server-components)):

```
Request to /dashboard
        │
        ├──────────────────┐
        ▼                  ▼
   layout.tsx          page.tsx
        │                  │
   getUser()           getUser()
        │                  │
   if !user            if !user
   redirect()          redirect()
```

If page doesn't check auth, it will crash accessing `user.id` before layout's redirect takes effect.

## Logout

**File:** `components/logout-button.tsx`

```typescript
'use client'

export function LogoutButton() {
  const router = useRouter()

  const logout = async () => {
    const supabase = createClient()
    await supabase.auth.signOut()
    router.push('/auth/login')
  }

  return <button onClick={logout}>Logout</button>
}
```

## Error Handling

### Auth Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `refresh_token_not_found` | Expired/cleared cookies | Expected; user redirects to login |
| `session_not_found` | No active session | Expected; user redirects to login |
| OAuth redirect mismatch | URL not in allowed list | Add URL to Supabase + Discord |

### Error Boundary

**File:** `app/dashboard/error.tsx`

```typescript
'use client'

export default function DashboardError({ error, reset }) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

Catches unexpected errors in dashboard routes.

## Security Considerations

1. **Always use `getUser()`** for auth checks, not `getSession()` ([Supabase docs](https://supabase.com/docs/guides/auth/server-side/nextjs))
2. **Validate redirect URLs** - Only allow relative paths in OAuth callback
3. **RLS at database level** - Even if auth is bypassed, queries are filtered
4. **httpOnly cookies** - Tokens not accessible to JavaScript
5. **Layered defense** - proxy + page + layout all check auth

## References

- [Supabase SSR Auth](https://supabase.com/docs/guides/auth/server-side/nextjs)
- [Next.js Server Components](https://nextjs.org/docs/app/building-your-application/rendering/server-components)
- [Next.js Error Handling](https://nextjs.org/docs/app/building-your-application/routing/error-handling)
