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
      expect(fetch).toHaveBeenCalledTimes(2)
    })
    expect(lastActivityRequest()).toMatchObject({
      kind: 'basketball',
      notes: 'Pickup game',
      focus_tags: ['Lower Body', 'Cardio'],
    })
    expect(await screen.findByText('Pickup game')).toBeInTheDocument()
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
  const lastCall = vi.mocked(fetch).mock.calls.at(-1)
  const init = lastCall?.[1] as RequestInit | undefined
  const body = JSON.parse(init?.body as string) as {
    activity: Record<string, unknown>
  }

  return body.activity
}
