import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { healthMetricKinds } from '../../api/healthMetrics'
import type { HealthMetric, HealthMetricKind } from '../../api/healthMetrics'
import { HealthOverview } from './HealthOverview'

const bodyWeight = healthMetric({
  id: 'weight-1',
  kind: 'body_weight',
  value: 82.4,
  unit: 'kg',
})
const steps = healthMetric({
  id: 'steps-1',
  kind: 'steps',
  value: 8_245,
  unit: 'count',
})

describe('HealthOverview', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('shows latest metrics and switches the recent reading list', async () => {
    mockHealthMetricPages({ body_weight: [bodyWeight], steps: [steps] })

    render(<HealthOverview />)

    expect(await screen.findAllByText('82.4 kg')).toHaveLength(2)
    expect(screen.getByText('8,245 steps')).toBeInTheDocument()
    expect(
      screen.getByRole('heading', { name: 'Recent Readings' }),
    ).toBeInTheDocument()
    expect(screen.getAllByText('82.4 kg')).toHaveLength(2)

    fireEvent.click(screen.getByRole('button', { name: /Steps/ }))

    expect(screen.getAllByText('8,245 steps')).toHaveLength(2)
    expect(fetch).toHaveBeenCalledWith(
      '/api/v1/health_metrics?kind=steps&limit=7',
      expect.objectContaining({ headers: { Accept: 'application/json' } }),
    )
  })

  it('shows an empty state for metrics that have not synced', async () => {
    mockHealthMetricPages({ body_weight: [bodyWeight] })

    render(<HealthOverview />)

    await screen.findAllByText('82.4 kg')
    fireEvent.click(screen.getByRole('button', { name: /Sleep/ }))

    expect(
      screen.getByText('No sleep readings have synced yet.'),
    ).toBeInTheDocument()
  })

  it('rounds total sleep minutes before formatting hours and minutes', async () => {
    const sleep = healthMetric({
      id: 'sleep-1',
      kind: 'sleep_duration',
      value: 119.75,
      unit: 'minutes',
    })
    mockHealthMetricPages({ sleep_duration: [sleep] })

    render(<HealthOverview />)

    expect(await screen.findByText('2h 0m')).toBeInTheDocument()
  })

  it('retries after the health metric request fails', async () => {
    vi.mocked(fetch).mockRejectedValueOnce(new TypeError('Connection lost'))

    render(<HealthOverview />)

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Health data could not be loaded',
    )

    mockHealthMetricPages({ body_weight: [bodyWeight] })
    fireEvent.click(screen.getByRole('button', { name: 'Retry' }))

    expect(await screen.findAllByText('82.4 kg')).toHaveLength(2)
  })

  it('keeps the current dashboard visible while refreshing', async () => {
    mockHealthMetricPages({ body_weight: [bodyWeight] })
    render(<HealthOverview />)
    await screen.findAllByText('82.4 kg')

    const resolveRequests: Array<(response: Response) => void> = []
    vi.mocked(fetch).mockImplementation(
      () =>
        new Promise<Response>((resolve) => {
          resolveRequests.push(resolve)
        }),
    )
    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }))

    expect(screen.getAllByText('82.4 kg')).toHaveLength(2)
    expect(screen.getByRole('button', { name: 'Refreshing...' })).toBeDisabled()

    await waitFor(() => expect(resolveRequests).toHaveLength(6))
    resolveRequests.forEach((resolve) => resolve(healthMetricResponse([])))
    await waitFor(() =>
      expect(screen.getByRole('button', { name: 'Refresh' })).toBeEnabled(),
    )
  })
})

function mockHealthMetricPages(
  overrides: Partial<Record<HealthMetricKind, HealthMetric[]>>,
) {
  healthMetricKinds.forEach((kind) => {
    vi.mocked(fetch).mockResolvedValueOnce(
      healthMetricResponse(overrides[kind] ?? []),
    )
  })
}

function healthMetricResponse(metrics: HealthMetric[]) {
  return new Response(
    JSON.stringify({
      health_metrics: metrics,
      meta: { limit: 7, offset: 0, total: metrics.length },
    }),
    { headers: { 'Content-Type': 'application/json' } },
  )
}

function healthMetric(
  overrides: Pick<HealthMetric, 'id' | 'kind' | 'value' | 'unit'>,
): HealthMetric {
  return {
    ...overrides,
    started_at: '2026-10-10T08:00:00.000Z',
    ended_at: '2026-10-10T08:00:00.000Z',
    source: 'healthkit',
    created_at: '2026-10-10T08:01:00.000Z',
    updated_at: '2026-10-10T08:01:00.000Z',
  }
}
