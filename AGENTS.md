# Repository Guidance

This repository contains a Rails API, a React/Vite web client, and a SwiftUI iOS
client for a personal fitness tracker.

## General Standards

- Prefer small, behavior-focused changes over broad refactors.
- Use framework conventions and existing app patterns before adding custom
  architecture, extra services, or new libraries.
- Avoid new service boundaries unless the current app boundary is causing a
  concrete operational, ownership, or scaling problem.
- Keep existing API response shapes stable unless the change explicitly updates
  the contract and all clients/tests.
- Preserve user data and historical workout records. Treat destructive updates,
  silent overwrites, and lossy migrations as high-risk.
- Add focused tests for changed behavior, especially API contracts, persistence
  rules, and client-visible edge cases.
- Use existing local patterns before adding new abstractions or dependencies.
- Prefer durable guardrails over prompt-only expectations: encode repeatable
  checks in tests, types, lint rules, database constraints, or CI where possible.

## Verification

- Rails API: `cd api && asdf exec bundle exec rails test`
- Rails style: `cd api && env RUBOCOP_CACHE_ROOT=tmp/rubocop_cache asdf exec bundle exec rubocop`
- Rails security: `cd api && asdf exec bundle exec brakeman --no-pager`
- Web: `cd web && npm run lint && npm run format && npm run test && npm run build`
- iOS: `cd ios && env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FitnessApp.xcodeproj -scheme FitnessApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing`

## Git Hygiene

- Keep commits atomic: each commit should represent one coherent behavior,
  refactor, documentation, or infrastructure change.
- Use lowercase Conventional Commit subjects matching the existing history, such
  as `feat: add workout template domain model`, `refactor: extract nested api
  serializers`, `docs: document local development commands`, or `chore: setup
  foundation ci`.
- Avoid vague repair subjects like `fix this`, `update this`, `changes`, or
  `misc`. Name the behavior or structure that changed.
- Prefer follow-up commits that can be understood independently. Before merge,
  squash or reword cleanup-only commits when they only correct earlier commits in
  the same branch.

## Code Review Rules

### Review posture

- Prioritize correctness, data loss, security, concurrency, migrations, and
  missing tests over style preferences.
- Findings should be actionable and tied to specific changed lines.
- Do not flag purely cosmetic issues when RuboCop, formatters, or compiler
  checks already cover them.
- Treat failing or unrun relevant tests as residual risk, but distinguish that
  from a code defect.

### API compatibility

- Flag changes that break existing clients without versioning, migration, or
  explicit contract updates.
- Partial update endpoints should preserve omitted attributes unless the API
  explicitly documents replacement semantics.
- Responses should use the repository's existing serializer and error envelope
  patterns.

### Data safety

- Flag migrations or service code that can drop, overwrite, or reinterpret
  fitness history without a clear migration path.
- Important model invariants should generally be backed by database constraints
  when the existing schema already uses constraints for the same class of rule.

### Performance

- Flag likely N+1 queries, unbounded queries, missing pagination, missing indexes
  for new lookup paths, and caching used to hide an inefficient uncached path.
- Ask for measurement when a change claims to improve performance.
