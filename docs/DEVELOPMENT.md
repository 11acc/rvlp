# Development Guide

Daily development workflow, common tasks, and patterns.

## Running Locally

```bash
# Start dev server with Turbopack
npm run dev

# Or with standard webpack
npm run dev -- --no-turbo
```

Open [http://localhost:3000](http://localhost:3000)

## Local Supabase (Optional)

```bash
# Start local Supabase stack
npx supabase start

# Stop
npx supabase stop

# Reset database (applies all migrations fresh)
npx supabase db reset

# View local Studio
open http://localhost:54323
```

## Creating New Features

### 1. Protected Page

```bash
mkdir -p app/feature-name
```

**Create `app/feature-name/page.tsx`:**
```typescript
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export default async function FeaturePage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    redirect('/auth/login')
  }

  return <div>Feature content</div>
}
```

### 2. Client Component

**Create `components/my-component.tsx`:**
```typescript
'use client'

import { createClient } from '@/lib/supabase/client'

export function MyComponent() {
  const supabase = createClient()
  // ... client-side logic
}
```

### 3. API Route Handler

**Create `app/api/endpoint/route.ts`:**
```typescript
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  return NextResponse.json({ data: 'response' })
}
```

## Database Changes

### Create Migration

```bash
npx supabase migration new add_feature_table
```

Edit `supabase/migrations/<timestamp>_add_feature_table.sql`

### Apply Migration

```bash
# Local
npx supabase db reset

# Remote
npx supabase db push
```

### Add RLS Policy

```sql
-- In migration file
ALTER TABLE public.new_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_own_rows
  ON public.new_table FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);
```

## Adding Protected Routes

### Checklist

- [ ] Create page in `app/` directory
- [ ] Add auth check with `getUser()` and redirect
- [ ] Add error boundary (`error.tsx`) if needed
- [ ] Add to layout if sharing nav/structure

### Nested Under Existing Protected Layout

If adding under `/dashboard/`:
```
app/dashboard/settings/page.tsx
```

Layout auth check already covers it, but page should still check auth before accessing user data.

## Testing Auth Flows

### Manual Testing

| Scenario | Steps | Expected |
|----------|-------|----------|
| Fresh login | Clear cookies → `/auth/login` → Discord | Redirects to `/dashboard` |
| Authenticated access | `/dashboard` with valid session | Shows dashboard |
| Unauthenticated access | Clear cookies → `/dashboard` | Redirects to `/auth/login` |
| Logout | Click logout button | Redirects to `/auth/login` |
| Token refresh | Wait 1hr → refresh page | Stays logged in |

### Check Auth State

Browser DevTools → Application → Cookies:
- Look for `sb-*` cookies (Supabase session)

Console:
```javascript
// In browser console
const { data } = await supabase.auth.getSession()
console.log(data.session)
```

## Common Tasks

### Get Current User in Server Component

```typescript
const supabase = await createClient()
const { data: { user } } = await supabase.auth.getUser()
```

### Query with RLS

```typescript
const { data, error } = await supabase
  .from('users')
  .select('*')
  .eq('user_id', user.id)
  .single()
```

### Handle Query Errors

```typescript
const { data, error } = await supabase.from('users').select('*')

if (error) {
  console.error('Query failed:', error.message)
  // Handle appropriately
}
```

### Add shadcn/ui Component

```bash
npx shadcn@latest add button
```

Components added to `components/ui/`.

## Environment Variables

### Adding New Variables

1. Add to `.env.local`:
   ```
   MY_NEW_VAR=value
   ```

2. For client access, prefix with `NEXT_PUBLIC_`:
   ```
   NEXT_PUBLIC_MY_VAR=value
   ```

3. Restart dev server

### Accessing Variables

```typescript
// Server-side
process.env.MY_SECRET_KEY

// Client-side (must be NEXT_PUBLIC_)
process.env.NEXT_PUBLIC_MY_VAR
```

## Scripts Reference

| Command | Purpose |
|---------|---------|
| `npm run dev` | Start dev server |
| `npm run build` | Production build |
| `npm run start` | Start production server |
| `npm run lint` | Run ESLint |
| `npx supabase start` | Start local Supabase |
| `npx supabase db reset` | Reset local database |
| `npx supabase db push` | Push migrations to remote |
