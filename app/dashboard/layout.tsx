import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { UserSidebar } from '@/components/user-sidebar'
import type { FullUserProfile } from '@/types/user'
import { toPublicProfile, excludeCurrentUser } from '@/lib/users'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error || !user) {
    redirect('/auth/login')
  }

  // Get current user's profile for the sidebar
  const { data: profile } = await supabase
    .from('users')
    .select('*')
    .eq('user_id', user.id)
    .single()

  if (!profile) {
    redirect('/auth/login')
  }

  // Fetch all public user profiles directly in Server Component
  const { data: allUsers, error: usersError } = await supabase.rpc('get_all_public_profiles')

  if (usersError) {
    console.error('Error fetching users:', usersError)
  }

  // Transform full profile to public profile using utility function
  const currentUserProfile = toPublicProfile(profile as FullUserProfile)

  // Filter out current user from the list (server-side)
  const otherUsers = excludeCurrentUser(allUsers || [], user.id)

  return (
    <div className="h-screen flex overflow-hidden">
      {/* Main Content Area */}
      <main className="flex-1 overflow-y-auto">
        {children}
      </main>
      
      {/* Right Sidebar - Always visible, full height */}
      <UserSidebar
        currentUserProfile={currentUserProfile}
        initialUsers={otherUsers}
      />
    </div>
  )
}
