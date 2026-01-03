'use client'

import { useState } from 'react'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { LogoutButton } from '@/components/logout-button'
import type { UserProfile } from '@/types/user'
import { getDisplayName, getAvatarFallback } from '@/lib/users'

interface UserSidebarProps {
  currentUserProfile: UserProfile
  initialUsers: UserProfile[]
}

export function UserSidebar({ 
  currentUserProfile,
  initialUsers 
}: UserSidebarProps) {
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null)

  const selectedUser = selectedUserId
    ? initialUsers.find((u) => u.user_id === selectedUserId)
    : null

  return (
    <div className="h-screen w-80 border-l bg-background flex flex-col">
      {/* Current User Section - Always at top */}
      <div className="p-4 border-b">
        <div className="flex items-center gap-3 mb-3">
          <Avatar className="h-10 w-10">
            <AvatarImage
              src={currentUserProfile.avatar_url || undefined}
              alt={getDisplayName(currentUserProfile)}
            />
            <AvatarFallback>
              {getAvatarFallback(currentUserProfile)}
            </AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <p className="font-semibold text-sm truncate">
              {getDisplayName(currentUserProfile)}
            </p>
            <p className="text-xs text-muted-foreground truncate">
              @{currentUserProfile.oauth_username}
            </p>
          </div>
        </div>
        <LogoutButton />
      </div>

      {/* Other Users List */}
      <div className="flex-1 overflow-y-auto p-4">
        <h2 className="text-sm font-semibold text-muted-foreground mb-3 px-2">
          Users
        </h2>
        {initialUsers.length === 0 ? (
          <div className="text-sm text-muted-foreground px-2">No other users found</div>
        ) : (
          <div className="space-y-2">
            {initialUsers.map((user) => (
              <button
                key={user.user_id}
                onClick={() =>
                  setSelectedUserId(selectedUserId === user.user_id ? null : user.user_id)
                }
                className="w-full flex items-center gap-3 p-2 rounded-lg hover:bg-accent transition-colors text-left"
              >
                <Avatar className="h-8 w-8">
                  <AvatarImage
                    src={user.avatar_url || undefined}
                    alt={getDisplayName(user)}
                  />
                  <AvatarFallback>
                    {getAvatarFallback(user)}
                  </AvatarFallback>
                </Avatar>
                <span className="text-sm font-medium truncate flex-1">
                  {getDisplayName(user)}
                </span>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Selected User Profile Card - Expands within sidebar */}
      {selectedUser && (
        <div className="border-t p-4 bg-muted/30">
          <Card>
            <CardHeader>
              <div className="flex items-center justify-between">
                <CardTitle className="text-base">Profile</CardTitle>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setSelectedUserId(null)}
                  className="h-7 px-2 text-xs"
                >
                  Close
                </Button>
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex items-center gap-3">
                <Avatar className="h-16 w-16">
                  <AvatarImage
                    src={selectedUser.avatar_url || undefined}
                    alt={getDisplayName(selectedUser)}
                  />
                  <AvatarFallback>
                    {getAvatarFallback(selectedUser)}
                  </AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                  <p className="font-semibold truncate">
                    {getDisplayName(selectedUser)}
                  </p>
                  <p className="text-sm text-muted-foreground truncate">
                    @{selectedUser.oauth_username}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
