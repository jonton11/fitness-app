import { useEffect, useState } from 'react'

import { fetchHealth } from './api/health'

type ApiStatus = 'checking' | 'online' | 'offline'

const statusLabels: Record<ApiStatus, string> = {
  checking: 'Checking',
  online: 'Online',
  offline: 'Offline',
}

function App() {
  const [apiStatus, setApiStatus] = useState<ApiStatus>('checking')

  useEffect(() => {
    let isCurrent = true

    fetchHealth()
      .then((health) => {
        if (isCurrent) {
          setApiStatus(health.status === 'ok' ? 'online' : 'offline')
        }
      })
      .catch(() => {
        if (isCurrent) {
          setApiStatus('offline')
        }
      })

    return () => {
      isCurrent = false
    }
  }, [])

  return (
    <main className="app-shell">
      <section className="app-panel" aria-labelledby="app-title">
        <p className="eyebrow">Personal fitness</p>
        <h1 id="app-title">Fitness</h1>
        <p className="lede">Web client foundation is running.</p>
        <p className="api-status" role="status">
          <span className={`status-dot ${apiStatus}`} aria-hidden="true" />
          API: {statusLabels[apiStatus]}
        </p>
      </section>
    </main>
  )
}

export default App
