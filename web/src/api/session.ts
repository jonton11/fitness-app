export type User = {
  id: string
  email_address: string
}

type UserResponse = {
  user: User
}

type ErrorResponse = {
  errors?: Array<{
    message: string
  }>
}

export async function getCurrentUser(): Promise<User | null> {
  const response = await fetch('/api/v1/session', {
    headers: { Accept: 'application/json' },
  })

  if (response.status === 401) {
    return null
  }

  return parseUserResponse(response)
}

export async function createSession(
  emailAddress: string,
  password: string,
): Promise<User> {
  const response = await fetch('/api/v1/session', {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      session: {
        email_address: emailAddress,
        password,
      },
    }),
  })

  return parseUserResponse(response)
}

export async function deleteSession(): Promise<void> {
  const response = await fetch('/api/v1/session', {
    method: 'DELETE',
    headers: { Accept: 'application/json' },
  })

  if (!response.ok) {
    throw await sessionError(response)
  }
}

async function parseUserResponse(response: Response): Promise<User> {
  if (!response.ok) {
    throw await sessionError(response)
  }

  const body = (await response.json()) as UserResponse
  return body.user
}

async function sessionError(response: Response): Promise<Error> {
  const body = (await response.json().catch(() => null)) as ErrorResponse | null
  const message = body?.errors?.[0]?.message

  return new Error(message ?? `Session request failed with ${response.status}`)
}
