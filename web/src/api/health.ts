export type HealthResponse = {
  status: 'ok'
}

export async function fetchHealth(): Promise<HealthResponse> {
  const response = await fetch('/api/v1/health', {
    headers: { Accept: 'application/json' },
  })

  if (!response.ok) {
    throw new Error(`Health check failed with ${response.status}`)
  }

  const body = (await response.json()) as Partial<HealthResponse>

  if (body.status !== 'ok') {
    throw new Error('Health check returned an unexpected response')
  }

  return { status: body.status }
}
