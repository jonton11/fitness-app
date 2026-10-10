import type { Exercise } from './exercises'

export const routineTargetModes = [
  'completion_only',
  'reps',
  'duration',
  'load_optional',
] as const

export type RoutineTargetMode = (typeof routineTargetModes)[number]
export type RoutineStatus = 'active' | 'archived' | 'all'

export type RoutineItem = {
  id: string
  position: number
  exercise_id: string
  exercise: Exercise
  target_mode: RoutineTargetMode
  sets: number | null
  target_reps: number | null
  target_duration_seconds: number | null
  notes_override: string | null
  created_at: string
  updated_at: string
}

export type Routine = {
  id: string
  name: string
  notes: string | null
  archived_at: string | null
  items: RoutineItem[]
  created_at: string
  updated_at: string
  lock_version: number
}

export type RoutineItemPayload = {
  id?: string
  position: number
  exercise_id: string
  target_mode: RoutineTargetMode
  sets: number | null
  target_reps: number | null
  target_duration_seconds: number | null
  notes_override: string | null
}

export type RoutinePayload = {
  name?: string
  notes?: string | null
  archived_at?: string | null
  lock_version?: number
  items?: RoutineItemPayload[]
}

export type ApiError = {
  field: string
  code: string
  message: string
}

type RoutineListResponse = {
  routines: Routine[]
}

type RoutineResponse = {
  routine: Routine
}

type ErrorResponse = {
  errors: ApiError[]
}

export async function listRoutines(
  query: string,
  status: RoutineStatus,
): Promise<Routine[]> {
  const params = new URLSearchParams({ status })

  if (query.trim()) {
    params.set('q', query.trim())
  }

  const response = await fetchJson<RoutineListResponse>(
    `/api/v1/routines?${params.toString()}`,
  )
  return response.routines
}

export async function createRoutine(payload: RoutinePayload): Promise<Routine> {
  const response = await fetchJson<RoutineResponse>('/api/v1/routines', {
    method: 'POST',
    body: JSON.stringify({ routine: payload }),
  })
  return response.routine
}

export async function updateRoutine(
  id: string,
  payload: RoutinePayload,
): Promise<Routine> {
  const response = await fetchJson<RoutineResponse>(`/api/v1/routines/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ routine: payload }),
  })
  return response.routine
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
      throw new RoutineApiError(body.errors)
    }

    throw new Error(`Routine request failed with ${response.status}`)
  }

  return (await response.json()) as T
}

export class RoutineApiError extends Error {
  readonly errors: ApiError[]

  constructor(errors: ApiError[]) {
    super(errors.map((error) => error.message).join(', '))
    this.errors = errors
  }
}
