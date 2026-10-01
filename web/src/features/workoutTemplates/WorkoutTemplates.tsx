import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'

import {
  WorkoutTemplateApiError,
  createWorkoutTemplate,
  listWorkoutTemplates,
  updateWorkoutTemplate,
} from '../../api/workoutTemplates'
import type {
  WorkoutTemplate,
  WorkoutTemplatePayload,
  WorkoutTemplateStatus,
} from '../../api/workoutTemplates'

type Draft = {
  name: string
  notes: string
}

const emptyDraft: Draft = {
  name: '',
  notes: '',
}

export function WorkoutTemplates() {
  const [templates, setTemplates] = useState<WorkoutTemplate[]>([])
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState<WorkoutTemplateStatus>('active')
  const [selectedTemplate, setSelectedTemplate] =
    useState<WorkoutTemplate | null>(null)
  const [draft, setDraft] = useState<Draft>(emptyDraft)
  const [errors, setErrors] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    let isCurrent = true

    listWorkoutTemplates(query, status)
      .then((nextTemplates) => {
        if (isCurrent) {
          setTemplates(nextTemplates)
        }
      })
      .catch(() => {
        if (isCurrent) {
          setErrors(['Could not load workout templates.'])
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

  const selectedId = selectedTemplate?.id

  const panelTitle = useMemo(() => {
    return selectedTemplate ? 'Edit Template' : 'New Template'
  }, [selectedTemplate])

  function startNewTemplate() {
    setSelectedTemplate(null)
    setDraft(emptyDraft)
    setErrors([])
  }

  function handleQueryChange(value: string) {
    setQuery(value)
    setIsLoading(true)
  }

  function handleStatusChange(nextStatus: WorkoutTemplateStatus) {
    setStatus(nextStatus)
    setSelectedTemplate(null)
    setDraft(emptyDraft)
    setErrors([])
    setIsLoading(true)
  }

  function startEditing(template: WorkoutTemplate) {
    setSelectedTemplate(template)
    setDraft({
      name: template.name,
      notes: template.notes ?? '',
    })
    setErrors([])
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setIsSaving(true)
    setErrors([])

    const payload = toPayload(draft, selectedTemplate ?? undefined)

    try {
      const savedTemplate = selectedTemplate
        ? await updateWorkoutTemplate(selectedTemplate.id, payload)
        : await createWorkoutTemplate(payload)

      setSelectedTemplate(savedTemplate)
      setDraft({
        name: savedTemplate.name,
        notes: savedTemplate.notes ?? '',
      })
      setTemplates((currentTemplates) =>
        upsertTemplate(currentTemplates, savedTemplate),
      )
    } catch (error) {
      setErrors(extractMessages(error))
    } finally {
      setIsSaving(false)
    }
  }

  async function handleArchiveToggle() {
    if (!selectedTemplate) {
      return
    }

    if (
      !selectedTemplate.archived_at &&
      !confirmArchive(selectedTemplate.name)
    ) {
      return
    }

    setIsSaving(true)
    setErrors([])

    const payload = {
      ...toPayload(draft, selectedTemplate),
      archived_at: selectedTemplate.archived_at
        ? null
        : new Date().toISOString(),
    }

    try {
      const savedTemplate = await updateWorkoutTemplate(
        selectedTemplate.id,
        payload,
      )
      setSelectedTemplate(savedTemplate)
      setTemplates((currentTemplates) =>
        shouldShowInCurrentStatus(savedTemplate, status)
          ? upsertTemplate(currentTemplates, savedTemplate)
          : currentTemplates.filter(
              (template) => template.id !== savedTemplate.id,
            ),
      )
    } catch (error) {
      setErrors(extractMessages(error))
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <main className="app-shell">
      <section className="library-layout" aria-labelledby="templates-title">
        <header className="library-header">
          <div>
            <p className="eyebrow">Workout Templates</p>
            <h1 id="templates-title">Workouts</h1>
          </div>
          <button
            className="secondary-button"
            type="button"
            onClick={startNewTemplate}
          >
            New
          </button>
        </header>

        <div className="library-grid">
          <section className="library-list" aria-label="Workout template list">
            <label className="field-label" htmlFor="template-search">
              Search
            </label>
            <input
              id="template-search"
              className="text-input"
              type="search"
              value={query}
              onChange={(event) => handleQueryChange(event.target.value)}
              placeholder="Search templates"
            />

            <div className="filter-tabs" aria-label="Workout template status">
              {(
                ['active', 'archived', 'all'] satisfies WorkoutTemplateStatus[]
              ).map((nextStatus) => (
                <button
                  className={status === nextStatus ? 'selected' : ''}
                  key={nextStatus}
                  type="button"
                  onClick={() => handleStatusChange(nextStatus)}
                >
                  {statusLabel(nextStatus)}
                </button>
              ))}
            </div>

            <div className="list-stack" aria-busy={isLoading}>
              {templates.map((template) => (
                <button
                  className={`exercise-row ${template.id === selectedId ? 'selected' : ''}`}
                  key={template.id}
                  type="button"
                  onClick={() => startEditing(template)}
                >
                  <span>
                    <strong>{template.name}</strong>
                    <small>
                      {template.slots.length}{' '}
                      {template.slots.length === 1 ? 'exercise' : 'exercises'}
                      {template.archived_at ? ' · Archived' : ''}
                    </small>
                  </span>
                </button>
              ))}

              {!isLoading && templates.length === 0 ? (
                <p className="empty-state">No workout templates found.</p>
              ) : null}
            </div>
          </section>

          <section
            className="editor-panel"
            aria-labelledby="template-form-title"
          >
            <h2 id="template-form-title">{panelTitle}</h2>

            {selectedTemplate?.archived_at ? (
              <p className="archive-note" role="status">
                Archived templates are hidden from normal workout selection.
              </p>
            ) : null}

            {errors.length ? (
              <div className="error-list" role="alert">
                {errors.map((message) => (
                  <p key={message}>{message}</p>
                ))}
              </div>
            ) : null}

            <form className="exercise-form" onSubmit={handleSubmit}>
              <label className="field-label" htmlFor="template-name">
                Name
              </label>
              <input
                id="template-name"
                className="text-input"
                value={draft.name}
                onChange={(event) =>
                  setDraft((current) => ({
                    ...current,
                    name: event.target.value,
                  }))
                }
              />

              <label className="field-label" htmlFor="template-notes">
                Notes
              </label>
              <textarea
                id="template-notes"
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
                {selectedTemplate ? (
                  <button
                    className={
                      selectedTemplate.archived_at
                        ? 'secondary-button'
                        : 'danger-button'
                    }
                    type="button"
                    onClick={handleArchiveToggle}
                    disabled={isSaving}
                  >
                    {selectedTemplate.archived_at ? 'Restore' : 'Archive'}
                  </button>
                ) : null}
                <button
                  className="secondary-button"
                  type="button"
                  onClick={startNewTemplate}
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

function toPayload(
  draft: Draft,
  template?: WorkoutTemplate,
): WorkoutTemplatePayload {
  return {
    name: draft.name,
    notes: draft.notes.trim() || null,
    lock_version: template?.lock_version,
    slots: template?.slots.map((slot) => ({
      id: slot.id,
      position: slot.position,
      label: slot.label,
      default_exercise_id: slot.default_exercise_id,
      rest_seconds: slot.rest_seconds,
      lock_version: slot.lock_version,
      exercise_options: slot.exercise_options.map((option) => ({
        id: option.id,
        position: option.position,
        exercise_id: option.exercise_id,
        starting_load_value: option.starting_load_value,
        next_load_value: option.next_load_value,
        progression_increment: option.progression_increment,
      })),
      set_prescriptions: slot.set_prescriptions.map((prescription) => ({
        id: prescription.id,
        position: prescription.position,
        set_type: prescription.set_type,
        rep_min: prescription.rep_min,
        rep_max: prescription.rep_max,
        load_strategy: prescription.load_strategy,
        load_value: prescription.load_value,
      })),
    })),
  }
}

function upsertTemplate(
  templates: WorkoutTemplate[],
  template: WorkoutTemplate,
): WorkoutTemplate[] {
  const existingIndex = templates.findIndex(
    (current) => current.id === template.id,
  )

  if (existingIndex === -1) {
    return [...templates, template].sort((left, right) =>
      left.name.localeCompare(right.name),
    )
  }

  return templates.map((current) =>
    current.id === template.id ? template : current,
  )
}

function shouldShowInCurrentStatus(
  template: WorkoutTemplate,
  status: WorkoutTemplateStatus,
): boolean {
  if (status === 'all') {
    return true
  }

  return status === 'archived'
    ? Boolean(template.archived_at)
    : !template.archived_at
}

function statusLabel(status: WorkoutTemplateStatus): string {
  if (status === 'all') {
    return 'All'
  }

  return status === 'archived' ? 'Archived' : 'Active'
}

function confirmArchive(name: string): boolean {
  return window.confirm(
    [
      `Archive "${name}"?`,
      '',
      'Future workout starts will hide this template.',
      'Existing history will remain preserved.',
      'You can restore it later.',
    ].join('\n'),
  )
}

function extractMessages(error: unknown): string[] {
  if (error instanceof WorkoutTemplateApiError) {
    return error.errors.map((apiError) => apiError.message)
  }

  if (error instanceof Error) {
    return [error.message]
  }

  return ['Something went wrong.']
}
