import { NextResponse } from 'next/server'
// The client you created from the Server-Side Auth instructions
import { createClient } from '@/lib/supabase/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')

  // DIAGNOSTIC: Log callback parameters
  // console.log('[OAUTH CALLBACK] Received request')
  // console.log('[OAUTH CALLBACK] Code:', code ? 'present' : 'missing')
  // console.log('[OAUTH CALLBACK] Next parameter:', searchParams.get('next'))
  // console.log('[OAUTH CALLBACK] All search params:', Array.from(searchParams.entries()))

  // Default to dashboard for successful OAuth logins
  // Use query param if provided, otherwise go to dashboard
  let next = searchParams.get('next') ?? '/dashboard'

  // Security: ensure the redirect is to a relative URL
  if (!next.startsWith('/')) {
    // if "next" is not a relative URL, use the default
    next = '/dashboard'
  }
  // console.log('[OAUTH CALLBACK] Final redirect destination:', next)

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) {
      const forwardedHost = request.headers.get('x-forwarded-host') // original origin before load balancer
      const isLocalEnv = process.env.NODE_ENV === 'development'
      if (isLocalEnv) {
        // we can be sure that there is no load balancer in between, so no need to watch for X-Forwarded-Host
        return NextResponse.redirect(`${origin}${next}`)
      } else if (forwardedHost) {
        return NextResponse.redirect(`https://${forwardedHost}${next}`)
      } else {
        return NextResponse.redirect(`${origin}${next}`)
      }
    } else {
      // Pass error details to error page
      const errorMessage = encodeURIComponent(error.message || 'Failed to exchange code for session')
      return NextResponse.redirect(`${origin}/auth/error?error=${errorMessage}`)
    }
  }

  // return the user to an error page with instructions
  const errorMessage = encodeURIComponent('No authorization code provided')
  return NextResponse.redirect(`${origin}/auth/error?error=${errorMessage}`)
}
