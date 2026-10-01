import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'

import {
  ExerciseApiError,
  createExercise,
  listExercises,
  loadTypes,
  updateExercise,
} from '../../api/exercises'
import type { Exercise, ExercisePayload, LoadType } from '../../api/exercises'

type Draft = {
  name: string
  primaryMuscleGroup: string
  secondaryMuscleGroups: string
  loadType: LoadType
  notes: string
  externalUrl: string
}

const emptyDraft: Draft = {
  name: '',
  primaryMuscleGroup: '',
  secondaryMuscleGroups: '',
  loadType: 'lb',
  notes: '',
  externalUrl: '',
}

const loadTypeLabels: Record<LoadType, string> = {
  lb: 'Pounds',
  kg: 'Kilograms',
  machine_stack: 'Machine stack',
  plate_count: 'Plate count',
  bodyweight: 'Bodyweight',
  bodyweight_plus_added: 'Bodyweight plus added',
  assisted: 'Assisted',
  none: 'None',
}

export function ExerciseLibrary() {
  const [exercises, setExercises] = useState<Exercise[]>([])
  const [query, setQuery] = useState('')
  const [selectedExercise, setSelectedExercise] = useState<Exercise | null>(
    null,
  )
  const [draft, setDraft] = useState<Draft>(emptyDraft)
  const [errors, setErrors] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    let isCurrent = true

    listExercises(query)
      .then((nextExercises) => {
        if (isCurrent) {
          setExercises(nextExercises)
        }
      })
      .catch(() => {
        if (isCurrent) {
          setErrors(['Could not load exercises.'])
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
  }, [query])

  const selectedId = selectedExercise?.id

  const panelTitle = useMemo(() => {
    return selectedExercise ? 'Edit Exercise' : 'New Exercise'
  }, [selectedExercise])

  function startNewExercise() {
    setSelectedExercise(null)
    setDraft(emptyDraft)
    setErrors([])
  }

  function handleQueryChange(value: string) {
    setQuery(value)
    setIsLoading(true)
  }

  function startEditing(exercise: Exercise) {
    setSelectedExercise(exercise)
    setDraft({
      name: exercise.name,
      primaryMuscleGroup: exercise.primary_muscle_group,
      secondaryMuscleGroups: exercise.secondary_muscle_groups.join(', '),
      loadType: exercise.load_type,
      notes: exercise.notes ?? '',
      externalUrl: exercise.external_url ?? '',
    })
    setErrors([])
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setIsSaving(true)
    setErrors([])

    const payload = toPayload(draft, selectedExercise ?? undefined)

    try {
      const savedExercise = selectedExercise
        ? await updateExercise(selectedExercise.id, payload)
        : await createExercise(payload)

      setSelectedExercise(savedExercise)
      setDraft({
        name: savedExercise.name,
        primaryMuscleGroup: savedExercise.primary_muscle_group,
        secondaryMuscleGroups: savedExercise.secondary_muscle_groups.join(', '),
        loadType: savedExercise.load_type,
        notes: savedExercise.notes ?? '',
        externalUrl: savedExercise.external_url ?? '',
      })
      setExercises((currentExercises) =>
        upsertExercise(currentExercises, savedExercise),
      )
    } catch (error) {
      setErrors(extractMessages(error))
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <main className="app-shell">
      <section className="library-layout" aria-labelledby="exercise-title">
        <header className="library-header">
          <div>
            <p className="eyebrow">Exercise Library</p>
            <h1 id="exercise-title">Exercises</h1>
          </div>
          <button
            className="secondary-button"
            type="button"
            onClick={startNewExercise}
          >
            New
          </button>
        </header>

        <div className="library-grid">
          <section className="library-list" aria-label="Exercise list">
            <label className="field-label" htmlFor="exercise-search">
              Search
            </label>
            <input
              id="exercise-search"
              className="text-input"
              type="search"
              value={query}
              onChange={(event) => handleQueryChange(event.target.value)}
              placeholder="Search exercises"
            />

            <div className="list-stack" aria-busy={isLoading}>
              {exercises.map((exercise) => (
                <button
                  className={`exercise-row ${exercise.id === selectedId ? 'selected' : ''}`}
                  key={exercise.id}
                  type="button"
                  onClick={() => startEditing(exercise)}
                >
                  <span>
                    <strong>{exercise.name}</strong>
                    <small>
                      {exercise.primary_muscle_group} ·{' '}
                      {loadTypeLabels[exercise.load_type]}
                    </small>
                  </span>
                </button>
              ))}

              {!isLoading && exercises.length === 0 ? (
                <p className="empty-state">No exercises found.</p>
              ) : null}
            </div>
          </section>

          <section
            className="editor-panel"
            aria-labelledby="exercise-form-title"
          >
            <h2 id="exercise-form-title">{panelTitle}</h2>

            {errors.length ? (
              <div className="error-list" role="alert">
                {errors.map((message) => (
                  <p key={message}>{message}</p>
                ))}
              </div>
            ) : null}

            <form className="exercise-form" onSubmit={handleSubmit}>
              <label className="field-label" htmlFor="exercise-name">
                Name
              </label>
              <input
                id="exercise-name"
                className="text-input"
                value={draft.name}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    name: event.target.value,
                  }))
                }
              />

              <label className="field-label" htmlFor="primary-muscle">
                Primary Muscle Group
              </label>
              <input
                id="primary-muscle"
                className="text-input"
                value={draft.primaryMuscleGroup}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    primaryMuscleGroup: event.target.value,
                  }))
                }
              />

              <label className="field-label" htmlFor="secondary-muscles">
                Secondary Muscle Groups
              </label>
              <input
                id="secondary-muscles"
                className="text-input"
                value={draft.secondaryMuscleGroups}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    secondaryMuscleGroups: event.target.value,
                  }))
                }
                placeholder="Comma-separated"
              />

              <label className="field-label" htmlFor="load-type">
                Load Type
              </label>
              <select
                id="load-type"
                className="text-input"
                value={draft.loadType}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    loadType: event.target.value as LoadType,
                  }))
                }
              >
                {loadTypes.map((loadType) => (
                  <option key={loadType} value={loadType}>
                    {loadTypeLabels[loadType]}
                  </option>
                ))}
              </select>

              <label className="field-label" htmlFor="external-url">
                External URL
              </label>
              <input
                id="external-url"
                className="text-input"
                value={draft.externalUrl}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    externalUrl: event.target.value,
                  }))
                }
              />

              <label className="field-label" htmlFor="notes">
                Notes
              </label>
              <textarea
                id="notes"
                className="text-input notes-input"
                value={draft.notes}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    notes: event.target.value,
                  }))
                }
              />

              <div className="form-actions">
                <button
                  className="primary-button"
                  type="submit"
                  disabled={isSaving}
                >
                  {isSaving ? 'Saving' : 'Save'}
                </button>
                <button
                  className="secondary-button"
                  type="button"
                  onClick={startNewExercise}
                >
                  Clear
                </button>
              </div>
            </form>
          </section>
        </div>
      </section>
    </main>
  )
}

function toPayload(draft: Draft, exercise?: Exercise): ExercisePayload {
  return {
    name: draft.name,
    primary_muscle_group: draft.primaryMuscleGroup,
    secondary_muscle_groups: draft.secondaryMuscleGroups
      .split(',')
      .map((group) => group.trim())
      .filter(Boolean),
    load_type: draft.loadType,
    notes: draft.notes.trim() || null,
    external_url: draft.externalUrl.trim() || null,
    lock_version: exercise?.lock_version,
  }
}

function upsertExercise(exercises: Exercise[], exercise: Exercise): Exercise[] {
  const existingIndex = exercises.findIndex(
    (current) => current.id === exercise.id,
  )

  if (existingIndex === -1) {
    return [...exercises, exercise].sort((left, right) =>
      left.name.localeCompare(right.name),
    )
  }

  return exercises.map((current) =>
    current.id === exercise.id ? exercise : current,
  )
}

function extractMessages(error: unknown): string[] {
  if (error instanceof ExerciseApiError) {
    return error.errors.map((apiError) => apiError.message)
  }

  if (error instanceof Error) {
    return [error.message]
  }

  return ['Something went wrong.']
}
