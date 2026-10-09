import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type { Activity } from '../../api/activities'
import { ActivityManager } from './ActivityManager'

const basketball: Activity = {
  id: 'activity-1',
  kind: 'basketball',
  started_at: '2026-10-08T01:00:00.000Z',
  ended_at: '2026-10-08T02:12:00.000Z',
  notes: 'Pickup game',
  focus_tags: ['Lower Body', 'Cardio'],
  source: 'manual',
  created_at: '2026-10-08T02:12:00.000Z',
  updated_at: '2026-10-08T02:12:00.000Z',
}

describe('ActivityManager', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    vi.stubGlobal('crypto', {
      randomUUID: vi.fn(() => '00000000-0000-4000-8000-000000000001'),
    })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('renders manual activity history', async () => {
    mockJsonResponse({
      activities: [basketball],
      meta: { limit: 50, offset: 0, total: 1 },
    })

    render(<ActivityManager />)

    expect(await screen.findByText('Pickup game')).toBeInTheDocument()
    expect(screen.getByText('72 min')).toBeInTheDocument()
    expect(screen.getByText('Lower Body')).toBeInTheDocument()
    expect(fetch).toHaveBeenCalledWith(
      '/api/v1/activities?limit=50&offset=0',
      expect.objectContaining({ headers: expect.any(Object) }),
    )
  })

  it('logs an activity and adds it to history', async () => {
    mockJsonResponse({
      activities: [],
      meta: { limit: 50, offset: 0, total: 0 },
    })
    mockJsonResponse({ activity: basketball }, 201)
    mockJsonResponse({
      activities: [basketball],
      meta: { limit: 50, offset: 0, total: 1 },
    })

    render(<ActivityManager />)

    fireEvent.click(await screen.findByRole('button', { name: 'Basketball' }))
    fireEvent.change(screen.getByLabelText('Started at'), {
      target: { value: '2026-10-07T18:00' },
    })
    fireEvent.click(screen.getByLabelText('Include end time'))
    fireEvent.change(screen.getByLabelText('Ended at'), {
      target: { value: '2026-10-07T19:12' },
    })
    fireEvent.change(screen.getByLabelText('Notes (optional)'), {
      target: { value: 'Pickup game' },
    })
    fireEvent.change(screen.getByLabelText('Focus tags (optional)'), {
      target: { value: 'Lower Body, Cardio, Lower Body' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Log Activity' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(3)
    })
    expect(lastActivityRequest()).toMatchObject({
      id: '00000000-0000-4000-8000-000000000001',
      kind: 'basketball',
      notes: 'Pickup game',
      focus_tags: ['Lower Body', 'Cardio'],
    })
    expect(await screen.findByText('Pickup game')).toBeInTheDocument()
  })

  it('reuses the draft ID when retrying an uncertain submission', async () => {
    mockJsonResponse({
      activities: [],
      meta: { limit: 50, offset: 0, total: 0 },
    })
    vi.mocked(fetch).mockRejectedValueOnce(new TypeError('Connection lost'))
    mockJsonResponse({ activity: basketball }, 201)
    mockJsonResponse({
      activities: [basketball],
      meta: { limit: 50, offset: 0, total: 1 },
    })

    render(<ActivityManager />)

    fireEvent.click(await screen.findByRole('button', { name: 'Log Activity' }))
    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Could not log activity.',
    )

    fireEvent.click(screen.getByRole('button', { name: 'Log Activity' }))

    await waitFor(() => {
      expect(activityRequests()).toHaveLength(2)
    })
    expect(activityRequests().map((request) => request.id)).toEqual([
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000001',
    ])
  })

  it('resumes pagination after logging a backdated activity', async () => {
    const firstPage = Array.from({ length: 50 }, (_, index) => ({
      ...basketball,
      id: `activity-${index}`,
      notes: `Activity ${index + 1}`,
    }))
    const backdated: Activity = {
      ...basketball,
      id: 'activity-51',
      kind: 'recovery',
      started_at: '2026-10-01T18:00:00.000Z',
      ended_at: null,
      notes: 'Backdated recovery',
      focus_tags: [],
    }
    mockJsonResponse({
      activities: firstPage,
      meta: { limit: 50, offset: 0, total: 50 },
    })
    mockJsonResponse({ activity: backdated }, 201)
    mockJsonResponse({
      activities: firstPage,
      meta: { limit: 50, offset: 0, total: 51 },
    })
    mockJsonResponse({
      activities: [backdated],
      meta: { limit: 50, offset: 50, total: 51 },
    })

    render(<ActivityManager />)

    fireEvent.change(await screen.findByLabelText('Started at'), {
      target: { value: '2026-10-01T11:00' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Log Activity' }))

    await waitFor(() => expect(fetch).toHaveBeenCalledTimes(3))
    expect(screen.queryByText('Backdated recovery')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Load More' }))

    expect(await screen.findByText('Backdated recovery')).toBeInTheDocument()
    expect(fetch).toHaveBeenNthCalledWith(
      4,
      '/api/v1/activities?limit=50&offset=50',
      expect.objectContaining({ headers: expect.any(Object) }),
    )
  })

  it('keeps the form open when creation fails', async () => {
    mockJsonResponse({
      activities: [],
      meta: { limit: 50, offset: 0, total: 0 },
    })
    mockJsonResponse(
      { errors: [{ field: 'kind', code: 'invalid', message: 'Nope' }] },
      422,
    )

    render(<ActivityManager />)
    fireEvent.change(await screen.findByLabelText('Notes (optional)'), {
      target: { value: 'Keep this note' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Log Activity' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Nope')
    expect(screen.getByDisplayValue('Keep this note')).toBeInTheDocument()
  })
})

function mockJsonResponse(body: unknown, status = 200) {
  vi.mocked(fetch).mockResolvedValueOnce(
    new Response(JSON.stringify(body), {
      headers: { 'Content-Type': 'application/json' },
      status,
    }),
  )
}

function lastActivityRequest() {
  return activityRequests().at(-1)
}

function activityRequests() {
  return vi
    .mocked(fetch)
    .mock.calls.filter(([, init]) => init?.method === 'POST')
    .map(([, init]) => {
      const body = JSON.parse(init?.body as string) as {
        activity: Record<string, unknown>
      }

      return body.activity
    })
}
