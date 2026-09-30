import { render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import App from './App'

describe('App', () => {
  beforeEach(() => {
    vi.stubGlobal('fetch', vi.fn())
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it('renders the web client shell', () => {
    vi.mocked(fetch).mockRejectedValue(new Error('offline'))

    render(<App />)

    expect(screen.getByRole('heading', { name: 'Fitness' })).toBeInTheDocument()
  })

  it('shows the API as online when the health check succeeds', async () => {
    vi.mocked(fetch).mockResolvedValue(
      new Response(JSON.stringify({ status: 'ok' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }),
    )

    render(<App />)

    expect(screen.getByRole('status')).toHaveTextContent('API: Checking')
    expect(await screen.findByText('API: Online')).toBeInTheDocument()
    expect(fetch).toHaveBeenCalledWith('/api/v1/health', {
      headers: { Accept: 'application/json' },
    })
  })

  it('shows the API as offline when the health check fails', async () => {
    vi.mocked(fetch).mockResolvedValue(new Response(null, { status: 503 }))

    render(<App />)

    expect(await screen.findByText('API: Offline')).toBeInTheDocument()
  })
})
