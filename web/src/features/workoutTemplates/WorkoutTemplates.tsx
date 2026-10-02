import { useEffect, useMemo, useState } from 'react'
import type { FormEvent } from 'react'

import { listExercises } from '../../api/exercises'
import type { Exercise } from '../../api/exercises'
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

type SlotDraft = {
  id?: string
  lockVersion?: number
  label: string
  defaultExerciseId: string
  restSeconds: string
  options: OptionDraft[]
  setPrescriptions: SetPrescriptionDraft[]
}

type OptionDraft = {
  id?: string
  exerciseId: string
  startingLoadValue: string
  nextLoadValue: string
  progressionIncrement: string
}

type SetPrescriptionDraft = {
  id?: string
  setType: 'warmup' | 'working'
  repMin: string
  repMax: string
  loadStrategy:
    | 'working_load'
    | 'percentage_of_working_load'
    | 'explicit'
    | 'bodyweight'
    | 'none'
  loadValue: string
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
  const [slotDrafts, setSlotDrafts] = useState<SlotDraft[]>([])
  const [availableExercises, setAvailableExercises] = useState<Exercise[]>([])
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

  useEffect(() => {
    let isCurrent = true

    listExercises('', 'active')
      .then((exercises) => {
        if (isCurrent) {
          setAvailableExercises(exercises)
        }
      })
      .catch(() => {
        if (isCurrent) {
          setErrors(['Could not load exercises for templates.'])
        }
      })

    return () => {
      isCurrent = false
    }
  }, [])

  const selectedId = selectedTemplate?.id

  const panelTitle = useMemo(() => {
    return selectedTemplate ? 'Edit Template' : 'New Template'
  }, [selectedTemplate])

  function startNewTemplate() {
    setSelectedTemplate(null)
    setDraft(emptyDraft)
    setSlotDrafts([])
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
    setSlotDrafts([])
    setErrors([])
    setIsLoading(true)
  }

  function startEditing(template: WorkoutTemplate) {
    setSelectedTemplate(template)
    setDraft({
      name: template.name,
      notes: template.notes ?? '',
    })
    setSlotDrafts(slotDraftsFromTemplate(template))
    setErrors([])
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setIsSaving(true)
    setErrors([])

    const payload = toPayload(draft, slotDrafts, selectedTemplate ?? undefined)

    try {
      const savedTemplate = selectedTemplate
        ? await updateWorkoutTemplate(selectedTemplate.id, payload)
        : await createWorkoutTemplate(payload)

      setSelectedTemplate(savedTemplate)
      setDraft({
        name: savedTemplate.name,
        notes: savedTemplate.notes ?? '',
      })
      setSlotDrafts(slotDraftsFromTemplate(savedTemplate))
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
      ...toPayload(draft, slotDrafts, selectedTemplate),
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
      setSlotDrafts(slotDraftsFromTemplate(savedTemplate))
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

  function addSlot() {
    setSlotDrafts((currentSlots) => [
      ...currentSlots,
      createSlotDraft(availableExercises),
    ])
  }

  function removeSlot(slotIndex: number) {
    setSlotDrafts((currentSlots) =>
      currentSlots.filter((_, index) => index !== slotIndex),
    )
  }

  function moveSlot(slotIndex: number, direction: -1 | 1) {
    setSlotDrafts((currentSlots) => {
      const nextIndex = slotIndex + direction
      if (nextIndex < 0 || nextIndex >= currentSlots.length) {
        return currentSlots
      }

      const nextSlots = [...currentSlots]
      const movingSlot = nextSlots[slotIndex]
      nextSlots[slotIndex] = nextSlots[nextIndex]
      nextSlots[nextIndex] = movingSlot
      return nextSlots
    })
  }

  function updateSlot(slotIndex: number, changes: Partial<SlotDraft>) {
    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) =>
        index === slotIndex ? { ...slot, ...changes } : slot,
      ),
    )
  }

  function updateDefaultExercise(slotIndex: number, exerciseId: string) {
    if (!exerciseId) {
      return
    }

    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) => {
        if (index !== slotIndex) {
          return slot
        }

        const hasOption = slot.options.some(
          (option) => option.exerciseId === exerciseId,
        )

        return {
          ...slot,
          defaultExerciseId: exerciseId,
          options: hasOption
            ? slot.options
            : [createOptionDraft(exerciseId), ...slot.options],
        }
      }),
    )
  }

  function addSubstitute(slotIndex: number, exerciseId: string) {
    if (!exerciseId) {
      return
    }

    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) => {
        if (index !== slotIndex) {
          return slot
        }

        const alreadySelected = slot.options.some(
          (option) => option.exerciseId === exerciseId,
        )

        if (alreadySelected) {
          return slot
        }

        return {
          ...slot,
          options: [...slot.options, createOptionDraft(exerciseId)],
        }
      }),
    )
  }

  function removeSubstitute(slotIndex: number, exerciseId: string) {
    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) =>
        index === slotIndex
          ? {
              ...slot,
              options: slot.options.filter(
                (option) =>
                  option.exerciseId === slot.defaultExerciseId ||
                  option.exerciseId !== exerciseId,
              ),
            }
          : slot,
      ),
    )
  }

  function updateDefaultOption(
    slotIndex: number,
    changes: Partial<OptionDraft>,
  ) {
    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) => {
        if (index !== slotIndex) {
          return slot
        }

        return {
          ...slot,
          options: ensureDefaultOption(slot).map((option) =>
            option.exerciseId === slot.defaultExerciseId
              ? { ...option, ...changes }
              : option,
          ),
        }
      }),
    )
  }

  function addSetPrescription(slotIndex: number) {
    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) =>
        index === slotIndex
          ? {
              ...slot,
              setPrescriptions: [
                ...slot.setPrescriptions,
                createSetPrescriptionDraft(),
              ],
            }
          : slot,
      ),
    )
  }

  function updateSetPrescription(
    slotIndex: number,
    setIndex: number,
    changes: Partial<SetPrescriptionDraft>,
  ) {
    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) =>
        index === slotIndex
          ? {
              ...slot,
              setPrescriptions: slot.setPrescriptions.map(
                (set, currentSetIndex) =>
                  currentSetIndex === setIndex ? { ...set, ...changes } : set,
              ),
            }
          : slot,
      ),
    )
  }

  function removeSetPrescription(slotIndex: number, setIndex: number) {
    setSlotDrafts((currentSlots) =>
      currentSlots.map((slot, index) =>
        index === slotIndex
          ? {
              ...slot,
              setPrescriptions: slot.setPrescriptions.filter(
                (_, currentSetIndex) => currentSetIndex !== setIndex,
              ),
            }
          : slot,
      ),
    )
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

              <section className="slot-editor" aria-labelledby="slots-title">
                <div className="section-heading">
                  <h3 id="slots-title">Slots</h3>
                  <button
                    className="secondary-button"
                    type="button"
                    onClick={addSlot}
                  >
                    Add Slot
                  </button>
                </div>

                {slotDrafts.map((slot, slotIndex) => {
                  const slotNumber = slotIndex + 1
                  const defaultOption = ensureDefaultOption(slot).find(
                    (option) => option.exerciseId === slot.defaultExerciseId,
                  )
                  const substitutes = slot.options.filter(
                    (option) => option.exerciseId !== slot.defaultExerciseId,
                  )

                  return (
                    <section className="slot-card" key={slot.id ?? slotIndex}>
                      <div className="slot-card-header">
                        <h4>Slot {slotNumber}</h4>
                        <div className="inline-actions">
                          <button
                            className="secondary-button compact-button"
                            type="button"
                            onClick={() => moveSlot(slotIndex, -1)}
                            disabled={slotIndex === 0}
                          >
                            Up
                          </button>
                          <button
                            className="secondary-button compact-button"
                            type="button"
                            onClick={() => moveSlot(slotIndex, 1)}
                            disabled={slotIndex === slotDrafts.length - 1}
                          >
                            Down
                          </button>
                          <button
                            className="danger-button compact-button"
                            type="button"
                            onClick={() => removeSlot(slotIndex)}
                          >
                            Remove
                          </button>
                        </div>
                      </div>

                      <div className="slot-grid">
                        <label className="field-label">
                          Label
                          <input
                            className="text-input"
                            aria-label={`Slot ${slotNumber} label`}
                            value={slot.label}
                            onChange={(event) =>
                              updateSlot(slotIndex, {
                                label: event.target.value,
                              })
                            }
                          />
                        </label>

                        <label className="field-label">
                          Default Exercise
                          <select
                            className="text-input"
                            aria-label={`Slot ${slotNumber} default exercise`}
                            value={slot.defaultExerciseId}
                            onChange={(event) =>
                              updateDefaultExercise(
                                slotIndex,
                                event.target.value,
                              )
                            }
                          >
                            <option value="">Select exercise</option>
                            {availableExercises.map((exercise) => (
                              <option key={exercise.id} value={exercise.id}>
                                {exercise.name}
                              </option>
                            ))}
                          </select>
                        </label>

                        <label className="field-label">
                          Rest Seconds
                          <input
                            className="text-input"
                            aria-label={`Slot ${slotNumber} rest seconds`}
                            inputMode="numeric"
                            value={slot.restSeconds}
                            onChange={(event) =>
                              updateSlot(slotIndex, {
                                restSeconds: event.target.value,
                              })
                            }
                          />
                        </label>
                      </div>

                      <div className="slot-grid">
                        <label className="field-label">
                          Starting Load
                          <input
                            className="text-input"
                            aria-label={`Slot ${slotNumber} starting load`}
                            inputMode="decimal"
                            value={defaultOption?.startingLoadValue ?? ''}
                            onChange={(event) =>
                              updateDefaultOption(slotIndex, {
                                startingLoadValue: event.target.value,
                              })
                            }
                          />
                        </label>

                        <label className="field-label">
                          Next Load
                          <input
                            className="text-input"
                            aria-label={`Slot ${slotNumber} next load`}
                            inputMode="decimal"
                            value={defaultOption?.nextLoadValue ?? ''}
                            onChange={(event) =>
                              updateDefaultOption(slotIndex, {
                                nextLoadValue: event.target.value,
                              })
                            }
                          />
                        </label>

                        <label className="field-label">
                          Progression Increment
                          <input
                            className="text-input"
                            aria-label={`Slot ${slotNumber} progression increment`}
                            inputMode="decimal"
                            value={defaultOption?.progressionIncrement ?? ''}
                            onChange={(event) =>
                              updateDefaultOption(slotIndex, {
                                progressionIncrement: event.target.value,
                              })
                            }
                          />
                        </label>
                      </div>

                      <div className="substitute-section">
                        <label className="field-label">
                          Allowed Substitutes
                          <select
                            className="text-input"
                            aria-label={`Slot ${slotNumber} substitute exercise`}
                            value=""
                            onChange={(event) =>
                              addSubstitute(slotIndex, event.target.value)
                            }
                          >
                            <option value="">Add substitute</option>
                            {availableExercises
                              .filter(
                                (exercise) =>
                                  exercise.id !== slot.defaultExerciseId &&
                                  !slot.options.some(
                                    (option) =>
                                      option.exerciseId === exercise.id,
                                  ),
                              )
                              .map((exercise) => (
                                <option key={exercise.id} value={exercise.id}>
                                  {exercise.name}
                                </option>
                              ))}
                          </select>
                        </label>

                        {substitutes.length ? (
                          <div className="substitute-list">
                            {substitutes.map((option) => (
                              <span key={option.exerciseId}>
                                {exerciseName(
                                  availableExercises,
                                  option.exerciseId,
                                )}
                                <button
                                  type="button"
                                  onClick={() =>
                                    removeSubstitute(
                                      slotIndex,
                                      option.exerciseId,
                                    )
                                  }
                                >
                                  Remove
                                </button>
                              </span>
                            ))}
                          </div>
                        ) : null}
                      </div>

                      <div className="set-prescriptions">
                        <div className="section-heading compact-heading">
                          <h5>Set Prescriptions</h5>
                          <button
                            className="secondary-button compact-button"
                            type="button"
                            onClick={() => addSetPrescription(slotIndex)}
                          >
                            Add Set
                          </button>
                        </div>

                        {slot.setPrescriptions.map((set, setIndex) => {
                          const setNumber = setIndex + 1
                          const needsLoadValue =
                            set.loadStrategy === 'percentage_of_working_load' ||
                            set.loadStrategy === 'explicit'

                          return (
                            <div
                              className="set-prescription-row"
                              key={set.id ?? setIndex}
                            >
                              <select
                                className="text-input"
                                aria-label={`Slot ${slotNumber} set ${setNumber} type`}
                                value={set.setType}
                                onChange={(event) =>
                                  updateSetPrescription(slotIndex, setIndex, {
                                    setType: event.target.value as
                                      'warmup' | 'working',
                                  })
                                }
                              >
                                <option value="working">Working</option>
                                <option value="warmup">Warm-up</option>
                              </select>

                              <input
                                className="text-input"
                                aria-label={`Slot ${slotNumber} set ${setNumber} rep min`}
                                inputMode="numeric"
                                value={set.repMin}
                                onChange={(event) =>
                                  updateSetPrescription(slotIndex, setIndex, {
                                    repMin: event.target.value,
                                  })
                                }
                              />

                              <input
                                className="text-input"
                                aria-label={`Slot ${slotNumber} set ${setNumber} rep max`}
                                inputMode="numeric"
                                value={set.repMax}
                                onChange={(event) =>
                                  updateSetPrescription(slotIndex, setIndex, {
                                    repMax: event.target.value,
                                  })
                                }
                              />

                              <select
                                className="text-input"
                                aria-label={`Slot ${slotNumber} set ${setNumber} load strategy`}
                                value={set.loadStrategy}
                                onChange={(event) =>
                                  updateSetPrescription(slotIndex, setIndex, {
                                    loadStrategy: event.target.value as
                                      | 'working_load'
                                      | 'percentage_of_working_load'
                                      | 'explicit'
                                      | 'bodyweight'
                                      | 'none',
                                    loadValue:
                                      event.target.value ===
                                        'percentage_of_working_load' ||
                                      event.target.value === 'explicit'
                                        ? set.loadValue
                                        : '',
                                  })
                                }
                              >
                                <option value="working_load">
                                  Working load
                                </option>
                                <option value="percentage_of_working_load">
                                  % of working load
                                </option>
                                <option value="explicit">Explicit</option>
                                <option value="bodyweight">Bodyweight</option>
                                <option value="none">None</option>
                              </select>

                              <input
                                className="text-input"
                                aria-label={`Slot ${slotNumber} set ${setNumber} load value`}
                                inputMode="decimal"
                                value={set.loadValue}
                                disabled={!needsLoadValue}
                                onChange={(event) =>
                                  updateSetPrescription(slotIndex, setIndex, {
                                    loadValue: event.target.value,
                                  })
                                }
                              />

                              <button
                                className="danger-button compact-button"
                                type="button"
                                onClick={() =>
                                  removeSetPrescription(slotIndex, setIndex)
                                }
                              >
                                Remove
                              </button>
                            </div>
                          )
                        })}
                      </div>
                    </section>
                  )
                })}
              </section>

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
  slotDrafts: SlotDraft[],
  template?: WorkoutTemplate,
): WorkoutTemplatePayload {
  return {
    name: draft.name,
    notes: draft.notes.trim() || null,
    lock_version: template?.lock_version,
    slots: slotDrafts.map((slot, slotIndex) => ({
      id: slot.id,
      position: slotIndex + 1,
      label: slot.label,
      default_exercise_id: slot.defaultExerciseId,
      rest_seconds: parseInteger(slot.restSeconds),
      lock_version: slot.lockVersion,
      exercise_options: ensureDefaultOption(slot).map(
        (option, optionIndex) => ({
          id: option.id,
          position: optionIndex + 1,
          exercise_id: option.exerciseId,
          starting_load_value: parseOptionalNumber(option.startingLoadValue),
          next_load_value: parseOptionalNumber(option.nextLoadValue),
          progression_increment: parseOptionalNumber(
            option.progressionIncrement,
          ),
        }),
      ),
      set_prescriptions: slot.setPrescriptions.map(
        (prescription, prescriptionIndex) => ({
          id: prescription.id,
          position: prescriptionIndex + 1,
          set_type: prescription.setType,
          rep_min: parseInteger(prescription.repMin),
          rep_max: parseInteger(prescription.repMax),
          load_strategy: prescription.loadStrategy,
          load_value:
            prescription.loadStrategy === 'percentage_of_working_load' ||
            prescription.loadStrategy === 'explicit'
              ? parseOptionalNumber(prescription.loadValue)
              : null,
        }),
      ),
    })),
  }
}

function slotDraftsFromTemplate(template: WorkoutTemplate): SlotDraft[] {
  return template.slots.map((slot) => ({
    id: slot.id,
    lockVersion: slot.lock_version,
    label: slot.label,
    defaultExerciseId: slot.default_exercise_id,
    restSeconds: String(slot.rest_seconds),
    options: slot.exercise_options.map((option) => ({
      id: option.id,
      exerciseId: option.exercise_id,
      startingLoadValue: numberToDraft(option.starting_load_value),
      nextLoadValue: numberToDraft(option.next_load_value),
      progressionIncrement: numberToDraft(option.progression_increment),
    })),
    setPrescriptions: slot.set_prescriptions.map((prescription) => ({
      id: prescription.id,
      setType: prescription.set_type,
      repMin: String(prescription.rep_min),
      repMax: String(prescription.rep_max),
      loadStrategy: prescription.load_strategy,
      loadValue: numberToDraft(prescription.load_value),
    })),
  }))
}

function createSlotDraft(exercises: Exercise[]): SlotDraft {
  const defaultExerciseId = exercises[0]?.id ?? ''

  return {
    label: '',
    defaultExerciseId,
    restSeconds: '180',
    options: defaultExerciseId ? [createOptionDraft(defaultExerciseId)] : [],
    setPrescriptions: [createSetPrescriptionDraft()],
  }
}

function createOptionDraft(exerciseId: string): OptionDraft {
  return {
    exerciseId,
    startingLoadValue: '',
    nextLoadValue: '',
    progressionIncrement: '',
  }
}

function createSetPrescriptionDraft(): SetPrescriptionDraft {
  return {
    setType: 'working',
    repMin: '5',
    repMax: '8',
    loadStrategy: 'working_load',
    loadValue: '',
  }
}

function ensureDefaultOption(slot: SlotDraft): OptionDraft[] {
  const hasDefaultOption = slot.options.some(
    (option) => option.exerciseId === slot.defaultExerciseId,
  )

  if (!slot.defaultExerciseId || hasDefaultOption) {
    return sortOptions(slot)
  }

  return sortOptions({
    ...slot,
    options: [createOptionDraft(slot.defaultExerciseId), ...slot.options],
  })
}

function sortOptions(slot: SlotDraft): OptionDraft[] {
  return [...slot.options].sort((left, right) => {
    if (left.exerciseId === slot.defaultExerciseId) {
      return -1
    }

    if (right.exerciseId === slot.defaultExerciseId) {
      return 1
    }

    return 0
  })
}

function exerciseName(exercises: Exercise[], exerciseId: string): string {
  return (
    exercises.find((exercise) => exercise.id === exerciseId)?.name ??
    'Selected exercise'
  )
}

function parseInteger(value: string): number {
  const parsed = Number.parseInt(value, 10)
  return Number.isNaN(parsed) ? 0 : parsed
}

function parseOptionalNumber(value: string): number | null {
  const trimmedValue = value.trim()
  if (!trimmedValue) {
    return null
  }

  const parsed = Number(trimmedValue)
  return Number.isNaN(parsed) ? null : parsed
}

function numberToDraft(value: number | null): string {
  return value === null ? '' : String(value)
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
