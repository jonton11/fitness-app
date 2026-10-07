import { useEffect, useMemo, useState } from 'react'

import {
  WorkoutSessionApiError,
  listWorkoutSessions,
  updateWorkoutSessionSet,
} from '../../api/workoutSessions'
import type {
  WorkoutSession,
  WorkoutSessionExercise,
  WorkoutSessionSet,
  WorkoutSessionSetCompletionState,
  WorkoutSessionSetPayload,
} from '../../api/workoutSessions'

type SetDraft = {
  completionState: WorkoutSessionSetCompletionState
  actualReps: string
  actualLoadValue: string
}

export function WorkoutHistory() {
  const [sessions, setSessions] = useState<WorkoutSession[]>([])
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(
    null,
  )
  const [isLoading, setIsLoading] = useState(true)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [editingSetId, setEditingSetId] = useState<string | null>(null)
  const [setDraft, setSetDraft] = useState<SetDraft | null>(null)
  const [setErrors, setSetErrors] = useState<string[]>([])
  const [isSavingSet, setIsSavingSet] = useState(false)

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

  function startEditingSet(set: WorkoutSessionSet) {
    setEditingSetId(set.id)
    setSetDraft({
      completionState: set.completion_state,
      actualReps: set.actual_reps == null ? '' : String(set.actual_reps),
      actualLoadValue:
        set.actual_load_value == null
          ? ''
          : formatNumber(set.actual_load_value),
    })
    setSetErrors([])
  }

  function updateSetDraft(changes: Partial<SetDraft>) {
    setSetDraft((currentDraft) =>
      currentDraft ? { ...currentDraft, ...changes } : currentDraft,
    )
    setSetErrors([])
  }

  function cancelEditingSet() {
    setEditingSetId(null)
    setSetDraft(null)
    setSetErrors([])
  }

  async function saveSetCorrection(set: WorkoutSessionSet) {
    if (!setDraft) {
      return
    }

    const payload = correctionPayload(set, setDraft)

    if ('errors' in payload) {
      setSetErrors(payload.errors)
      return
    }

    setIsSavingSet(true)
    setSetErrors([])

    try {
      const savedSet = await updateWorkoutSessionSet(set.id, payload)
      setSessions((currentSessions) =>
        currentSessions.map((session) => replaceSessionSet(session, savedSet)),
      )
      cancelEditingSet()
    } catch (error) {
      setSetErrors(extractMessages(error))
    } finally {
      setIsSavingSet(false)
    }
  }

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
              <SessionDetail
                editingSetId={editingSetId}
                isSavingSet={isSavingSet}
                onCancelSetEdit={cancelEditingSet}
                onSaveSet={saveSetCorrection}
                onSetDraftChange={updateSetDraft}
                onStartSetEdit={startEditingSet}
                session={selectedSession}
                setDraft={setDraft}
                setErrors={setErrors}
              />
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

function SessionDetail({
  editingSetId,
  isSavingSet,
  onCancelSetEdit,
  onSaveSet,
  onSetDraftChange,
  onStartSetEdit,
  session,
  setDraft,
  setErrors,
}: {
  editingSetId: string | null
  isSavingSet: boolean
  onCancelSetEdit: () => void
  onSaveSet: (set: WorkoutSessionSet) => void
  onSetDraftChange: (changes: Partial<SetDraft>) => void
  onStartSetEdit: (set: WorkoutSessionSet) => void
  session: WorkoutSession
  setDraft: SetDraft | null
  setErrors: string[]
}) {
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

      {setErrors.length ? (
        <div className="error-list" role="alert">
          {setErrors.map((message) => (
            <p key={message}>{message}</p>
          ))}
        </div>
      ) : null}

      <div className="history-exercise-list">
        {session.exercises
          .slice()
          .sort((first, second) => first.position - second.position)
          .map((exercise) => (
            <ExerciseDetail
              editingSetId={editingSetId}
              exercise={exercise}
              isSavingSet={isSavingSet}
              key={exercise.id}
              onCancelSetEdit={onCancelSetEdit}
              onSaveSet={onSaveSet}
              onSetDraftChange={onSetDraftChange}
              onStartSetEdit={onStartSetEdit}
              setDraft={setDraft}
            />
          ))}
      </div>
    </>
  )
}

function ExerciseDetail({
  editingSetId,
  exercise,
  isSavingSet,
  onCancelSetEdit,
  onSaveSet,
  onSetDraftChange,
  onStartSetEdit,
  setDraft,
}: {
  editingSetId: string | null
  exercise: WorkoutSessionExercise
  isSavingSet: boolean
  onCancelSetEdit: () => void
  onSaveSet: (set: WorkoutSessionSet) => void
  onSetDraftChange: (changes: Partial<SetDraft>) => void
  onStartSetEdit: (set: WorkoutSessionSet) => void
  setDraft: SetDraft | null
}) {
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
            <SetResult
              isEditing={editingSetId === set.id}
              isSaving={isSavingSet}
              key={set.id}
              onCancel={onCancelSetEdit}
              onDraftChange={onSetDraftChange}
              onEdit={onStartSetEdit}
              onSave={onSaveSet}
              set={set}
              setDraft={setDraft}
            />
          ))}
      </div>
    </section>
  )
}

function SetResult({
  isEditing,
  isSaving,
  onCancel,
  onDraftChange,
  onEdit,
  onSave,
  set,
  setDraft,
}: {
  isEditing: boolean
  isSaving: boolean
  onCancel: () => void
  onDraftChange: (changes: Partial<SetDraft>) => void
  onEdit: (set: WorkoutSessionSet) => void
  onSave: (set: WorkoutSessionSet) => void
  set: WorkoutSessionSet
  setDraft: SetDraft | null
}) {
  if (isEditing && setDraft) {
    const isPerformed = performedCompletionState(setDraft.completionState)

    return (
      <form
        className="set-edit-form"
        onSubmit={(event) => {
          event.preventDefault()
          onSave(set)
        }}
      >
        <label className="field-label">
          State
          <select
            className="text-input"
            aria-label={`Set ${set.position} state`}
            value={setDraft.completionState}
            onChange={(event) =>
              onDraftChange({
                completionState: event.target
                  .value as WorkoutSessionSetCompletionState,
              })
            }
          >
            <option value="completed">Completed</option>
            <option value="attempted_but_target_not_met">Attempted</option>
            <option value="not_performed">Not Performed</option>
          </select>
        </label>

        <label className="field-label">
          Reps
          <input
            className="text-input"
            aria-label={`Set ${set.position} actual reps`}
            disabled={!isPerformed}
            inputMode="numeric"
            min="0"
            type="number"
            value={isPerformed ? setDraft.actualReps : ''}
            onChange={(event) =>
              onDraftChange({ actualReps: event.target.value })
            }
          />
        </label>

        <label className="field-label">
          Load
          <input
            className="text-input"
            aria-label={`Set ${set.position} actual load`}
            disabled={!isPerformed}
            inputMode="decimal"
            min="0"
            step="0.01"
            type="number"
            value={isPerformed ? setDraft.actualLoadValue : ''}
            onChange={(event) =>
              onDraftChange({ actualLoadValue: event.target.value })
            }
          />
        </label>

        <div className="inline-actions set-edit-actions">
          <button
            className="primary-button compact-button"
            disabled={isSaving}
            type="submit"
          >
            Save
          </button>
          <button
            className="secondary-button compact-button"
            disabled={isSaving}
            type="button"
            onClick={onCancel}
          >
            Cancel
          </button>
        </div>
      </form>
    )
  }

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
      <button
        className="secondary-button compact-button"
        aria-label={`Edit set ${set.position}`}
        type="button"
        onClick={() => onEdit(set)}
      >
        Edit
      </button>
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
        performedCompletionState(set.completion_state),
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

function correctionPayload(
  set: WorkoutSessionSet,
  draft: SetDraft,
): WorkoutSessionSetPayload | { errors: string[] } {
  if (!performedCompletionState(draft.completionState)) {
    return {
      completion_state: draft.completionState,
      lock_version: set.lock_version,
    }
  }

  const actualReps = parseNonNegativeInteger(draft.actualReps)
  const actualLoadValue = parseOptionalNonNegativeNumber(draft.actualLoadValue)
  const errors: string[] = []

  if (actualReps == null) {
    errors.push('Enter reps for performed sets.')
  }

  if (actualLoadValue === false) {
    errors.push('Enter a valid load.')
  }

  if (errors.length) {
    return { errors }
  }

  const validActualLoadValue =
    actualLoadValue === false ? null : actualLoadValue

  return {
    actual_reps: actualReps,
    actual_load_value: validActualLoadValue,
    completion_state: draft.completionState,
    lock_version: set.lock_version,
  }
}

function parseNonNegativeInteger(value: string) {
  const trimmedValue = value.trim()
  if (!trimmedValue) {
    return null
  }

  const parsedValue = Number(trimmedValue)
  return Number.isInteger(parsedValue) && parsedValue >= 0 ? parsedValue : null
}

function parseOptionalNonNegativeNumber(value: string) {
  const trimmedValue = value.trim()
  if (!trimmedValue) {
    return null
  }

  const parsedValue = Number(trimmedValue)
  return Number.isFinite(parsedValue) && parsedValue >= 0 ? parsedValue : false
}

function replaceSessionSet(
  session: WorkoutSession,
  savedSet: WorkoutSessionSet,
) {
  if (
    !session.exercises.some((exercise) =>
      exercise.workout_session_sets.some((set) => set.id === savedSet.id),
    )
  ) {
    return session
  }

  return {
    ...session,
    exercises: session.exercises.map((exercise) => ({
      ...exercise,
      workout_session_sets: exercise.workout_session_sets.map((set) =>
        set.id === savedSet.id ? savedSet : set,
      ),
    })),
  }
}

function extractMessages(error: unknown) {
  if (error instanceof WorkoutSessionApiError) {
    return error.errors.map((apiError) => apiError.message)
  }

  return ['Could not save workout correction.']
}

function performedCompletionState(state: WorkoutSessionSetCompletionState) {
  return state === 'completed' || state === 'attempted_but_target_not_met'
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
