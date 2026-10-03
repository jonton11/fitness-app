# Rails API Guidance

These rules apply to the Rails API under `api/`.

## Rails Standards

- Prefer Rails conventions and the app's existing controller/service/serializer
  patterns over new framework layers.
- Do not introduce non-Rails patterns, extra gems, or service boundaries when
  Rails conventions already cover the job.
- Keep controllers thin: parameter handling, status mapping, and rendering belong
  there; domain state transitions belong in models or service objects.
- Use strong parameters for all client-controlled attributes.
- Keep validations close to the model and mirror critical database invariants
  with check constraints where practical.
- Prefer Active Record migration helpers such as `rename_table`,
  `rename_column`, `add_check_constraint`, `remove_check_constraint`,
  `add_index`, and `remove_index` over raw SQL. Use raw SQL only when Rails does
  not expose the needed database behavior, and make that reason clear in the
  migration.
- Keep migrations reversible with `change` when Rails can infer the inverse, or
  with symmetric `up`/`down` methods when it cannot. Avoid hand-renaming or
  over-specifying generated indexes and constraints unless a stable database
  object name is part of the app contract.
- Preserve optimistic locking behavior on mutable resources where the API already
  exposes `lock_version` and handles `ActiveRecord::StaleObjectError`.
- Avoid `update_all`, `delete_all`, and validation-skipping persistence unless
  the code explains why bypassing callbacks/validations is safe.

## Testing

- Cover API endpoints with integration tests for success, validation errors,
  not-found errors, and stale object conflicts when locking applies.
- Cover service objects with focused unit tests for state transitions and edge
  cases.
- For migration changes, verify both directions in test or development using
  `env RAILS_ENV=test asdf exec bundle exec rails db:migrate db:rollback db:migrate`
  when local database access is available.
- Prefer realistic Active Record records over heavy mocking for persistence
  behavior.

## Code Review Rules

### Rails API contracts

- Flag endpoints that return inconsistent error envelopes, status codes, or
  serializer shapes compared with nearby controllers.
- Flag PATCH/update code that overwrites fields omitted by the client unless
  replacement semantics are intentional and tested.
- Flag mutable endpoints that can lose concurrent edits when nearby resources
  use Rails optimistic locking.
- Flag controller code that accepts unpermitted or overly broad client input.

### Persistence integrity

- Flag model-only invariants that should also be enforced by the database,
  especially for workout history, completion state, ownership, or ordering.
- Flag migrations that add constraints or non-null columns without accounting
  for existing rows and rollback/deploy safety.
- Flag migrations that use raw SQL, adapter-specific DDL, or hand-managed
  constraint/index renames when the same change can be expressed with clear
  Active Record migration helpers.
- Flag validations whose blank/present behavior mishandles valid zero values.
- Flag uniqueness validations that are not backed by a matching unique index
  when duplicates would corrupt user-visible data.

### Rails performance

- Treat performance as an evidence question. Prefer query plans, query counts,
  logs, or benchmarks over intuition.
- Flag N+1 queries and repeated database work in serializers, controllers, and
  views. Use eager loading deliberately, and verify it matches the query shape.
- Flag new filtering, ordering, or joins that lack supporting indexes on
  realistic data paths.
- Do not accept caching as the first fix for slow code. The uncached path should
  be understood and reasonably efficient first.

### Rails maintainability

- Flag duplicated serialization logic when an existing serializer can be reused.
- Flag service objects that hide surprising defaults or side effects instead of
  making state transitions explicit.
- Flag tests that assert only happy paths for user-visible data mutations.
