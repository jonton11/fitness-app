import { ExerciseLibrary } from './features/exercises/ExerciseLibrary'
import { WorkoutHistory } from './features/workoutSessions/WorkoutHistory'
import { WorkoutTemplates } from './features/workoutTemplates/WorkoutTemplates'

import { useState } from 'react'

type Section = 'workouts' | 'history' | 'exercises'

function App() {
  const [section, setSection] = useState<Section>('workouts')

  return (
    <>
      <nav className="app-nav" aria-label="Primary">
        <button
          className={section === 'workouts' ? 'selected' : ''}
          type="button"
          onClick={() => setSection('workouts')}
        >
          Workouts
        </button>
        <button
          className={section === 'history' ? 'selected' : ''}
          type="button"
          onClick={() => setSection('history')}
        >
          History
        </button>
        <button
          className={section === 'exercises' ? 'selected' : ''}
          type="button"
          onClick={() => setSection('exercises')}
        >
          Exercises
        </button>
      </nav>
      {section === 'workouts' ? <WorkoutTemplates /> : null}
      {section === 'history' ? <WorkoutHistory /> : null}
      {section === 'exercises' ? <ExerciseLibrary /> : null}
    </>
  )
}

export default App
