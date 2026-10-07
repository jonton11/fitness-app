import { type FormEvent, useState } from 'react'

import type { User } from '../../api/session'

type LoginProps = {
  onLogin: (emailAddress: string, password: string) => Promise<User>
}

export function Login({ onLogin }: LoginProps) {
  const [emailAddress, setEmailAddress] = useState('')
  const [password, setPassword] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setIsSubmitting(true)

    try {
      await onLogin(emailAddress, password)
    } catch (submissionError) {
      setError(
        submissionError instanceof Error
          ? submissionError.message
          : 'Unable to sign in',
      )
      setIsSubmitting(false)
    }
  }

  return (
    <main className="login-shell">
      <section className="login-panel" aria-labelledby="login-heading">
        <p className="eyebrow">Fitness</p>
        <h1 id="login-heading">Sign in</h1>
        <form className="login-form" onSubmit={handleSubmit}>
          {error ? (
            <div className="error-list" role="alert">
              <p>{error}</p>
            </div>
          ) : null}
          <label>
            <span className="field-label">Email address</span>
            <input
              className="text-input"
              type="email"
              autoComplete="username"
              value={emailAddress}
              onChange={(event) => setEmailAddress(event.target.value)}
              required
              autoFocus
            />
          </label>
          <label>
            <span className="field-label">Password</span>
            <input
              className="text-input"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
            />
          </label>
          <button
            className="primary-button login-button"
            type="submit"
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
      </section>
    </main>
  )
}
