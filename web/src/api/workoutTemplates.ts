export type WorkoutTemplateStatus = 'active' | 'archived' | 'all'

export type ExerciseSummary = {
  id: string
  name: string
  primary_muscle_group: string
  load_type: string
  archived_at: string | null
}

export type WorkoutTemplateExerciseOption = {
  id: string
  position: number
  exercise_id: string
  exercise: ExerciseSummary
  is_default: boolean
  starting_load_value: number | null
  next_load_value: number | null
  progression_increment: number | null
  created_at: string
  updated_at: string
}

export type WorkoutTemplateSetPrescription = {
  id: string
  position: number
  set_type: 'warmup' | 'working'
  rep_min: number
  rep_max: number
  load_strategy:
    | 'working_load'
    | 'percentage_of_working_load'
    | 'explicit'
    | 'bodyweight'
    | 'none'
  load_value: number | null
  created_at: string
  updated_at: string
}

export type WorkoutTemplateSlot = {
  id: string
  position: number
  label: string
  default_exercise_id: string
  default_exercise: ExerciseSummary
  rest_seconds: number
  created_at: string
  updated_at: string
  lock_version: number
  exercise_options: WorkoutTemplateExerciseOption[]
  set_prescriptions: WorkoutTemplateSetPrescription[]
}

export type WorkoutTemplate = {
  id: string
  name: string
  notes: string | null
  archived_at: string | null
  created_at: string
  updated_at: string
  lock_version: number
  slots: WorkoutTemplateSlot[]
}

export type WorkoutTemplatePayload = {
  name: string
  notes: string | null
  archived_at?: string | null
  lock_version?: number
  slots?: WorkoutTemplateSlotPayload[]
}

export type WorkoutTemplateSlotPayload = {
  id?: string
  position: number
  label: string
  default_exercise_id: string
  rest_seconds: number
  lock_version?: number
  exercise_options: WorkoutTemplateExerciseOptionPayload[]
  set_prescriptions: WorkoutTemplateSetPrescriptionPayload[]
}

export type WorkoutTemplateExerciseOptionPayload = {
  id?: string
  position: number
  exercise_id: string
  starting_load_value: number | null
  next_load_value: number | null
  progression_increment: number | null
}

export type WorkoutTemplateSetPrescriptionPayload = {
  id?: string
  position: number
  set_type: 'warmup' | 'working'
  rep_min: number
  rep_max: number
  load_strategy:
    | 'working_load'
    | 'percentage_of_working_load'
    | 'explicit'
    | 'bodyweight'
    | 'none'
  load_value: number | null
}

export type ApiError = {
  field: string
  code: string
  message: string
}

type WorkoutTemplateListResponse = {
  workout_templates: WorkoutTemplate[]
}

type WorkoutTemplateResponse = {
  workout_template: WorkoutTemplate
}

type ErrorResponse = {
  errors: ApiError[]
}

export async function listWorkoutTemplates(
  query: string,
  status: WorkoutTemplateStatus,
): Promise<WorkoutTemplate[]> {
  const params = new URLSearchParams()

  params.set('status', status)

  if (query.trim()) {
    params.set('q', query.trim())
  }

  const path = `/api/v1/workout_templates${params.size ? `?${params.toString()}` : ''}`
  const response = await fetchJson<WorkoutTemplateListResponse>(path)
  return response.workout_templates
}

export async function createWorkoutTemplate(
  payload: WorkoutTemplatePayload,
): Promise<WorkoutTemplate> {
  const response = await fetchJson<WorkoutTemplateResponse>(
    '/api/v1/workout_templates',
    {
      method: 'POST',
      body: JSON.stringify({ workout_template: payload }),
    },
  )

  return response.workout_template
}

export async function updateWorkoutTemplate(
  id: string,
  payload: WorkoutTemplatePayload,
): Promise<WorkoutTemplate> {
  const response = await fetchJson<WorkoutTemplateResponse>(
    `/api/v1/workout_templates/${id}`,
    {
      method: 'PATCH',
      body: JSON.stringify({ workout_template: payload }),
    },
  )

  return response.workout_template
}

async function fetchJson<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...init.headers,
    },
  })

  if (!response.ok) {
    const body = (await response
      .json()
      .catch(() => null)) as ErrorResponse | null

    if (body?.errors?.length) {
      throw new WorkoutTemplateApiError(body.errors)
    }

    throw new Error(`Workout template request failed with ${response.status}`)
  }

  return (await response.json()) as T
}

export class WorkoutTemplateApiError extends Error {
  readonly errors: ApiError[]

  constructor(errors: ApiError[]) {
    super(errors.map((error) => error.message).join(', '))
    this.errors = errors
  }
}
