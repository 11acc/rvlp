# Database

Schema, migrations, RLS policies, and query patterns.

## Schema Overview

### auth.users (Supabase Managed)

Managed by Supabase Auth. Contains:
- `id` (uuid) - Primary key
- `email` - User email
- `raw_user_meta_data` (jsonb) - OAuth provider data

### public.users (App Profiles)

```sql
CREATE TABLE public.users (
  user_id uuid PRIMARY KEY,              -- FK to auth.users(id)
  provider_id text NOT NULL UNIQUE,      -- OAuth provider identifier
  oauth_username text NOT NULL UNIQUE,   -- Discord username
  email varchar NULL,                    -- User email
  display_name text NULL,                -- Display name
  avatar_url text NULL,                  -- Avatar URL
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT users_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id)
    ON UPDATE CASCADE ON DELETE CASCADE
);
```

**Indexes:**
```sql
CREATE INDEX idx_users_user_id ON public.users(user_id);
```

### user_profiles_public (View)

Public-safe view for user directories:

```sql
CREATE VIEW public.user_profiles_public AS
SELECT user_id, oauth_username, display_name, avatar_url
FROM public.users;
```

Hides `email` and `provider_id`.

## Row Level Security (RLS)

RLS enabled on `public.users`. All queries filtered by `auth.uid()`.

### SELECT Policy

```sql
CREATE POLICY users_select_own_profile
  ON public.users FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);
```

Users can only read their own row.

### INSERT Policy

```sql
CREATE POLICY users_self_insert
  ON public.users FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);
```

Users can only insert rows matching their `auth.uid()`.

### UPDATE Policy

```sql
CREATE POLICY users_update_own_profile
  ON public.users FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

Users can only update their own row.

### DELETE Policy

**None.** Users cannot delete their profile.

## Triggers

### Auto-Update Timestamp

```sql
CREATE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

### Prevent Immutable Field Changes

```sql
CREATE FUNCTION prevent_system_field_updates()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS DISTINCT FROM OLD.user_id OR
     NEW.provider_id IS DISTINCT FROM OLD.provider_id OR
     NEW.oauth_username IS DISTINCT FROM OLD.oauth_username THEN
    RAISE EXCEPTION 'Cannot modify immutable fields';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER prevent_system_field_updates
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION prevent_system_field_updates();
```

### Signup Trigger

Auto-creates profile on OAuth signup:

```sql
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (
    user_id,
    provider_id,
    oauth_username,
    email,
    display_name,
    avatar_url
  )
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'provider_id',
    NEW.raw_user_meta_data ->> 'name',
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data ->> 'full_name',
      NEW.email,
      NEW.raw_user_meta_data ->> 'name'
    ),
    NEW.raw_user_meta_data ->> 'avatar_url'
  )
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

## Migration Workflow

### View Current Migrations

```bash
ls supabase/migrations/
```

### Create New Migration

```bash
npx supabase migration new my_migration_name
# Creates: supabase/migrations/<timestamp>_my_migration_name.sql
```

### Apply Migrations

**Local:**
```bash
npx supabase db reset
```

**Remote:**
```bash
npx supabase db push
```

### Migration Files

| File | Purpose |
|------|---------|
| `001_create_users_rls.sql` | Users table, RLS, triggers |
| `002_create_signup_trigger.sql` | Auto-profile on OAuth signup |

## Common Query Patterns

### Get Current User's Profile

```typescript
// app/dashboard/page.tsx
const { data: profile } = await supabase
  .from('users')
  .select('*')
  .eq('user_id', user.id)
  .single()
```

RLS ensures only own row is returned.

### Public User Directory

```typescript
const { data: profiles } = await supabase
  .from('user_profiles_public')
  .select('*')
  .limit(10)
```

Returns only public columns for all users.

### View Another User's Public Profile

```typescript
const { data: profile } = await supabase
  .from('user_profiles_public')
  .select('*')
  .eq('user_id', someUserId)
  .single()
```

### Update Own Profile

```typescript
const { error } = await supabase
  .from('users')
  .update({ display_name: 'New Name' })
  .eq('user_id', user.id)
```

Immutable fields (`user_id`, `provider_id`, `oauth_username`) cannot be changed.

## Service Role Bypass

For admin operations, use the service role key (server-side only):

```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

// Bypasses RLS - full access
const { data } = await supabase.from('users').select('*')
```

**Never expose service role key to client.**

## References

- [Supabase RLS Guide](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Migrations](https://supabase.com/docs/guides/cli/local-development)
