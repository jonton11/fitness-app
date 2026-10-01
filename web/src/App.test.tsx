import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from './App'
import type { Exercise } from './api/exercises'
import type { WorkoutTemplate } from './api/workoutTemplates'

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

const upperTemplate: WorkoutTemplate = {
  id: 'template-1',
  name: 'Upper Body',
  notes: 'Main upper body day.',
  archived_at: null,
  created_at: '2026-10-01T00:00:00.000Z',
  updated_at: '2026-10-01T00:00:00.000Z',
  lock_version: 0,
  slots: [],
}

describe('App', () => {
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

  it('renders exercises from the API', async () => {
    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })

    render(<App />)
    fireEvent.click(screen.getByRole('button', { name: 'Exercises' }))

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

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })
    mockJsonResponse({ exercise: savedExercise }, 201)

    render(<App />)
    fireEvent.click(screen.getByRole('button', { name: 'Exercises' }))

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
      expect(fetch).toHaveBeenCalledTimes(4)
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

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ exercise: updatedExercise })

    render(<App />)
    fireEvent.click(screen.getByRole('button', { name: 'Exercises' }))

    fireEvent.click(await screen.findByText('Incline Dumbbell Press'))
    fireEvent.change(screen.getByLabelText('Name'), {
      target: { value: 'Incline Press' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(4)
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

  it('filters archived exercises', async () => {
    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({
      exercises: [{ ...deadBug, archived_at: '2026-10-01T01:00:00.000Z' }],
      meta: {},
    })

    render(<App />)
    fireEvent.click(screen.getByRole('button', { name: 'Exercises' }))

    fireEvent.click(await screen.findByRole('button', { name: 'Archived' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenLastCalledWith(
        '/api/v1/exercises?status=archived',
        expect.anything(),
      )
    })
    expect(await screen.findByText('Dead Bug')).toBeInTheDocument()
  })

  it('archives an exercise and removes it from the active list', async () => {
    const archivedExercise = {
      ...inclinePress,
      archived_at: '2026-10-01T01:00:00.000Z',
      lock_version: 1,
    } satisfies Exercise

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ exercise: archivedExercise })

    render(<App />)
    fireEvent.click(screen.getByRole('button', { name: 'Exercises' }))

    fireEvent.click(await screen.findByText('Incline Dumbbell Press'))
    fireEvent.click(screen.getByRole('button', { name: 'Archive' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(4)
    })
    expect(confirm).toHaveBeenCalledWith(
      expect.stringContaining('Past workout history will be preserved.'),
    )
    expect(lastExerciseRequest()).toMatchObject({
      archived_at: expect.any(String) as string,
      lock_version: 0,
    })
    expect(
      within(screen.getByLabelText('Exercise list')).queryByText(
        'Incline Dumbbell Press',
      ),
    ).not.toBeInTheDocument()
  })

  it('renders workout templates from the API', async () => {
    mockJsonResponse({ workout_templates: [upperTemplate], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: 'Workouts' }),
    ).toBeInTheDocument()
    expect(screen.getByText('Upper Body')).toBeInTheDocument()
    expect(screen.getByText('0 exercises')).toBeInTheDocument()
  })

  it('creates a workout template', async () => {
    const savedTemplate = {
      ...upperTemplate,
      id: 'template-2',
      name: 'Core & Arms',
      notes: 'Core and arm accessories.',
    } satisfies WorkoutTemplate

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ workout_template: savedTemplate }, 201)

    render(<App />)

    fireEvent.change(await screen.findByLabelText('Name'), {
      target: { value: 'Core & Arms' },
    })
    fireEvent.change(screen.getByLabelText('Notes'), {
      target: { value: 'Core and arm accessories.' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(3)
    })
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/v1/workout_templates',
      expect.objectContaining({ method: 'POST' }),
    )
    expect(lastWorkoutTemplateRequest()).toMatchObject({
      name: 'Core & Arms',
      notes: 'Core and arm accessories.',
    })
    expect(await screen.findByText('Core & Arms')).toBeInTheDocument()
  })

  it('saves workout template slots with substitutes and prescriptions', async () => {
    const savedTemplate = {
      ...upperTemplate,
      name: 'Upper Body',
      notes: 'Main upper body day.',
      slots: [
        {
          id: 'slot-1',
          position: 1,
          label: 'Upper Chest Press',
          default_exercise_id: inclinePress.id,
          default_exercise: {
            id: inclinePress.id,
            name: inclinePress.name,
            primary_muscle_group: inclinePress.primary_muscle_group,
            load_type: inclinePress.load_type,
            archived_at: null,
          },
          rest_seconds: 180,
          created_at: '2026-10-01T00:00:00.000Z',
          updated_at: '2026-10-01T00:00:00.000Z',
          lock_version: 0,
          exercise_options: [],
          set_prescriptions: [],
        },
      ],
    } satisfies WorkoutTemplate

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })
    mockJsonResponse({ workout_template: savedTemplate }, 201)

    render(<App />)

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(2)
    })

    fireEvent.change(screen.getByLabelText('Name'), {
      target: { value: 'Upper Body' },
    })
    fireEvent.change(screen.getByLabelText('Notes'), {
      target: { value: 'Main upper body day.' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Add Slot' }))

    fireEvent.change(screen.getByLabelText('Slot 1 label'), {
      target: { value: 'Upper Chest Press' },
    })
    fireEvent.change(screen.getByLabelText('Slot 1 rest seconds'), {
      target: { value: '180' },
    })
    fireEvent.change(screen.getByLabelText('Slot 1 starting load'), {
      target: { value: '60' },
    })
    fireEvent.change(screen.getByLabelText('Slot 1 next load'), {
      target: { value: '65' },
    })
    fireEvent.change(screen.getByLabelText('Slot 1 progression increment'), {
      target: { value: '5' },
    })
    fireEvent.change(screen.getByLabelText('Slot 1 substitute exercise'), {
      target: { value: deadBug.id },
    })
    fireEvent.change(screen.getByLabelText('Slot 1 set 1 load strategy'), {
      target: { value: 'percentage_of_working_load' },
    })
    fireEvent.change(screen.getByLabelText('Slot 1 set 1 load value'), {
      target: { value: '65' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(3)
    })

    const request = lastWorkoutTemplateRequest()
    expect(request).toMatchObject({
      name: 'Upper Body',
      notes: 'Main upper body day.',
    })
    expect(request.slots).toMatchObject([
      {
        position: 1,
        label: 'Upper Chest Press',
        default_exercise_id: inclinePress.id,
        rest_seconds: 180,
        exercise_options: [
          {
            position: 1,
            exercise_id: inclinePress.id,
            starting_load_value: 60,
            next_load_value: 65,
            progression_increment: 5,
          },
          {
            position: 2,
            exercise_id: deadBug.id,
          },
        ],
        set_prescriptions: [
          {
            position: 1,
            set_type: 'working',
            rep_min: 5,
            rep_max: 8,
            load_strategy: 'percentage_of_working_load',
            load_value: 65,
          },
        ],
      },
    ])
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

function lastWorkoutTemplateRequest() {
  const lastCall = vi.mocked(fetch).mock.calls.at(-1)
  const init = lastCall?.[1] as RequestInit | undefined
  const body = JSON.parse(init?.body as string) as {
    workout_template: Record<string, unknown>
  }

  return body.workout_template
}
