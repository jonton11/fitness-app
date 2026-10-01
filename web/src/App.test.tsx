import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from './App'
import type { Exercise } from './api/exercises'

const inclinePress: Exercise = {
  id: 'exercise-1',
  name: 'Incline Dumbbell Press',
  primary_muscle_group: 'Chest',
  secondary_muscle_groups: ['Shoulders', 'Triceps'],
  load_type: 'lb',
  notes: 'Bench setting notch 4',
  external_url: 'https://example.com/incline',
  archived_at: null,
  created_at: '2026-10-01T00:00:00.000Z',
  updated_at: '2026-10-01T00:00:00.000Z',
  lock_version: 0,
}

const deadBug: Exercise = {
  id: 'exercise-2',
  name: 'Dead Bug',
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

describe('App', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('renders exercises from the API', async () => {
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: 'Exercises' }),
    ).toBeInTheDocument()
    expect(screen.getByText('Incline Dumbbell Press')).toBeInTheDocument()
    expect(screen.getByText('Dead Bug')).toBeInTheDocument()
  })

  it('creates an exercise', async () => {
    const savedExercise = {
      ...deadBug,
      id: 'exercise-3',
      name: 'Cable Lateral Raise',
      primary_muscle_group: 'Shoulders',
      load_type: 'machine_stack',
    } satisfies Exercise

    mockJsonResponse({ exercises: [], meta: {} })
    mockJsonResponse({ exercise: savedExercise }, 201)

    render(<App />)

    fireEvent.change(await screen.findByLabelText('Name'), {
      target: { value: 'Cable Lateral Raise' },
    })
    fireEvent.change(screen.getByLabelText('Primary Muscle Group'), {
      target: { value: 'Shoulders' },
    })
    fireEvent.change(screen.getByLabelText('Load Type'), {
      target: { value: 'machine_stack' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(2)
    })
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/v1/exercises',
      expect.objectContaining({ method: 'POST' }),
    )
    expect(lastExerciseRequest()).toMatchObject({
      name: 'Cable Lateral Raise',
      primary_muscle_group: 'Shoulders',
      load_type: 'machine_stack',
    })
    expect(await screen.findByText('Cable Lateral Raise')).toBeInTheDocument()
  })

  it('updates an exercise with lock version', async () => {
    const updatedExercise = {
      ...inclinePress,
      name: 'Incline Press',
      lock_version: 1,
    } satisfies Exercise

    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ exercise: updatedExercise })

    render(<App />)

    fireEvent.click(await screen.findByText('Incline Dumbbell Press'))
    fireEvent.change(screen.getByLabelText('Name'), {
      target: { value: 'Incline Press' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(2)
    })
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/v1/exercises/exercise-1',
      expect.objectContaining({ method: 'PATCH' }),
    )
    expect(lastExerciseRequest()).toMatchObject({
      name: 'Incline Press',
      lock_version: 0,
    })
    expect(await screen.findByText('Incline Press')).toBeInTheDocument()
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

function lastExerciseRequest() {
  const lastCall = vi.mocked(fetch).mock.calls.at(-1)
  const init = lastCall?.[1] as RequestInit | undefined
  const body = JSON.parse(init?.body as string) as {
    exercise: Record<string, unknown>
  }

  return body.exercise
}
