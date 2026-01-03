import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"

export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) {
    redirect('/auth/login')
  }

  // Get user profile from public.users table
  const { data: profile } = await supabase
    .from('users')
    .select('*')
    .eq('user_id', user.id)
    .single()

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold mb-6">Welcome to Your Dashboard</h1>

        <div className="bg-card p-6 rounded-lg border">
          <h2 className="text-xl font-semibold mb-4">Profile Information</h2>

          {profile ? (
            <div className="space-y-3">
              <div>
                <span className="text-muted-foreground">Display Name:</span>
                <p className="text-lg">{profile.display_name}</p>
              </div>

              <div>
                <span className="text-muted-foreground">Username:</span>
                <p className="text-lg">@{profile.oauth_username}</p>
              </div>

              <div>
                <span className="text-muted-foreground">Email:</span>
                <p className="text-lg">{user.email}</p>
              </div>

              {profile.avatar_url && (
                <div>
                  <span className="text-muted-foreground">Avatar:</span>
                  <Avatar>
                    <AvatarImage
                      src={profile.avatar_url}
                      alt="Avatar"
                    />
                    <AvatarFallback>?</AvatarFallback>
                  </Avatar>
                </div>
              )}
            </div>
          ) : (
            <p className="text-muted-foreground">
              Profile not found. Please contact support if this persists.
            </p>
          )}
        </div>
      </div>
    </div>
  )
}
