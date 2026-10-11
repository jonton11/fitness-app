export const healthMetricKinds = [
  'body_weight',
  'body_fat_percentage',
  'steps',
  'active_energy',
  'sleep_duration',
  'resting_heart_rate',
] as const

export type HealthMetricKind = (typeof healthMetricKinds)[number]

export type HealthMetric = {
  id: string
  kind: HealthMetricKind
  value: number
  unit: 'kg' | 'percent' | 'count' | 'kcal' | 'minutes' | 'bpm'
  started_at: string
  ended_at: string
  source: 'healthkit'
  created_at: string
  updated_at: string
}

export type HealthMetricPage = {
  healthMetrics: HealthMetric[]
  limit: number
  offset: number
  total: number
}

type HealthMetricListResponse = {
  health_metrics: HealthMetric[]
  meta: {
    limit: number
    offset: number
    total: number
  }
}

export async function listHealthMetrics(
  kind: HealthMetricKind,
  limit = 7,
): Promise<HealthMetricPage> {
  const params = new URLSearchParams({ kind, limit: String(limit) })
  const response = await fetch(`/api/v1/health_metrics?${params.toString()}`, {
    headers: { Accept: 'application/json' },
  })

  if (!response.ok) {
    throw new Error(`Health metric request failed with ${response.status}`)
  }

  const body = (await response.json()) as HealthMetricListResponse
  return {
    healthMetrics: body.health_metrics,
    ...body.meta,
  }
}
