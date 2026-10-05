# Personal Fitness App — Codex Handoff Specification

**Status:** Ready for implementation  
**Source of truth:** This document. Mockups are visual references and do not override behavior defined here.  
**Initial user model:** Single-user personal application.  
**Initial data migration:** None. Start fresh; do not import the existing spreadsheet.

---

## 1. Product Goal

Build a personal fitness system with two clients sharing one backend:

- **iPhone app (SwiftUI):** optimized for fast, low-friction workout execution at the gym.
- **Web app (React + TypeScript):** optimized for overview, configuration, template/exercise management, historical review/editing, analytics, and health overview.
- **Rails REST API:** canonical shared application/domain layer.
- **PostgreSQL:** canonical shared datastore.
- **Local iPhone persistence:** local-first workout execution with asynchronous sync to Rails.

The app is for one person initially. Avoid multi-tenant, social, subscription, coaching-marketplace, or public-user abstractions unless a current requirement needs them.

The core UX principle is:

> If the app already knows a value, prefill it. During a workout, the user should primarily record what changed.

---

## 2. High-Level Architecture

```text
SwiftUI iPhone app
  ├─ SwiftUI UI
  ├─ local SQLite-backed persistence
  ├─ offline sync queue
  └─ HealthKit
          │
          │ HTTPS / JSON REST
          ▼
      Rails API
          │
          ▼
      PostgreSQL
          ▲
          │ HTTPS / JSON REST
          │
React + TypeScript web app
```

### Architectural ownership

**Rails owns shared business rules**, including:

- progression calculation;
- next-session target generation;
- workout completion behavior;
- historical recalculation;
- exercise/template archive behavior;
- substitution relationships;
- validation of domain invariants;
- normalization of shared health data.

**iOS owns device-specific behavior**, including:

- local persistence;
- offline workout execution;
- sync queue/outbox;
- HealthKit access;
- rest-timer presentation;
- iOS navigation/state.

**React owns web presentation/configuration**, not shared fitness business logic.

Do not independently reimplement progression rules in React and Swift.

---

## 3. Technology Choices

### iOS

- SwiftUI
- local SQLite-backed persistence
- prefer Apple-native persistence first; introduce a third-party SQLite library only if a concrete sync requirement justifies it
- HealthKit
- Keychain for API credentials/tokens
- TestFlight distribution

### Web

- React
- TypeScript
- Vite
- standard browser `fetch` or a small typed API wrapper
- avoid Next.js because Rails owns the backend and server-side domain logic

### Backend

- Rails in API-oriented mode
- PostgreSQL
- resource-oriented REST API
- JSON
- `/api/v1` namespace
- services for application/domain workflows

### Infrastructure

- Docker / Docker Compose
- primary production host: user's Windows PC
- private remote connectivity: Tailscale
- reverse proxy/TLS: Caddy or equivalent simple reverse proxy
- production host is private; do not expose Rails/Postgres directly to the public internet
- same deployment must be portable to macOS for manual failover

### CI/CD

- GitHub Actions
- Windows production host runs a self-hosted GitHub Actions runner
- merge/push to protected `main` triggers production deployment after CI passes
- Mac may have a separate failover runner/label but is not automatically promoted

---

## 4. Repository Structure

Use a monorepo.

```text
fitness/
├── api/                 # Rails
├── web/                 # React + TypeScript + Vite
├── ios/                 # SwiftUI project
├── docs/
│   ├── SPEC.md
│   └── mockups/
├── deployment/
│   ├── caddy/
│   ├── scripts/
│   └── backup/
├── docker-compose.yml
├── .github/
│   └── workflows/
└── README.md
```

Do not create separate repositories for clients/backend in v1.

---

## 5. Product Vocabulary

Use these terms consistently in code, API payloads, database tables, tests, and UI copy.

### Exercise

A reusable exercise definition.

Examples:

- Flat Barbell Bench Press
- Incline Dumbbell Press
- Incline Smith Press
- Cable Lateral Raise
- Jefferson Curl
- Dead Bug

An exercise is not itself a workout prescription.

### Workout Template

Reusable definition of a strength workout, e.g.:

- Upper
- Core and Arms
- Legs (Strength)

A template contains ordered **Workout Template Slots**.

### Workout Template Slot

A position/training intent inside a template.

Example:

```text
Upper Chest Press
default exercise: Incline Dumbbell Press
allowed substitutes:
- Incline Smith Press
- Incline Machine Press
```

The slot contains the workout-specific prescription.

### Exercise Option / Substitute

An exercise allowed to fulfill a template slot.

Each exercise option retains its own progression/history.

### Workout Session

A dated instance of a workout template that the user actually starts.

### Session Exercise

The exercise actually selected/performed for a slot during one workout session.

This may differ from the template's default exercise because of substitution.

### Set Prescription

What the workout intends the user to perform.

Examples:

- warm-up: 4–6 reps at 65% of working load;
- working set: 5–8 reps;
- 3 total working sets.

### Set Result

What the user actually did:

- actual reps;
- actual load;
- completion state.

### Routine

A recurring rehab/mobility/checklist-style group of exercises that does not inherently use progressive overload.

### Activity

A non-set-based activity such as:

- Basketball
- Rest Day
- Recovery
- Other

### Health Metric

Normalized health data originating from HealthKit or future integrations.

---

## 6. Exercise Model

An exercise should support at least:

```text
id
name
primary_muscle_group
secondary_muscle_groups[]
load_type
notes
external_url
archived_at
created_at
updated_at
lock_version
```

### Notes

Use a single freeform Notes field rather than separate description/setup fields.

Examples:

```text
Incline 45 degrees
Bench setting notch 4
Keep knees straight
Ball between legs
```

Notes may be multi-line and should support longer rehab instructions.

### External link

A generic optional URL.

Typical use:

- YouTube technique video;
- physio reference;
- external tutorial.

Do not model it specifically as a YouTube field.

### Load types

Support explicit load semantics:

```text
lb
kg
machine_stack
plate_count
bodyweight
bodyweight_plus_added
assisted
none
```

The display value for `machine_stack` is an equipment-relative value, not a claim about equivalent physical resistance.

Example:

```text
Cable Lateral Raise
Load type: machine_stack
Load: 12.5
```

That means "12.5 on this machine/setup".

### Progression increment

If automatic load progression is enabled for an exercise option, the user must be able to configure the load increment appropriate to that exercise/equipment.

Examples:

```text
Dumbbells: +5
Cable stack: +2.5
Smith: +10
```

Do not guess equivalence across equipment.

---

## 7. Exercise Archiving

v1 has **Archive/Restore**, not permanent deletion.

Archiving an exercise:

- preserves all historical workout data;
- preserves historical references;
- removes it from normal "add exercise" choices;
- removes it from normal substitute choices;
- flags active workout templates that still reference it;
- does not silently remove it from templates;
- permits later restoration.

If a template references an archived exercise, show a clear state such as:

```text
Archived exercise — replace or restore
```

Do not implement destructive permanent delete in v1.

---

## 8. Workout Template Model

A Workout Template includes:

```text
id
name
notes (optional)
archived_at
created_at
updated_at
lock_version
```

A template has ordered slots.

A slot includes at least:

```text
id
workout_template_id
position
label / training_intent
default_exercise_id
rest_seconds
created_at
updated_at
lock_version
```

Examples of `label / training_intent`:

```text
Upper Chest Press
Side Delt Isolation
Horizontal Pull
```

A slot may also carry muscle/focus tags used for suggestion heuristics.

### Exercise options for a slot

Represent default + substitutes explicitly.

Example:

```text
slot: Upper Chest Press

default:
- Incline Dumbbell Press

allowed:
- Incline Smith Press
- Incline Machine Press
```

Substitutes are user-built organically.

Do not preload a huge exercise library.

---

## 9. Set Prescriptions

A template slot may contain ordered set prescriptions.

Support at least:

```text
set_type:
- warmup
- working

position
rep_min
rep_max
load_strategy
load_value (nullable depending on strategy)
```

Possible load strategies can include:

```text
working_load
percentage_of_working_load
explicit
bodyweight
none
```

Warm-up support is required because the source training structure contains warm-up sets.

Historical sessions must preserve the prescription that existed when the session started, even if the template changes later.

---

## 10. Workout Template CRUD

Users can:

- create template;
- read template;
- edit template;
- archive/restore template;
- add/remove slots;
- reorder slots;
- change default exercise;
- manage substitutes;
- configure set prescriptions;
- configure rest time;
- configure starting/next load and progression increment.

### Template edit semantics

Template edits affect **future sessions**, not completed history.

Do not rewrite completed workout sessions because a template changed.

---

## 11. Starting a Workout

Starting a template creates a Workout Session snapshot.

First-ever session:

- use template defaults;
- use configured starting loads.

Later sessions:

- populate planned targets using the progression state derived by Rails from previous completed performance.

Do not require a pre-created chain of future workout session records.

The next workout should feel pre-populated, but the implementation may generate that snapshot when the user previews/starts the next session.

---

## 12. Active Workout UX

The user must be able to perform exercises in any order.

The app must not force:

```text
Exercise 1
then Exercise 2
then Exercise 3
```

The active workout behaves like a completion list.

Example:

```text
Upper

○ Flat Barbell Bench Press
○ Incline Dumbbell Press
○ Overhead Machine Press
○ Weighted Pull-Ups
○ Cable Lateral Raises
```

Tapping any exercise opens its current set.

This is important because equipment may be occupied.

---

## 13. Primary Set Logging Interaction

Optimize for one-handed, minimal-input gym usage.

Primary screen should answer:

- what exercise am I doing?
- what set am I on?
- what is the target?
- how many reps did I do?

Example:

```text
Incline Dumbbell Press

Set 2 of 3
Target: 65 lb × 5–8

Reps
[-]  7  [+]

[ Save Set ]
```

The planned load is prefilled.

Normally the user changes only reps.

Weight/load is editable, but secondary.

The "last performance" may be available as secondary/expandable context, but it is not required in the primary layout.

---

## 14. Rest Timer

Saving a completed set starts the configured rest timer automatically.

Example:

```text
✓ 65 lb × 7 saved

Rest
2:59
```

The timer is presentation/device behavior.

Saving the set must succeed locally even if the server is unreachable.

---

## 15. Exercise Substitution During a Workout

From an active exercise, the user can choose **Swap Exercise**.

The UI should show:

```text
Existing substitutes
- Incline Smith Press
- Incline Machine Press

+ Add New Substitute
```

Selecting an existing substitute:

- replaces the exercise for the current session slot;
- loads that substitute's own planned/history state;
- does not overwrite the default exercise's progression;
- records the substitute as the exercise actually performed.

After the session, the next workout may still default to the template's normal/default exercise.

---

## 16. Add New Substitute During Workout

The user must be able to create a new exercise without abandoning the active workout.

Minimum creation fields:

```text
name
load_type
primary_muscle_group
secondary_muscle_groups (optional)
notes (optional)
external_url (optional)
progression_increment (if automatic progression is enabled)
```

After save:

1. add it to the exercise library;
2. associate it with the current slot as an allowed substitute;
3. select it for the current workout session.

Do not require a prebuilt exercise catalog.

---

## 17. Workout Completion and Incomplete Workouts

The active workout must have a top-level overflow/action menu.

Include at least:

```text
Finish Workout
Skip Exercise
Add Exercise
Cancel Workout
```

A user may finish at any point.

Distinguish:

```text
completed
attempted_but_target_not_met
not_performed
```

Never encode "not performed" as `0 reps`.

### Finish behavior

When the user chooses Finish Workout:

- preserve every completed/attempted result;
- remaining planned sets/exercises become not performed;
- save the session;
- run progression calculation only from relevant performed working sets;
- carry unchanged targets forward for not-performed work.

---

## 18. Progression Rules

v1 should use a simple double-progression rule.

For a slot/exercise option:

- planned load is prefilled;
- each working set has a target rep range;
- warm-up sets do not determine progression.

### Default "clear" rule

An exercise is considered cleared at the current load when **all required working sets meet or exceed the top of the target rep range**.

Example:

```text
Target: 3 × 5–8 at 65 lb

65 × 8
65 × 8
65 × 8
=> clear
```

Next target:

```text
65 + configured progression increment
```

If not cleared:

```text
65 × 8
65 × 7
65 × 6
=> not clear
=> next session stays at 65
```

If the exercise was not performed:

- no performance judgment;
- carry the current target forward.

### Manual override

The user may explicitly override a calculated future target.

Store the distinction between:

```text
calculated target
manual override
```

Historical recalculation must not silently destroy an explicit manual override.

---

## 19. Progression State

Do not model future workouts primarily as duplicated future rows.

Maintain progression state sufficient to build the next session.

Progression should be scoped so that:

- different exercise variants retain independent progression;
- the same exercise can have different prescriptions in different workout slots/templates.

A reasonable scope is:

```text
workout_template_slot + exercise_option
```

Completed history remains immutable historical records unless explicitly edited.

---

## 20. Historical Editing

The web app supports correcting completed workouts.

Typical use:

```text
Recorded:
65 × 8
65 × 8
65 × 8

Corrected:
65 × 8
65 × 7
65 × 6
```

When historical performance changes:

1. save the corrected historical data;
2. recalculate affected derived progression state from that point forward;
3. preserve explicit manual overrides unless the user intentionally removes/changes them.

Historical edits should be uncommon but supported.

The iPhone remains the primary writer during active workout execution.

---

## 21. Routines / Rehab

Rehab/mobility uses the same Exercise library but a different workflow.

Examples:

- Jefferson Curls
- Dead Bugs
- Hip Openers
- Hip Rotations
- Standing Posterior Pelvic Tilts

A Routine includes:

```text
name
notes (optional)
ordered routine items
archived_at
```

Routine item supports:

```text
exercise_id
position
target mode:
- completion_only
- reps
- duration
- load_optional

sets (optional)
target reps (optional)
target duration (optional)
notes override (optional)
```

### Routine principles

- progressive overload is not assumed;
- emphasize form, mobility, consistency, and completion;
- routine UI can behave like a checklist;
- no built-in reminder system in v1.

Example:

```text
Daily Rehab

○ Hip rotations          3 × 10
○ Pelvic tilts           3 × 10
○ Dead bugs              3 × 8 / side
○ Jefferson curls        2 × 10
```

---

## 22. Activities

Support simple non-set-based activities:

```text
Basketball
Rest Day
Recovery
Other
```

An Activity should support at least:

```text
kind
started_at / date
ended_at (optional)
notes (optional)
focus tags / muscle impact tags (optional)
source:
- manual
- healthkit
- oura (future)
```

v1 only requires manual activity creation.

Basketball does not need sets/reps.

---

## 23. Suggested Workout

Do not implement a rigid rotation such as:

```text
Upper → Core and Arms → Legs → repeat
```

Real life can interrupt sequence:

```text
Mon: Upper
Tue: Basketball
Wed: Rest
Thu: ?
```

On Thursday, Upper may be a better suggestion because upper body has had several days away while lower body was recently active.

### v1 suggestion model

Keep this deliberately simple.

Inputs:

- template focus/muscle tags;
- last meaningful activity per focus/muscle group;
- completed workouts;
- manual Basketball/Rest/Recovery activities.

The suggestion is informational.

The user can always start any template.

UI wording should be **Suggested**, not **Next Up**, because the app does not own the schedule.

Do not use Oura readiness/recovery scoring to drive v1 suggestions.

---

## 24. Health Overview

The app should support a profile/health overview backed by normalized health metrics.

Target metrics may include:

```text
body weight
body fat percentage
steps
active energy
dietary calories
protein
carbohydrates
fat
sleep duration
heart rate
```

The iPhone reads HealthKit and uploads normalized records to Rails.

Architecture:

```text
Oura / MyFitnessPal / Renpho
          ↓
      Apple Health
          ↓
       HealthKit
          ↓
       iPhone
          ↓
        Rails
          ↓
      PostgreSQL
          ↓
   Web + iPhone views
```

Not every proprietary Oura metric will be available through Apple Health. Direct proprietary Oura integration is out of scope for v1.

### Permissions

Request only HealthKit permissions needed for metrics actually displayed/synced.

The app must work if HealthKit access is denied.

Do not block workout functionality on health permissions.

---

## 25. Out of Scope for v1

Do not implement:

- automatic Oura activity importing/grouping;
- automatic linking/merging fragmented Oura Basketball records;
- advanced readiness/recovery coaching;
- large built-in exercise database;
- permanent destructive exercise deletion;
- built-in reminder/notification scheduling for rehab;
- social features;
- public profiles;
- subscriptions/payments;
- multi-tenant organizations;
- complex AI coaching;
- spreadsheet history import.

The data model should not intentionally make future external activity imports impossible, but do not build those features now.

---

## 26. iPhone Navigation

Primary navigation:

```text
Home
Workouts
Exercises
History
```

Potential Health/Profile surface may be added as health functionality is implemented.

### Home

- Suggested workout
- quick Start Workout
- quick Log Activity
- recent status

### Workouts

- Workout Templates
- Routines
- create/edit/archive templates/routines

### Exercises

- exercise library
- create
- edit
- archive/restore

### History

- workout sessions
- routines
- activities

---

## 27. Web Priorities

Primary web areas:

```text
Dashboard
Workout Templates
Exercise Library
Workout History
Historical Editing
Progression / Analytics
Health Overview
Settings / Integrations
```

The web does not need to reproduce the exact gym-optimized set-entry experience.

The web is optimized for:

- overview;
- bulk/easy editing;
- template design;
- exercise management;
- historical review;
- corrections;
- analytics.

---

## 28. REST API Standards

Follow conventional REST semantics.

### Conventions

- namespace: `/api/v1`
- JSON request/response bodies
- nouns/resources in URLs
- HTTP verbs convey intent
- standard status codes
- predictable validation error structure
- pagination for collection endpoints that can grow
- filter/sort via query parameters where appropriate
- no business logic duplicated in clients
- use UUIDs as public record identifiers
- timestamps serialized as ISO-8601 UTC
- include `lock_version`/version data where conflict detection matters

### Example resources

```text
GET    /api/v1/exercises
POST   /api/v1/exercises
GET    /api/v1/exercises/:id
PATCH  /api/v1/exercises/:id

GET    /api/v1/workout_templates
POST   /api/v1/workout_templates
GET    /api/v1/workout_templates/:id
PATCH  /api/v1/workout_templates/:id

POST   /api/v1/workout_sessions
GET    /api/v1/workout_sessions/:id
PATCH  /api/v1/workout_sessions/:id

POST   /api/v1/workout_session_sets
PATCH  /api/v1/workout_session_sets/:id

GET    /api/v1/routines
POST   /api/v1/routines

GET    /api/v1/activities
POST   /api/v1/activities

GET    /api/v1/health_metrics
POST   /api/v1/health_metrics
```

Archive/restore should preferably be represented as ordinary state changes (e.g. `archived_at`) through PATCH rather than unnecessary RPC-style endpoints.

### Validation error shape

Use one stable shape.

Example:

```json
{
  "errors": [
    {
      "field": "name",
      "code": "blank",
      "message": "Name can't be blank"
    }
  ]
}
```

### Idempotency

Phone sync operations that may be retried must be idempotent.

Use client-generated UUIDs for locally created records so replaying a create does not duplicate data.

---

## 29. Authentication

Single-user only in v1.

Requirements:

- no public sign-up flow;
- one user is provisioned explicitly;
- web uses a secure HTTP-only session or similarly simple secure browser auth;
- iOS uses a bearer/API credential stored in Keychain;
- both map to the same User;
- Tailscale/private network is an additional network boundary, not a substitute for application auth.

Do not build roles/permissions/admin panels unless needed later.

---

## 30. Local-First iPhone Sync

### Ownership model

During an active workout:

```text
iPhone = authoritative writer for workout execution
```

This includes:

- selected exercise/substitute;
- actual reps;
- actual load;
- completed/skipped state;
- session finish state.

After successful sync:

```text
Rails/Postgres = canonical shared history
```

Web primarily manages:

- exercises;
- templates;
- notes;
- substitutions;
- configuration;
- historical corrections.

### Local save behavior

`Save Set` must:

1. persist locally immediately;
2. update UI immediately;
3. enqueue sync;
4. never wait on network before acknowledging the set.

### Sync outbox

Maintain a local outbox containing pending mutations.

Operations should be retried safely.

Client-created records use UUIDs generated before server sync.

### Pulling server changes

On app launch/foreground and at useful checkpoints:

- push pending local changes;
- pull newer server-managed configuration;
- update templates/exercises without disrupting an active session snapshot.

An active Workout Session must remain stable even if the underlying template changes during the session.

---

## 31. Conflict Handling

Do not use naive "latest timestamp wins" globally.

Use optimistic versioning.

Rails records that can be edited across clients should include `lock_version` (or equivalent).

Example flow:

```text
client read version 4
client PATCHes with version 4

if server is still version 4:
  apply change
  return version 5

if server is already version 5:
  return conflict
```

Use HTTP `409 Conflict` (or equivalent clear conflict response).

### Expected conflict frequency

Low, because ownership is intentionally separated:

- active workout execution: phone-owned;
- template/exercise configuration: usually web/server-owned;
- historical correction: explicit server edit.

### Conflict UX

Never silently destroy one side.

For v1, if an unexpected conflict cannot be automatically resolved safely:

- keep local data;
- mark sync as needing attention;
- show a concise conflict/retry state.

Do not build a complex Google-Docs-style merge editor.

---

## 32. Dates, Timezones, and Units

- store timestamps in UTC;
- serialize ISO-8601;
- maintain user timezone preference (initially America/Vancouver);
- render local date/time in clients;
- never infer `0` to mean skipped/not performed;
- units/load types are explicit;
- do not convert `machine_stack` values into lb/kg.

---

## 33. Database Guidelines

Use PostgreSQL as canonical server data store.

Use:

- UUID primary keys;
- foreign keys;
- `NOT NULL` constraints where appropriate;
- unique indexes for actual invariants;
- Rails validations for user-facing validation;
- database constraints for data integrity;
- optimistic locking where cross-client edits are possible.

Do not use schemaless JSON as a substitute for normal relational modeling when the relationships are known.

JSON/JSONB is appropriate only for genuinely flexible metadata, not core domain entities.

---

## 34. Rails Code Style

Core philosophy:

```text
Slim controllers
Slim models
Fat services
```

### Controllers

Own HTTP concerns:

- params;
- auth;
- status code;
- serialization;
- calling application services.

Do not put progression/recalculation/sync workflows directly in controllers.

### Models

Own:

- persistence;
- associations;
- validations;
- simple model-local invariants/behavior.

Avoid turning ActiveRecord models into giant workflow objects.

Avoid critical cross-domain behavior hidden in callbacks.

### Services

Use explicit, well-named services for meaningful workflows.

Examples:

```text
WorkoutSessions::Start
WorkoutSessions::Complete
WorkoutSessions::SwapExercise
Progression::CalculateNextTarget
Progression::RecalculateFromHistory
Sync::ApplyMutation
HealthMetrics::Ingest
```

Avoid generic `Utils`, `Manager`, or `Helper` dumping grounds.

A service should exist because a coherent workflow exists, not because "service objects are the architecture".

---

## 35. React Code Style

Use feature-oriented organization.

Example:

```text
src/
├── app/
├── api/
├── components/
└── features/
    ├── exercises/
    ├── workoutTemplates/
    ├── workoutHistory/
    ├── routines/
    ├── activities/
    └── health/
```

Requirements:

- TypeScript;
- functional components;
- hooks;
- explicit typed API contracts;
- keep server state separate from local UI state;
- no progression/business logic duplicated from Rails;
- reusable components only after genuine reuse exists;
- avoid premature component factories/abstraction layers;
- ESLint + Prettier in CI.

---

## 36. SwiftUI Code Style

Use feature-oriented organization.

Example:

```text
Features/
├── Home/
├── Workout/
├── Exercises/
├── Routines/
├── History/
└── Health/

Data/
├── API/
├── LocalStore/
└── Sync/

Models/
```

Views should primarily present state and emit user intent.

Do not place persistence/network/sync workflows directly in SwiftUI View bodies.

Device-specific responsibilities may live in observable feature models/services:

```text
start workout
save set locally
swap exercise
manage rest timer
queue sync
read HealthKit
```

Rails remains the source of shared progression/domain rules.

---

## 37. No-AI-Slop Engineering Standard

Generated code must look intentionally authored.

Avoid:

- comments explaining obvious syntax;
- redundant comments restating method names;
- speculative extensibility;
- unnecessary interfaces/protocols;
- wrappers around one-line library calls without value;
- "manager" classes with unclear responsibility;
- generic helper dumping grounds;
- deeply layered architecture for hypothetical future users;
- excessive defensive checks where invariants are already enforced;
- duplicated validation/business logic across clients;
- enormous files created because generation is easier than design;
- placeholder TODOs when the current requirement can be completed now;
- verbose README prose generated merely to document obvious code.

Prefer:

- boring, explicit names;
- small cohesive units;
- straightforward Rails conventions;
- simple data flow;
- refactoring only when actual repetition/complexity appears;
- code that another engineer can read without reverse-engineering agent intent.

Key rule:

> Implement the simplest design that cleanly satisfies the current spec. Do not introduce abstractions for hypothetical future requirements.

---

## 38. Git and Commit Strategy

The repository history must tell the story of the application being built.

Do **not** create one giant:

```text
Initial commit
```

containing the entire generated system.

Codex may structure commits itself, but it must commit incrementally as coherent work is completed.

### Commit requirements

Every commit must be:

- atomic;
- cohesive;
- understandable in isolation;
- easy to revert;
- in a working state;
- accompanied by relevant tests;
- limited to one meaningful change;
- free of unrelated refactors.

### Authorship

All commits must use the user's configured Git identity.

Never add:

```text
Co-authored-by: Codex
Co-authored-by: ChatGPT
Generated-by: AI
```

or any other AI/pairing attribution/trailer.

Do not alter Git author identity to an AI/tool identity.

If Git author identity is missing, stop before committing and require the user to configure their own Git identity.

### Commit messages

Use lightweight Conventional Commit-style prefixes:

```text
feat:
fix:
refactor:
chore:
docs:
```

Examples:

```text
chore: scaffold rails api
chore: configure postgres and docker compose
chore: scaffold react application
chore: scaffold swiftui application
feat: add exercise domain model
feat: add exercise rest endpoints
feat: add exercise library
feat: add exercise archiving
feat: add workout template slots
feat: generate workout session from template
fix: preserve manual progression override
refactor: extract progression calculator
```

### Tests and commits

Tests are **not separate commits** from the behavior they validate.

Avoid:

```text
feat: add exercise archiving
test: add exercise archiving tests
```

Prefer one commit:

```text
feat: add exercise archiving
```

containing implementation + relevant tests.

### Database migrations

A migration and the application behavior that requires it should normally land in the same atomic commit.

### Branching

Use short-lived feature/fix branches.

Examples:

```text
feat/exercise-library
feat/workout-template-editor
feat/ios-set-logging
fix/progression-carry-forward
```

Use pull requests even for solo development where practical.

Squash-merging the feature PR into `main` is acceptable, but the branch itself should still be built as a coherent sequence while work is in progress.

### Pull request descriptions

Pull requests that change user-facing UI must include screenshots showing the changed screen or state.

---

## 39. Testing Strategy

Tests protect behavior; do not chase coverage metrics for their own sake.

### Rails

Prioritize:

- service/domain tests for progression;
- request/API tests;
- model constraint/validation tests where useful;
- historical recalculation;
- archive semantics;
- substitution behavior;
- incomplete workout behavior;
- sync/idempotency/conflict behavior.

### React

Prioritize user-visible workflows:

- template/exercise CRUD;
- archive/restore states;
- historical edit flows;
- validation/errors.

Do not over-test trivial presentational implementation details.

### SwiftUI

Prioritize:

- local save before network;
- active workout state;
- set completion;
- out-of-order exercises;
- substitution;
- sync queue;
- conflict state;
- timer behavior where logic is nontrivial.

### CI rule

Relevant tests, linting, and builds must pass before deployment.

Do not commit knowingly broken builds.

---

## 40. CI/CD and Deployment

### Pipeline

Expected production flow:

```text
feature branch
    ↓
PR / CI
    ↓
merge to main
    ↓
CI
    ↓
production deploy job
    ↓
self-hosted Windows runner
    ↓
pre-migration Postgres backup
    ↓
Rails migrations
    ↓
build/update Docker services
    ↓
health check
    ↓
success
```

### Production services

Docker Compose should run:

```text
reverse proxy (Caddy)
Rails API
PostgreSQL
React static web
```

Exact composition may combine React static serving with the proxy if that keeps the setup simpler.

### Restart behavior

Production containers should automatically restart after host reboot.

The Windows machine is the normal authoritative server.

---

## 41. Private Networking

Use Tailscale for remote private access.

Goals:

- no public Rails endpoint;
- no router port forwarding;
- no purchased domain required;
- iPhone and Mac can reach production while away from home;
- PostgreSQL is never exposed directly to clients.

Use HTTPS for application traffic.

---

## 42. Backups and Recovery

PostgreSQL is canonical shared data and must be backed up.

### Required backups

- automatic backup before production migrations;
- scheduled local `pg_dump`;
- retention sufficient to recover from accidental bad deployments/edits;
- maintain at least one copy that can be restored on the Mac when practical.

Because the dataset is tiny, favor simple full logical dumps over complicated incremental systems.

A sensible v1 retention default:

```text
14 daily backups
+ pre-deploy backups for recent deployments
```

Do not commit database backups to Git.

### Restore

Document and script:

```text
backup
restore
verify
```

A restore should be testable without inventing a new process during an incident.

---

## 43. Manual Mac Failover

Use a **single active server**.

Normal:

```text
Windows = authoritative production server
Mac     = client + potential failover host
```

Do not build automatic multi-primary database replication.

If Windows becomes unavailable for an extended period:

1. obtain latest safe PostgreSQL backup;
2. start same Docker Compose stack on Mac;
3. restore backup;
4. promote Mac manually;
5. point clients to promoted server configuration;
6. ensure only one server is authoritative/writable.

Do not attempt automatic leader election or distributed database failover in v1.

---

## 44. Observability

Keep observability local and simple.

Required:

- structured Rails logs;
- deployment logs;
- sync failure logs;
- basic client-visible sync state;
- `/health` endpoint;
- database connectivity included in health verification where appropriate.

Do not add paid monitoring/observability services in v1.

---

## 45. API Compatibility

TestFlight clients may lag behind backend deployments.

Therefore:

- avoid breaking response shapes casually;
- add fields compatibly;
- version intentionally;
- keep `/api/v1` backward compatible within v1;
- remove/rename fields only with an explicit migration plan.

---

## 46. Security / Secrets

Never commit:

- `.env`;
- API tokens;
- passwords;
- signing secrets;
- Apple credentials;
- production database dumps;
- Tailscale credentials.

Use environment variables / local secret storage appropriate to each runtime.

The private Tailscale network does not remove the need for app auth and TLS.

---

## 47. Mockups

Mockups are visual references.

Recommended filenames:

```text
00-overview.png
01-home.png
02-workout-templates.png
03-create-workout-template.png
04-edit-exercise-in-template.png
05-exercise-library.png
06-archive-exercise.png
07-start-workout.png
08-active-set-tracking.png
09-swap-exercise.png
10-add-new-substitute.png
11-log-other-activities.png
12-history-and-suggestions.png
```

Use them for:

- hierarchy;
- density;
- interaction intent;
- rough visual language.

Do not treat generated placeholder text, exact spacing, or every pixel as a requirement.

If mockup and this document disagree, **this document wins**.

---

## 48. Suggested Implementation Order

The implementation should be incremental and usable as early as possible.

### Phase 0 — Repository and infrastructure foundation

Deliver:

- monorepo;
- Rails API scaffold;
- React/Vite scaffold;
- SwiftUI scaffold;
- Docker Compose;
- PostgreSQL;
- basic Rails health endpoint;
- CI lint/test/build;
- no giant bootstrap commit.

Acceptance:

- each app builds;
- Rails connects to Postgres;
- web can call `/api/v1/health` in development;
- CI passes.

### Phase 1 — Exercise library

Deliver:

- exercise schema;
- REST CRUD;
- archive/restore;
- React exercise library;
- basic iOS exercise read/create/edit as needed;
- load types;
- notes/external URL;
- tests.

Acceptance:

- create/edit/archive/restore exercise;
- archived exercises disappear from normal selection;
- data persists through Rails/Postgres.

### Phase 2 — Workout templates

Deliver:

- templates;
- ordered slots;
- exercise options/substitutes;
- prescriptions;
- reorder UI;
- rest time;
- progression increment configuration.

Acceptance:

- build an Upper template manually from fresh exercises;
- add/reorder slots;
- configure default exercise/substitutes;
- save/reload from both clients where relevant.

### Phase 3 — Workout execution

Deliver:

- start session from template;
- snapshot prescriptions;
- local iPhone persistence;
- active workout checklist;
- out-of-order execution;
- reps-first set logging;
- editable load;
- rest timer;
- finish incomplete workout;
- substitution.

Acceptance:

- workout can be completed with server unavailable;
- user can jump between exercises;
- saving a set is immediate;
- incomplete session preserves correct states.

### Phase 4 — Sync

Deliver:

- client UUIDs;
- outbox/retry;
- optimistic locking;
- idempotent mutation replay;
- pull of server configuration;
- conflict handling.

Acceptance:

- workout logged offline later syncs exactly once;
- retries do not duplicate sets;
- web template edit reaches phone;
- active session snapshot is not mutated underneath the user.

### Phase 5 — Progression

Deliver:

- progression state;
- clear/not-clear calculation;
- automatic next target;
- manual override;
- recalculation after historical edit.

Acceptance:

```text
3×8 at 65 with target 5–8
=> next target increases by configured increment

8/7/6 at 65
=> next target remains 65

not performed
=> target remains unchanged
```

Historical correction recomputes derived state without erasing explicit overrides.

### Phase 6 — Routines and activities

Deliver:

- rehab routines;
- checklist-style completion;
- manual Basketball / Rest / Recovery / Other;
- history.

Acceptance:

- user can create daily rehab routine;
- routine does not force progression;
- Basketball can be logged without set tracking.

### Phase 7 — Suggested workout

Deliver simple heuristic based on recency/focus tags.

Acceptance:

- suggestion is not a forced schedule;
- recent Basketball can influence lower-body recency;
- user can start any workout regardless of suggestion.

### Phase 8 — HealthKit / Health overview

Deliver:

- explicit HealthKit permissions;
- normalized sync to Rails;
- basic health dashboard.

Acceptance:

- health permissions may be denied without affecting workouts;
- selected metrics can be viewed on web after iPhone sync.

### Phase 9 — Production deployment

Deliver:

- Windows Docker production deployment;
- Tailscale access;
- Caddy/TLS;
- GitHub Actions self-hosted deployment;
- pre-migration backup;
- health check;
- restart-on-boot;
- documented Mac failover.

Acceptance:

- merge to `main` deploys only after CI passes;
- failed health check is visible and does not silently report success;
- production survives Windows reboot;
- iPhone can sync remotely over private network.

---

## 49. Definition of Done for a Feature

A feature is not done merely because UI exists.

A feature is done when applicable:

- schema/migration exists;
- API contract exists;
- Rails behavior exists;
- client behavior exists;
- validations/errors exist;
- tests ship in the same commit(s);
- offline implications are handled;
- archive/history implications are handled;
- relevant mockup intent is met;
- CI passes;
- documentation is updated when behavior would otherwise be unclear.

---

## 50. Codex Working Rules

Before coding a feature:

1. read this spec;
2. inspect existing code and conventions;
3. identify the smallest coherent implementation slice;
4. plan atomic commits;
5. implement + test that slice;
6. commit using the user's Git identity;
7. continue to the next slice.

Do not:

- rewrite unrelated code;
- create a giant "initial app" commit;
- add speculative architecture;
- add AI attribution to Git history;
- separate tests from the feature/fix they validate;
- silently make product decisions that contradict this spec;
- implement out-of-scope features merely because they are convenient;
- duplicate Rails business logic in both clients.

When a requirement is genuinely ambiguous and materially affects behavior, stop and ask rather than inventing a new product rule.

---

# End of Specification
