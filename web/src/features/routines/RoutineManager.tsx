import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'

import { listExercises } from '../../api/exercises'
import type { Exercise } from '../../api/exercises'
import {
  RoutineApiError,
  createRoutine,
  listRoutines,
  updateRoutine,
} from '../../api/routines'
import type {
  Routine,
  RoutineItemPayload,
  RoutineStatus,
  RoutineTargetMode,
} from '../../api/routines'

type RoutineDraft = {
  name: string
  notes: string
  items: RoutineItemDraft[]
}

type RoutineItemDraft = {
  id?: string
  exerciseId: string
  targetMode: RoutineTargetMode
  sets: string
  targetReps: string
  targetDurationSeconds: string
  notesOverride: string
}

const emptyDraft: RoutineDraft = { name: '', notes: '', items: [] }

export function RoutineManager() {
  const [routines, setRoutines] = useState<Routine[]>([])
  const [exercises, setExercises] = useState<Exercise[]>([])
  const [selectedRoutine, setSelectedRoutine] = useState<Routine | null>(null)
  const [draft, setDraft] = useState<RoutineDraft>(emptyDraft)
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState<RoutineStatus>('active')
  const [errors, setErrors] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    let isCurrent = true

    listRoutines(query, status)
      .then((nextRoutines) => {
        if (isCurrent) {
          setRoutines(nextRoutines)
          setSelectedRoutine(
            (current) =>
              nextRoutines.find((routine) => routine.id === current?.id) ??
              null,
          )
        }
      })
      .catch(() => {
        if (isCurrent) {
          setErrors(['Could not load routines.'])
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
  }, [query, status])

  useEffect(() => {
    let isCurrent = true

    listExercises('', 'active')
      .then((nextExercises) => {
        if (isCurrent) {
          setExercises(nextExercises)
        }
      })
      .catch(() => {
        if (isCurrent) {
          setErrors(['Could not load exercises for routines.'])
        }
      })

    return () => {
      isCurrent = false
    }
  }, [])

  function selectRoutine(routine: Routine) {
    setSelectedRoutine(routine)
    setDraft(draftFromRoutine(routine))
    setErrors([])
  }

  function startNewRoutine() {
    setSelectedRoutine(null)
    setDraft(emptyDraft)
    setErrors([])
  }

  function addItem(exerciseId: string) {
    if (
      !exerciseId ||
      draft.items.some((item) => item.exerciseId === exerciseId)
    ) {
      return
    }

    setDraft((current) => ({
      ...current,
      items: [
        ...current.items,
        {
          exerciseId,
          targetMode: 'completion_only',
          sets: '',
          targetReps: '',
          targetDurationSeconds: '',
          notesOverride: '',
        },
      ],
    }))
  }

  function updateItem(index: number, updates: Partial<RoutineItemDraft>) {
    setDraft((current) => ({
      ...current,
      items: current.items.map((item, itemIndex) =>
        itemIndex === index ? { ...item, ...updates } : item,
      ),
    }))
  }

  function changeTargetMode(index: number, targetMode: RoutineTargetMode) {
    const clearedFields: Partial<RoutineItemDraft> =
      targetMode === 'completion_only'
        ? { sets: '', targetReps: '', targetDurationSeconds: '' }
        : targetMode === 'duration'
          ? { targetReps: '' }
          : { targetDurationSeconds: '' }

    updateItem(index, { targetMode, ...clearedFields })
  }

  function moveItem(index: number, direction: -1 | 1) {
    const targetIndex = index + direction
    if (targetIndex < 0 || targetIndex >= draft.items.length) {
      return
    }

    setDraft((current) => {
      const items = [...current.items]
      ;[items[index], items[targetIndex]] = [items[targetIndex], items[index]]
      return { ...current, items }
    })
  }

  async function saveRoutine(event: FormEvent) {
    event.preventDefault()
    setErrors([])
    setIsSaving(true)

    try {
      const payload = {
        name: draft.name,
        notes: draft.notes.trim() || null,
        lock_version: selectedRoutine?.lock_version,
        items: draft.items.map(itemPayload),
      }
      const savedRoutine = selectedRoutine
        ? await updateRoutine(selectedRoutine.id, payload)
        : await createRoutine(payload)

      setRoutines((current) =>
        [
          ...current.filter((routine) => routine.id !== savedRoutine.id),
          savedRoutine,
        ].sort((left, right) => left.name.localeCompare(right.name)),
      )
      selectRoutine(savedRoutine)
    } catch (error) {
      setErrors(errorMessages(error, 'Could not save routine.'))
    } finally {
      setIsSaving(false)
    }
  }

  async function toggleArchive() {
    if (!selectedRoutine) {
      return
    }

    const action = selectedRoutine.archived_at ? 'restore' : 'archive'
    if (
      !confirm(
        `${action === 'archive' ? 'Archive' : 'Restore'} ${selectedRoutine.name}?`,
      )
    ) {
      return
    }

    setErrors([])
    setIsSaving(true)

    try {
      const savedRoutine = await updateRoutine(selectedRoutine.id, {
        archived_at: selectedRoutine.archived_at
          ? null
          : new Date().toISOString(),
        lock_version: selectedRoutine.lock_version,
      })
      setRoutines((current) =>
        current.filter((routine) => routine.id !== savedRoutine.id),
      )
      startNewRoutine()
    } catch (error) {
      setErrors(errorMessages(error, `Could not ${action} routine.`))
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <main className="app-shell">
      <section className="library-layout" aria-labelledby="routines-title">
        <header className="library-header">
          <div>
            <p className="eyebrow">Routine Library</p>
            <h1 id="routines-title">Routines</h1>
          </div>
          <button
            className="primary-button"
            type="button"
            onClick={startNewRoutine}
          >
            New Routine
          </button>
        </header>

        <div className="library-grid">
          <section className="library-list" aria-label="Routine list">
            <label className="field-label" htmlFor="routine-search">
              Search
            </label>
            <input
              id="routine-search"
              className="text-input"
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
            <div className="filter-tabs" aria-label="Routine status">
              {(['active', 'archived', 'all'] as const).map((nextStatus) => (
                <button
                  className={status === nextStatus ? 'selected' : ''}
                  key={nextStatus}
                  type="button"
                  onClick={() => setStatus(nextStatus)}
                >
                  {capitalize(nextStatus)}
                </button>
              ))}
            </div>
            <div className="list-stack">
              {isLoading ? (
                <p className="empty-state">Loading routines...</p>
              ) : null}
              {!isLoading && routines.length === 0 ? (
                <p className="empty-state">No routines found.</p>
              ) : null}
              {routines.map((routine) => (
                <button
                  className={`exercise-row ${selectedRoutine?.id === routine.id ? 'selected' : ''}`}
                  key={routine.id}
                  type="button"
                  onClick={() => selectRoutine(routine)}
                >
                  <span>
                    <strong>{routine.name}</strong>
                    <small>
                      {routine.items.length}{' '}
                      {routine.items.length === 1 ? 'item' : 'items'}
                    </small>
                  </span>
                </button>
              ))}
            </div>
          </section>

          <section
            className="editor-panel"
            aria-labelledby="routine-editor-title"
          >
            <h2 id="routine-editor-title">
              {selectedRoutine ? 'Edit Routine' : 'Create Routine'}
            </h2>
            {errors.length ? (
              <div className="error-list" role="alert">
                {errors.map((error) => (
                  <p key={error}>{error}</p>
                ))}
              </div>
            ) : null}
            <form className="exercise-form" onSubmit={saveRoutine}>
              <label className="field-label">
                Name
                <input
                  className="text-input"
                  value={draft.name}
                  onChange={(event) =>
                    setDraft((current) => ({
                      ...current,
                      name: event.target.value,
                    }))
                  }
                />
              </label>
              <label className="field-label">
                Notes
                <textarea
                  className="text-input notes-input"
                  value={draft.notes}
                  onChange={(event) =>
                    setDraft((current) => ({
                      ...current,
                      notes: event.target.value,
                    }))
                  }
                />
              </label>

              <div className="routine-item-editor">
                <div className="section-heading">
                  <h3>Routine Items</h3>
                  <select
                    className="text-input routine-exercise-picker"
                    aria-label="Add routine exercise"
                    value=""
                    onChange={(event) => addItem(event.target.value)}
                  >
                    <option value="">Add exercise</option>
                    {exercises
                      .filter(
                        (exercise) =>
                          !draft.items.some(
                            (item) => item.exerciseId === exercise.id,
                          ),
                      )
                      .map((exercise) => (
                        <option key={exercise.id} value={exercise.id}>
                          {exercise.name}
                        </option>
                      ))}
                  </select>
                </div>

                {draft.items.length === 0 ? (
                  <p className="empty-state">
                    Add exercises to build this routine.
                  </p>
                ) : null}

                {draft.items.map((item, index) => (
                  <RoutineItemEditor
                    exercises={exercises}
                    index={index}
                    item={item}
                    key={item.id ?? item.exerciseId}
                    onChange={(updates) => updateItem(index, updates)}
                    onModeChange={(targetMode) =>
                      changeTargetMode(index, targetMode)
                    }
                    onMove={(direction) => moveItem(index, direction)}
                    onRemove={() =>
                      setDraft((current) => ({
                        ...current,
                        items: current.items.filter(
                          (_, itemIndex) => itemIndex !== index,
                        ),
                      }))
                    }
                    totalItems={draft.items.length}
                  />
                ))}
              </div>

              <div className="form-actions">
                <button
                  className="primary-button"
                  type="submit"
                  disabled={isSaving}
                >
                  {isSaving ? 'Saving...' : 'Save'}
                </button>
                {selectedRoutine ? (
                  <button
                    className={
                      selectedRoutine.archived_at
                        ? 'secondary-button'
                        : 'danger-button'
                    }
                    type="button"
                    onClick={toggleArchive}
                    disabled={isSaving}
                  >
                    {selectedRoutine.archived_at ? 'Restore' : 'Archive'}
                  </button>
                ) : null}
              </div>
            </form>
          </section>
        </div>
      </section>
    </main>
  )
}

type RoutineItemEditorProps = {
  exercises: Exercise[]
  index: number
  item: RoutineItemDraft
  totalItems: number
  onChange: (updates: Partial<RoutineItemDraft>) => void
  onModeChange: (targetMode: RoutineTargetMode) => void
  onMove: (direction: -1 | 1) => void
  onRemove: () => void
}

function RoutineItemEditor({
  exercises,
  index,
  item,
  totalItems,
  onChange,
  onModeChange,
  onMove,
  onRemove,
}: RoutineItemEditorProps) {
  const exercise = exercises.find(
    (candidate) => candidate.id === item.exerciseId,
  )
  const numberLabel = `Item ${index + 1}`

  return (
    <article className="slot-card">
      <div className="slot-card-header">
        <h4>
          {index + 1}. {exercise?.name ?? 'Unavailable exercise'}
        </h4>
        <div className="inline-actions">
          <button
            className="secondary-button compact-button"
            type="button"
            onClick={() => onMove(-1)}
            disabled={index === 0}
          >
            Move Up
          </button>
          <button
            className="secondary-button compact-button"
            type="button"
            onClick={() => onMove(1)}
            disabled={index === totalItems - 1}
          >
            Move Down
          </button>
          <button
            className="danger-button compact-button"
            type="button"
            onClick={onRemove}
          >
            Remove
          </button>
        </div>
      </div>

      <div className="routine-target-grid">
        <label className="field-label">
          Target Mode
          <select
            className="text-input"
            aria-label={`${numberLabel} target mode`}
            value={item.targetMode}
            onChange={(event) =>
              onModeChange(event.target.value as RoutineTargetMode)
            }
          >
            <option value="completion_only">Completion only</option>
            <option value="reps">Reps</option>
            <option value="duration">Duration</option>
            <option value="load_optional">Optional load</option>
          </select>
        </label>

        {item.targetMode !== 'completion_only' ? (
          <label className="field-label">
            Sets
            <input
              className="text-input"
              aria-label={`${numberLabel} sets`}
              inputMode="numeric"
              value={item.sets}
              onChange={(event) => onChange({ sets: event.target.value })}
            />
          </label>
        ) : null}

        {item.targetMode === 'reps' || item.targetMode === 'load_optional' ? (
          <label className="field-label">
            Target Reps
            <input
              className="text-input"
              aria-label={`${numberLabel} target reps`}
              inputMode="numeric"
              value={item.targetReps}
              onChange={(event) => onChange({ targetReps: event.target.value })}
            />
          </label>
        ) : null}

        {item.targetMode === 'duration' ? (
          <label className="field-label">
            Seconds
            <input
              className="text-input"
              aria-label={`${numberLabel} target seconds`}
              inputMode="numeric"
              value={item.targetDurationSeconds}
              onChange={(event) =>
                onChange({ targetDurationSeconds: event.target.value })
              }
            />
          </label>
        ) : null}
      </div>

      <label className="field-label">
        Notes Override
        <input
          className="text-input"
          aria-label={`${numberLabel} notes override`}
          value={item.notesOverride}
          onChange={(event) => onChange({ notesOverride: event.target.value })}
        />
      </label>
    </article>
  )
}

function draftFromRoutine(routine: Routine): RoutineDraft {
  return {
    name: routine.name,
    notes: routine.notes ?? '',
    items: routine.items.map((item) => ({
      id: item.id,
      exerciseId: item.exercise_id,
      targetMode: item.target_mode,
      sets: numberToDraft(item.sets),
      targetReps: numberToDraft(item.target_reps),
      targetDurationSeconds: numberToDraft(item.target_duration_seconds),
      notesOverride: item.notes_override ?? '',
    })),
  }
}

function itemPayload(
  item: RoutineItemDraft,
  index: number,
): RoutineItemPayload {
  return {
    id: item.id,
    position: index + 1,
    exercise_id: item.exerciseId,
    target_mode: item.targetMode,
    sets: optionalInteger(item.sets),
    target_reps: optionalInteger(item.targetReps),
    target_duration_seconds: optionalInteger(item.targetDurationSeconds),
    notes_override: item.notesOverride.trim() || null,
  }
}

function optionalInteger(value: string): number | null {
  return value.trim() ? Number.parseInt(value, 10) : null
}

function numberToDraft(value: number | null): string {
  return value === null ? '' : String(value)
}

function errorMessages(error: unknown, fallback: string): string[] {
  if (error instanceof RoutineApiError) {
    return error.errors.map((apiError) => apiError.message)
  }
  return [fallback]
}

function capitalize(value: string) {
  return `${value.charAt(0).toUpperCase()}${value.slice(1)}`
}
