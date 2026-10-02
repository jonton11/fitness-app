# Web Client Guidance

These rules apply to the React, TypeScript, and Vite client under `web/`.

## TypeScript Standards

- Prefer precise domain types and useful inference over broad annotations.
- Avoid `any`. Use `unknown` at untrusted boundaries, then narrow deliberately.
- Prefer discriminated unions for UI state that has distinct modes, such as
  loading, loaded, empty, error, and submitting.
- Do not use type assertions to silence a real mismatch between the Rails API
  response and the client model.
- Keep Rails API response types close to the fetch/client boundary so changes in
  server contracts are easy to audit.

## React Standards

- Keep server state, form state, and view state separate.
- Preserve loading, empty, error, and optimistic-update states for user-facing
  workflows.
- Prefer small components that match product workflows over generic abstractions
  that hide data flow.
- Keep accessibility and keyboard interaction intact when changing forms,
  dialogs, tables, or navigation.

## Code Review Rules

### Type safety

- Flag type assertions, `any`, or widened string/object types that hide possible
  API contract drift.
- Flag duplicated client-side copies of server enums unless there is a test or
  clear synchronization path.
- Flag changes that make impossible UI states representable when a union type
  could model the state accurately.

### Client behavior

- Flag UI changes that drop loading, empty, error, disabled, or retry states.
- Flag mutations that can leave local UI state inconsistent with the Rails API
  response.
- Flag tests that cover only rendered happy paths while skipping user events,
  validation errors, or failed requests.
