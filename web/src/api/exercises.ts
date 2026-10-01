export const loadTypes = [
  'lb',
  'kg',
  'machine_stack',
  'plate_count',
  'bodyweight',
  'bodyweight_plus_added',
  'assisted',
  'none',
] as const

export type LoadType = (typeof loadTypes)[number]

export type Exercise = {
  id: string
  name: string
  primary_muscle_group: string
  secondary_muscle_groups: string[]
  load_type: LoadType
  notes: string | null
  external_url: string | null
  archived_at: string | null
  created_at: string
  updated_at: string
  lock_version: number
}

export type ExercisePayload = {
  name: string
  primary_muscle_group: string
  secondary_muscle_groups: string[]
  load_type: LoadType
  notes: string | null
  external_url: string | null
  lock_version?: number
}

export type ApiError = {
  field: string
  code: string
  message: string
}

type ExerciseListResponse = {
  exercises: Exercise[]
}

type ExerciseResponse = {
  exercise: Exercise
}

type ErrorResponse = {
  errors: ApiError[]
}

export async function listExercises(query: string): Promise<Exercise[]> {
  const params = new URLSearchParams()

  if (query.trim()) {
    params.set('q', query.trim())
  }

  const path = `/api/v1/exercises${params.size ? `?${params.toString()}` : ''}`
  const response = await fetchJson<ExerciseListResponse>(path)
  return response.exercises
}

export async function createExercise(
  payload: ExercisePayload,
): Promise<Exercise> {
  const response = await fetchJson<ExerciseResponse>('/api/v1/exercises', {
    method: 'POST',
    body: JSON.stringify({ exercise: payload }),
  })

  return response.exercise
}

export async function updateExercise(
  id: string,
  payload: ExercisePayload,
): Promise<Exercise> {
  const response = await fetchJson<ExerciseResponse>(
    `/api/v1/exercises/${id}`,
    {
      method: 'PATCH',
      body: JSON.stringify({ exercise: payload }),
    },
  )

  return response.exercise
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
      throw new ExerciseApiError(body.errors)
    }

    throw new Error(`Exercise request failed with ${response.status}`)
  }

  return (await response.json()) as T
}

export class ExerciseApiError extends Error {
  readonly errors: ApiError[]

  constructor(errors: ApiError[]) {
    super(errors.map((error) => error.message).join(', '))
    this.errors = errors
  }
}
