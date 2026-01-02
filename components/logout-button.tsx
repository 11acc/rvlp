'use client'

import { createClient } from '@/lib/supabase/client'
import { Button } from '@/components/ui/button'
import { useRouter } from 'next/navigation'
import { useState } from 'react'

export function LogoutButton() {
  const router = useRouter()
  const [isLoading, setIsLoading] = useState(false)

  const logout = async () => {
    try {
      setIsLoading(true)
      const supabase = createClient()
      const { error } = await supabase.auth.signOut()

      if (error) {
        console.error('Logout error:', error)
        // Still redirect even if signOut fails to clear local state
      }

      router.push('/auth/login')
    } catch (error) {
      console.error('Logout error:', error)
      // Still redirect to login on error
      router.push('/auth/login')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Button onClick={logout} disabled={isLoading}>
      {isLoading ? 'Logging out...' : 'Logout'}
    </Button>
  )
}
