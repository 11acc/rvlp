# Architecture

System design, authentication flow, and key architectural decisions.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Next.js 16 App                          │
├─────────────────────────────────────────────────────────────────┤
│  proxy.ts                                                       │
│  ├── Runs on EVERY request (except static files)               │
│  ├── Calls getUser() to sync/refresh tokens                    │
│  └── Updates response cookies                                   │
├─────────────────────────────────────────────────────────────────┤
│  Server Components (app/)                                       │
│  ├── Create per-request Supabase client                        │
│  ├── Check auth with getUser()                                 │
│  └── Query database with RLS enforcement                       │
├─────────────────────────────────────────────────────────────────┤
│  Client Components (components/)                                │
│  ├── Create browser Supabase client                            │
│  └── Initiate OAuth, handle logout                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Supabase                               │
├─────────────────────────────────────────────────────────────────┤
│  Auth Service                                                   │
│  ├── OAuth providers (Discord)                                 │
│  ├── Session management                                        │
│  └── Token refresh                                             │
├─────────────────────────────────────────────────────────────────┤
│  PostgreSQL                                                     │
│  ├── auth.users (managed by Supabase)                          │
│  ├── public.users (app profiles, RLS protected)                │
│  └── Triggers (auto-create profile on signup)                  │
└─────────────────────────────────────────────────────────────────┘
```

## Authentication Flow

### Login Flow

```
┌──────────┐    ┌───────────────┐    ┌─────────┐    ┌──────────┐
│  User    │    │ login-form.tsx│    │ Discord │    │ Supabase │
└────┬─────┘    └───────┬───────┘    └────┬────┘    └────┬─────┘
     │                  │                  │              │
     │ Click Login      │                  │              │
     │─────────────────>│                  │              │
     │                  │                  │              │
     │                  │ signInWithOAuth('discord')      │
     │                  │─────────────────────────────────>
     │                  │                  │              │
     │                  │       Redirect to Discord       │
     │<────────────────────────────────────────────────────
     │                  │                  │              │
     │ Authorize App    │                  │              │
     │─────────────────────────────────────>              │
     │                  │                  │              │
     │                  │    Redirect with code           │
     │<────────────────────────────────────────────────────
     │                  │                  │              │
     │ /auth/oauth?code=...                │              │
     │─────────────────>│                  │              │
     │                  │                  │              │
     │                  │ exchangeCodeForSession(code)    │
     │                  │─────────────────────────────────>
     │                  │                  │              │
     │                  │         Session + Cookies       │
     │<────────────────────────────────────────────────────
     │                  │                  │              │
     │ Redirect to /dashboard              │              │
     │<─────────────────│                  │              │
```

### Request Flow (Authenticated)

```
Browser Request
      │
      ▼
┌─────────────┐
│  proxy.ts   │ ── getUser() ──> Supabase Auth
│             │ <── user/error ──
│             │
│  if token   │ ── Refreshes cookies in response
│  needs      │
│  refresh    │
└─────────────┘
      │
      ▼
┌─────────────────┐
│ Layout/Page     │ ── getUser() ──> Supabase Auth
│ (Server Comp)   │ <── user/error ──
│                 │
│ if (!user)      │ ── redirect('/auth/login')
│                 │
│ else            │ ── Query with RLS
└─────────────────┘
      │
      ▼
   Response
```

## File Structure Philosophy

```
app/                          # Route handlers (Next.js App Router)
├── auth/                     # Auth-related routes
│   ├── login/               # Login page
│   ├── oauth/               # OAuth callback (Route Handler)
│   └── error/               # Auth error display
└── dashboard/               # Protected routes
    ├── layout.tsx           # Shared auth check + nav
    ├── page.tsx             # Page with auth check
    └── error.tsx            # Error boundary

lib/supabase/                # Supabase client factories
├── server.ts                # Server Component client (async)
└── client.ts                # Browser client (sync)

components/                  # React components
├── ui/                      # shadcn/ui primitives
├── login-form.tsx           # OAuth initiation
└── logout-button.tsx        # Session signOut

supabase/migrations/         # Database migrations
├── 001_*.sql                # Table + RLS
└── 002_*.sql                # Triggers

proxy.ts                     # Token refresh (runs every request)
```

## Server vs Client Components

| Aspect | Server Component | Client Component |
|--------|-----------------|------------------|
| File marker | None (default) | `'use client'` |
| Supabase client | `await createClient()` | `createClient()` |
| Auth check | `getUser()` + redirect | N/A |
| Database queries | Yes, with RLS | Yes, with RLS |
| Use for | Pages, layouts, data fetching | Interactivity, OAuth init |

**Server Component** (`app/dashboard/page.tsx`):
```typescript
export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/auth/login')
  // ...
}
```

**Client Component** (`components/login-form.tsx`):
```typescript
'use client'
export function LoginForm() {
  const supabase = createClient()
  await supabase.auth.signInWithOAuth({ provider: 'discord' })
}
```

## Cookie-Based Session Management

Sessions stored in httpOnly cookies, managed by Supabase SSR:

1. **Initial Login**: Supabase sets session cookies via OAuth callback
2. **Every Request**: `proxy.ts` calls `getUser()` which:
   - Validates access token
   - Refreshes if expired (using refresh token)
   - Updates cookies in response
3. **Logout**: `signOut()` clears cookies

**Cookie Sync Pattern** (`proxy.ts:15-25`):
```typescript
cookies: {
  getAll() {
    return request.cookies.getAll()
  },
  setAll(cookiesToSet) {
    cookiesToSet.forEach(({ name, value, options }) =>
      supabaseResponse.cookies.set(name, value, options)
    )
  },
}
```

## RLS Security Model

All database queries enforce Row Level Security:

```
┌────────────────────────────────────────────────────────────┐
│  Client Query                                              │
│  supabase.from('users').select('*')                       │
└────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────┐
│  RLS Policy Evaluation                                     │
│  WHERE auth.uid() = user_id                               │
│                                                            │
│  ✓ Returns only rows matching current user                │
│  ✓ Enforced at database level                             │
│  ✓ Cannot be bypassed by client                           │
└────────────────────────────────────────────────────────────┘
```

**Policies on `public.users`:**
- SELECT: Own row only (`auth.uid() = user_id`)
- INSERT: Own row only
- UPDATE: Own row only
- DELETE: None (users cannot delete their profile)

**Public View** (`user_profiles_public`):
- Exposes only: `user_id`, `oauth_username`, `display_name`, `avatar_url`
- Hides: `email`, `provider_id`
- For user directories/discovery features

See [DATABASE.md](./DATABASE.md) for full schema and policies.

## Key Architectural Decisions

### 1. proxy.ts vs middleware.ts
Next.js 16 uses `proxy.ts` for request interception ([docs](https://nextjs.org/docs/app/api-reference/file-conventions/proxy)). This runs on every request to sync cookies.

### 2. Page-Level Auth Checks
Both layout AND page check auth independently because they execute in parallel. The page must protect itself.

### 3. Server-First Rendering
All protected routes are Server Components. Client components only used for interactivity (OAuth init, logout).

### 4. Database Triggers for Profile Creation
On OAuth signup, a PostgreSQL trigger auto-creates the `public.users` row, extracting OAuth metadata.
