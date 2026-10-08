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
import type { Routine } from './api/routines'
import type { User } from './api/session'
import type { WorkoutSession } from './api/workoutSessions'
import type { WorkoutTemplate } from './api/workoutTemplates'

const owner: User = {
  id: 'user-1',
  email_address: 'owner@example.com',
}

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

const dailyRehab: Routine = {
  id: 'routine-1',
  name: 'Daily Rehab',
  notes: 'Move slowly.',
  archived_at: null,
  created_at: '2026-10-01T00:00:00.000Z',
  updated_at: '2026-10-01T00:00:00.000Z',
  lock_version: 0,
  items: [
    {
      id: 'routine-item-1',
      position: 1,
      exercise_id: deadBug.id,
      exercise: deadBug,
      target_mode: 'reps',
      sets: 3,
      target_reps: 8,
      target_duration_seconds: null,
      notes_override: 'Each side',
      created_at: '2026-10-01T00:00:00.000Z',
      updated_at: '2026-10-01T00:00:00.000Z',
    },
    {
      id: 'routine-item-2',
      position: 2,
      exercise_id: inclinePress.id,
      exercise: inclinePress,
      target_mode: 'completion_only',
      sets: null,
      target_reps: null,
      target_duration_seconds: null,
      notes_override: null,
      created_at: '2026-10-01T00:00:00.000Z',
      updated_at: '2026-10-01T00:00:00.000Z',
    },
  ],
}

const completedSession: WorkoutSession = {
  id: 'session-1',
  workout_template_id: 'template-1',
  workout_template_name: 'Upper Body',
  status: 'completed',
  started_at: '2026-10-03T12:00:00.000Z',
  completed_at: '2026-10-03T12:45:00.000Z',
  canceled_at: null,
  created_at: '2026-10-03T12:00:00.000Z',
  updated_at: '2026-10-03T12:45:00.000Z',
  lock_version: 1,
  exercises: [
    {
      id: 'session-exercise-1',
      workout_template_slot_id: 'slot-1',
      workout_template_exercise_option_id: 'option-1',
      position: 1,
      label: 'Upper Chest Press',
      selected_exercise_id: inclinePress.id,
      selected_exercise: {
        id: inclinePress.id,
        name: inclinePress.name,
        load_type: inclinePress.load_type,
      },
      rest_seconds: 180,
      planned_working_load_value: 65,
      progression_increment: 5,
      status: 'completed',
      created_at: '2026-10-03T12:00:00.000Z',
      updated_at: '2026-10-03T12:45:00.000Z',
      workout_session_sets: [
        {
          id: 'session-set-1',
          workout_template_set_prescription_id: 'prescription-1',
          position: 1,
          set_type: 'working',
          target_rep_min: 5,
          target_rep_max: 8,
          load_strategy: 'working_load',
          prescribed_load_value: null,
          planned_load_value: 65,
          actual_reps: 8,
          actual_load_value: 65,
          completion_state: 'completed',
          completed_at: '2026-10-03T12:20:00.000Z',
          lock_version: 1,
          created_at: '2026-10-03T12:00:00.000Z',
          updated_at: '2026-10-03T12:20:00.000Z',
        },
        {
          id: 'session-set-2',
          workout_template_set_prescription_id: 'prescription-2',
          position: 2,
          set_type: 'working',
          target_rep_min: 5,
          target_rep_max: 8,
          load_strategy: 'working_load',
          prescribed_load_value: null,
          planned_load_value: 65,
          actual_reps: null,
          actual_load_value: null,
          completion_state: 'not_performed',
          completed_at: null,
          lock_version: 1,
          created_at: '2026-10-03T12:00:00.000Z',
          updated_at: '2026-10-03T12:45:00.000Z',
        },
      ],
    },
  ],
}

describe('App', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
    vi.stubGlobal(
      'confirm',
      vi.fn(() => true),
    )
    mockJsonResponse({ user: owner })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('shows the sign-in form when there is no browser session', async () => {
    vi.mocked(fetch).mockReset()
    mockJsonResponse({ errors: [{ message: 'Authentication required' }] }, 401)

    render(<App />)

    expect(
      await screen.findByRole('heading', { name: 'Sign in' }),
    ).toBeInTheDocument()
  })

  it('signs in and loads the application', async () => {
    vi.mocked(fetch).mockReset()
    mockJsonResponse({ errors: [{ message: 'Authentication required' }] }, 401)
    mockJsonResponse({ user: owner }, 201)
    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })

    render(<App />)

    fireEvent.change(await screen.findByLabelText('Email address'), {
      target: { value: owner.email_address },
    })
    fireEvent.change(screen.getByLabelText('Password'), {
      target: { value: 'correct-password' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(
      await screen.findByRole('heading', { name: 'Workouts' }),
    ).toBeInTheDocument()
    expect(fetch).toHaveBeenNthCalledWith(
      2,
      '/api/v1/session',
      expect.objectContaining({ method: 'POST' }),
    )
    expect(sessionRequest()).toEqual({
      email_address: owner.email_address,
      password: 'correct-password',
    })
  })

  it('shows a rejected credential message', async () => {
    vi.mocked(fetch).mockReset()
    mockJsonResponse({ errors: [{ message: 'Authentication required' }] }, 401)
    mockJsonResponse(
      { errors: [{ message: 'Email or password is incorrect' }] },
      401,
    )

    render(<App />)

    fireEvent.change(await screen.findByLabelText('Email address'), {
      target: { value: owner.email_address },
    })
    fireEvent.change(screen.getByLabelText('Password'), {
      target: { value: 'wrong-password' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }))

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Email or password is incorrect',
    )
  })

  it('signs out of the browser session', async () => {
    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })
    mockNoContentResponse()

    render(<App />)

    fireEvent.click(await screen.findByRole('button', { name: 'Sign out' }))

    expect(
      await screen.findByRole('heading', { name: 'Sign in' }),
    ).toBeInTheDocument()
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/v1/session',
      expect.objectContaining({ method: 'DELETE' }),
    )
  })

  it('renders exercises from the API', async () => {
    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })

    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'Exercises' }))

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
    fireEvent.click(await screen.findByRole('button', { name: 'Exercises' }))

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
      expect(fetch).toHaveBeenCalledTimes(5)
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
    fireEvent.click(await screen.findByRole('button', { name: 'Exercises' }))

    fireEvent.click(await screen.findByText('Incline Dumbbell Press'))
    fireEvent.change(screen.getByLabelText('Name'), {
      target: { value: 'Incline Press' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(5)
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
    fireEvent.click(await screen.findByRole('button', { name: 'Exercises' }))

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
    fireEvent.click(await screen.findByRole('button', { name: 'Exercises' }))

    fireEvent.click(await screen.findByText('Incline Dumbbell Press'))
    fireEvent.click(screen.getByRole('button', { name: 'Archive' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(5)
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
    expect(await screen.findByText('Upper Body')).toBeInTheDocument()
    expect(screen.getByText('0 exercises')).toBeInTheDocument()
  })

  it('renders completed workout history from the API', async () => {
    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ workout_sessions: [completedSession], meta: {} })

    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'History' }))

    expect(
      await screen.findByRole('heading', { name: 'History' }),
    ).toBeInTheDocument()
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/v1/workout_sessions?status=completed',
      expect.anything(),
    )
    expect(screen.getAllByText('Upper Body').length).toBeGreaterThanOrEqual(2)
    expect(screen.getByText('Upper Chest Press')).toBeInTheDocument()
    expect(screen.getByText('8 reps')).toBeInTheDocument()
    expect(screen.getByText('65 load')).toBeInTheDocument()

    const notPerformedRow = screen.getByText('Not Performed').parentElement
    if (!notPerformedRow) {
      throw new Error('Expected a row for the not-performed set')
    }

    expect(within(notPerformedRow).getAllByText('-')).toHaveLength(2)
  })

  it('edits a completed workout history set with lock version', async () => {
    const updatedSet = {
      ...completedSession.exercises[0].workout_session_sets[0],
      actual_reps: 7,
      actual_load_value: 62.5,
      lock_version: 2,
    }

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress], meta: {} })
    mockJsonResponse({ workout_sessions: [completedSession], meta: {} })
    mockJsonResponse({ workout_session_set: updatedSet })

    render(<App />)
    fireEvent.click(await screen.findByRole('button', { name: 'History' }))

    expect(await screen.findByText('8 reps')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Edit set 1' }))
    fireEvent.change(screen.getByLabelText('Set 1 actual reps'), {
      target: { value: '7' },
    })
    fireEvent.change(screen.getByLabelText('Set 1 actual load'), {
      target: { value: '62.5' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(5)
    })
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/v1/workout_session_sets/session-set-1',
      expect.objectContaining({ method: 'PATCH' }),
    )
    expect(lastWorkoutSessionSetRequest()).toMatchObject({
      actual_reps: 7,
      actual_load_value: 62.5,
      completion_state: 'completed',
      lock_version: 1,
    })
    expect(await screen.findByText('7 reps')).toBeInTheDocument()
    expect(screen.getByText('62.5 load')).toBeInTheDocument()
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
      expect(fetch).toHaveBeenCalledTimes(4)
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
      expect(fetch).toHaveBeenCalledTimes(3)
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
      expect(fetch).toHaveBeenCalledTimes(4)
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

  it('loads routines for authoring', async () => {
    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })
    mockJsonResponse({ routines: [dailyRehab], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })

    render(<App />)

    fireEvent.click(await screen.findByRole('button', { name: 'Routines' }))

    expect(
      await screen.findByRole('heading', { name: 'Routines' }),
    ).toBeInTheDocument()
    fireEvent.click(await screen.findByRole('button', { name: /Daily Rehab/ }))

    expect(screen.getByDisplayValue('Move slowly.')).toBeInTheDocument()
    expect(screen.getByText('1. Dead Bug')).toBeInTheDocument()
    expect(screen.getByDisplayValue('Each side')).toBeInTheDocument()
  })

  it('creates a routine with exercise targets', async () => {
    const savedRoutine = {
      ...dailyRehab,
      id: 'routine-2',
      name: 'Core Reset',
      notes: null,
      items: [dailyRehab.items[0]],
    } satisfies Routine

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })
    mockJsonResponse({ routines: [], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })
    mockJsonResponse({ routine: savedRoutine }, 201)

    render(<App />)

    fireEvent.click(await screen.findByRole('button', { name: 'Routines' }))
    fireEvent.change(await screen.findByLabelText('Name'), {
      target: { value: 'Core Reset' },
    })
    fireEvent.change(screen.getByLabelText('Add routine exercise'), {
      target: { value: deadBug.id },
    })
    fireEvent.change(screen.getByLabelText('Item 1 target mode'), {
      target: { value: 'reps' },
    })
    fireEvent.change(screen.getByLabelText('Item 1 sets'), {
      target: { value: '3' },
    })
    fireEvent.change(screen.getByLabelText('Item 1 target reps'), {
      target: { value: '8' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(6)
    })
    expect(fetch).toHaveBeenLastCalledWith(
      '/api/v1/routines',
      expect.objectContaining({ method: 'POST' }),
    )
    expect(lastRoutineRequest()).toMatchObject({
      name: 'Core Reset',
      notes: null,
      items: [
        {
          position: 1,
          exercise_id: deadBug.id,
          target_mode: 'reps',
          sets: 3,
          target_reps: 8,
        },
      ],
    })
  })

  it('persists reordered routine items', async () => {
    const reorderedRoutine = {
      ...dailyRehab,
      lock_version: 1,
      items: [dailyRehab.items[1], dailyRehab.items[0]],
    } satisfies Routine

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })
    mockJsonResponse({ routines: [dailyRehab], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })
    mockJsonResponse({ routine: reorderedRoutine })

    render(<App />)

    fireEvent.click(await screen.findByRole('button', { name: 'Routines' }))
    fireEvent.click(await screen.findByRole('button', { name: /Daily Rehab/ }))
    fireEvent.click(screen.getAllByRole('button', { name: 'Move Down' })[0])
    fireEvent.click(screen.getByRole('button', { name: 'Save' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(6)
    })
    expect(fetch).toHaveBeenLastCalledWith(
      `/api/v1/routines/${dailyRehab.id}`,
      expect.objectContaining({ method: 'PATCH' }),
    )
    expect(lastRoutineRequest()).toMatchObject({
      lock_version: 0,
      items: [
        { id: 'routine-item-2', position: 1 },
        { id: 'routine-item-1', position: 2 },
      ],
    })
  })

  it('archives a routine', async () => {
    const archivedRoutine = {
      ...dailyRehab,
      archived_at: '2026-10-07T00:00:00.000Z',
      lock_version: 1,
    } satisfies Routine

    mockJsonResponse({ workout_templates: [], meta: {} })
    mockJsonResponse({ exercises: [], meta: {} })
    mockJsonResponse({ routines: [dailyRehab], meta: {} })
    mockJsonResponse({ exercises: [inclinePress, deadBug], meta: {} })
    mockJsonResponse({ routine: archivedRoutine })

    render(<App />)

    fireEvent.click(await screen.findByRole('button', { name: 'Routines' }))
    fireEvent.click(await screen.findByRole('button', { name: /Daily Rehab/ }))
    fireEvent.click(screen.getByRole('button', { name: 'Archive' }))

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(6)
    })
    expect(lastRoutineRequest()).toMatchObject({
      archived_at: expect.any(String),
      lock_version: 0,
    })
    expect(await screen.findByText('No routines found.')).toBeInTheDocument()
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

function mockNoContentResponse() {
  vi.mocked(fetch).mockResolvedValueOnce(new Response(null, { status: 204 }))
}

function sessionRequest() {
  const call = vi.mocked(fetch).mock.calls[1]
  const init = call?.[1] as RequestInit | undefined
  const body = JSON.parse(init?.body as string) as {
    session: {
      email_address: string
      password: string
    }
  }

  return body.session
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

function lastRoutineRequest() {
  const lastCall = vi.mocked(fetch).mock.calls.at(-1)
  const init = lastCall?.[1] as RequestInit | undefined
  const body = JSON.parse(init?.body as string) as {
    routine: Record<string, unknown>
  }

  return body.routine
}

function lastWorkoutSessionSetRequest() {
  const lastCall = vi.mocked(fetch).mock.calls.at(-1)
  const init = lastCall?.[1] as RequestInit | undefined
  const body = JSON.parse(init?.body as string) as {
    workout_session_set: Record<string, unknown>
  }

  return body.workout_session_set
}
