import { ExerciseLibrary } from './features/exercises/ExerciseLibrary'
import { Login } from './features/auth/Login'
import { ActivityManager } from './features/activities/ActivityManager'
import { RoutineManager } from './features/routines/RoutineManager'
import { WorkoutHistory } from './features/workoutSessions/WorkoutHistory'
import { WorkoutTemplates } from './features/workoutTemplates/WorkoutTemplates'

import { useEffect, useState } from 'react'
import {
  createSession,
  deleteSession,
  getCurrentUser,
  type User,
} from './api/session'

type Section = 'workouts' | 'routines' | 'activities' | 'history' | 'exercises'

type AuthenticationState =
  | { status: 'loading' }
  | { status: 'signed-out' }
  | { status: 'signed-in'; user: User }

function App() {
  const [section, setSection] = useState<Section>('workouts')
  const [authentication, setAuthentication] = useState<AuthenticationState>({
    status: 'loading',
  })
  const [isSigningOut, setIsSigningOut] = useState(false)
  const [signOutError, setSignOutError] = useState<string | null>(null)

  useEffect(() => {
    let isCurrent = true

    getCurrentUser()
      .then((user) => {
        if (isCurrent) {
          setAuthentication(
            user ? { status: 'signed-in', user } : { status: 'signed-out' },
          )
        }
      })
      .catch(() => {
        if (isCurrent) {
          setAuthentication({ status: 'signed-out' })
        }
      })

    return () => {
      isCurrent = false
    }
  }, [])

  async function handleLogin(emailAddress: string, password: string) {
    const user = await createSession(emailAddress, password)
    setAuthentication({ status: 'signed-in', user })
    return user
  }

  async function handleLogout() {
    setSignOutError(null)
    setIsSigningOut(true)

    try {
      await deleteSession()
      setAuthentication({ status: 'signed-out' })
    } catch (error) {
      setSignOutError(
        error instanceof Error ? error.message : 'Unable to sign out',
      )
    } finally {
      setIsSigningOut(false)
    }
  }

  if (authentication.status === 'loading') {
    return (
      <main className="session-loading" aria-live="polite">
        Loading...
      </main>
    )
  }

  if (authentication.status === 'signed-out') {
    return <Login onLogin={handleLogin} />
  }

  return (
    <>
      <nav className="app-nav" aria-label="Primary">
        <div className="nav-sections">
          <button
            className={section === 'workouts' ? 'selected' : ''}
            type="button"
            onClick={() => setSection('workouts')}
          >
            Workouts
          </button>
          <button
            className={section === 'routines' ? 'selected' : ''}
            type="button"
            onClick={() => setSection('routines')}
          >
            Routines
          </button>
          <button
            className={section === 'history' ? 'selected' : ''}
            type="button"
            onClick={() => setSection('history')}
          >
            History
          </button>
          <button
            className={section === 'activities' ? 'selected' : ''}
            type="button"
            onClick={() => setSection('activities')}
          >
            Activities
          </button>
          <button
            className={section === 'exercises' ? 'selected' : ''}
            type="button"
            onClick={() => setSection('exercises')}
          >
            Exercises
          </button>
        </div>
        <div className="session-controls">
          <span>{authentication.user.email_address}</span>
          <button type="button" onClick={handleLogout} disabled={isSigningOut}>
            {isSigningOut ? 'Signing out...' : 'Sign out'}
          </button>
        </div>
      </nav>
      {signOutError ? (
        <div className="nav-error" role="alert">
          {signOutError}
        </div>
      ) : null}
      {section === 'workouts' ? <WorkoutTemplates /> : null}
      {section === 'routines' ? <RoutineManager /> : null}
      {section === 'activities' ? <ActivityManager /> : null}
      {section === 'history' ? <WorkoutHistory /> : null}
      {section === 'exercises' ? <ExerciseLibrary /> : null}
    </>
  )
}

export default App
