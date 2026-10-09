export const activityKinds = [
  'rest_day',
  'basketball',
  'recovery',
  'other',
] as const

export type ActivityKind = (typeof activityKinds)[number]

export type Activity = {
  id: string
  kind: ActivityKind
  started_at: string
  ended_at: string | null
  notes: string | null
  focus_tags: string[]
  source: 'manual'
  created_at: string
  updated_at: string
}

export type ActivityPayload = {
  id: string
  kind: ActivityKind
  started_at: string
  ended_at: string | null
  notes: string | null
  focus_tags: string[]
}

export type ActivityPage = {
  activities: Activity[]
  limit: number
  offset: number
  total: number
}

export type ApiError = {
  field: string
  code: string
  message: string
}

type ActivityListResponse = {
  activities: Activity[]
  meta: {
    limit: number
    offset: number
    total: number
  }
}

type ActivityResponse = {
  activity: Activity
}

type ErrorResponse = {
  errors: ApiError[]
}

export async function listActivities(
  offset = 0,
  limit = 50,
): Promise<ActivityPage> {
  const params = new URLSearchParams({
    limit: String(limit),
    offset: String(offset),
  })
  const response = await fetchJson<ActivityListResponse>(
    `/api/v1/activities?${params.toString()}`,
  )

  return { activities: response.activities, ...response.meta }
}

export async function createActivity(
  payload: ActivityPayload,
): Promise<Activity> {
  const response = await fetchJson<ActivityResponse>('/api/v1/activities', {
    method: 'POST',
    body: JSON.stringify({ activity: payload }),
  })

  return response.activity
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
      throw new ActivityApiError(body.errors)
    }

    throw new Error(`Activity request failed with ${response.status}`)
  }

  return (await response.json()) as T
}

export class ActivityApiError extends Error {
  readonly errors: ApiError[]

  constructor(errors: ApiError[]) {
    super(errors.map((error) => error.message).join(', '))
    this.errors = errors
  }
}
