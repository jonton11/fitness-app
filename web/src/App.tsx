import { ExerciseLibrary } from './features/exercises/ExerciseLibrary'
import { WorkoutTemplates } from './features/workoutTemplates/WorkoutTemplates'

import { useState } from 'react'

type Section = 'workouts' | 'exercises'

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
          className={section === 'exercises' ? 'selected' : ''}
          type="button"
          onClick={() => setSection('exercises')}
        >
          Exercises
        </button>
      </nav>
      {section === 'workouts' ? <WorkoutTemplates /> : <ExerciseLibrary />}
    </>
  )
}

export default App
