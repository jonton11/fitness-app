export type WorkoutSessionStatus = 'active' | 'completed' | 'canceled'

export type WorkoutSessionExerciseStatus = 'pending' | 'completed' | 'skipped'

export type WorkoutSessionSetCompletionState =
  'pending' | 'completed' | 'attempted_but_target_not_met' | 'not_performed'

export type WorkoutSessionExerciseSummary = {
  id: string
  name: string
  load_type: string
}

export type WorkoutSessionSet = {
  id: string
  workout_template_set_prescription_id: string | null
  position: number
  set_type: 'warmup' | 'working'
  target_rep_min: number
  target_rep_max: number
  load_strategy:
    | 'working_load'
    | 'percentage_of_working_load'
    | 'explicit'
    | 'bodyweight'
    | 'none'
  prescribed_load_value: number | null
  planned_load_value: number | null
  actual_reps: number | null
  actual_load_value: number | null
  completion_state: WorkoutSessionSetCompletionState
  completed_at: string | null
  lock_version: number
  created_at: string
  updated_at: string
}

export type WorkoutSessionExercise = {
  id: string
  workout_template_slot_id: string | null
  workout_template_exercise_option_id: string | null
  position: number
  label: string
  selected_exercise_id: string
  selected_exercise: WorkoutSessionExerciseSummary
  rest_seconds: number
  planned_working_load_value: number | null
  progression_increment: number | null
  status: WorkoutSessionExerciseStatus
  created_at: string
  updated_at: string
  workout_session_sets: WorkoutSessionSet[]
}

export type WorkoutSession = {
  id: string
  workout_template_id: string
  workout_template_name: string
  status: WorkoutSessionStatus
  started_at: string
  completed_at: string | null
  canceled_at: string | null
  created_at: string
  updated_at: string
  lock_version: number
  exercises: WorkoutSessionExercise[]
}

export type WorkoutSessionSetPayload = {
  actual_reps?: number | null
  actual_load_value?: number | null
  completion_state?: WorkoutSessionSetCompletionState
  completed_at?: string | null
  lock_version: number
}

export type ApiError = {
  field: string
  code: string
  message: string
}

type WorkoutSessionListResponse = {
  workout_sessions: WorkoutSession[]
}

type WorkoutSessionSetResponse = {
  workout_session_set: WorkoutSessionSet
}

type ErrorResponse = {
  errors: ApiError[]
}

export async function listWorkoutSessions(
  status: WorkoutSessionStatus | 'all' = 'completed',
): Promise<WorkoutSession[]> {
  const params = new URLSearchParams({ status })
  const response = await fetchJson<WorkoutSessionListResponse>(
    `/api/v1/workout_sessions?${params.toString()}`,
  )

  return response.workout_sessions
}

export async function updateWorkoutSessionSet(
  id: string,
  payload: WorkoutSessionSetPayload,
): Promise<WorkoutSessionSet> {
  const response = await fetchJson<WorkoutSessionSetResponse>(
    `/api/v1/workout_session_sets/${id}`,
    {
      method: 'PATCH',
      body: JSON.stringify({ workout_session_set: payload }),
    },
  )

  return response.workout_session_set
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
      throw new WorkoutSessionApiError(body.errors)
    }

    throw new Error(`Workout session request failed with ${response.status}`)
  }

  return (await response.json()) as T
}

export class WorkoutSessionApiError extends Error {
  readonly errors: ApiError[]

  constructor(errors: ApiError[]) {
    super(errors.map((error) => error.message).join(', '))
    this.errors = errors
  }
}
