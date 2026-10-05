import { useEffect, useMemo, useState } from 'react'

import { listWorkoutSessions } from '../../api/workoutSessions'
import type {
  WorkoutSession,
  WorkoutSessionExercise,
  WorkoutSessionSet,
} from '../../api/workoutSessions'

export function WorkoutHistory() {
  const [sessions, setSessions] = useState<WorkoutSession[]>([])
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(
    null,
  )
  const [isLoading, setIsLoading] = useState(true)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    let isCurrent = true

    listWorkoutSessions('completed')
      .then((nextSessions) => {
        if (!isCurrent) {
          return
        }

        setSessions(nextSessions)
        setSelectedSessionId((currentSelectedId) => {
          if (
            currentSelectedId &&
            nextSessions.some((session) => session.id === currentSelectedId)
          ) {
            return currentSelectedId
          }

          return nextSessions[0]?.id ?? null
        })
        setErrorMessage(null)
      })
      .catch(() => {
        if (isCurrent) {
          setErrorMessage('Could not load workout history.')
        }
      })
      .finally(() => {
        if (isCurrent) {
          setIsLoading(false)
        }
      })

    return () => {
      isCurrent = false
    }
  }, [])

  const selectedSession = useMemo(() => {
    return sessions.find((session) => session.id === selectedSessionId) ?? null
  }, [selectedSessionId, sessions])

  return (
    <main className="app-shell">
      <section className="library-layout" aria-labelledby="history-title">
        <header className="library-header">
          <div>
            <p className="eyebrow">Workout History</p>
            <h1 id="history-title">History</h1>
          </div>
        </header>

        <div className="library-grid history-grid">
          <section className="library-list" aria-label="Completed workouts">
            <div className="list-stack" aria-busy={isLoading}>
              {sessions.map((session) => (
                <button
                  className={`exercise-row ${session.id === selectedSessionId ? 'selected' : ''}`}
                  key={session.id}
                  type="button"
                  onClick={() => setSelectedSessionId(session.id)}
                >
                  <span>
                    <strong>{session.workout_template_name}</strong>
                    <small>
                      {formatDateTime(
                        session.completed_at ?? session.started_at,
                      )}
                      {' · '}
                      {sessionSummary(session)}
                    </small>
                  </span>
                </button>
              ))}

              {!isLoading && sessions.length === 0 ? (
                <p className="empty-state">No completed workouts yet.</p>
              ) : null}
            </div>
          </section>

          <section className="editor-panel" aria-labelledby="history-detail">
            {errorMessage ? (
              <div className="error-list" role="alert">
                <p>{errorMessage}</p>
              </div>
            ) : null}

            {selectedSession ? (
              <SessionDetail session={selectedSession} />
            ) : (
              <div className="empty-detail">
                <h2 id="history-detail">Workout Details</h2>
                <p>Select a completed workout to review its logged sets.</p>
              </div>
            )}
          </section>
        </div>
      </section>
    </main>
  )
}

function SessionDetail({ session }: { session: WorkoutSession }) {
  return (
    <>
      <div className="detail-heading">
        <div>
          <h2 id="history-detail">{session.workout_template_name}</h2>
          <p>
            {formatDateTime(session.started_at)}
            {session.completed_at
              ? ` to ${formatTime(session.completed_at)}`
              : ''}
          </p>
        </div>
        <span className="status-pill">{statusLabel(session.status)}</span>
      </div>

      <div className="session-summary-grid" aria-label="Workout summary">
        <SummaryItem
          label="Exercises"
          value={String(session.exercises.length)}
        />
        <SummaryItem
          label="Sets"
          value={`${performedSetCount(session)} / ${totalSetCount(session)}`}
        />
        <SummaryItem label="Template" value={session.workout_template_name} />
      </div>

      <div className="history-exercise-list">
        {session.exercises
          .slice()
          .sort((first, second) => first.position - second.position)
          .map((exercise) => (
            <ExerciseDetail exercise={exercise} key={exercise.id} />
          ))}
      </div>
    </>
  )
}

function ExerciseDetail({ exercise }: { exercise: WorkoutSessionExercise }) {
  return (
    <section className="history-exercise" aria-labelledby={exercise.id}>
      <div className="compact-heading">
        <h3 id={exercise.id}>{exercise.label}</h3>
        <span>{exercise.selected_exercise.name}</span>
      </div>

      <div className="set-result-list">
        {exercise.workout_session_sets
          .slice()
          .sort((first, second) => first.position - second.position)
          .map((set) => (
            <SetResult set={set} key={set.id} />
          ))}
      </div>
    </section>
  )
}

function SetResult({ set }: { set: WorkoutSessionSet }) {
  return (
    <div className="set-result-row">
      <span>
        <strong>Set {set.position}</strong>
        <small>
          {set.target_rep_min}-{set.target_rep_max} reps
        </small>
      </span>
      <span>{completionStateLabel(set.completion_state)}</span>
      <span>{set.actual_reps == null ? '-' : `${set.actual_reps} reps`}</span>
      <span>{formatLoad(set.actual_load_value)}</span>
    </div>
  )
}

function SummaryItem({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}

function sessionSummary(session: WorkoutSession) {
  return `${performedSetCount(session)} of ${totalSetCount(session)} sets logged`
}

function performedSetCount(session: WorkoutSession) {
  return session.exercises.reduce((count, exercise) => {
    return (
      count +
      exercise.workout_session_sets.filter((set) =>
        ['completed', 'attempted_but_target_not_met'].includes(
          set.completion_state,
        ),
      ).length
    )
  }, 0)
}

function totalSetCount(session: WorkoutSession) {
  return session.exercises.reduce(
    (count, exercise) => count + exercise.workout_session_sets.length,
    0,
  )
}

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

function formatTime(value: string) {
  return new Intl.DateTimeFormat(undefined, {
    timeStyle: 'short',
  }).format(new Date(value))
}

function formatLoad(value: number | null) {
  if (value == null) {
    return '-'
  }

  return `${formatNumber(value)} load`
}

function formatNumber(value: number) {
  return Number.isInteger(value)
    ? String(value)
    : value.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
}

function statusLabel(status: WorkoutSession['status']) {
  return status[0].toUpperCase() + status.slice(1)
}

function completionStateLabel(state: WorkoutSessionSet['completion_state']) {
  switch (state) {
    case 'completed':
      return 'Completed'
    case 'attempted_but_target_not_met':
      return 'Attempted'
    case 'not_performed':
      return 'Not Performed'
    case 'pending':
      return 'Pending'
  }
}
