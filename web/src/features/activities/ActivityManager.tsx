import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'

import {
  ActivityApiError,
  activityKinds,
  createActivity,
  listActivities,
} from '../../api/activities'
import type {
  Activity,
  ActivityKind,
  ActivityPayload,
} from '../../api/activities'

type ActivityDraft = {
  kind: ActivityKind
  startedAt: string
  hasEndTime: boolean
  endedAt: string
  notes: string
  focusTags: string
}

const pageSize = 50

export function ActivityManager() {
  const [activities, setActivities] = useState<Activity[]>([])
  const [total, setTotal] = useState(0)
  const [draft, setDraft] = useState<ActivityDraft>(() => newDraft())
  const [errors, setErrors] = useState<string[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isLoadingMore, setIsLoadingMore] = useState(false)
  const [isSaving, setIsSaving] = useState(false)

  useEffect(() => {
    let isCurrent = true

    listActivities(0, pageSize)
      .then((page) => {
        if (isCurrent) {
          setActivities(page.activities)
          setTotal(page.total)
          setErrors([])
        }
      })
      .catch(() => {
        if (isCurrent) {
          setErrors(['Could not load activity history.'])
        }
      })
      .finally(() => {
        if (isCurrent) {
          setIsLoading(false)
        }
      })

    return () => {
      isCurrent = false
    }
  }, [])

  function updateDraft(changes: Partial<ActivityDraft>) {
    setDraft((current) => ({ ...current, ...changes }))
    setErrors([])
  }

  async function saveActivity(event: FormEvent) {
    event.preventDefault()
    const payload = payloadFromDraft(draft)

    if ('errors' in payload) {
      setErrors(payload.errors)
      return
    }

    setIsSaving(true)
    setErrors([])

    try {
      const activity = await createActivity(payload)
      setActivities((current) => [
        activity,
        ...current.filter((item) => item.id !== activity.id),
      ])
      setTotal((current) => current + 1)
      setDraft(newDraft())
    } catch (error) {
      setErrors(errorMessages(error, 'Could not log activity.'))
    } finally {
      setIsSaving(false)
    }
  }

  async function loadMore() {
    if (isLoadingMore || activities.length >= total) {
      return
    }

    setIsLoadingMore(true)

    try {
      const page = await listActivities(activities.length, pageSize)
      const existingIDs = new Set(activities.map((activity) => activity.id))
      setActivities((current) => [
        ...current,
        ...page.activities.filter((activity) => !existingIDs.has(activity.id)),
      ])
      setTotal(page.total)
    } catch {
      setErrors(['Could not load more activity history.'])
    } finally {
      setIsLoadingMore(false)
    }
  }

  return (
    <main className="app-shell">
      <section className="library-layout" aria-labelledby="activities-title">
        <header className="library-header">
          <div>
            <p className="eyebrow">Manual Activity</p>
            <h1 id="activities-title">Activities</h1>
          </div>
        </header>

        <div className="library-grid activity-grid">
          <section className="library-list" aria-label="Activity history">
            <h2>History</h2>
            <div className="activity-history" aria-busy={isLoading}>
              {isLoading ? (
                <p className="empty-state">Loading activities...</p>
              ) : null}
              {!isLoading && activities.length === 0 ? (
                <p className="empty-state">No activities logged yet.</p>
              ) : null}
              {activities.map((activity) => (
                <ActivityHistoryRow activity={activity} key={activity.id} />
              ))}
            </div>
            {activities.length < total ? (
              <button
                className="secondary-button activity-load-more"
                type="button"
                onClick={loadMore}
                disabled={isLoadingMore}
              >
                {isLoadingMore ? 'Loading...' : 'Load More'}
              </button>
            ) : null}
          </section>

          <section
            className="editor-panel"
            aria-labelledby="activity-editor-title"
          >
            <h2 id="activity-editor-title">Log Activity</h2>
            {errors.length ? (
              <div className="error-list" role="alert">
                {errors.map((error) => (
                  <p key={error}>{error}</p>
                ))}
              </div>
            ) : null}
            <form className="exercise-form" onSubmit={saveActivity}>
              <fieldset className="activity-kind-fieldset">
                <legend className="field-label">Activity type</legend>
                <div className="activity-kind-options">
                  {activityKinds.map((kind) => (
                    <button
                      aria-pressed={draft.kind === kind}
                      className={draft.kind === kind ? 'selected' : ''}
                      key={kind}
                      type="button"
                      onClick={() => updateDraft({ kind })}
                    >
                      {activityKindLabel(kind)}
                    </button>
                  ))}
                </div>
              </fieldset>

              <label className="field-label">
                Started at
                <input
                  className="text-input"
                  type="datetime-local"
                  value={draft.startedAt}
                  onChange={(event) =>
                    updateDraft({ startedAt: event.target.value })
                  }
                  required
                />
              </label>

              <label className="activity-toggle">
                <input
                  type="checkbox"
                  checked={draft.hasEndTime}
                  onChange={(event) =>
                    updateDraft({
                      hasEndTime: event.target.checked,
                      endedAt: event.target.checked
                        ? draft.endedAt || draft.startedAt
                        : '',
                    })
                  }
                />
                Include end time
              </label>

              {draft.hasEndTime ? (
                <label className="field-label">
                  Ended at
                  <input
                    className="text-input"
                    type="datetime-local"
                    value={draft.endedAt}
                    onChange={(event) =>
                      updateDraft({ endedAt: event.target.value })
                    }
                    required
                  />
                </label>
              ) : null}

              <label className="field-label">
                Notes (optional)
                <textarea
                  className="text-input notes-input"
                  value={draft.notes}
                  onChange={(event) =>
                    updateDraft({ notes: event.target.value })
                  }
                />
              </label>

              <label className="field-label">
                Focus tags (optional)
                <input
                  className="text-input"
                  value={draft.focusTags}
                  onChange={(event) =>
                    updateDraft({ focusTags: event.target.value })
                  }
                  placeholder="Lower Body, Cardio"
                />
              </label>

              <div className="form-actions">
                <button
                  className="primary-button"
                  type="submit"
                  disabled={isSaving}
                >
                  {isSaving ? 'Saving...' : 'Log Activity'}
                </button>
              </div>
            </form>
          </section>
        </div>
      </section>
    </main>
  )
}

function ActivityHistoryRow({ activity }: { activity: Activity }) {
  return (
    <article className={`activity-row activity-${activity.kind}`}>
      <div className="activity-row-heading">
        <strong>{activityKindLabel(activity.kind)}</strong>
        <span>{formatDate(activity.started_at)}</span>
      </div>
      {activity.ended_at ? (
        <small>{durationLabel(activity.started_at, activity.ended_at)}</small>
      ) : null}
      {activity.notes ? <p>{activity.notes}</p> : null}
      {activity.focus_tags.length ? (
        <div className="activity-tags">
          {activity.focus_tags.map((tag) => (
            <span key={tag}>{tag}</span>
          ))}
        </div>
      ) : null}
    </article>
  )
}

function newDraft(now = new Date()): ActivityDraft {
  return {
    kind: 'rest_day',
    startedAt: localDateTimeValue(now),
    hasEndTime: false,
    endedAt: '',
    notes: '',
    focusTags: '',
  }
}

function payloadFromDraft(
  draft: ActivityDraft,
): ActivityPayload | { errors: string[] } {
  const startedAt = new Date(draft.startedAt)
  if (Number.isNaN(startedAt.getTime())) {
    return { errors: ['Enter a valid start time.'] }
  }

  let endedAt: Date | null = null
  if (draft.hasEndTime) {
    endedAt = new Date(draft.endedAt)
    if (Number.isNaN(endedAt.getTime())) {
      return { errors: ['Enter a valid end time.'] }
    }
    if (endedAt < startedAt) {
      return { errors: ['End time must be at or after the start time.'] }
    }
  }

  return {
    kind: draft.kind,
    started_at: startedAt.toISOString(),
    ended_at: endedAt?.toISOString() ?? null,
    notes: draft.notes.trim() || null,
    focus_tags: uniqueTags(draft.focusTags),
  }
}

function uniqueTags(value: string): string[] {
  return [
    ...new Set(
      value
        .split(',')
        .map((tag) => tag.trim())
        .filter(Boolean),
    ),
  ]
}

function localDateTimeValue(date: Date): string {
  const offsetDate = new Date(
    date.getTime() - date.getTimezoneOffset() * 60_000,
  )
  return offsetDate.toISOString().slice(0, 16)
}

function activityKindLabel(kind: ActivityKind): string {
  switch (kind) {
    case 'rest_day':
      return 'Rest Day'
    case 'basketball':
      return 'Basketball'
    case 'recovery':
      return 'Recovery'
    case 'other':
      return 'Other'
  }
}

function formatDate(value: string): string {
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value))
}

function durationLabel(startedAt: string, endedAt: string): string {
  const minutes = Math.max(
    0,
    Math.round(
      (new Date(endedAt).getTime() - new Date(startedAt).getTime()) / 60_000,
    ),
  )
  return `${minutes} min`
}

function errorMessages(error: unknown, fallback: string): string[] {
  if (error instanceof ActivityApiError) {
    return error.errors.map((item) => item.message)
  }

  return [fallback]
}
