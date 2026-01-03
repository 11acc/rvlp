# Setup Guide

Complete setup from scratch for local development and production.

## Prerequisites

| Requirement | Version | Check |
|-------------|---------|-------|
| Node.js | 20+ | `node --version` |
| npm | 10+ | `npm --version` |
| Supabase CLI | Latest | `npx supabase --version` |
| Supabase Project | Free tier works | [supabase.com](https://supabase.com) |

## Environment Variables

Create `.env.local` in project root:

| Variable | Required | Description |
|----------|----------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_OR_ANON_KEY` | Yes | Supabase anon/public key |
| `NEXT_PUBLIC_SITE_URL` | Yes | Your app URL (for OAuth redirects) |

```bash
# .env.local
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_OR_ANON_KEY=your-anon-key
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

**Where to find credentials:**
1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project
3. Settings → API → Project URL and anon key

## Local Setup

### 1. Clone and Install

```bash
git clone <repo-url>
cd rvlp
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env.local
# Edit .env.local with your Supabase credentials
```

### 3. Start Local Supabase (Optional)

For local database development:

```bash
npx supabase start
```

This starts local Supabase with:
- PostgreSQL on port 54322
- Studio UI at http://localhost:54323
- Auth on port 54321

### 4. Apply Migrations

```bash
# Against local Supabase
npx supabase db reset

# Against remote Supabase
npx supabase db push
```

### 5. Start Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

## Discord OAuth Setup

### Supabase Dashboard

1. Go to Authentication → Providers → Discord
2. Enable Discord provider
3. Copy the **Callback URL** (you'll need this for Discord)

### Discord Developer Portal

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Create New Application (or select existing)
3. OAuth2 → General:
   - Add Redirect: `https://your-project.supabase.co/auth/v1/callback`
   - Add Redirect: `http://localhost:3000/auth/oauth` (for local dev)
4. Copy **Client ID** and **Client Secret**

### Back to Supabase

1. Paste Client ID and Client Secret in Discord provider settings
2. Save

### Supabase Redirect URLs

Add these in Authentication → URL Configuration → Redirect URLs:

**Development:**
```
http://localhost:3000/**
http://localhost:3000/auth/oauth
```

**Production:**
```
https://yourdomain.com/**
https://yourdomain.com/auth/oauth
```

## Verify Setup

### 1. Start Server
```bash
npm run dev
```

### 2. Test OAuth Flow
1. Navigate to `/auth/login`
2. Click "Continue with Discord"
3. Authorize in Discord
4. Should redirect to `/dashboard`

### 3. Check Console
Look for:
```
[PROXY] getUser called
```
This confirms `proxy.ts` is running.

### 4. Verify Database
After first login, check `public.users` table has a row with your Discord data.

## Production Deployment

### Vercel

1. Push to GitHub
2. Import in Vercel
3. Add environment variables:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_OR_ANON_KEY`
   - `NEXT_PUBLIC_SITE_URL` (your Vercel domain)

### Database Migrations

```bash
# Push migrations to production Supabase
npx supabase db push --linked
```

### Update OAuth Redirects

Add your production domain to:
1. Discord Developer Portal → OAuth2 → Redirects
2. Supabase → Authentication → URL Configuration

## Common Setup Issues

| Issue | Solution |
|-------|----------|
| OAuth redirect mismatch | Verify URLs match exactly in Discord + Supabase |
| Missing user profile | Check trigger in `002_create_signup_trigger.sql` |
| Cookies not setting | Ensure `proxy.ts` exists and is named correctly |
| RLS blocking queries | Verify policies in `001_create_users_rls.sql` |

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for detailed solutions.
