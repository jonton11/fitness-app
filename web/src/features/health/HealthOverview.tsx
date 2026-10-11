import { useEffect, useState } from 'react'

import { healthMetricKinds, listHealthMetrics } from '../../api/healthMetrics'
import type { HealthMetric, HealthMetricKind } from '../../api/healthMetrics'

type HealthMetricsByKind = Record<HealthMetricKind, HealthMetric[]>

type HealthOverviewState =
  | { status: 'loading' }
  | { status: 'error' }
  | {
      status: 'loaded'
      metricsByKind: HealthMetricsByKind
      refreshedAt: Date
    }

const metricDetails: Record<
  HealthMetricKind,
  { label: string; description: string }
> = {
  body_weight: { label: 'Body Weight', description: 'Latest measurement' },
  body_fat_percentage: {
    label: 'Body Fat',
    description: 'Latest measurement',
  },
  steps: { label: 'Steps', description: 'Latest synced sample' },
  active_energy: {
    label: 'Active Energy',
    description: 'Latest synced sample',
  },
  sleep_duration: {
    label: 'Sleep',
    description: 'Latest sleep segment',
  },
  resting_heart_rate: {
    label: 'Resting Heart Rate',
    description: 'Latest measurement',
  },
}

const readingDateFormatter = new Intl.DateTimeFormat(undefined, {
  dateStyle: 'medium',
  timeStyle: 'short',
})

const refreshTimeFormatter = new Intl.DateTimeFormat(undefined, {
  timeStyle: 'short',
})

const numberFormatter = new Intl.NumberFormat(undefined, {
  maximumFractionDigits: 0,
})

export function HealthOverview() {
  const [state, setState] = useState<HealthOverviewState>({
    status: 'loading',
  })
  const [selectedKind, setSelectedKind] =
    useState<HealthMetricKind>('body_weight')
  const [isRefreshing, setIsRefreshing] = useState(false)

  useEffect(() => {
    let isCurrent = true

    loadMetricsByKind()
      .then((metricsByKind) => {
        if (isCurrent) {
          setState({
            status: 'loaded',
            metricsByKind,
            refreshedAt: new Date(),
          })
        }
      })
      .catch(() => {
        if (isCurrent) {
          setState({ status: 'error' })
        }
      })

    return () => {
      isCurrent = false
    }
  }, [])

  async function refreshHealthMetrics() {
    setIsRefreshing(true)

    try {
      const metricsByKind = await loadMetricsByKind()
      setState({ status: 'loaded', metricsByKind, refreshedAt: new Date() })
    } catch {
      setState({ status: 'error' })
    } finally {
      setIsRefreshing(false)
    }
  }

  if (state.status === 'loading') {
    return (
      <main className="app-shell">
        <section
          className="library-layout health-layout"
          aria-labelledby="health-title"
          aria-busy="true"
        >
          <HealthHeader />
          <p className="empty-state">Loading health data...</p>
        </section>
      </main>
    )
  }

  if (state.status === 'error') {
    return (
      <main className="app-shell">
        <section
          className="library-layout health-layout"
          aria-labelledby="health-title"
        >
          <HealthHeader />
          <div className="health-error" role="alert">
            <h2>Health data could not be loaded</h2>
            <p>Check the server connection, then try again.</p>
            <button
              className="secondary-button"
              type="button"
              onClick={() => void refreshHealthMetrics()}
            >
              Retry
            </button>
          </div>
        </section>
      </main>
    )
  }

  const selectedMetrics = state.metricsByKind[selectedKind]

  return (
    <main className="app-shell">
      <section
        className="library-layout health-layout"
        aria-labelledby="health-title"
      >
        <HealthHeader
          refreshedAt={state.refreshedAt}
          isRefreshing={isRefreshing}
          onRefresh={() => void refreshHealthMetrics()}
        />

        <div className="health-metric-grid" aria-label="Latest health metrics">
          {healthMetricKinds.map((kind) => {
            const latestMetric = state.metricsByKind[kind][0]
            const details = metricDetails[kind]

            return (
              <button
                aria-pressed={selectedKind === kind}
                className={`health-metric-card${selectedKind === kind ? ' selected' : ''}`}
                key={kind}
                type="button"
                onClick={() => setSelectedKind(kind)}
              >
                <span>{details.label}</span>
                <strong>
                  {latestMetric ? formatMetricValue(latestMetric) : 'No data'}
                </strong>
                <small>
                  {latestMetric
                    ? readingDateFormatter.format(
                        new Date(latestMetric.ended_at),
                      )
                    : 'Waiting for Apple Health sync'}
                </small>
              </button>
            )
          })}
        </div>

        <section className="health-readings" aria-labelledby="readings-title">
          <div className="health-readings-heading">
            <div>
              <p className="eyebrow">{metricDetails[selectedKind].label}</p>
              <h2 id="readings-title">Recent Readings</h2>
            </div>
            <span>{metricDetails[selectedKind].description}</span>
          </div>

          {selectedMetrics.length === 0 ? (
            <p className="empty-state health-empty-state">
              No {metricDetails[selectedKind].label.toLowerCase()} readings have
              synced yet.
            </p>
          ) : (
            <div className="health-reading-list">
              {selectedMetrics.map((metric) => (
                <article className="health-reading-row" key={metric.id}>
                  <div>
                    <strong>{formatMetricValue(metric)}</strong>
                    <span>
                      {readingDateFormatter.format(new Date(metric.ended_at))}
                    </span>
                  </div>
                  <small>Apple Health</small>
                </article>
              ))}
            </div>
          )}
        </section>
      </section>
    </main>
  )
}

async function loadMetricsByKind(): Promise<HealthMetricsByKind> {
  const metricsByKind: HealthMetricsByKind = {
    body_weight: [],
    body_fat_percentage: [],
    steps: [],
    active_energy: [],
    sleep_duration: [],
    resting_heart_rate: [],
  }

  await Promise.all(
    healthMetricKinds.map(async (kind) => {
      metricsByKind[kind] = (await listHealthMetrics(kind)).healthMetrics
    }),
  )

  return metricsByKind
}

function HealthHeader({
  refreshedAt,
  isRefreshing = false,
  onRefresh,
}: {
  refreshedAt?: Date
  isRefreshing?: boolean
  onRefresh?: () => void
}) {
  return (
    <header className="library-header health-header">
      <div>
        <p className="eyebrow">Apple Health</p>
        <h1 id="health-title">Health</h1>
        <p className="health-intro">
          Measurements synced securely from your iPhone.
        </p>
      </div>
      {refreshedAt && onRefresh ? (
        <div className="health-refresh">
          <span>Updated {refreshTimeFormatter.format(refreshedAt)}</span>
          <button
            className="secondary-button"
            type="button"
            onClick={onRefresh}
            disabled={isRefreshing}
          >
            {isRefreshing ? 'Refreshing...' : 'Refresh'}
          </button>
        </div>
      ) : null}
    </header>
  )
}

function formatMetricValue(metric: HealthMetric) {
  switch (metric.kind) {
    case 'body_weight':
      return `${metric.value.toFixed(1)} kg`
    case 'body_fat_percentage':
      return `${metric.value.toFixed(1)}%`
    case 'steps':
      return `${numberFormatter.format(metric.value)} steps`
    case 'active_energy':
      return `${numberFormatter.format(metric.value)} kcal`
    case 'sleep_duration': {
      const totalMinutes = Math.round(metric.value)
      const hours = Math.floor(totalMinutes / 60)
      const minutes = totalMinutes % 60
      return hours > 0 ? `${hours}h ${minutes}m` : `${minutes} min`
    }
    case 'resting_heart_rate':
      return `${numberFormatter.format(metric.value)} bpm`
  }
}
