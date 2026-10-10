import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type { Exercise } from '../../api/exercises'
import type { Routine } from '../../api/routines'
import { RoutineManager } from './RoutineManager'

const exercise: Exercise = {
  id: 'exercise-1',
  name: 'Exercise 1',
  primary_muscle_group: 'Core',
  secondary_muscle_groups: [],
  load_type: 'none',
  notes: null,
  external_url: null,
  archived_at: null,
  created_at: '2026-10-01T00:00:00.000Z',
  updated_at: '2026-10-01T00:00:00.000Z',
  lock_version: 0,
}

const routine: Routine = {
  id: 'routine-1',
  name: 'Daily Rehab',
  notes: null,
  archived_at: null,
  items: [],
  created_at: '2026-10-01T00:00:00.000Z',
  updated_at: '2026-10-01T00:00:00.000Z',
  lock_version: 0,
}

describe('RoutineManager', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    vi.stubGlobal(
      'confirm',
      vi.fn(() => true),
    )
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('loads every exercise page for the routine picker', async () => {
    const firstPage = Array.from({ length: 100 }, (_, index) => ({
      ...exercise,
      id: `exercise-${index + 1}`,
      name: `Exercise ${index + 1}`,
    }))
    vi.mocked(fetch).mockImplementation(async (input) => {
      const path = String(input)

      if (path === '/api/v1/routines?status=active') {
        return jsonResponse({ routines: [], meta: {} })
      }
      if (path.endsWith('limit=100&offset=0')) {
        return jsonResponse({
          exercises: firstPage,
          meta: { limit: 100, offset: 0, total: 101 },
        })
      }
      if (path.endsWith('limit=100&offset=100')) {
        return jsonResponse({
          exercises: [
            { ...exercise, id: 'exercise-101', name: 'Exercise 101' },
          ],
          meta: { limit: 100, offset: 100, total: 101 },
        })
      }

      throw new Error(`Unexpected request: ${path}`)
    })

    render(<RoutineManager />)

    expect(
      await screen.findByRole('option', { name: 'Exercise 101' }),
    ).toBeInTheDocument()
    expect(fetch).toHaveBeenCalledWith(
      '/api/v1/exercises?status=active&limit=100&offset=100',
      expect.any(Object),
    )
  })

  it('does not add a new active routine to the archived view', async () => {
    vi.mocked(fetch).mockImplementation(async (input, init) => {
      const path = String(input)

      if (path.startsWith('/api/v1/exercises')) {
        return jsonResponse({
          exercises: [],
          meta: { limit: 100, offset: 0, total: 0 },
        })
      }
      if (init?.method === 'POST') {
        return jsonResponse(routineEnvelope(routine), 201)
      }
      if (path.startsWith('/api/v1/routines')) {
        return jsonResponse({ routines: [], meta: {} })
      }

      throw new Error(`Unexpected request: ${path}`)
    })

    render(<RoutineManager />)

    fireEvent.click(await screen.findByRole('button', { name: 'Archived' }))
    fireEvent.change(screen.getByLabelText('Name'), {
      target: { value: routine.name },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(screen.getByLabelText('Name')).toHaveValue('')
    })
    expect(
      screen.queryByRole('button', { name: /Daily Rehab/ }),
    ).not.toBeInTheDocument()
  })

  it('keeps an archived routine visible in the all view', async () => {
    const archivedRoutine = {
      ...routine,
      archived_at: '2026-10-10T18:00:00.000Z',
      lock_version: 1,
    }
    vi.mocked(fetch).mockImplementation(async (input, init) => {
      const path = String(input)

      if (path.startsWith('/api/v1/exercises')) {
        return jsonResponse({
          exercises: [],
          meta: { limit: 100, offset: 0, total: 0 },
        })
      }
      if (init?.method === 'PATCH') {
        return jsonResponse(routineEnvelope(archivedRoutine))
      }
      if (path === '/api/v1/routines?status=all') {
        return jsonResponse({ routines: [routine], meta: {} })
      }
      if (path.startsWith('/api/v1/routines')) {
        return jsonResponse({ routines: [routine], meta: {} })
      }

      throw new Error(`Unexpected request: ${path}`)
    })

    render(<RoutineManager />)

    fireEvent.click(await screen.findByRole('button', { name: 'All' }))
    fireEvent.click(await screen.findByRole('button', { name: /Daily Rehab/ }))
    fireEvent.click(screen.getByRole('button', { name: 'Archive' }))

    expect(
      await screen.findByRole('button', { name: /Daily Rehab/ }),
    ).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Restore' })).toBeInTheDocument()
  })
})

function routineEnvelope(savedRoutine: Routine) {
  return { routine: savedRoutine }
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { 'Content-Type': 'application/json' },
    status,
  })
}
